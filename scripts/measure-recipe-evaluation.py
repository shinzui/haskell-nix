#!/usr/bin/env python3
"""Measure retained recipe evaluation with explicit generations and source inputs.

The expression accepts generation and scope (scoped or consumer). Both generations
must return the same derivation identity. No target outputs are built.
"""

import argparse
import hashlib
import json
import re
import subprocess
import time
from pathlib import Path

from benchmark_resources import HostResources, POLICY, hardware, timing_stability


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expression", required=True, type=Path)
    parser.add_argument("--input", action="append", default=[], type=Path)
    parser.add_argument("--source-revision", required=True)
    parser.add_argument("--baseline-generation", type=int, required=True)
    parser.add_argument("--candidate-generation", type=int, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(exist_ok=False, parents=True)
    inputs = [args.expression.resolve(), Path(__file__).resolve(),
              Path(__file__).with_name("benchmark_resources.py").resolve(),
              *(p.resolve() for p in args.input)]

    def identities():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}

    base = ["nix", "eval", "--json", "--impure", "--offline", "--no-write-lock-file",
            "--option", "eval-cache", "false", "--max-jobs", "0", "--builders", "",
            "--file", str(args.expression.resolve())]
    receipt = {"schema_version": 1, "project_uri": "mori://shinzui/haskell-nix",
               "source_revision": args.source_revision, "hardware": hardware(),
               "nix_version": subprocess.check_output(["nix", "--version"], text=True).strip(),
               "resource_policy": POLICY, "input_sha256": identities(),
               "baseline_generation": args.baseline_generation, "candidate_generation": args.candidate_generation,
               "minimum_saving": 0.2, "pairs_per_scope": 5, "command_prefix": base,
               "cache_state": "Warm immutable source/converter outputs; fresh evaluators; eval-cache false; offline; all builders disabled",
               "target_builds": False, "measurements": [], "results": {}, "status": "declared before measurement"}
    destination = args.output_dir / "receipt.json"

    def save():
        destination.write_text(json.dumps(receipt, indent=2) + "\n")

    def run(scope, trial, label):
        generation = args.baseline_generation if label == "baseline" else args.candidate_generation
        name = f"{scope}-{trial}-{label}"
        prefix = args.output_dir / name
        command = ["/usr/bin/time", "-l", "-o", str(prefix.with_suffix(".time")),
                   *base, "--apply", f'f: f {{ generation = {generation}; scope = {json.dumps(scope)}; }}']
        resources = HostResources().start()
        started = time.perf_counter()
        try:
            with prefix.with_suffix(".out").open("w") as stdout, prefix.with_suffix(".log").open("w") as stderr:
                result = subprocess.run(command, stdout=stdout, stderr=stderr)
            elapsed = time.perf_counter() - started
        finally:
            observed = resources.finish()
        rss = re.search(r"(\d+)\s+maximum resident set size", prefix.with_suffix(".time").read_text())
        row = {"scope": scope, "trial": trial, "label": label, "command": command,
               "elapsed_seconds": elapsed, "exit_code": result.returncode,
               "max_rss_bytes_darwin": int(rss.group(1)) if rss else None,
               "output": prefix.with_suffix(".out").read_text().strip(), "host_resources": observed}
        receipt["measurements"].append(row)
        save()
        print(f"{name}: {elapsed:.3f}s; exit {result.returncode}", flush=True)
        if result.returncode or not observed["assessment"]["accepted"]:
            raise ValueError(f"Failed evaluation or sustained resource pressure: {name}")
        if identities() != receipt["input_sha256"]:
            raise ValueError("Declared input bytes changed during measurement")
        return row["output"]

    save()
    try:
        for scope in ["scoped", "consumer"]:
            expected = run(scope, 0, "baseline")
            if run(scope, 0, "candidate") != expected:
                raise ValueError("Baseline and candidate identities differ")
            for trial in range(1, 6):
                for label in (["baseline", "candidate"] if trial % 2 else ["candidate", "baseline"]):
                    if run(scope, trial, label) != expected:
                        raise ValueError("A measured identity changed")
            rows = [r for r in receipt["measurements"] if r["scope"] == scope and r["trial"] > 0]
            timings = {label: timing_stability([r["elapsed_seconds"] for r in rows if r["label"] == label])
                       for label in ["baseline", "candidate"]}
            saving = 1 - timings["candidate"]["median_seconds"] / timings["baseline"]["median_seconds"]
            stable = all(t["stable"] for t in timings.values())
            receipt["results"][scope] = {"timings": timings, "saving_fraction": saving,
                                          "resource_policy_accepted": stable,
                                          "threshold_passed": stable and saving >= receipt["minimum_saving"]}
            save()
        receipt["status"] = "measured; performance and stability results explicit; total-cost/adoption remain separate"
    except BaseException as error:
        receipt["status"] = "incomplete; no campaign acceptance"
        receipt["failure"] = str(error)
        raise
    finally:
        save()


if __name__ == "__main__":
    main()
