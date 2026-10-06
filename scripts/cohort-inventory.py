#!/usr/bin/env python3
"""Export and inventory recorded inputs; never build inside contributor checkouts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from cohort_toolchain import compiler_args, compiler_environment


INPUT_FILES = (
    "cabal/contributors.json", "cabal/inventory-inputs.json", "cabal/policy-floors.json",
    "cabal/policy-roots.json", "cabal/floors.config", "cabal/compiler-boot-packages.json",
    "flake.nix", "flake.lock", "cabal.project", "packages/first-party-lock.json",
    "config/first-party-families.json",
)
INPUT_DIRECTORIES = ("config", "lib", "nix", "overlays", "patches")


def capture_inputs(root):
    paths = {root / name for name in INPUT_FILES}
    for directory in INPUT_DIRECTORIES:
        paths.update(path for path in (root / directory).rglob("*") if path.is_file())
    return {path: path.read_bytes() for path in sorted(paths)}


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def capture(args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def mori_path(uri):
    # Mori writes its canonical reference on stderr; stdout is the resolved path.
    return Path(capture(["mori", "path", uri]).splitlines()[-1])


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")


def read_floors(path):
    result = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("--") or line == "constraints:":
            continue
        match = re.fullmatch(r"(?:,\s*)?any\.([^\s,]+)\s+>=([0-9]+(?:\.[0-9]+)*)", line)
        if not match or match[1] in result:
            raise ValueError(f"invalid generated floor record: {line}")
        result[match[1]] = match[2]
    return result


def floor_delta(before, after):
    removed = sorted(before.keys() - after.keys())
    changed = {name: {"before": before[name], "after": after[name]}
               for name in sorted(before.keys() & after.keys()) if before[name] != after[name]}
    lowered = [name for name, values in changed.items()
               if tuple(map(int, values["after"].split("."))) < tuple(map(int, values["before"].split(".")))]
    return {"added": sorted(after.keys() - before.keys()), "removed": removed,
            "changed": changed, "lowered": lowered}


def canonical_inventory(value):
    """Identity list order/multiplicity is incidental; all retained values matter."""
    result = json.loads(json.dumps(value))
    for package in result.get("packages", {}).values():
        identities = {json.dumps(identity, sort_keys=True) for identity in package["identities"]}
        package["identities"] = [json.loads(identity) for identity in sorted(identities)]
    return result


def promote_inventories(destination, staged, expected):
    current = {path.name: path.read_bytes() for path in destination.glob("*.json")}
    if current != expected:
        raise RuntimeError("Recorded inventories changed during capture; no files promoted")
    originals = current
    candidates = {path.name: path.read_bytes() for path in staged.glob("*.json")}
    try:
        for name, content in candidates.items():
            with tempfile.NamedTemporaryFile(dir=destination, prefix=name + ".", delete=False) as handle:
                handle.write(content)
                temporary = Path(handle.name)
            try:
                os.replace(temporary, destination / name)
            finally:
                temporary.unlink(missing_ok=True)
        for name in originals.keys() - candidates.keys():
            (destination / name).unlink()
    except BaseException:
        for name in candidates.keys() - originals.keys():
            (destination / name).unlink(missing_ok=True)
        for name, content in originals.items():
            (destination / name).write_bytes(content)
        raise


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
    parser.add_argument("--promote", action="store_true",
                        help="Explicitly refresh recorded inventories after reviewing staged observations")
    parser.add_argument("--check-recorded", action="store_true",
                        help="Require the staged inventory to match recorded metadata; never promote")
    args = parser.parse_args()
    if args.check_recorded and args.promote:
        parser.error("--check-recorded and --promote are mutually exclusive")
    root = Path.cwd()
    root_revision = capture(["git", "rev-parse", "HEAD"])
    baseline = capture_inputs(root)
    contributors = json.loads(baseline[root / "cabal/contributors.json"])
    inputs = json.loads(baseline[root / "cabal/inventory-inputs.json"])
    recorded = {path.name: path.read_bytes() for path in (root / "cabal/inventory").glob("*.json")}
    run(["cabal", "build", "exe:haskell-nix-update"])
    cli = capture(["cabal", "list-bin", "exe:haskell-nix-update"])
    scratch = args.reuse_solves or Path(tempfile.mkdtemp(prefix="cohort-inventory-", dir="/tmp"))
    print(f"Inventory scratch: {scratch}", flush=True)
    candidate = Path(tempfile.mkdtemp(prefix="cohort-inventory-candidate-", dir="/tmp"))
    staged_inventory = candidate / "inventory"
    staged_inventory.mkdir()
    print(f"Staged inventory and receipt: {candidate}; recorded inputs are unchanged", flush=True)
    captured_contributors = candidate / "contributors.json"
    captured_inputs = candidate / "inventory-inputs.json"
    captured_contributors.write_bytes(baseline[root / "cabal/contributors.json"])
    captured_inputs.write_bytes(baseline[root / "cabal/inventory-inputs.json"])
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
                command += ["--builddir=dist-cohort-" + config["name"], *compiler_args()]
                with (scratch / (name + "-" + config["name"] + ".log")).open("w") as log:
                    run(command, cwd=export, stdout=log, stderr=subprocess.STDOUT,
                        env=compiler_environment())
        for config in contributor["configurations"]:
            builddir = "dist-newstyle" if args.reuse_solves else "dist-cohort-" + config["name"]
            suffix = "" if config["name"] == "default" else "-" + config["name"]
            run([cli, "cohort", "inventory", "--contributor", name,
                 "--contributors", str(captured_contributors),
                 "--configuration", config["name"], "--source", str(export),
                 "--plan", str(export / builddir / "cache/plan.json"),
                 "--out", str(staged_inventory / (name + suffix + ".json"))])
    inventories = [json.loads(p.read_text()) for p in staged_inventory.glob("*.json")
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
               "--system", inputs["system"], "--out", str(staged_inventory / "nix.json")]
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
    for path, content in baseline.items():
        destination = candidate / "inputs" / path.relative_to(root)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
    captured = candidate / "inputs"
    run([cli, "cohort", "stub", "--inventory", str(staged_inventory),
         "--lock", str(captured / "packages/first-party-lock.json"),
         "--catalog", str(captured / "config/first-party-families.json"),
         "--policy-floors", str(captured / "cabal/policy-floors.json"),
         "--policy-roots", str(captured / "cabal/policy-roots.json"),
         "--out-dir", str(candidate / "cohort")])
    delta = floor_delta(read_floors(captured / "cabal/floors.config"),
                        read_floors(candidate / "cohort/floors.config"))
    staged = {path.name: path.read_bytes() for path in staged_inventory.glob("*.json")}
    changed_records = sorted(name for name in recorded.keys() | staged.keys()
                             if name not in recorded or name not in staged
                             or canonical_inventory(json.loads(recorded[name])) != canonical_inventory(json.loads(staged[name])))
    receipt = {"exports": str(scratch), "candidate": str(candidate),
               "capturedRootRevision": root_revision,
               "capturedFlakeLockSHA256": hashlib.sha256(baseline[root / "flake.lock"]).hexdigest(),
               "recordedChannelRevision": inputs["channelRevision"],
               "capturedToolchainInputs": [str(path.relative_to(root)) for path in baseline],
               "stockCompiler": os.environ.get("COHORT_GHC"),
               "stockPackageTool": os.environ.get("COHORT_GHC_PKG"),
               "floorDelta": delta, "changedInventoryRecords": changed_records,
               "promoted": False}
    write_json(candidate / "receipt.json", receipt)
    print(json.dumps(receipt, sort_keys=True, indent=2), flush=True)
    if delta["removed"] or delta["lowered"]:
        raise SystemExit("Candidate loses recorded floors; retain historical observations before promotion. "
                         "Staged evidence is preserved; accepted inputs are unchanged.")
    if args.check_recorded and changed_records:
        raise SystemExit("Staged metadata differs from recorded inventory; see receipt. No files promoted.")
    try:
        unchanged = capture_inputs(root) == baseline
    except OSError:
        unchanged = False
    if not unchanged:
        raise SystemExit("Recorded solve inputs changed during capture; no files promoted.")
    if {path.name: path.read_bytes() for path in (root / "cabal/inventory").glob("*.json")} != recorded:
        raise SystemExit("Recorded inventory files changed during capture; no files promoted.")
    if args.promote:
        promote_inventories(root / "cabal/inventory", staged_inventory, recorded)
        receipt["promoted"] = True
        write_json(candidate / "receipt.json", receipt)
        print("Promoted explicitly reviewed inventories; regenerate the cohort from this snapshot.")
    else:
        print("Inventory staged for review. Accepted files unchanged; use --promote only after reviewing the receipt.")


if __name__ == "__main__":
    main()
