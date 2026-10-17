#!/usr/bin/env python3
"""Prepare a disposable closed Mori core foundation without changing module bytes.

Owner: mori://shinzui/mori. Generated source ownership/scaffold integration,
native correctness, performance, retained inventories and adoption remain gates.
"""

import argparse
import hashlib
import io
import json
import re
import shutil
import subprocess
import tarfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkout", type=Path, required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--module-list", type=Path, required=True)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--trim-unbuilt-foundation-sources", action="store_true",
                        help="Keep test fixtures but omit copied test/executable sources with no foundation component")
    parser.add_argument("--api-foundation", action="store_true",
                        help="Audit API imports and replace its core dependency with the stable foundation")
    args = parser.parse_args()
    checkout, destination = args.checkout.resolve(), args.destination.resolve()
    if destination.exists() or destination.is_relative_to(checkout):
        parser.error("Use a new destination outside the producing checkout")
    inventory = json.loads(args.inventory.read_text())
    modules = json.loads(args.module_list.read_text())
    if inventory["project_uri"] != "mori://shinzui/mori" or not modules or len(set(modules)) != len(modules):
        parser.error("Require the explicit Mori inventory and a nonempty unique module list")
    selected = set(modules)
    if not selected < set(inventory["modules"]):
        parser.error("Select a strict subset of the reviewed component")
    if "Mori.Automation.ConfigHash" in selected:
        parser.error("The declared ConfigHash leaf must remain outside the foundation")
    for name in modules:
        if not set(inventory["modules"][name]["internal_imports"]) <= selected:
            parser.error(f"Foundation is not closed: {name}")
    revision = subprocess.check_output(["git", "rev-parse", args.revision + "^{commit}"], cwd=checkout, text=True).strip()
    archive = subprocess.check_output(["git", "archive", "--format=tar", revision], cwd=checkout)
    original = destination / "baseline"
    original.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(original, filter="data")
    candidate = destination / "candidate"
    shutil.copytree(original, candidate, symlinks=True)
    package = candidate / "mori-core"
    cabal = package / "mori-core.cabal"
    if hashlib.sha256(cabal.read_bytes()).hexdigest() != inventory["cabal_sha256"]:
        parser.error("Cabal metadata differs from the reviewed inventory")
    text = cabal.read_text()
    header, rest = text.split("\nlibrary\n", 1)
    library, later = rest.split("\nexecutable mori-migrations\n", 1)
    _, dependencies = library.split("\n  build-depends:", 1)
    version = re.search(r"^version:\s*(\S+)", text, re.M).group(1)
    foundation = candidate / "mori-core-foundation"
    # Preserve all migrations, fixtures and embedded Keiro trees at their
    # original package-relative paths. Both library sources stay complete.
    shutil.copytree(package, foundation, symlinks=True)
    (foundation / "mori-core.cabal").unlink()
    if args.trim_unbuilt_foundation_sources:
        for name in ["diagrams", "domain", "test-diagrams"]:
            shutil.rmtree(foundation / name)
        for source in (foundation / "migrations").rglob("*.hs"):
            source.unlink()
        for child in (foundation / "test").iterdir():
            if child.name != "fixtures":
                if child.is_dir():
                    shutil.rmtree(child)
                else:
                    child.unlink()
    moved = []
    for name, row in inventory["modules"].items():
        source = package / row["file"]
        if not source.resolve().is_relative_to(package.resolve()):
            parser.error(f"Module escapes the owned package: {name}")
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != row["source_sha256"]:
            parser.error(f"Reviewed module bytes changed: {name}")
        if name in selected:
            exact = "    " + name + "\n"
            if library.count(exact) != 1:
                parser.error(f"Require exactly one exposed declaration: {name}")
            library = library.replace(exact, "")
            # Only our newly created disposable copy is changed.
            source.unlink()
            moved.append({"module": name, "file": row["file"], "sha256": digest})
        else:
            (foundation / row["file"]).unlink()
    foundation_header = header.replace("name: mori-core\n", "name: mori-core-foundation\n", 1)
    (foundation / "mori-core-foundation.cabal").write_text(
        foundation_header + "\n\nlibrary\n  import: common-options\n  hs-source-dirs: src\n  exposed-modules:\n"
        + "".join("    " + name + "\n" for name in sorted(selected))
        + "\n  build-depends:" + dependencies)
    library += "\n  reexported-modules:\n" + "".join(
        "    mori-core-foundation:" + name + (",\n" if index + 1 < len(modules) else "\n")
        for index, name in enumerate(sorted(selected)))
    revised = header + "\nlibrary\n" + library + "\nexecutable mori-migrations\n" + later
    revised = revised.replace("  build-depends:\n", "  build-depends:\n    mori-core-foundation ==" + version + ",\n")
    cabal.write_text(revised)
    project = candidate / "cabal.project"
    project.write_text(project.read_text().replace("packages: ", "packages: mori-core-foundation ", 1))
    # The existing owned constructor supplies the same pinned schema before
    # compiling either library. Shared recipes, flags and bounds stay intact.
    overlay = candidate / "nix/haskell-overlay.nix"
    text = overlay.read_text()
    declaration = '  mori-core = haskellLib.overrideCabal\n'
    if text.count(declaration) != 1:
        parser.error("Unexpected owned overlay boundary")
    foundation_recipe = '''  mori-core-foundation = haskellLib.overrideCabal
    (drv: {
      prePatch = (drv.prePatch or "") + ''
        cp -r ${mori-schema-src} ../schema
      '';
    })
    (own "mori-core-foundation");
'''
    overlay.write_text(text.replace(declaration, foundation_recipe + declaration, 1))
    api_boundary = None
    if args.api_foundation:
        api = candidate / "mori-api"
        source_hashes = {}
        imported_modules = set()
        remaining = set(inventory["modules"]) - selected
        for path in sorted(api.rglob("*.hs")):
            if not path.resolve().is_relative_to(api.resolve()):
                parser.error("API source escapes its owned package")
            names = re.findall(r'^\s*import\s+(?:qualified\s+)?(?:"[^\"]+"\s+)?([A-Z][\w.]*)', path.read_text(), re.M)
            if remaining.intersection(names):
                parser.error(f"API imports volatile core modules: {path}")
            imported_modules.update(set(names).intersection(inventory["modules"]))
            source_hashes[str(path.relative_to(api))] = hashlib.sha256(path.read_bytes()).hexdigest()
        api_cabal = api / "mori-api.cabal"
        original_api = api_cabal.read_bytes()
        text = original_api.decode()
        if text.count("    mori-core,\n") != 2:
            parser.error("Unexpected API library/test dependency declarations")
        text = text.replace("    mori-core,\n", "    mori-core-foundation,\n")
        api_cabal.write_text(text)
        api_boundary = {"before_cabal_sha256": hashlib.sha256(original_api).hexdigest(),
                        "after_cabal_sha256": hashlib.sha256(api_cabal.read_bytes()).hexdigest(),
                        "old_dependency": "mori-core", "new_dependency": "mori-core-foundation",
                        "components": ["library", "mori-api-test"],
                        "imported_foundation_modules": sorted(imported_modules),
                        "preserved_haskell_sources": source_hashes}
    manifest = {"schema_version": 1, "project_uri": "mori://shinzui/mori", "source_revision": revision,
                "inventory_sha256": hashlib.sha256(args.inventory.read_bytes()).hexdigest(),
                "new_package": "mori-core-foundation", "version": version, "moved_modules": moved,
                "remaining_modules": sorted(set(inventory["modules"]) - selected),
                "unbuilt_foundation_sources": "omitted; fixtures retained" if args.trim_unbuilt_foundation_sources else "retained for original pilot reproduction",
                "api_boundary": api_boundary,
                "public_modules": "Every moved module reexported through the original mori-core package",
                "resource_policy": "Complete original non-Mori sources, migrations and fixtures retained in both packages; exact pinned schema supplied to each by the existing owned factory",
                "hazards": {name: inventory["modules"][name] for name in sorted(selected)
                            if any(inventory["modules"][name][key] for key in
                                   ("template_haskell", "resource_calls", "cpp", "source_import"))},
                "settings": "Original optimization, common options, dependency bounds, tests and runtime scope preserved",
                "generated_ownership": "Source bytes preserved; scaffold/gate routing and retained owned inventories need validation before adoption",
                "adoption": "Disposable pilot only; production layouts, pins and defaults unchanged",
                "native_validation": "pending"}
    (destination / "split-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps({"destination": str(destination), "moved_module_count": len(moved), "revision": revision}))


if __name__ == "__main__":
    main()
