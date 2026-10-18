"""Record macOS host headroom without requiring exclusive use of the machine.

Only OS commands are queried. Process arguments and store files are never read.
The same monitor and acceptance rules apply to both variants of a campaign.
"""

import os
import platform
import re
import statistics
import subprocess
import threading
import time
from pathlib import Path


POLICY = {
    "name": "mac-studio-headroom-v1",
    "minimum_cpu_idle_percent": 10,
    "minimum_memory_free_percent": 10,
    "sustained_pressure_seconds": 15,
    "maximum_relative_timing_range": 0.25,
    "concurrent_compilers": "record; process presence alone never rejects a run",
    "limits": "Host-wide samples, not CPU affinity or isolated builder accounting. "
              "Disk contention and thermal effects are not isolated; timing spread is checked separately.",
}


def hardware():
    return {
        "platform": platform.platform(),
        "logical_cpus": os.cpu_count(),
        "model": subprocess.check_output(["sysctl", "-n", "hw.model"], text=True).strip(),
        "memory_bytes": int(subprocess.check_output(["sysctl", "-n", "hw.memsize"], text=True)),
    }


def assess(samples, errors):
    reasons = ["resource sampling failed"] if errors or not samples else []
    for key, threshold in [("cpu_idle_percent", POLICY["minimum_cpu_idle_percent"]),
                           ("memory_free_percent", POLICY["minimum_memory_free_percent"])]:
        since = None
        for row in samples:
            since = (row["elapsed_seconds"] if since is None else since) if row[key] < threshold else None
            if since is not None and row["elapsed_seconds"] - since >= POLICY["sustained_pressure_seconds"]:
                reasons.append("sustained " + key + " below " + str(threshold))
                break
    return {"accepted": not reasons, "reasons": reasons}


def timing_stability(values):
    median = statistics.median(values)
    relative_range = (max(values) - min(values)) / median if median > 0 else float("inf")
    return {"median_seconds": median, "min_seconds": min(values), "max_seconds": max(values),
            "relative_range": relative_range,
            "stable": relative_range <= POLICY["maximum_relative_timing_range"]}


class HostResources:
    def __init__(self):
        if platform.system() != "Darwin":
            raise ValueError("The mac-studio resource policy requires macOS")
        self.samples = []
        self.errors = []
        self.stop = threading.Event()
        self.ready = threading.Event()
        self.started = time.monotonic()
        self.thread = threading.Thread(target=self.sample, daemon=True)

    def start(self):
        self.thread.start()
        self.ready.wait()
        return self

    def sample(self):
        try:
            while not self.stop.is_set():
                # The second top report measures the interval, rather than the
                # first report's cumulative CPU counters. Retain I/O/VM facts.
                top = subprocess.check_output(["top", "-l", "2", "-s", "1", "-n", "0"], text=True, timeout=10)
                pressure = subprocess.check_output(["memory_pressure", "-Q"], text=True, timeout=10)
                processes = subprocess.check_output(["ps", "-axo", "pid=,rss=,comm="], text=True, timeout=10)
                active = []
                for line in processes.splitlines():
                    fields = line.split(None, 2)
                    if len(fields) == 3 and re.fullmatch(r"ghc(?:-[\d.]+)?|clang(?:-[\d.]+)?|ld(?:64)?|(?:ghc-)?iserv.*|Setup|\.?cabal(?:-wrapped)?|.*-tests?", Path(fields[2]).name):
                        active.append({"pid": int(fields[0]), "rss_kib": int(fields[1]), "name": Path(fields[2]).name})
                self.samples.append({
                    "elapsed_seconds": time.monotonic() - self.started,
                    "cpu_idle_percent": float(re.findall(r"([\d.]+)% idle", top)[-1]),
                    "memory_free_percent": int(re.search(r"memory free percentage: (\d+)%", pressure).group(1)),
                    "load_average": os.getloadavg(), "compiler_and_test_processes": active,
                    "vm_and_io": [line for line in top.splitlines() if line.startswith(("VM:", "Disks:"))][-2:],
                })
                self.ready.set()
                self.stop.wait(1)
        except Exception as error:
            self.errors.append(str(error))
        finally:
            self.ready.set()

    def finish(self):
        self.stop.set()
        self.thread.join()
        return {"policy": POLICY, "samples": self.samples, "errors": self.errors,
                "assessment": assess(self.samples, self.errors)}
