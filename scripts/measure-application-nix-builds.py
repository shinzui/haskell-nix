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
        self.ready = threading.Event()
        self.thread = threading.Thread(target=self.sample, daemon=True)

    def sample(self):
        first = True
        while not self.stop.is_set():
            result = subprocess.run(["ps", "-axo", "pid=,rss=,comm="], capture_output=True, text=True)
            if result.returncode:
                self.errors.append(result.stderr.strip())
                self.ready.set()
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
            self.ready.set()
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
    idle_start = time.perf_counter()
    observed_busy = []
    while True:
        memory = CompilerMemory()
        memory.thread.start()
        memory.ready.wait()
        if not args.require_idle_compilers or (not memory.preexisting and not memory.errors):
            break
        memory.finish()
        observed_busy = memory.preexisting
        if memory.errors or time.perf_counter() - idle_start >= args.idle_wait_seconds:
            raise ValueError(f"Compiler host is not idle: {memory.preexisting}; sampling errors: {memory.errors}; resume this campaign when idle")
        time.sleep(0.5)
    idle_wait = time.perf_counter() - idle_start
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
        "idle_wait_seconds": idle_wait,
        "compilers_observed_before_wait": observed_busy,
        "log": prefix.with_suffix(".log").name,
        "phase_limits": "No separate linker, test or transfer instrumentation; memory is sampled host compiler RSS, not isolated builder accounting; phase events are builder log boundaries.",
    }
    prefix.with_suffix(".receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"{stage} {trial} {label}: {elapsed:.2f}s; compiled {sum(modules.values())} modules", flush=True)
    if code:
        raise subprocess.CalledProcessError(code, command)
    report = (identity or {}).get("compatibilityReport", {})
    if label == "candidate" and report.get("enabled") and not report.get("accepted"):
        raise ValueError(f"Candidate rejected its seed: {report.get('reason')}; this is a clean fallback, not a reuse measurement")
    if stage == "paired" and args.replace and not sum(modules.values()):
        raise ValueError("Source-edit target is already built; use a fresh declared replacement variant for this campaign")
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
    parser.add_argument("--require-idle-compilers", action="store_true",
                        help="Reject a trial when host compiler processes are already active before Nix starts")
    parser.add_argument("--idle-wait-seconds", type=float, default=60,
                        help="Wait at most this long for other host compilers before pausing; excluded from build timing")
    parser.add_argument("--resume", action="store_true", help="Continue the same verified input context and completed trial prefix")
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
    if args.idle_wait_seconds < 0 or args.idle_wait_seconds > 60:
        parser.error("Idle waiting must be between zero and 60 seconds")
    args.output_dir.mkdir(parents=True, exist_ok=args.resume)
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
        "require_idle_compilers": args.require_idle_compilers,
        "compiler_count_semantics": "GHC Compiling events, including Setup and repeated module names across components",
        "trials": [], "warmup": [],
    }
    summary = args.output_dir / "summary.json"
    if args.resume:
        previous = json.loads(summary.read_text())
        fixed = ["project_uri", "source_revision", "platform", "nix_version", "workload", "replacement",
                 "minimum_saving", "cores", "max_jobs", "expression_sha256", "lock_sha256",
                 "evaluation_cache", "require_idle_compilers"]
        if any(previous.get(key) != metadata.get(key) for key in fixed):
            parser.error("Resume context differs; start a new campaign")
        expected = [(trial, label) for trial in range(1, args.trials + 1)
                    for label in (["baseline", "candidate"] if trial % 2 else ["candidate", "baseline"])]
        actual = [(row["trial"], row["label"]) for row in previous["trials"]]
        if actual != expected[:len(actual)] or len(previous["warmup"]) != 2:
            parser.error("Resume requires two completed warmups and a complete ordered trial prefix")
        if [row["label"] for row in previous["warmup"]] != ["baseline", "candidate"]:
            parser.error("Resume warmup order is invalid")
        for row in previous["warmup"]:
            if row["exit_code"] or row["source_variant_sha256"] != digest(sources[row["label"]] / args.edit):
                parser.error("Original disposable source differs from the completed warmup")
            recorded_source = row["command"][row["command"].index("source") + 1]
            if Path(recorded_source).resolve() != sources[row["label"]]:
                parser.error("Resume source directory differs")
            # Re-evaluate only the already completed original warmup, never a
            # pending changed target. Its full identity binds all source,
            # environment, compatibility and seed inputs, including other files.
            current_identity = json.loads(subprocess.check_output([
                "nix", "eval", "--json", "--impure", "--file", str(args.expression),
                "--argstr", "source", str(sources[row["label"]]), "identity"]))
            if current_identity != row["identity"]:
                parser.error("Resume source, recipe or seed inputs changed")
        if any(row["exit_code"] or not sum(row["compiled_modules"].values()) for row in previous["trials"]):
            parser.error("Resume prefix contains a failed or already cached changed-code trial")
        metadata = previous
        metadata.setdefault("resumptions", []).append(datetime.now(timezone.utc).isoformat())
    summary.write_text(json.dumps(metadata, indent=2) + "\n")
    try:
        # Includes the one-time filter migration build; excluded from paired medians.
        if not args.resume:
            for label, source in sources.items():
                metadata["warmup"].append(run_trial(args, label, source, 0, "warmup"))
                summary.write_text(json.dumps(metadata, indent=2) + "\n")
        for trial in range(1, args.trials + 1):
            order = ["baseline", "candidate"] if trial % 2 else ["candidate", "baseline"]
            for label in order:
                if any(row["trial"] == trial and row["label"] == label for row in metadata["trials"]):
                    continue
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
        metadata["cost_limits"] = (
            "migration_cost_seconds is the candidate warmup only, retained for receipt compatibility. "
            "Cached warmups cannot establish seed creation cost. Include independently measured seed creation, "
            "source/recipe migration, final validation, transfer and retention before any adoption decision; "
            "break_even_edits excludes those additional costs."
        )
        summary.write_text(json.dumps(metadata, indent=2) + "\n")
    finally:
        for label, source in sources.items():
            (source / args.edit).write_bytes(original[label])


if __name__ == "__main__":
    main()
