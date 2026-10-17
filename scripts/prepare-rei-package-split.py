#!/usr/bin/env python3
"""Prepare a disposable Rei CLI package-boundary pilot from an immutable Git archive.

Owner: mori://shinzui/rei. No producing checkout, default, dependency pin or
retained runtime is changed. Native build, tests, timings and adoption are
separate gates. Cabal module reexports preserve the original public names:
https://cabal.readthedocs.io/en/3.12/cabal-package-description-file.html
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
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--use-reviewed-resources", action="store_true",
                        help="Require exact source/resource-hash reviews for every conservative hazard in the inventory")
    args = parser.parse_args()
    destination, checkout = args.destination.resolve(), args.checkout.resolve()
    if destination.exists() or destination.is_relative_to(checkout):
        parser.error("Use a new destination outside the producing checkout")
    inventory = json.loads(args.inventory.read_text())
    if inventory["project_uri"] != "mori://shinzui/rei":
        parser.error("Only the declared Rei pilot is supported")
    foundation = next(p for p in inventory["proposals"] if p["prefix"] == "explicit foundation")
    if not foundation["boundary_closed"]:
        parser.error("Foundation must be closed")
    if foundation["hazard_modules"] and not args.use_reviewed_resources:
        parser.error("Foundation must be closed and free of unresolved source hazards")
    modules = foundation["selected_modules"]
    if not modules:
        parser.error("Foundation is empty")
    revision = subprocess.check_output(["git", "rev-parse", args.revision + "^{commit}"], cwd=checkout, text=True).strip()
    resources = {}
    if args.use_reviewed_resources:
        reviews = foundation.get("reviewed_hazards", {})
        if inventory.get("source_revision") != revision or set(reviews) != set(foundation["hazard_modules"]):
            parser.error("Reviewed hazards must cover the exact immutable source revision")
        required = set()
        for module, review in reviews.items():
            row = inventory["modules"][module]
            calls = row["resource_calls"]
            if (row["cpp"] or row["source_import"] or not review.get("review", "").strip()
                    or review.get("source_sha256") != row["source_sha256"]
                    or any(call != "embedStringFile" for call, _ in calls)
                    or review.get("resources") != sorted({path for _, path in calls})):
                parser.error(f"Unresolved or mismatched source/resource review: {module}")
            required.update(review["resources"])
        resources = foundation.get("resources", {})
        if set(resources) != required:
            parser.error("Resource hashes must cover exactly the reviewed literal inputs")
        for path, digest in resources.items():
            if (not re.fullmatch(r"[A-Za-z0-9_./-]+", path) or Path(path).is_absolute()
                    or ".." in Path(path).parts or not re.fullmatch(r"[0-9a-f]{64}", digest)):
                parser.error("Unsafe resource path or missing exact SHA-256")
    archive = subprocess.check_output(["git", "archive", "--format=tar", revision], cwd=checkout)
    original = destination / "baseline"
    original.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        tar.extractall(original, filter="data")
    candidate = destination / "candidate"
    shutil.copytree(original, candidate, symlinks=True)
    package = candidate / "rei-cli"
    cabal = package / "rei-cli.cabal"
    text = cabal.read_text()
    if hashlib.sha256(cabal.read_bytes()).hexdigest() != inventory["cabal_sha256"]:
        parser.error("Cabal metadata differs from the reviewed inventory")
    header, rest = text.split("\nlibrary\n", 1)
    library, later = rest.split("\nexecutable rei\n", 1)
    _, dependencies = library.split("\n  build-depends:", 1)
    version = re.search(r"^version:\s*(\S+)", text, re.M).group(1)
    new = candidate / "rei-cli-foundation"
    new.mkdir()
    for path, digest in sorted(resources.items()):
        source = package / path
        if (source.is_symlink() or not source.is_file()
                or not source.resolve().is_relative_to(package.resolve())
                or hashlib.sha256(source.read_bytes()).hexdigest() != digest):
            parser.error(f"Reviewed resource changed or escapes package: {path}")
        target = new / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    moved = []
    for module in modules:
        row = inventory["modules"][module]
        source = package / row["file"]
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if digest != row["source_sha256"] or not source.resolve().is_relative_to(package.resolve()):
            parser.error(f"Reviewed module bytes changed or escape package: {module}")
        target = new / row["file"]
        target.parent.mkdir(parents=True, exist_ok=True)
        source.rename(target)
        moved.append({"module": module, "file": row["file"], "sha256": digest})
        exact = "    " + module + "\n"
        if library.count(exact) != 1:
            parser.error(f"Expected exactly one exposed declaration: {module}")
        library = library.replace(exact, "")
    foundation_header = header.replace("name: rei-cli\n", "name: rei-cli-foundation\n", 1)
    foundation_header = re.sub(r"\nextra-source-files:.*?(?=\ncommon common-options)", "", foundation_header, flags=re.S)
    if resources:
        foundation_header = foundation_header.replace("\ncommon common-options",
            "\nextra-source-files:\n" + "".join("  " + path + "\n" for path in sorted(resources))
            + "\ncommon common-options", 1)
    (new / "rei-cli-foundation.cabal").write_text(foundation_header + "\n\nlibrary\n  import: common-options\n  hs-source-dirs: src\n  exposed-modules:\n" + "".join("    " + module + "\n" for module in modules) + "\n  build-depends:" + dependencies)
    reexports = "\n  reexported-modules:\n" + "".join("    rei-cli-foundation:" + module + (",\n" if index + 1 < len(modules) else "\n") for index, module in enumerate(modules))
    library += reexports
    revised = header + "\nlibrary\n" + library + "\nexecutable rei\n" + later
    # The test suite and executables retain all their original dependencies;
    # explicit access to moved public modules is valid in every component.
    revised = revised.replace("  build-depends:\n", "  build-depends:\n    rei-cli-foundation ==" + version + ",\n")
    cabal.write_text(revised)
    project = candidate / "cabal.project"
    if project.exists():
        project.write_text(project.read_text().replace("packages:\n", "packages:\n  rei-cli-foundation\n", 1))
    receipt = {"schema_version": 1, "project_uri": "mori://shinzui/rei", "source_revision": revision,
               "inventory_sha256": hashlib.sha256(args.inventory.read_bytes()).hexdigest(),
               "moved_modules": moved, "new_package": "rei-cli-foundation", "version": version,
               "public_module_names": "Original rei-cli library reexports every moved module without renaming",
               "dependencies": "All original library bounds retained; no shared source, flag, compiler, test or optimization changes",
               "test_sources": "unchanged; explicit foundation dependency added to every original component",
               "adoption": "Disposable pilot only; not a retained owned-package inventory or production adoption",
               "native_validation": "pending"}
    if args.use_reviewed_resources:
        receipt["reviewed_resources"] = resources
        receipt["resource_policy"] = "Exact immutable source reviews; unchanged literal resources copied and declared in the foundation Cabal package"
    (destination / "split-manifest.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"destination": str(destination), "moved_module_count": len(moved), "revision": revision}))


if __name__ == "__main__":
    main()
