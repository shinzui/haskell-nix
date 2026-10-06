#!/usr/bin/env python3
"""Export and inventory recorded inputs; never build inside contributor checkouts."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def capture(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def mori_path(uri):
    # Mori writes its canonical reference on stderr; stdout is the resolved path.
    return Path(capture(["mori", "path", uri]).splitlines()[-1])


def write_json(path, data):
    path.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")


def deployed_haskell_versions(metadata, names):
    """Classify build-graph metadata; this is diagnostic, not executable parity."""
    # Nix supports both the legacy direct map and the versioned JSON envelope.
    graph = metadata.get("derivations", metadata)
    if not isinstance(graph, dict):
        raise ValueError("Nix derivation metadata must contain a derivation map")
    versions = {}
    for record in graph.values():
        if not isinstance(record, dict):
            raise ValueError("invalid Nix derivation metadata record")
        env = record.get("env", {})
        # These phases and scripts identify the pinned Haskell generic builder.
        # Native libraries, compilers and source-vendor artifacts can have the
        # same basename as a Haskell package; their names establish no role.
        is_haskell = (
            "setupCompilerEnvironmentPhase" in env.get("prePhases", "").split()
            and "compileBuildDriverPhase" in env.get("preConfigurePhases", "").split()
            and bool(env.get("setupCompilerEnvironmentPhase"))
            and bool(env.get("compileBuildDriverPhase"))
        )
        name, version = env.get("pname"), env.get("version")
        if not is_haskell or name not in names:
            continue
        if not isinstance(version, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", version):
            raise ValueError(f"invalid Haskell derivation version for {name}: {version!r}")
        # Floors retain every observed Haskell version through their maximum;
        # manifests must later verify all instances and the actual root edges.
        if name not in versions or tuple(map(int, version.split("."))) > tuple(map(int, versions[name].split("."))):
            versions[name] = version
    return versions


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--reuse-solves", type=Path,
                        help="Use existing scratch exports after checking their recorded revision markers")
    args = parser.parse_args()
    root = Path.cwd()
    contributors = json.loads((root / "cabal/contributors.json").read_text())
    inputs = json.loads((root / "cabal/inventory-inputs.json").read_text())
    run(["cabal", "build", "exe:haskell-nix-update"])
    cli = capture(["cabal", "list-bin", "exe:haskell-nix-update"])
    scratch = args.reuse_solves or Path(tempfile.mkdtemp(prefix="cohort-inventory-", dir="/tmp"))
    print(f"Inventory scratch: {scratch}", flush=True)
    for contributor in contributors:
        name = contributor["name"]
        export = scratch / name
        marker = export / ".cohort-recorded-revision"
        if args.reuse_solves:
            if not marker.exists() or marker.read_text().strip() != contributor["revision"]:
                raise ValueError(f"{name}: reused export lacks matching recorded revision")
        else:
            source = mori_path(contributor["mori"])
            export.mkdir()
            archive = subprocess.Popen(["git", "-C", str(source), "archive", "--format=tar",
                                        contributor["revision"]], stdout=subprocess.PIPE)
            run(["tar", "-x", "-C", str(export)], stdin=archive.stdout)
            archive.stdout.close()
            if archive.wait() != 0:
                raise RuntimeError(f"{name}: git archive failed")
            marker.write_text(contributor["revision"] + "\n")
            for config in contributor["configurations"]:
                command = ["cabal", "build", "all", "--dry-run", "--enable-tests", "--enable-benchmarks"]
                if contributor["indexStateOverride"]:
                    command.append("--index-state=" + contributor["indexStateOverride"])
                for package, flags in sorted(config["flags"].items()):
                    command.append("--constraint=" + package + " " + flags)
                # Separate build directories prevent one flag configuration overwriting another.
                command += ["--builddir=dist-cohort-" + config["name"]]
                with (scratch / (name + "-" + config["name"] + ".log")).open("w") as log:
                    run(command, cwd=export, stdout=log, stderr=subprocess.STDOUT)
        for config in contributor["configurations"]:
            builddir = "dist-newstyle" if args.reuse_solves else "dist-cohort-" + config["name"]
            suffix = "" if config["name"] == "default" else "-" + config["name"]
            run([cli, "cohort", "inventory", "--contributor", name,
                 "--configuration", config["name"], "--source", str(export),
                 "--plan", str(export / builddir / "cache/plan.json"),
                 "--out", "cabal/inventory/" + name + suffix + ".json"])
    inventories = [json.loads(p.read_text()) for p in (root / "cabal/inventory").glob("*.json")
                   if p.name != "nix.json"]
    names = sorted({name for inventory in inventories for name in inventory["packages"]})
    names_file = scratch / "names.json"
    write_json(names_file, names)
    # Pin the package scope to the recorded channel revision. This is selection
    # evidence; final application manifests belong to the consumer plans.
    channel_ref = "git+file://" + str(root) + "?rev=" + inputs["channelRevision"]
    expression = '''let
      flake = builtins.getFlake %s;
      pkgs = import flake.inputs.nixpkgs { system = %s; overlays = [ flake.overlays.github ]; };
      hp = pkgs.haskell.packages.ghc9124;
      names = builtins.fromJSON (builtins.readFile %s);
      versionOf = name: let result = builtins.tryEval
        (if builtins.hasAttr name hp && hp.${name} != null then hp.${name}.version else null);
        in if result.success then result.value else "<error>";
      in builtins.listToAttrs (map (name: { inherit name; value = versionOf name; }) names)'''
    expression %= (json.dumps(channel_ref), json.dumps(inputs["system"]), json.dumps(str(names_file)))
    channel_file = scratch / "channel.json"
    write_json(channel_file, json.loads(capture(["nix", "eval", "--impure", "--json", "--expr", expression])))
    dotfiles = mori_path(inputs["dotfiles"])
    dotfiles_ref = "git+file://" + str(dotfiles) + "?rev=" + inputs["dotfilesRevision"]
    command = [cli, "cohort", "inventory-nix", "--names", str(names_file), "--channel", str(channel_file),
               "--channel-revision", inputs["channelRevision"], "--dotfiles-revision", inputs["dotfilesRevision"],
               "--system", inputs["system"], "--out", "cabal/inventory/nix.json"]
    for contributor in contributors:
        if not contributor["deployedAttr"]:
            continue
        attr = "darwinConfigurations.SungkyungM1X.pkgs." + contributor["deployedAttr"] + ".drvPath"
        drv = capture(["nix", "eval", "--raw", dotfiles_ref + "#" + attr])
        # Metadata API only: never open or traverse any store path. The build
        # graph includes statically linked libraries but also native homonyms.
        metadata = json.loads(capture(["nix", "derivation", "show", "--recursive", drv]))
        versions = deployed_haskell_versions(metadata, names)
        deployed_file = scratch / (contributor["name"] + "-deployed.json")
        write_json(deployed_file, versions)
        command += ["--deployed", contributor["name"] + "=" + str(deployed_file)]
    run(command)


if __name__ == "__main__":
    main()
