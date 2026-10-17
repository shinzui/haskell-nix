#!/usr/bin/env python3
"""Measure paired source-invalidation builds using a caller-supplied Nix expression.

The expression takes `source` and exports `package` and JSON-serializable `identity`.
Use disposable source directories: --edit is restored even if a build fails.
Nix owns all store access; this script only reads its JSON and build logs.
"""

import argparse
import hashlib
import json
import math
import platform
import re
import statistics
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_trial(args, label, source, trial, stage):
    prefix = args.output_dir / f"{stage}-{trial}-{label}"
    common = ["--impure", "--file", str(args.expression), "--argstr", "source", str(source)]
    command = ["nix", "build", *common, "package", "--no-link", "--json",
               "--print-build-logs", "--max-jobs", "1", "--cores", str(args.cores)]
    # Time the first Nix invocation for this variant: pre-evaluation or dry-run
    # would warm IFD translation before the clock starts.
    start = time.perf_counter()
    with prefix.with_suffix(".log").open("w") as log, prefix.with_suffix(".build.json").open("w") as result:
        process = subprocess.Popen(command, stdout=result, stderr=subprocess.PIPE, text=True)
        phases = []
        modules = {}
        try:
            for line in process.stderr:
                log.write(line)
                log.flush()
                if "Running phase:" in line:
                    phases.append({"elapsed_seconds": time.perf_counter() - start, "message": line.strip()})
                match = re.search(r"^(\S+)> \[\s*\d+ of\s*\d+\] Compiling ", line)
                if match:
                    modules[match[1]] = modules.get(match[1], 0) + 1
            code = process.wait()
        except BaseException:
            process.terminate()
            process.wait()
            raise
        finally:
            process.stderr.close()
    elapsed = time.perf_counter() - start
    identity = json.loads(subprocess.check_output(["nix", "eval", "--json", *common, "identity"])) if code == 0 else None
    receipt = {
        "trial": trial, "stage": stage, "label": label, "command": command,
        "source_variant_sha256": digest(source / args.edit),
        "identity": identity, "elapsed_seconds": elapsed, "exit_code": code,
        "compiled_modules": modules, "phase_events": phases,
        "build_result": json.loads(prefix.with_suffix(".build.json").read_text()) if code == 0 else None,
        "cache_state": "warm dependencies; initial build plan and actual compilations recorded in build log",
        "log": prefix.with_suffix(".log").name,
        "phase_limits": "No separate linker, test, memory or transfer instrumentation; phase events are builder log boundaries.",
    }
    prefix.with_suffix(".receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"{stage} {trial} {label}: {elapsed:.2f}s; compiled {sum(modules.values())} modules", flush=True)
    if code:
        raise subprocess.CalledProcessError(code, command)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expression", required=True, type=Path)
    parser.add_argument("--baseline-source", required=True, type=Path)
    parser.add_argument("--candidate-source", required=True, type=Path)
    parser.add_argument("--edit", required=True, type=Path, help="Relative prose file; appends Markdown comments only")
    parser.add_argument("--project-uri", required=True)
    parser.add_argument("--source-revision", required=True)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--trials", type=int, default=5)
    parser.add_argument("--cores", type=int, default=16)
    parser.add_argument("--minimum-saving", type=float, default=0.20)
    args = parser.parse_args()
    if args.trials < 5 or args.cores < 1 or not 0 < args.minimum_saving < 1:
        parser.error("Use at least five pairs, positive cores and a saving fraction between zero and one")
    if args.edit.is_absolute() or ".." in args.edit.parts:
        parser.error("--edit must stay inside each disposable source directory")
    args.expression = args.expression.resolve()
    sources = {"baseline": args.baseline_source.resolve(), "candidate": args.candidate_source.resolve()}
    if sources["baseline"] == sources["candidate"]:
        parser.error("Baseline and candidate need separate disposable directories")
    if any(args.output_dir.resolve().is_relative_to(source) for source in sources.values()):
        parser.error("Keep receipts outside both source directories")
    args.output_dir.mkdir(parents=True, exist_ok=False)
    original = {label: (source / args.edit).read_bytes() for label, source in sources.items()}
    if len(set(original.values())) != 1:
        parser.error("Both sides must start with the same prose bytes")
    metadata = {
        "schema_version": 1, "project_uri": args.project_uri, "source_revision": args.source_revision,
        "started_at": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(),
        "nix_version": subprocess.check_output(["nix", "--version"], text=True).strip(),
        "workload": f"documentation-only edit: {args.edit}",
        "minimum_saving": args.minimum_saving, "cores": args.cores, "max_jobs": 1,
        "expression_sha256": digest(args.expression),
        "lock_sha256": {label: digest(source / "flake.lock") for label, source in sources.items()},
        "evaluation_cache": "Nix expression evaluation, fresh process per invocation; no flake output evaluation cache",
        "compiler_count_semantics": "GHC Compiling events, including Setup and repeated module names across components",
        "trials": [], "warmup": [],
    }
    summary = args.output_dir / "summary.json"
    summary.write_text(json.dumps(metadata, indent=2) + "\n")
    try:
        # Includes the one-time filter migration build; excluded from paired medians.
        for label, source in sources.items():
            metadata["warmup"].append(run_trial(args, label, source, 0, "warmup"))
            summary.write_text(json.dumps(metadata, indent=2) + "\n")
        for trial in range(1, args.trials + 1):
            order = ["baseline", "candidate"] if trial % 2 else ["candidate", "baseline"]
            for label in order:
                source = sources[label]
                (source / args.edit).write_bytes(original[label] + f"\n<!-- paired rebuild trial {trial} -->\n".encode())
                receipt = run_trial(args, label, source, trial, "paired")
                receipt["order"] = order.index(label) + 1
                metadata["trials"].append(receipt)
                summary.write_text(json.dumps(metadata, indent=2) + "\n")
        medians = {}
        metadata["timings"] = {}
        for label in sources:
            values = [r["elapsed_seconds"] for r in metadata["trials"] if r["label"] == label]
            medians[label] = statistics.median(values)
            metadata["timings"][label] = {"median_seconds": medians[label], "min_seconds": min(values), "max_seconds": max(values)}
        metadata["saving_fraction"] = 1 - medians["candidate"] / medians["baseline"]
        metadata["timing_threshold_passed"] = metadata["saving_fraction"] >= args.minimum_saving
        saving = medians["baseline"] - medians["candidate"]
        migration = next(r["elapsed_seconds"] for r in metadata["warmup"] if r["label"] == "candidate")
        metadata["migration_cost_seconds"] = migration
        metadata["break_even_edits"] = math.ceil(migration / saving) if saving > 0 else None
        summary.write_text(json.dumps(metadata, indent=2) + "\n")
    finally:
        for label, source in sources.items():
            (source / args.edit).write_bytes(original[label])


if __name__ == "__main__":
    main()
