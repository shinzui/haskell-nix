#!/usr/bin/env python3
"""Resolve the initial/broad cohort from explicitly recorded inputs."""
import json
from pathlib import Path
import subprocess
import tempfile
from cohort_toolchain import compiler_args, compiler_environment


def run(args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def main():
    run(["cabal", "build", "exe:haskell-nix-update"])
    cli = subprocess.check_output(["cabal", "list-bin", "exe:haskell-nix-update"], text=True).strip()
    inputs = json.loads(Path("cabal/inventory-inputs.json").read_text())
    run([cli, "cohort", "stub"])
    generated = Path("cabal/cohort.project.freeze")
    generated.unlink(missing_ok=True)
    # Imported policy edits must be read afresh; retain the old cache as evidence.
    cache = Path("cabal/dist-newstyle/cache")
    if cache.exists():
        retained_cache = Path(tempfile.mkdtemp(prefix="cache-before-resolve-", dir=cache.parent))
        cache.rename(retained_cache / "cache")
    selected_index = "--index-state=" + inputs["indexState"]
    run(["cabal", "build", "all", "--dry-run", "--project-file=cohort.project", selected_index, *compiler_args()], cwd="cabal", env=compiler_environment())
    run(["cabal", "freeze", "--project-file=cohort.project", selected_index, *compiler_args()], cwd="cabal", env=compiler_environment())
    run([cli, "cohort", "normalise-freeze", "--in", str(generated), "--out", "cabal/cohort.freeze",
         "--index-state", inputs["indexState"], "--haskell-nix-rev", inputs["channelRevision"], "--compiler", inputs["compiler"]])
    generated.unlink()


if __name__ == "__main__":
    main()
