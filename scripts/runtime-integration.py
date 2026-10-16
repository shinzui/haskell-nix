#!/usr/bin/env python3
"""Run bounded disposable scenarios against the retained-generation verifier."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

SCENARIOS = [
    "kiroku/append/correctness/all-order-and-gaps",
    "kiroku/append/correctness/multi-stream-atomicity",
    "kiroku/read/correctness/cursor-semantics",
    "keiro/workflow/correctness/linear-replay-smoke",
    "keiro/workflow/correctness/replay-and-journal-identity",
    "keiro/shard/correctness/ack-coupled-handler-variants",
    "pgmq/ack/correctness/delete-archive-semantics",
    "kafka/consumer/concurrency/static-membership-fencing-is-observable",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--channel", choices=["github", "hackage"], default="github")
    args = parser.parse_args()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    root = Path(__file__).resolve().parent.parent
    record = json.loads((root / "packages/runtime-lock.json").read_text())["runtimes"]["keiro-runtime"][0]
    profile = json.loads((root / f"cabal/runtimes/keiro-runtime/1/{args.channel}-sources.json").read_text())
    results = []
    for index, scenario in enumerate(SCENARIOS):
        command = [args.runner, "run", scenario, "--out", str(output / "runs"),
                   "--timeout", "150", "--strict-known-defects", "--json"]
        if not scenario.startswith("kafka/"):
            command += ["--dim", "pg.version=" + ("18" if scenario.startswith("keiro/") else "17")]
        completed = subprocess.run(command, capture_output=True, text=True, timeout=180)
        (output / f"{index}.stdout").write_text(completed.stdout)
        (output / f"{index}.stderr").write_text(completed.stderr)
        if completed.returncode:
            raise RuntimeError(f"{scenario}: exit {completed.returncode}; see {output}/{index}.stderr")
        result = json.loads(completed.stdout)
        assert result["scenario"] == scenario and result["outcome"] == "passed" and not result["blocking"], result
        identity = result["cohort"]
        assert identity["cohort"] == "keiro-runtime-1" and identity["compiler"] == "ghc-9.12.4", identity
        for component in identity["components"]:
            for package in component["packages"]:
                expected = profile[package["name"]]
                assert package["version"] == expected["version"], package
                if expected["source"] == "SourcePin":
                    origin = expected["identities"][0]["pkg-src"]["source-repo"]
                    assert package["source"]["type"] == "git" and package["source"]["rev"] == origin["tag"], package
                else:
                    assert package["source"]["type"] == "hackage", package
        results.append({"scenario": scenario, "runId": result["runId"], "outcome": result["outcome"],
                        "resultSha256": hashlib.sha256(completed.stdout.encode()).hexdigest()})
        print(f"passed {scenario}", flush=True)
    receipt = {"schemaVersion": 1, "runtime": "keiro-runtime", "generation": 1,
               "runtimeFingerprint": record["fingerprint"],
               "sourceChannel": args.channel, "postgresMajors": [17, 18], "results": results}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"All {len(results)} disposable runtime scenarios passed; {output}/receipt.json", flush=True)


if __name__ == "__main__":
    main()
