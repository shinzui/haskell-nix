#!/usr/bin/env python3
"""Verify the freeze-only solve against recorded versions and source identities."""
import subprocess
import json
from pathlib import Path
from cohort_toolchain import compiler_args, compiler_environment


def main():
    subprocess.run(["cabal", "build", "exe:haskell-nix-update"], check=True)
    cli = subprocess.check_output(["cabal", "list-bin", "exe:haskell-nix-update"], text=True).strip()
    inputs = json.loads(Path("cabal/inventory-inputs.json").read_text())
    subprocess.run(["cabal", "build", "all", "--dry-run", "--project-file=check.project",
                    "--index-state=" + inputs["indexState"], *compiler_args()],
                   cwd="cabal", check=True, env=compiler_environment())
    subprocess.run([cli, "cohort", "check", "--compiler", inputs["compiler"]], check=True)


if __name__ == "__main__":
    main()
