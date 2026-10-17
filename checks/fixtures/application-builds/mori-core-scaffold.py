#!/usr/bin/env python3
"""Run the declared Mori scaffolder against the combined core source tree.

Owner: mori://shinzui/mori. The existing Keiro tool owns generated Haskell bytes.
This command preserves package placement and derives Cabal module lists/public
reexports from that placement, leaving all other package settings unchanged.
"""

import argparse
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def files(directory):
    result = {}
    if directory.is_symlink():
        raise ValueError("Source layout does not accept symlinks: " + str(directory))
    for parent, directories, names in os.walk(directory, followlinks=False):
        for name in sorted(directories + names):
            path = Path(parent) / name
            if path.is_symlink():
                raise ValueError("Source layout does not accept symlinks: " + str(path))
        for name in sorted(names):
            path = Path(parent) / name
            result[path.relative_to(directory)] = (path.read_bytes(), bool(path.stat().st_mode & 0o111))
    return result


def library_field(cabal, field):
    library = cabal.split("\nlibrary\n", 1)[1]
    library = re.split(r"\n(?=executable |test-suite |benchmark |library )", library, maxsplit=1)[0]
    match = re.search(r"(?m)^  " + re.escape(field) + r":[ \t]*([^\n]*)\n((?:(?: {4,}|\t)[^\n]*\n|\n)*)", library)
    if match is None:
        return []
    content = "\n".join(line.split("--", 1)[0] for line in (match[1] + "\n" + match[2]).splitlines())
    return [name for name in re.split(r"[,\s]+", content.strip()) if name]


def module_names(entries):
    return {".".join(path.with_suffix("").parts) for path in entries
            if path.parts[0] == "Mori" and path.suffix == ".hs"}


def check_module_coverage(root, sources, cabals=None):
    cabals = cabals or {name: (root / name / (name + ".cabal")).read_text() for name in sources}
    exposed = {}
    for name, entries in sources.items():
        actual = module_names(entries)
        declared = library_field(cabals[name], "exposed-modules")
        if len(declared) != len(set(declared)) or actual != set(declared):
            raise ValueError(name + ": review exposed-modules after scaffolding; missing="
                             + str(sorted(actual - set(declared))) + "; stale=" + str(sorted(set(declared) - actual)))
        exposed[name] = actual
    reexports = library_field(cabals["mori-core"], "reexported-modules")
    expected = {"mori-core-foundation:" + name for name in exposed["mori-core-foundation"]}
    if len(reexports) != len(set(reexports)) or set(reexports) != expected:
        raise ValueError("mori-core: review public reexports after foundation module changes")


