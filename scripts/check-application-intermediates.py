#!/usr/bin/env python3
"""Verify native intermediate reuse using Nix logs and metadata, without store reads.

This is a feasibility/correctness receipt, not a performance benchmark. Run from
the repository root with a new --output-dir outside the source tree.
"""

import argparse
import hashlib
import json
import platform
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def run(command):
    return subprocess.run(command, capture_output=True, text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--system", default="aarch64-darwin")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    destination = args.output_dir.resolve()
    if destination.is_relative_to(root):
        parser.error("Keep evidence outside the source tree")
    destination.mkdir(parents=True, exist_ok=False)
    target = f".#checks.{args.system}.application-incremental"
    common = ["--max-jobs", "1", "--cores", "4"]
    receipt = {
        "schema_version": 1,
        "project_uri": "mori://shinzui/haskell-nix",
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "platform": platform.platform(),
        "system": args.system,
        "nix_version": subprocess.check_output(["nix", "--version"], text=True).strip(),
        "lock_sha256": hashlib.sha256((root / "flake.lock").read_bytes()).hexdigest(),
        "fixture_sha256": {
            str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted((root / "checks/fixtures/application-incremental").rglob("*"))
            if path.is_file()
        },
        "scope": "Native builder feasibility and correctness; no timing or application speedup claim",
        "cache_state": "Existing dependencies/outputs allowed; original build logs fetched with nix log",
        "results": [],
    }

    def save(name, process):
        content = process.stdout + process.stderr
        path = destination / f"{name}.log"
        path.write_text(content)
        return {"file": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    def evaluate(attribute):
        return json.loads(subprocess.check_output(["nix", "eval", "--json", f"{target}.{attribute}"], text=True))

    check = run(["nix", "build", target, "--no-link", "--json", "--print-build-logs", *common])
    receipt["correctness_check"] = {"exit_code": check.returncode, "log": save("correctness", check)}
    if check.returncode:
        raise RuntimeError(f"Native correctness check failed; see {destination}")
    receipt["identity"] = evaluate("identity")
    library = {"Stable", "Leaf", "Combined", "Embedded"}
    logs = {}
    for policy in ["clean", "seeded"]:
        for variant in ["unchanged", "leaf", "interface", "data"]:
            drv = receipt["identity"][policy][variant]
            log = run(["nix", "log", drv])
            if log.returncode:
                raise RuntimeError(f"Cannot retrieve build log for {policy}/{variant}")
            compilations = re.findall(r"\[\s*\d+ of\s*\d+\] Compiling (\S+)", log.stdout + log.stderr)
            modules = library.intersection(compilations)
            logs[policy, variant] = modules
            receipt["results"].append({
                "policy": policy, "variant": variant, "derivation": drv,
                "compilation_events": compilations, "library_modules_compiled": sorted(modules),
                "log": save(f"{policy}-{variant}", log),
            })
    for variant in ["unchanged", "leaf", "interface", "data"]:
        if logs["clean", variant] != library:
            raise RuntimeError(f"Clean {variant} did not compile the complete fixture library")
    expected = {
        "unchanged": set(), "leaf": {"Leaf", "Combined"},
        "interface": {"Leaf", "Combined"}, "data": {"Embedded"},
    }
    for variant, modules in expected.items():
        if logs["seeded", variant] != modules:
            raise RuntimeError(f"Unexpected compiler work for seeded {variant}: {logs['seeded', variant]}")

    for variant, cause in [
        ("invalid-interface", r"Couldn['’]t match"),
        ("removed", r"can['’]t find source for Leaf|Could not find module [‘']Leaf"),
    ]:
        for policy in ["clean", "seeded"]:
            attribute = f"negative.{variant}.{policy}"
            drv = evaluate(f"{attribute}.drvPath")
            build = run(["nix", "build", f"{target}.{attribute}", "--no-link", "--print-build-logs", *common])
            log = run(["nix", "log", drv])
            log_reference = save(f"{policy}-{variant}", log)
            if build.returncode == 0 or log.returncode or not re.search(cause, log.stdout + log.stderr):
                save(f"{policy}-{variant}-invocation", build)
                raise RuntimeError(f"Expected source failure not established for {policy}/{variant}; see {destination}")
            receipt["results"].append({
                "policy": policy, "variant": variant, "derivation": drv,
                "exit_code": build.returncode, "expected_failure_matched": cause, "log": log_reference,
            })
    receipt["status"] = "passed"
    (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Passed native reuse, behavior and source-error checks: {destination / 'receipt.json'}")


if __name__ == "__main__":
    main()
