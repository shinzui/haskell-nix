#!/usr/bin/env python3
"""Materialize hash-checked Cabal runtime imports from an immutable channel commit."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import tempfile
import sys
from urllib.request import urlopen


def prepare(revision, runtime, generation, channel, fetch, application_sources=None):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("channel revision must be a full immutable Git revision")
    if not re.fullmatch(r"[a-z0-9-]+", runtime) or generation < 1 or channel not in ("github", "hackage"):
        raise ValueError("invalid runtime, generation or source channel")
    lock = json.loads(fetch("packages/runtime-lock.json"))
    if lock.get("schemaVersion") != 1:
        raise ValueError("unsupported runtime lock schema")
    matches = [r for r in lock["runtimes"].get(runtime, []) if r["generation"] == generation]
    if len(matches) != 1:
        raise ValueError("unknown or ambiguous retained runtime generation")
    record = matches[0]
    prefix = f"cabal/runtimes/{runtime}/{generation}"
    if record["freezeFile"] != prefix + "/cohort.freeze" or not re.fullmatch(r"[0-9a-f]{64}", record["fingerprint"]):
        raise ValueError("invalid retained runtime projection identity")
    files = {}
    hashes = {}
    for name in ("cohort.freeze", "configuration.project", channel + ".project", channel + "-sources.json"):
        path = prefix + "/" + name
        expected = record["projections"][path]
        content = fetch(path)
        if hashlib.sha256(content).hexdigest() != expected:
            raise ValueError("runtime projection hash mismatch: " + path)
        files[name] = content
        hashes[name] = expected
    # The shared comparator owns parsing and validation. Supply its expected
    # source manifest for the selected transport, preserving the complete cohort
    # outside the retained runtime rather than ignoring intentional Git sources.
    sources = json.loads(fetch("cabal/cohort-sources.json"))
    runtime_sources = json.loads(files[channel + "-sources.json"])
    if set(runtime_sources) != set(record["ownership"]):
        raise ValueError("runtime source manifest does not match retained ownership")
    for name, package in runtime_sources.items():
        if name not in sources or sources[name]["version"] != package["version"]:
            raise ValueError("runtime/cohort version conflict: " + name)
    sources.update(runtime_sources)
    if application_sources:
        contributors = json.loads(fetch("cabal/contributors.json"))
        owners = {name: contributor["mori"] for contributor in contributors
                  for name in contributor["ownPackages"]}
        for name, policy in application_sources.items():
            if name in sources or name not in owners:
                raise ValueError("application source must be a declared contributor package outside the cohort: " + name)
            if policy.get("owner") != owners[name] or not str(policy.get("reason", "")).strip():
                raise ValueError("application source requires its declared owner and a reason: " + name)
            package = policy["package"]
            if package.get("source") != "SourcePin" or not package.get("identities"):
                raise ValueError("application source requires pinned source evidence: " + name)
            for identity in package["identities"]:
                source = identity.get("pkg-src", {})
                repo = source.get("source-repo", {})
                if (source.get("type") != "source-repo" or repo.get("type") != "git"
                        or not str(repo.get("location", "")).startswith("https://")
                        or not re.fullmatch(r"[0-9a-f]{40}", repo.get("tag", ""))
                        or not re.fullmatch(r"[0-9a-f]{64}", identity.get("pkg-src-sha256", ""))
                        or identity.get("pkg-name") != name
                        or identity.get("pkg-version") != package.get("version")):
                    raise ValueError("application source requires immutable matching source identity: " + name)
            sources[name] = package
    files["comparison-sources.json"] = (json.dumps(sources, indent=2, sort_keys=True) + "\n").encode()
    hashes["comparison-sources.json"] = hashlib.sha256(files["comparison-sources.json"]).hexdigest()
    metadata = {"schemaVersion": 1, "runtime": runtime, "generation": generation,
                "channel": channel, "channelRevision": revision,
                "runtimeFingerprint": record["fingerprint"], "files": hashes}
    files["selection.json"] = (json.dumps(metadata, indent=2, sort_keys=True) + "\n").encode()
    return files


def publish(destination, files, check=False):
    destination = Path(destination)
    if destination.is_symlink():
        raise ValueError("runtime import destination must not be a symlink")
    previous = {}
    for name, content in files.items():
        path = destination / name
        if path.is_symlink():
            raise ValueError("runtime projection must not be a symlink: " + name)
        previous[name] = path.read_bytes() if path.exists() else None
        if check and previous[name] != content:
            raise ValueError("missing or stale runtime import: " + name)
        if name not in ("selection.json", "comparison-sources.json") and previous[name] not in (None, content):
            raise ValueError("refusing to overwrite changed retained projection: " + name)
    if check:
        return
    destination.mkdir(parents=True, exist_ok=True)
    changed = []
    with tempfile.TemporaryDirectory(prefix=".runtime-import-", dir=destination) as temporary:
        staged = Path(temporary)
        for name, content in files.items():
            (staged / name).write_bytes(content)
        try:
            for name, content in files.items():
                if previous[name] == content:
                    continue
                (staged / name).replace(destination / name)
                changed.append(name)
        except BaseException:
            for name in reversed(changed):
                path = destination / name
                if previous[name] is None:
                    path.unlink()
                else:
                    path.write_bytes(previous[name])
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--runtime", default="keiro-runtime")
    parser.add_argument("--generation", type=int, required=True)
    parser.add_argument("--channel", choices=["github", "hackage"], required=True)
    parser.add_argument("--destination", required=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--application-sources", help="Owned contributor source policy, outside the shared cohort")
    args = parser.parse_args()
    # Validate revision before using it as part of any URL.
    if not re.fullmatch(r"[0-9a-f]{40}", args.revision):
        parser.error("--revision requires a full immutable Git revision")

    def fetch(path):
        assert not PurePosixPath(path).is_absolute() and ".." not in PurePosixPath(path).parts
        url = "https://raw.githubusercontent.com/shinzui/haskell-nix/" + args.revision + "/" + path
        with urlopen(url, timeout=60) as response:
            if not response.url.startswith("https://"):
                raise ValueError("runtime source transport requires HTTPS")
            return response.read()

    application_sources = json.loads(Path(args.application_sources).read_bytes()) if args.application_sources else None
    files = prepare(args.revision, args.runtime, args.generation, args.channel, fetch, application_sources)
    publish(args.destination, files, args.check)
    print(("Verified " if args.check else "Materialized ") + str(Path(args.destination) / (args.channel + ".project")))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print("runtime-import: " + str(error), file=sys.stderr)
        raise SystemExit(1) from None
