#!/usr/bin/env python3
"""Keep Hackage source/version selection out of overlay policy files."""
import re
import sys
from pathlib import Path


FETCH = re.compile(r"\bcallHackage(?:Direct)?\b|hackage\.haskell\.org/package")


def violations(directory):
    for path in sorted(Path(directory).rglob("*.nix")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if not line.lstrip().startswith("#") and FETCH.search(line):
                yield f"{path}:{number}: {line.strip()}"


def main():
    found = [line for directory in sys.argv[1:] for line in violations(directory)]
    if found:
        print("registry-policy-only: Hackage selection belongs in the cohort", file=sys.stderr)
        print("\n".join(found), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
