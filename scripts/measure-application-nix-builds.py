#!/usr/bin/env python3
"""Measure paired application builds using a caller-supplied Nix expression.

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
import threading
import time
from datetime import datetime, timezone
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class CompilerMemory:
    """Sample host compiler RSS. No process arguments or store files are read.

    This is a sampled host total, not isolated builder accounting. Report other
    compiler activity rather than attributing it to this build.
    """

    def __init__(self):
        self.stop = threading.Event()
        self.peak_kib = 0
        self.preexisting = []
        self.errors = []
        self.samples = 0
        self.thread = threading.Thread(target=self.sample, daemon=True)

    def sample(self):
        first = True
        while not self.stop.is_set():
            result = subprocess.run(["ps", "-axo", "pid=,rss=,comm="], capture_output=True, text=True)
            if result.returncode:
                self.errors.append(result.stderr.strip())
                return
            processes = []
            for line in result.stdout.splitlines():
                parts = line.split(None, 2)
                if len(parts) != 3:
                    continue
                name = Path(parts[2]).name
                if re.fullmatch(r"ghc(?:-[\d.]+)?|clang(?:-[\d.]+)?|ld(?:64)?|(?:ghc-)?iserv.*|Setup", name):
                    processes.append({"pid": int(parts[0]), "rss_kib": int(parts[1]), "name": name})
            if first:
                self.preexisting = processes
                first = False
            self.peak_kib = max(self.peak_kib, sum(p["rss_kib"] for p in processes))
            self.samples += 1
            self.stop.wait(0.25)

    def finish(self):
        self.stop.set()
        self.thread.join()
        return {"peak_kib": self.peak_kib, "samples": self.samples,
                "preexisting_processes": self.preexisting, "errors": self.errors,
                "scope": "Host compiler RSS sum sampled every 250 ms; may include concurrent unrelated compilers; not exact builder peak"}


def run_trial(args, label, source, trial, stage):
    prefix = args.output_dir / f"{stage}-{trial}-{label}"
    common = ["--impure", "--file", str(args.expression), "--argstr", "source", str(source)]
    command = ["nix", "build", *common, "package", "--no-link", "--json",
               "--print-build-logs", "--max-jobs", "1", "--cores", str(args.cores)]
    # Time the first Nix invocation for this variant: pre-evaluation or dry-run
    # would warm IFD translation before the clock starts.
    memory = CompilerMemory()
    memory.thread.start()
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
            memory_receipt = memory.finish()
    elapsed = time.perf_counter() - start
    identity = json.loads(subprocess.check_output(["nix", "eval", "--json", *common, "identity"])) if code == 0 else None
    receipt = {
        "trial": trial, "stage": stage, "label": label, "command": command,
        "source_variant_sha256": digest(source / args.edit),
        "identity": identity, "elapsed_seconds": elapsed, "exit_code": code,
        "compiled_modules": modules, "phase_events": phases,
        "build_result": json.loads(prefix.with_suffix(".build.json").read_text()) if code == 0 else None,
        "cache_state": "warm dependencies; initial build plan and actual compilations recorded in build log",
        "sampled_host_compiler_memory": memory_receipt,
        "log": prefix.with_suffix(".log").name,
        "phase_limits": "No separate linker, test or transfer instrumentation; memory is sampled host compiler RSS, not isolated builder accounting; phase events are builder log boundaries.",
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
    parser.add_argument("--edit", required=True, type=Path, help="Relative source file; appends prose comments unless --replace is supplied")
    parser.add_argument("--replace", nargs=2, metavar=("BEFORE", "AFTER"),
                        help="Replace exactly one occurrence instead of appending prose; AFTER must contain {trial}")
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
    if args.replace and (not args.replace[0] or "{trial}" not in args.replace[1]):
        parser.error("--replace needs a nonempty BEFORE and a distinct {trial} placeholder in AFTER")
    args.expression = args.expression.resolve()
    sources = {"baseline": args.baseline_source.resolve(), "candidate": args.candidate_source.resolve()}
    if sources["baseline"] == sources["candidate"]:
        parser.error("Baseline and candidate need separate disposable directories")
    if any(not (source / args.edit).resolve().is_relative_to(source) for source in sources.values()):
        parser.error("--edit must not resolve through a symlink outside either source directory")
    if any(args.output_dir.resolve().is_relative_to(source) for source in sources.values()):
        parser.error("Keep receipts outside both source directories")
    args.output_dir.mkdir(parents=True, exist_ok=False)
    original = {label: (source / args.edit).read_bytes() for label, source in sources.items()}
    if len(set(original.values())) != 1:
        parser.error("Both sides must start with the same source bytes")
    if args.replace and any(content.count(args.replace[0].encode()) != 1 for content in original.values()):
        parser.error("BEFORE must occur exactly once in both source files")
    metadata = {
        "schema_version": 1, "project_uri": args.project_uri, "source_revision": args.source_revision,
        "started_at": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(),
        "nix_version": subprocess.check_output(["nix", "--version"], text=True).strip(),
        "workload": f"{'source' if args.replace else 'documentation-only'} edit: {args.edit}",
        "replacement": args.replace,
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
                content = (original[label].replace(args.replace[0].encode(), args.replace[1].replace("{trial}", str(trial)).encode())
                           if args.replace else original[label] + f"\n<!-- paired rebuild trial {trial} -->\n".encode())
                (source / args.edit).write_bytes(content)
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
