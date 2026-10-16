#!/usr/bin/env python3
"""Publish declared dependency roots and prove substitution into an empty store.

Use Nix metadata APIs throughout; never infer dependency identities from path names.
The cohort-closure root retains every cohort library, including static dependencies.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import socket
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlsplit


def run(command, *, payload=None, quiet=False):
    result = subprocess.run(command, input=payload, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE if quiet else None, check=True)
    return result.stdout


def metadata(paths, store=None, all_paths=False, recursive=True, quiet=False):
    command = ["nix", "path-info", "--json"]
    if store:
        command += ["--store", store]
        if store.startswith("https://"):
            command += ["--option", "narinfo-cache-negative-ttl", "0"]
    command += ["--all"] if all_paths else (["--recursive"] if recursive else []) + list(paths)
    rows = json.loads(run(command, quiet=quiet))
    if isinstance(rows, list):
        rows = {row["path"]: row for row in rows if row is not None}
    return {
        path: {"narHash": row["narHash"], "narSize": row["narSize"], "references": sorted(row["references"])}
        for path, row in rows.items() if row is not None
    }


def validate_receipt(receipt):
    if receipt.get("schemaVersion") != 1:
        raise ValueError("unsupported publication receipt schema")
    roots, graph = receipt.get("roots"), receipt.get("paths")
    if not isinstance(roots, list) or not roots or not isinstance(graph, dict) or not graph:
        raise ValueError("publication receipt has no roots or dependency evidence")
    if any(root not in graph for root in roots):
        raise ValueError("publication receipt omits a declared root")
    if any(ref not in graph for row in graph.values() for ref in row["references"]):
        raise ValueError("publication receipt omits a dependency")
    cache = receipt.get("cache", "")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", cache):
        raise ValueError("invalid Cachix cache name")
    return roots, graph, "https://" + cache + ".cachix.org"


def receipt_caches(receipt):
    _, _, primary = validate_receipt(receipt)
    upstream = receipt.get("upstreamCaches", ["https://cache.nixos.org"])
    if not isinstance(upstream, list):
        raise ValueError("upstream caches must be a list")
    caches = list(dict.fromkeys([primary, *upstream]))
    for uri in caches:
        parsed = urlsplit(uri)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError("cache receipts require HTTPS cache URLs without embedded credentials")
    return caches


def remote_metadata(paths, caches):
    # Cachix intentionally omits paths already supplied by its upstream cache.
    # Query every retained path across the declared cache set rather than asking
    # one cache for a complete recursive closure that it does not own.
    def locate(path):
        for cache in caches:
            try:
                row = metadata([path], cache, recursive=False, quiet=True)
                if path in row:
                    return path, row[path], cache
            except subprocess.CalledProcessError:
                continue
        raise ValueError("path is unavailable from the declared cache set: " + path)
    with ThreadPoolExecutor(max_workers=8) as workers:
        rows = list(workers.map(locate, sorted(paths)))
    return {path: row for path, row, _ in rows}, {path: cache for path, _, cache in rows}


def require_equal(expected, actual):
    if expected != actual:
        changed = sorted(path for path in expected.keys() | actual.keys() if expected.get(path) != actual.get(path))
        raise ValueError("cache dependency evidence differs: " + ", ".join(changed))


def derivation_systems(document):
    # Nix's versioned JSON wraps the legacy derivation map.
    rows = document.get("derivations", document)
    if not isinstance(rows, dict) or not rows:
        raise ValueError("missing root derivation metadata")
    return sorted({row["system"] for row in rows.values()})


def write_receipt(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as handle:
        temporary = handle.name
        json.dump(value, handle, indent=2, sort_keys=True)
        handle.write("\n")
    os.replace(temporary, path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    publish = commands.add_parser("publish")
    publish.add_argument("--root", action="append", required=True, help="Nix installable; repeat for runtime roots")
    publish.add_argument("--cache", default="tan")
    publish.add_argument("--upstream-cache", action="append", default=["https://cache.nixos.org"])
    publish.add_argument("--receipt", required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("--receipt", required=True)
    verify.add_argument("--store", required=True, help="Empty verification store, e.g. local?root=/absolute/worker (no symlink parents)")
    verify.add_argument("--evidence", required=True)
    args = parser.parse_args()
    if args.command == "publish":
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", args.cache):
            parser.error("invalid Cachix cache name")
        built = json.loads(run(["nix", "build", "--json", "--no-link", "--print-build-logs",
                                "--max-jobs", "2", "--cores", "2", *args.root]))
        roots = sorted({path for row in built for path in row["outputs"].values()})
        derivations = json.loads(run(["nix", "derivation", "show", *sorted({row["drvPath"] for row in built})]))
        systems = derivation_systems(derivations)
        if len(systems) != 1:
            raise ValueError("publish roots for one supported system per receipt")
        paths = metadata(roots)
        receipt = {"schemaVersion": 1, "cache": args.cache, "installables": args.root,
                   "builds": built, "systems": systems, "roots": roots, "paths": paths,
                   "upstreamCaches": args.upstream_cache}
        caches = receipt_caches(receipt)
        run(["cachix", "push", args.cache], payload="\n".join(roots) + "\n")
        remote, sources = remote_metadata(paths, caches)
        require_equal(paths, remote)
        receipt["remoteCacheSources"] = sources
        receipt["remoteVerified"] = True
        write_receipt(args.receipt, receipt)
        print(f"Published and remotely verified {len(paths)} paths; receipt: {args.receipt}")
    else:
        receipt = json.loads(Path(args.receipt).read_text())
        roots, paths, _ = validate_receipt(receipt)
        caches = receipt_caches(receipt)
        worker_system = run(["nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem"]).strip()
        if receipt.get("systems") != [worker_system]:
            raise ValueError("verification must run on a worker matching the published root system")
        if Path(args.receipt).resolve() == Path(args.evidence).resolve():
            parser.error("verification evidence must not overwrite the publication receipt")
        present = metadata([], args.store, all_paths=True)
        overlap = sorted(paths.keys() & present.keys())
        if overlap:
            raise ValueError(f"verification store already contains {len(overlap)} expected paths; use an empty store")
        run(["nix-store", "--store", args.store, "--realise", *roots,
             "--option", "substituters", " ".join(caches), "--option", "max-jobs", "0",
             "--option", "builders", "", "--option", "fallback", "false",
             "--option", "narinfo-cache-negative-ttl", "0"])
        require_equal(paths, metadata(roots, args.store))
        write_receipt(args.evidence, {"schemaVersion": 1, "publication": receipt,
                                     "verificationStore": args.store, "initialExpectedPaths": 0,
                                     "workerSystem": worker_system, "workerHostname": socket.gethostname(),
                                     "substitutedPaths": len(paths), "buildsPerformed": 0})
        print(f"Verified {len(paths)} substitutions without builds; evidence: {args.evidence}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"cohort-cache: {error}", file=sys.stderr)
        sys.exit(1)
