#!/usr/bin/env python3
"""Verify a consumer's real helper reaps an orphan while retaining a live cluster.

The probe command must print a JSON object with dataDirectory, connectionString,
and consumerPid, then hold its database until SIGTERM. Only processes started by
this script are signalled. PostgreSQL must be available through PATH.
"""

import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--helper", required=True, help="Canonical Mori helper reference")
    parser.add_argument("--receipt", required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        parser.error("A holding probe command is required after --")
    owned = []
    with tempfile.TemporaryDirectory(prefix="mp3-cleanup-proof-") as work:
        work = Path(work)

        def start(label):
            tmpdir = work / label
            tmpdir.mkdir()
            env = dict(os.environ, TMPDIR=str(tmpdir))
            stderr = (work / (label + ".stderr")).open("w")
            process = subprocess.Popen(
                command, cwd=args.cwd, env=env, stdout=subprocess.PIPE,
                stderr=stderr, text=True,
            )
            owned.append((process, stderr, None))
            deadline = time.monotonic() + 180
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                while time.monotonic() < deadline:
                    if not selector.select(timeout=1):
                        continue
                    line = process.stdout.readline()
                    if not line:
                        stderr.flush()
                        raise RuntimeError(f"{label} exited before readiness:\n{Path(stderr.name).read_text()}")
                    try:
                        cluster = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if isinstance(cluster, dict) and "consumerPid" in cluster:
                        owned[-1] = (process, stderr, cluster)
                        cluster["tmpdir"] = str(tmpdir)
                        cluster["postmasterPid"] = int(
                            (Path(cluster["dataDirectory"]) / "postmaster.pid")
                            .read_text().splitlines()[0]
                        )
                        return cluster
            raise TimeoutError(f"{label} did not become ready")

        def query(cluster):
            result = subprocess.run(
                ["psql", cluster["connectionString"], "-XAtc", "SELECT 1"],
                capture_output=True, text=True, timeout=20, check=True,
            )
            assert result.stdout.strip() == "1", result

        try:
            live = start("live-session")
            orphan = start("killed-session")
            query(live)
            query(orphan)
            root = Path(live["dataDirectory"]).parent
            assert root.name.endswith("-" + str(os.geteuid())), "Root is not effective-UID specific"
            assert Path(orphan["dataDirectory"]).parent == root
            os.kill(orphan["consumerPid"], signal.SIGKILL)
            owned[1][0].wait(timeout=30)
            os.kill(orphan["postmasterPid"], 0)
            assert Path(orphan["dataDirectory"]).is_dir()
            replacement = start("replacement-session")
            assert Path(replacement["dataDirectory"]).parent == root
            assert not Path(orphan["dataDirectory"]).exists(), "Orphan data survived sweep"
            try:
                os.kill(orphan["postmasterPid"], 0)
            except ProcessLookupError:
                pass
            else:
                raise AssertionError("Orphan postmaster survived sweep")
            query(live)
            query(replacement)
            receipt = {
                "helper": args.helper, "command": command, "cwd": args.cwd,
                "stableRoot": str(root), "sessions": [live, orphan, replacement],
                "orphanDataRemoved": True, "orphanPostmasterRemoved": True,
                "liveConsumerStillConnectable": True,
            }
        finally:
            for process, stderr, cluster in reversed(owned):
                if process.poll() is None:
                    os.kill(cluster["consumerPid"] if cluster else process.pid, signal.SIGTERM)
                    process.wait(timeout=30)
                stderr.close()
        for cluster in [live, replacement]:
            assert not Path(cluster["dataDirectory"]).exists(), "Normal teardown left data"
            try:
                os.kill(cluster["postmasterPid"], 0)
            except ProcessLookupError:
                pass
            else:
                raise AssertionError("Normal teardown left a postmaster")
        receipt["normalTeardown"] = True
        Path(args.receipt).write_text(json.dumps(receipt, indent=2) + "\n")
        print("PASS: cross-session orphan reclaimed; concurrent live consumer retained")


if __name__ == "__main__":
    main()
