#!/usr/bin/env python3
"""Stage a targeted Cabal solve; retain recorded inputs and never auto-unlock."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def capture_inputs(root, runtime_freeze=None):
    """Capture both bytes and membership of every recorded solve input."""
    paths = {root / "cabal" / name for name in [
        "cohort.freeze", "cohort-sources.json", "common.config", "floors.config",
        "contributors.json", "inventory-inputs.json", "policy-floors.json",
        "compiler-boot-packages.json",
    ]}
    paths.update(root / name for name in [
        "flake.nix", "flake.lock", "cabal.project", "packages/first-party-lock.json",
        "config/first-party-families.json",
    ])
    # The flake selects the compiler/shell through these local modules. Capture
    # whole input trees so additions and removals also invalidate the candidate.
    for directory in ["cabal/inventory", "cabal/rei-family-cohort", "config",
                      "lib", "nix", "overlays", "patches"]:
        paths.update(path for path in (root / directory).rglob("*") if path.is_file())
    paths.update(path for path in root.glob("*.nix") if path.is_file())
    paths.update(path for path in root.glob("cabal.project*") if path.is_file())
    if runtime_freeze is not None:
        paths.add(runtime_freeze)
    return {path: path.read_bytes() for path in sorted(paths)}


def stage_inputs(root, stage, baseline, runtime_freeze=None):
    captured = stage / "inputs"
    for path, content in baseline.items():
        if not path.is_relative_to(root):
            continue
        destination = captured / path.relative_to(root)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content)
    runtime = None
    if runtime_freeze is not None:
        runtime = captured / "runtime.freeze"
        runtime.write_bytes(baseline[runtime_freeze])
    # The candidate project imports these siblings; write their captured bytes,
    # never reread working-tree files after the snapshot.
    for path, content in baseline.items():
        relative = path.relative_to(root) if path.is_relative_to(root) else None
        if relative is not None and (relative in [Path("cabal/common.config"), Path("cabal/floors.config")]
                                     or relative.is_relative_to("cabal/rei-family-cohort")):
            destination = stage / relative.relative_to("cabal")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
    return captured, runtime


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="+")
    parser.add_argument("--runtime-freeze", type=Path)
    parser.add_argument("--update-runtime", action="store_true")
    args = parser.parse_args()
    root = Path.cwd().resolve()
    cabal = root / "cabal"
    runtime_freeze = args.runtime_freeze.resolve() if args.runtime_freeze else None
    baseline = capture_inputs(root, runtime_freeze)
    inputs = json.loads(baseline[cabal / "inventory-inputs.json"])
    stage = Path(tempfile.mkdtemp(prefix="cohort-update-", dir="/tmp"))
    print(f"Targeted candidate and diagnostic logs: {stage}", flush=True)
    captured, runtime = stage_inputs(root, stage, baseline, runtime_freeze)
    previous = captured / "cabal"
    run(["cabal", "build", "exe:haskell-nix-update"])
    cli = subprocess.check_output(["cabal", "list-bin", "exe:haskell-nix-update"], text=True).strip()
    retained = [cli, "cohort", "update-constraints", "--freeze", str(previous / "cohort.freeze"),
                "--index-state", inputs["indexState"], "--out", str(stage / "retained.config")]
    for package in sorted(set(args.packages)):
        retained += ["--package", package]
    if runtime is not None:
        retained += ["--runtime-freeze", str(runtime)]
    if args.update_runtime:
        retained += ["--update-runtime"]
    run(retained)
    (stage / "cohort.project").write_text("packages: rei-family-cohort\nimport: floors.config\n"
                                         "import: retained.config\nimport: common.config\n")
    selected_index = "--index-state=" + inputs["indexState"]
    solve = ["cabal", "build", "all", "--dry-run", "--project-file=cohort.project", selected_index]
    with (stage / "solve.log").open("w") as log:
        result = subprocess.run(solve, cwd=stage, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print((stage / "solve.log").read_text())
        raise SystemExit("Targeted solve failed. The conflict set above identifies constraints requiring "
                         "explicit transitive unlocks. No request was widened and no cohort files changed.")
    run(["cabal", "freeze", "--project-file=cohort.project", selected_index], cwd=stage)
    run([cli, "cohort", "normalise-freeze", "--in", str(stage / "cohort.project.freeze"),
         "--out", str(stage / "cohort.freeze"), "--plan", str(stage / "dist-newstyle/cache/plan.json"),
         "--index-state", inputs["indexState"], "--haskell-nix-rev", inputs["channelRevision"],
         "--compiler", inputs["compiler"]])
    run([cli, "cohort", "report", "--freeze", str(stage / "cohort.freeze"),
         "--inventory", str(previous / "inventory"),
         "--lock", str(captured / "packages/first-party-lock.json"),
         "--catalog", str(captured / "config/first-party-families.json"),
         "--policy-floors", str(previous / "policy-floors.json"),
         "--out", str(stage / "cohort-report.txt")])
    run([cli, "cohort", "impact", "--before", str(previous / "cohort-sources.json"),
         "--after", str(stage / "cohort-sources.json"), "--inventory", str(previous / "inventory"),
         "--out", str(stage / "cohort-impact.txt")])
    run([cli, "cohort", "check", "--freeze", str(stage / "cohort.freeze"),
         "--sources", str(stage / "cohort-sources.json"), "--plan", str(stage / "dist-newstyle/cache/plan.json"),
         "--compiler", inputs["compiler"]])
    retained_check = [cli, "cohort", "check-retained", "--before", str(previous / "cohort-sources.json"),
                      "--after", str(stage / "cohort-sources.json")]
    for package in sorted(set(args.packages)):
        retained_check += ["--package", package]
    run(retained_check)
    try:
        unchanged = capture_inputs(root, runtime_freeze) == baseline
    except OSError:
        unchanged = False
    if not unchanged:
        raise SystemExit("Recorded inputs changed during this solve. Candidate retained; no files promoted.")
    outputs = ["cohort.freeze", "cohort-sources.json", "cohort-report.txt", "cohort-impact.txt"]
    originals = {name: (cabal / name).read_bytes() if (cabal / name).exists() else None for name in outputs}
    try:
        for name in outputs:
            temporary = cabal / (name + ".candidate")
            temporary.write_bytes((stage / name).read_bytes())
            os.replace(temporary, cabal / name)
    except BaseException:
        for name, content in originals.items():
            if content is None:
                (cabal / name).unlink(missing_ok=True)
            else:
                (cabal / name).write_bytes(content)
        raise
    print("Promoted targeted freeze, source manifest and reports; contributor revisions and index-state retained.")


if __name__ == "__main__":
    main()
