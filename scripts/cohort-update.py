#!/usr/bin/env python3
"""Stage a targeted Cabal solve; retain recorded inputs and never auto-unlock."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="+")
    parser.add_argument("--runtime-freeze", type=Path)
    parser.add_argument("--update-runtime", action="store_true")
    args = parser.parse_args()
    root = Path.cwd()
    cabal = root / "cabal"
    inputs = json.loads((cabal / "inventory-inputs.json").read_text())
    tracked = ["cohort.freeze", "cohort-sources.json", "common.config", "floors.config",
               "contributors.json", "inventory-inputs.json", "policy-floors.json"]
    tracked_paths = [cabal / name for name in tracked]
    tracked_paths += sorted((cabal / "inventory").glob("*.json"))
    tracked_paths += [root / "packages/first-party-lock.json", root / "config/first-party-families.json"]
    baseline = {path: path.read_bytes() for path in tracked_paths}
    run(["cabal", "build", "exe:haskell-nix-update"])
    cli = subprocess.check_output(["cabal", "list-bin", "exe:haskell-nix-update"], text=True).strip()
    stage = Path(tempfile.mkdtemp(prefix="cohort-update-", dir="/tmp"))
    print(f"Targeted candidate and diagnostic logs: {stage}", flush=True)
    for name in ["common.config", "floors.config"]:
        shutil.copy2(cabal / name, stage / name)
    shutil.copytree(cabal / "rei-family-cohort", stage / "rei-family-cohort")
    retained = [cli, "cohort", "update-constraints", "--freeze", str(cabal / "cohort.freeze"),
                "--index-state", inputs["indexState"], "--out", str(stage / "retained.config")]
    for package in sorted(set(args.packages)):
        retained += ["--package", package]
    if args.runtime_freeze:
        retained += ["--runtime-freeze", str(args.runtime_freeze.resolve())]
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
         "--index-state", inputs["indexState"], "--haskell-nix-rev", inputs["channelRevision"]])
    run([cli, "cohort", "report", "--freeze", str(stage / "cohort.freeze"),
         "--out", str(stage / "cohort-report.txt")])
    run([cli, "cohort", "impact", "--before", str(cabal / "cohort-sources.json"),
         "--after", str(stage / "cohort-sources.json"), "--out", str(stage / "cohort-impact.txt")])
    run([cli, "cohort", "check", "--freeze", str(stage / "cohort.freeze"),
         "--sources", str(stage / "cohort-sources.json"), "--plan", str(stage / "dist-newstyle/cache/plan.json")])
    if any(path.read_bytes() != content for path, content in baseline.items()):
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