def module_field(cabal, field, names, commas=False):
    if set(library_field(cabal, field)) == set(names):
        return cabal
    pattern = r"(?m)^  " + re.escape(field) + r":[ \t]*[^\n]*\n(?:(?: {4,}|\t)[^\n]*\n|\n)*"
    matches = list(re.finditer(pattern, cabal))
    if len(matches) != 1:
        raise ValueError("Expected one explicit main-library field: " + field)
    ordered = sorted(names)
    replacement = "  " + field + ":\n" + "".join(
        "    " + name + (",\n" if commas and index + 1 < len(ordered) else "\n")
        for index, name in enumerate(ordered)) + "\n"
    match = matches[0]
    return cabal[:match.start()] + replacement + cabal[match.end():]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compare staged output without changing source or goldens")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    packages = ["mori-core", "mori-core-foundation"]
    for name in packages:
        if (root / name).is_symlink() or (root / name / "src").is_symlink():
            raise ValueError("Source package/root must not be a symlink: " + name)
        if not (root / name / "src").is_dir():
            raise ValueError("Expected split source directory: " + name)
        cabal = root / name / (name + ".cabal")
        if cabal.is_symlink():
            raise ValueError("Owned Cabal metadata must not be a symlink: " + str(cabal))
        if library_field(cabal.read_text(), "other-modules"):
            raise ValueError("Review private library module ownership before using the split scaffolder")
    sources = {name: files(root / name / "src") for name in packages}
    if args.check:
        check_module_coverage(root, sources)
    combined, owners = {}, {}
    for name, entries in sources.items():
        for path, content in entries.items():
            if path in combined and combined[path] != content:
                raise ValueError("Conflicting duplicate source ownership: " + str(path))
            combined[path] = content
            owners.setdefault(path, []).append(name)
    goldens = root / "mori-core/test/fixtures/golden/events"
    parent = root
    for part in goldens.relative_to(root).parts:
        parent = parent / part
        if parent.is_symlink():
            raise ValueError("Golden directory must not traverse a symlink: " + str(parent))
    golden_files = files(goldens)
    with tempfile.TemporaryDirectory(prefix="mori-core-scaffold-") as temporary:
        stage = Path(temporary)
        output = stage / "src"
        output.mkdir()
        for path in combined:
            destination = output / path
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / owners[path][0] / "src" / path, destination)
        shutil.copytree(goldens, stage / "goldens")
        subprocess.run(["just", "keiro-dsl", "scaffold", "domain/mori.keiro-workspace",
                        "--out", str(output), "--goldens", str(stage / "goldens")], cwd=root, check=True)
        planned = files(output)
        if set(combined) - set(planned):
            raise ValueError("Scaffolder removed source files; review an explicit ownership migration")
        changes = [(path, content) for path, content in planned.items() if combined.get(path) != content]
        planned_goldens = files(stage / "goldens")
        if set(golden_files) - set(planned_goldens):
            raise ValueError("Scaffolder removed golden files; review an explicit migration")
        golden_changes = [(path, content) for path, content in planned_goldens.items() if golden_files.get(path) != content]
        projected = {name: dict(entries) for name, entries in sources.items()}
        for path, content in planned.items():
            destinations = owners.get(path, ["mori-core-foundation"] if path.parts[0] == "Mori" else packages)
            for name in destinations:
                projected[name][path] = content
        cabals = {name: (root / name / (name + ".cabal")).read_text() for name in packages}
        for name in packages:
            cabals[name] = module_field(cabals[name], "exposed-modules", module_names(projected[name]))
        cabals["mori-core"] = module_field(cabals["mori-core"], "reexported-modules",
            {"mori-core-foundation:" + name for name in module_names(projected["mori-core-foundation"])}, commas=True)
        check_module_coverage(root, projected, cabals)
        cabal_changes = {name: text for name, text in cabals.items()
                         if text != (root / name / (name + ".cabal")).read_text()}
        if args.check:
            if changes or golden_changes or cabal_changes:
                raise ValueError("Generated bytes differ; run just keiro-scaffold and review the source/golden changes")
        else:
            for path, content in changes:
                # Existing module placement is authoritative. New generated
                # Mori modules enter the foundation; its Cabal inventory and
                # original-package reexports are updated together below.
                destinations = owners.get(path, ["mori-core-foundation"] if path.parts[0] == "Mori" else packages)
                for name in destinations:
                    destination = root / name / "src" / path
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(output / path, destination)
            for path, content in golden_changes:
                destination = goldens / path
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(stage / "goldens" / path, destination)
            for name, text in cabal_changes.items():
                (root / name / (name + ".cabal")).write_text(text)
        digest = hashlib.sha256(b"".join(str(path).encode() + b"\0" + content[0]
                                        + (b"\0executable\0" if content[1] else b"\0regular\0")
                                        for path, content in sorted(planned.items()))).hexdigest()
        print("Mori split scaffold: " + ("unchanged" if args.check else "applied")
              + f"; files={len(planned)}; source-changes={len(changes)}; golden-changes={len(golden_changes)}; cabal-changes={len(cabal_changes)}; sha256={digest}")
        if not args.check and any(path not in combined and path.parts[0] == "Mori" for path, _ in changes):
            print("Review the new foundation modules and generated public reexports, then rerun the gate.")


if __name__ == "__main__":
    main()
