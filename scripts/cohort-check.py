#!/usr/bin/env python3
"""Verify the freeze-only solve against recorded versions and source identities."""
import subprocess


def main():
    subprocess.run(["cabal", "build", "exe:haskell-nix-update"], check=True)
    cli = subprocess.check_output(["cabal", "list-bin", "exe:haskell-nix-update"], text=True).strip()
    subprocess.run(["cabal", "build", "all", "--dry-run", "--project-file=check.project"],
                   cwd="cabal", check=True)
    subprocess.run([cli, "cohort", "check"], check=True)


if __name__ == "__main__":
    main()
