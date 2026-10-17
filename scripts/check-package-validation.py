#!/usr/bin/env python3
"""Run controlled strict-policy/removal fixtures; do not retire production entries."""

import argparse
import hashlib
import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path


def main():
    started = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    destination = args.output_dir.resolve()
    if destination.is_relative_to(root):
        parser.error("Keep receipts outside the source tree")
    destination.mkdir(parents=True, exist_ok=False)
    prefix = (
        f"let f = builtins.getFlake {json.dumps(str(root))}; "
        "p = import f.inputs.nixpkgs { system = builtins.currentSystem; }; "
        f"fixture = import {json.dumps(str(root / 'checks/package-validation.nix'))} "
        "{ lib = p.lib; pkgs = p; scope = p.haskell.packages.${f.lib.defaultGhc}; }; in "
    )

    def evaluate(selection):
        result = subprocess.run(
            ["nix", "eval", "--impure", "--json", "--expr", prefix + selection],
            capture_output=True, check=True,
        )
        return json.loads(result.stdout)

    contexts = {name: evaluate(f"fixture.{name}.context") for name in ["needed", "fixed", "blocked"]}
    assert contexts["blocked"]["status"] == "blocked"
    assert evaluate("fixture.blocked.baseline") is None
    assert evaluate("fixture.blocked.candidate") is None
    probes = []
    for name, phase, expected_success in [
        ("needed", "baseline", True), ("needed", "candidate", False),
        ("fixed", "baseline", True), ("fixed", "candidate", True),
    ]:
        probe_started = time.monotonic()
        context = contexts[name]
        selected = context[phase]
        assert selected["effective"]["testsEnabled"] is True
        assert selected["effective"]["boundsRelaxed"] is False
        flag = "-fcompatibility-repair" if phase == "baseline" else "-f-compatibility-repair"
        assert flag in selected["effective"]["configureFlags"]
        assert context["status"] == "unverified"
        command = ["nix", "build", "--impure", "--json", "--no-link", "--print-build-logs",
                   "--expr", prefix + f"fixture.{name}.{phase}"]
        result = subprocess.run(command, capture_output=True)
        (destination / f"{name}-{phase}-invocation.log").write_bytes(result.stdout + result.stderr)
        log_result = subprocess.run(["nix", "log", selected["derivation"]], capture_output=True)
        if log_result.returncode:
            raise RuntimeError(f"Native log unavailable for {name}/{phase}")
        log = log_result.stdout
        (destination / f"{name}-{phase}-build.log").write_bytes(log)
        if expected_success:
            if result.returncode or b"Test suite fixture-tests: PASS" not in log:
                raise RuntimeError(f"Enabled native suite did not pass: {name}/{phase}")
            output = json.loads(result.stdout)[0]
            assert output["drvPath"] == selected["derivation"]
            executable = Path(output["outputs"]["out"]) / "bin/validation-probe"
            behavior = subprocess.run([str(executable)], capture_output=True, timeout=30, check=True)
            if behavior.stdout != b"42\n":
                raise RuntimeError("Native behavior disagrees with the test suite")
            behavior_evidence = {"status": "passed", "command": [str(executable)],
                                 "exitCode": behavior.returncode,
                                 "stdoutSha256": hashlib.sha256(behavior.stdout).hexdigest()}
            manifest_name = name + phase.capitalize()
            manifest = evaluate(f"{{ derivation = fixture.manifests.{manifest_name}.drvPath; root = fixture.manifests.{manifest_name}.declaration.root.drvPath; compiler = fixture.manifests.{manifest_name}.declaration.compiler.drvPath; }}")
            assert manifest["root"] == selected["derivation"]
            assert manifest["compiler"] == context["compiler"]
            graph = subprocess.run(["nix", "build", "--impure", "--json", "--no-link",
                                    "--expr", prefix + f"fixture.manifests.{manifest_name}"], capture_output=True)
            (destination / f"{name}-{phase}-graph.log").write_bytes(graph.stdout + graph.stderr)
            if graph.returncode:
                raise RuntimeError("Existing cohort manifest producer rejected the strict test graph")
            graph_result = json.loads(graph.stdout)[0]
            assert graph_result["drvPath"] == manifest["derivation"]
            graph_evidence = {"status": "passed", **manifest}
            outcome = "passed"
        else:
            if (result.returncode == 0 or b"EP21_REPAIR_REQUIRED" not in log
                    or b"Test suite fixture-tests: FAIL" not in log
                    or b"Running phase: checkPhase" not in log):
                raise RuntimeError("Removal did not fail for the required native test cause")
            outcome = "failed"
            graph_evidence = {"status": "unverified", "reason": "candidate package tests failed"}
            behavior_evidence = {"status": "blocked", "reason": "candidate package tests failed"}
        probes.append({"fixture": name, "phase": phase, "nativeOutcome": outcome,
                       "derivation": selected["derivation"], "buildExitCode": result.returncode,
                       "logSha256": hashlib.sha256(log).hexdigest(), "graph": graph_evidence,
                       "expectedSuccess": expected_success, "behavior": behavior_evidence,
                       "elapsedSeconds": time.monotonic() - probe_started, "command": command})
    receipt = {
        "schemaVersion": 1,
        "observedAt": datetime.now(timezone.utc).isoformat(),
        "elapsedSeconds": time.monotonic() - started,
        "cacheState": "Uncontrolled; existing outputs and their original native logs are allowed; no speedup claim",
        "scope": "Controlled native Haskell fixtures with standard Cabal suites and executable probes",
        "status": "unverified",
        "nativeFixtureOutcome": "passed",
        "contexts": contexts,
        "probes": probes,
        "limitations": ["No production exception is retired", "Graph acceptance is limited to these controlled fixtures",
                        "No provided-service native probe", "No receipt verifier or updater verify command yet"],
    }
    (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Strict native fixture checks passed; staged receipt: {destination / 'receipt.json'}")


if __name__ == "__main__":
    main()
