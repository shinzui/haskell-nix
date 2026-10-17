#!/usr/bin/env python3
"""Stage scaffold, formatter and push-gate routing in the disposable Mori pilot."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    root = args.source.resolve()
    config = json.loads((root / ".mp4-pilot.json").read_text())
    if config.get("application") != "mori" or not config.get("packageSplit"):
        parser.error("Only a disposable prepared Mori split candidate is supported")
    helper = Path(__file__).resolve().parents[1] / "checks/fixtures/application-builds/mori-core-scaffold.py"
    target = root / "scripts/scaffold-core-sources.py"
    if target.exists():
        parser.error("Workflow is already prepared")
    shutil.copyfile(helper, target)
    justfile = root / "justfile"
    text = justfile.read_text()
    old = "  just keiro-dsl scaffold domain/mori.keiro-workspace --out mori-core/src --goldens mori-core/test/fixtures/golden/events"
    if text.count(old) != 1:
        parser.error("Unexpected scaffold command")
    text = text.replace(old, "  python3 scripts/scaffold-core-sources.py", 1)
    start = text.index('  scratch="$(mktemp -d)"', text.index("keiro-gate:"))
    end = text.index('  echo "keiro-gate: conformance suite"', start)
    text = text[:start] + '''  if ! python3 scripts/scaffold-core-sources.py --check > build/keiro-gate-scaffold.log 2>&1; then
    tail -40 build/keiro-gate-scaffold.log
    echo "keiro-gate: split source, Cabal inventory or golden drift; run just keiro-scaffold and review the changes" >&2
    exit 1
  fi
''' + text[end:]
    justfile.write_text(text)
    treefmt = root / "nix/treefmt.nix"
    lines = treefmt.read_text().splitlines(keepends=True)
    treefmt.write_text("".join(line + (line.replace('"mori-core/src/', '"mori-core-foundation/src/')
                                      if line.lstrip().startswith('"mori-core/src/') else "") for line in lines))
    hooks = root / "nix/pre-commit.nix"
    text = hooks.read_text().replace("mori-core/src", "mori-core(-foundation)?/src")
    text = text.replace("mori-core/test/fixtures/golden/events/)",
                        "mori-core/test/fixtures/golden/events/|cabal\\\\.project$|mori-core(-foundation)?/mori-core(-foundation)?\\\\.cabal$|scripts/(scaffold-core-sources\\\\.py|keiro-gate-fingerprint\\\\.sh)$)")
    hooks.write_text(text)
    fingerprint = root / "scripts/keiro-gate-fingerprint.sh"
    text = fingerprint.read_text()
    start = text.index("  find mori-core/src/Mori/Modules")
    end = text.index("  find mori-core/test/fixtures/golden/events", start)
    text = text[:start] + '''  printf '%s\\n' cabal.project mori-core/mori-core.cabal mori-core-foundation/mori-core-foundation.cabal scripts/scaffold-core-sources.py scripts/keiro-gate-fingerprint.sh
  for source_root in mori-core/src mori-core-foundation/src; do
    find "$source_root/Mori/Modules" -type d -name Generated -exec find {} -type f \\;
    find "$source_root" -mindepth 1 -maxdepth 1 -type d -name 'keiro-dsl-*' \\
      -exec find {} -type f \\;
  done
''' + text[end:]
    fingerprint.write_text(text)
    files = [target, justfile, treefmt, hooks, fingerprint]
    receipt = {"schemaVersion": 1, "project": "mori://shinzui/mori", "scope": "Disposable workflow preparation; native scaffold/conformance and production adoption pending",
               "files": {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files},
               "contract": "The same declared Keiro command sees one merged source tree; existing placement, duplicate resource bytes and executable bits are preserved. Module inventories and public reexports are derived together without changing other Cabal fields. Checks are read-only. Both roots and relevant package/project/helper metadata participate in formatter exclusions and push-gate fingerprints."}
    output = root.parent / "workflow-preparation.json"
    output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    print(output)


if __name__ == "__main__":
    main()
