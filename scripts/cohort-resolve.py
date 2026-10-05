#!/usr/bin/env python3
"""Resolve the initial/broad cohort from explicitly recorded inputs."""
import json
from pathlib import Path
import subprocess


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def main():
    run(["cabal", "build", "exe:haskell-nix-update"])
    cli = subprocess.check_output(["cabal", "list-bin", "exe:haskell-nix-update"], text=True).strip()
    inputs = json.loads(Path("cabal/inventory-inputs.json").read_text())
    run([cli, "cohort", "stub"])
    generated = Path("cabal/cohort.project.freeze")
    generated.unlink(missing_ok=True)
    run(["cabal", "build", "all", "--dry-run", "--project-file=cohort.project"], cwd="cabal")
    run(["cabal", "freeze", "--project-file=cohort.project"], cwd="cabal")
    run([cli, "cohort", "normalise-freeze", "--in", str(generated), "--out", "cabal/cohort.freeze",
         "--index-state", inputs["indexState"], "--haskell-nix-rev", inputs["channelRevision"]])
    generated.unlink()


if __name__ == "__main__":
    main()
