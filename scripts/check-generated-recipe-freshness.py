#!/usr/bin/env python3
"""Reconvert a validated command model without a nested writable Nix store."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def local_file(root, relative):
    path = Path(relative)
    if path.is_absolute() or any(part in ("..", ".") for part in path.parts):
        raise SystemExit("unverified input path")
    current = root
    for part in path.parts:
        current /= part
        if current.is_symlink():
            raise SystemExit("input path contains a symbolic link")
    if not current.is_file() or not current.resolve().is_relative_to(root.resolve()):
        raise SystemExit("input path is not a regular local file")
    return current


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--commands", type=Path, required=True)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--recipes", type=Path, required=True)
    parser.add_argument("--converter", type=Path, required=True)
    options = parser.parse_args()
    model = json.loads(options.commands.read_text())
    if model["schemaVersion"] != 1 or not model["packages"]:
        raise SystemExit("unsupported or empty command model")
    tool = model["configuration"]["converter"]
    if options.converter != Path(tool["output"]) / "bin/cabal2nix":
        raise SystemExit("converter differs from the Nix-bound command model")
    version = subprocess.check_output([str(options.converter), "--version"], text=True).strip()
    if version != tool["version"]:
        raise SystemExit("converter version changed")
    environment = os.environ.copy()
    environment.update({name: "http://127.0.0.1:9" for name in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY")})
    for name, command in sorted(model["packages"].items()):
        metadata = local_file(options.inputs, command["metadataPath"])
        archive = local_file(options.inputs, command["archivePath"])
        snapshots = {path: path.read_bytes() for path in (metadata, archive)}
        for path, expected in ((metadata, command["metadataSha256"]), (archive, command["archiveSha256"])):
            if hashlib.sha256(snapshots[path]).hexdigest() != expected:
                raise SystemExit(f"input identity changed for {name}: {path.name}")
        arguments = command["arguments"]
        if not arguments or arguments[-1] != command["metadataPath"]:
            raise SystemExit("unverified converter argument model")
        if "--src-expression=src" not in arguments or "--no-hpack" not in arguments:
            raise SystemExit("metadata-directory conversion requires an explicit source placeholder and disabled hpack")
        # The pinned converter initializes a user cache for a file URI even
        # when its hash is supplied. Directory input uses the same Cabal parser.
        # Keep exact metadata and flags; the separately bound source is `src`.
        # The byte comparison below must still match the ordinary generator.
        with tempfile.TemporaryDirectory(prefix="recipe-fresh-") as scratch:
            copied = Path(scratch) / metadata.name
            copied.write_bytes(snapshots[metadata])
            result = subprocess.run(
                [str(options.converter), *arguments[:-1], scratch],
                capture_output=True, text=True, env=environment,
            )
            if copied.read_bytes() != snapshots[metadata]:
                raise SystemExit(f"converter changed selected metadata for {name}")
        if result.returncode != 0:
            raise SystemExit(f"converter failed for {name}: {result.stderr.strip()}")
        if any(path in result.stdout for path in (str(metadata.resolve()), str(options.inputs.resolve()), scratch)):
            raise SystemExit(f"transient path leaked for {name}")
        if any(path.read_bytes() != original for path, original in snapshots.items()):
            raise SystemExit(f"inputs changed during conversion for {name}")
        expected = local_file(options.recipes, f"packages/{name}.nix").read_bytes()
        if (result.stdout.rstrip() + "\n").encode() != expected:
            raise SystemExit(f"generated recipe is stale: {name}")
        print(f"Fresh generated recipe: {name}")


if __name__ == "__main__":
    main()
