#!/usr/bin/env python3
"""Probe an application's seed guards in disposable archived sources.

Identity-only probes do not compile application candidates. Native behavior and
changed-build measurements are separate acceptance gates.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--application", choices=["rei", "mori"], required=True)
    parser.add_argument("--component", choices=["cli", "core"], default="cli")
    parser.add_argument("--checkout", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--seed-source", type=Path,
                        help="Explicit fixed checkpoint source; defaults to --source")
    parser.add_argument("--seed-revision",
                        help="Checkpoint revision stamp; defaults to the original current stamp")
    parser.add_argument("--validated-checkpoint-file", type=Path,
                        help="Reuse a successfully built exact checkpoint declaration")
    parser.add_argument("--retain-current-intermediates", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--application-revision", required=True)
    parser.add_argument("--alternate-stamp", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--expression", type=Path,
                        help="Nix source adapter; defaults to the original measured pilot")
    parser.add_argument("--native", action="store_true",
                        help="Build clean/seeded embedded-data and stamp variants and require both to reject a type error")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    destination = args.output_dir.resolve()
    source = args.source.resolve()
    if destination.is_relative_to(root) or destination.is_relative_to(source):
        parser.error("Keep evidence outside source trees")
    destination.mkdir(parents=True, exist_ok=False)
    environment = os.environ | {"MP4_APPLICATION_CHECKOUT": str(args.checkout.resolve())}
    application = args.application
    cli = f"{application}-cli"
    target = f"{application}-{args.component}"
    core_mode = args.component == "core"
    if core_mode and not args.expression:
        parser.error("Core guards require the producing-project --expression")
    if not args.expression and (args.seed_source or args.seed_revision or args.validated_checkpoint_file
                                or not args.retain_current_intermediates):
        parser.error("Explicit checkpoint/retention options require --expression")
    leaf = "src/Rei/Cli/Commands/Help.hs" if application == "rei" else "src/Mori/Command/Help.hs"
    target_leaf = ("src/Rei/Infrastructure/CategoryStream.hs" if application == "rei" else "src/Mori/Automation/ConfigHash.hs") if core_mode else leaf
    original_stamp = args.application_revision[:7]
    if args.alternate_stamp == original_stamp:
        parser.error("--alternate-stamp must differ from the original stamp")
    with tempfile.TemporaryDirectory(prefix=f"mp4-{application}-source-guards-") as temporary:
        candidate = Path(temporary) / application
        shutil.copytree(source, candidate, symlinks=True)

        checkpoint_declaration = (json.loads(args.validated_checkpoint_file.read_text())
                                  if args.validated_checkpoint_file else None)
        checkpoint_file = destination / "checkpoint-declaration.json"
        if checkpoint_declaration is not None:
            checkpoint_file.write_text(json.dumps(checkpoint_declaration, indent=2) + "\n")

        def arguments(policy="incremental", stamp=original_stamp):
            command = ["--impure", "--file",
                       str(args.expression or root / "checks/fixtures/application-builds/pilot.nix")]
            for name, value in {"source": str(candidate), "seedSource": str((args.seed_source or source).resolve()),
                                "application": application, "applicationRevision": args.application_revision,
                                "revision": stamp, "seedRevision": args.seed_revision or original_stamp, "policy": policy}.items():
                command += ["--argstr", name, value]
            if args.expression:
                command += ["--argstr", "component", args.component]
                command += ["--arg", "retainCurrentIntermediates", str(args.retain_current_intermediates).lower()]
                if checkpoint_declaration is not None:
                    command += ["--argstr", "validatedCheckpointFile", str(checkpoint_file)]
            return command

        def identity(policy="incremental", stamp=original_stamp):
            return json.loads(subprocess.check_output(["nix", "eval", "--json", *arguments(policy, stamp), "identity"], env=environment))

        native = []

        def native_pair(label, stamp=original_stamp, expected_error=False):
            outputs = {}
            for policy in ["clean", "incremental"]:
                command = ["nix", "build", "--json", "--no-link", "--print-build-logs",
                           "--max-jobs", "1", "--cores", "16", *arguments(policy, stamp), "package"]
                started = time.perf_counter()
                result = subprocess.run(command, capture_output=True, env=environment, timeout=900)
                elapsed = time.perf_counter() - started
                log = destination / f"{label}-{policy}.log"
                log.write_bytes(result.stderr)
                record = {"policy": policy, "exit_code": result.returncode, "elapsed_seconds": elapsed,
                          "log_sha256": hashlib.sha256(result.stderr).hexdigest()}
                if expected_error:
                    type_error = (b"Couldn't match" in result.stderr or
                                  all(part in result.stderr for part in [b"No instance for", b"IsString", b"Int", b'"invalid type"']))
                    if (result.returncode == 0 or b"mp4GuardTypeError" not in result.stderr
                            or not type_error):
                        raise ValueError(f"{policy} did not reject the deliberately invalid application type")
                else:
                    if result.returncode:
                        raise ValueError(f"Native {label}/{policy} failed; see {log}")
                    build = json.loads(result.stdout)[0]
                    record["build"] = build
                    binary = build["outputs"]["out"] + "/bin/" + application
                    commands = [["--version"], ["help", "time" if application == "rei" else "sealed-evaluation"]]
                    outputs[policy] = []
                    with tempfile.TemporaryDirectory(prefix="mp4-native-guard-home-") as home:
                        probe_env = environment | {"HOME": home, "XDG_CONFIG_HOME": home, "NO_COLOR": "1", "TERM": "dumb"}
                        for command in commands:
                            probe = subprocess.run([binary, *command], capture_output=True, env=probe_env, timeout=30)
                            if probe.returncode:
                                raise ValueError(f"Native behavior failed: {label}/{policy} {command}")
                            if label == "embedded-data" and command[0] == "help" and b"Embedded source-guard probe." not in probe.stdout:
                                raise ValueError("Seed hid changed embedded help")
                            if label == "stamp" and command == ["--version"] and stamp.encode() not in probe.stdout:
                                raise ValueError("Seed hid changed revision stamp")
                            outputs[policy].append((probe.stdout, probe.stderr))
                    record["behavior_sha256"] = [hashlib.sha256(out + b"\0" + err).hexdigest() for out, err in outputs[policy]]
                native.append({"probe": label, **record})
            if not expected_error and outputs["clean"] != outputs["incremental"]:
                raise ValueError(f"Clean/seeded application behavior differs: {label}")

        if args.expression and checkpoint_declaration is None:
            # Capture the explicitly selected origin once; never recompute it
            # from each mutated candidate's current dependency context.
            checkpoint_declaration = json.loads(subprocess.check_output(
                ["nix", "eval", "--json", *arguments("clean"), "checkpointDeclaration"], env=environment))
            checkpoint_file.write_text(json.dumps(checkpoint_declaration, indent=2) + "\n")
        baseline = identity()
        if not baseline["compatibilityReport"]["accepted"]:
            raise ValueError("Unchanged archived source must accept its seed")
        rows = []

        def probe(label, relative, transform, accepted, required_difference=None, core_changed=False, same_root=False):
            path = candidate / relative
            if not path.resolve().is_relative_to(candidate.resolve()):
                raise ValueError(f"Probe escapes disposable sources through a symlink: {relative}")
            original = path.read_bytes() if path.exists() else None
            try:
                path.write_bytes(transform(original or b""))
                result = identity()
                report = result["compatibilityReport"]
                if report["accepted"] != accepted:
                    raise ValueError(f"Unexpected seed decision for {label}: {report}")
                if required_difference and required_difference not in report["differences"]:
                    raise ValueError(f"Missing expected rejection field for {label}")
                if (result["core"] != baseline["core"]) != core_changed:
                    raise ValueError(f"Unexpected core invalidation: {label}")
                if same_root and result["root"] != baseline["root"]:
                    raise ValueError(f"Irrelevant source invalidated CLI: {label}")
                if not accepted and result["root"] != identity(policy="clean")["root"]:
                    raise ValueError(f"Rejected {label} failed to return the original clean recipe")
                rows.append({"probe": label, "identity": result})
                if args.native and not core_mode and label == "embedded help edit":
                    native_pair("embedded-data")
            finally:
                if original is None:
                    path.unlink()
                else:
                    path.write_bytes(original)

        probe("Haskell source comment edit", f"{target}/{target_leaf}",
              lambda content: content + b"\n-- source-guard implementation probe\n", True, core_changed=core_mode)
        if args.expression:
            probe("unrelated repository prose", "README.md",
                  lambda content: content + b"\nSource-guard repository prose.\n", True, same_root=True)
            if (candidate / cli / "README.md").is_file():
                probe("package README prose", f"{cli}/README.md",
                      lambda content: content + b"\nSource-guard package prose.\n", True, same_root=True)
            api_source = sorted((candidate / f"{application}-api/src").rglob("*.hs"))[0]
            # Mori's CLI imports its API library; Rei's CLI does not. Keep the
            # required dependency invalidation instead of excluding that source.
            api_is_dependency = application == "mori" and not core_mode
            probe("API dependency source" if api_is_dependency else "unrelated API source",
                  str(api_source.relative_to(candidate)),
                  lambda content: content + b"\n-- source-guard sibling probe\n",
                  not api_is_dependency, "recipeIdentity" if api_is_dependency else None,
                  same_root=application == "rei")
            if core_mode:
                probe("downstream CLI source edit", f"{cli}/{leaf}",
                      lambda content: content + b"\n-- source-guard downstream probe\n", True)
            else:
                core_source = sorted((candidate / f"{application}-core/src").rglob("*.hs"))[0]
                probe("core source edit", str(core_source.relative_to(candidate)),
                      lambda content: content + b"\n-- source-guard dependency probe\n", False,
                      "recipeIdentity", core_changed=True)
        probe("Cabal metadata edit", f"{target}/{target}.cabal",
              lambda content: content + b"\n-- source-guard metadata probe\n", False, "metadataIdentity", core_changed=core_mode)
        probe("added module", f"{target}/src/IntermediateGuardProbe.hs",
              lambda _: b"module IntermediateGuardProbe where\n", False, "sourceLayoutIdentity", core_changed=core_mode)
        if args.expression:
            probe("added native input", f"{target}/intermediate-guard-probe.h",
                  lambda _: b"#define INTERMEDIATE_GUARD_PROBE 1\n", False, "metadataIdentity", core_changed=core_mode)
        probe("embedded help edit", f"{cli}/help/{'time' if application == 'rei' else 'sealed-evaluation'}.md",
              lambda content: content + b"\nEmbedded source-guard probe.\n", True)
        stamp = identity(stamp=args.alternate_stamp)
        if (not stamp["compatibilityReport"]["accepted"] or stamp["core"] != baseline["core"]
                or stamp["root"] == baseline["root"]):
            raise ValueError("Stamp must change only the CLI recipe while retaining seed compatibility")
        rows.append({"probe": "synthetic stamp-only identity change", "identity": stamp})
        if args.native:
            if not core_mode:
                native_pair("stamp", stamp=args.alternate_stamp)
            path = candidate / target / target_leaf
            original = path.read_bytes()
            try:
                path.write_bytes(original + b'\nmp4GuardTypeError :: Int\nmp4GuardTypeError = "invalid type"\n')
                if not identity()["compatibilityReport"]["accepted"]:
                    raise ValueError("Type-error probe must test accepted intermediates")
                native_pair("type-error", expected_error=True)
            finally:
                path.write_bytes(original)
        receipt = {"schema_version": 1, "project_uri": f"mori://shinzui/{application}",
                   "source_revision": args.application_revision, "component": args.component, "baseline": baseline, "probes": rows,
                   "seed_source": str((args.seed_source or source).resolve()),
                   "validated_checkpoint": checkpoint_declaration,
                   "retain_current_intermediates": args.retain_current_intermediates,
                   "native_probes": native,
                   "scope": "Identity guards plus explicitly listed native probes; no timing claim",
                   "status": "passed"}
        (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print(f"Passed application identity guards: {destination / 'receipt.json'}")


if __name__ == "__main__":
    main()
