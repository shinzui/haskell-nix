#!/usr/bin/env python3
"""Verify composed Haskell records against Nix's exported derivation graph."""

import json
import argparse
import copy
from pathlib import Path
import sys


def construct(declaration, exported):
    if declaration.get("schemaVersion") != 1:
        raise ValueError("unsupported manifest schema")
    rows = exported.get("derivationGraph")
    if not isinstance(rows, list) or not rows:
        raise ValueError("missing actual derivation graph")
    graph = {}
    for row in rows:
        path, references = row["path"], sorted(row["references"])
        if path in graph and graph[path] != references:
            raise ValueError("conflicting graph records: " + path)
        graph[path] = references
    if any(ref not in graph for refs in graph.values() for ref in refs):
        raise ValueError("incomplete derivation graph")

    def reachable(root):
        found, pending = set(), [root]
        while pending:
            node = pending.pop()
            if node not in graph:
                raise ValueError("missing derivation graph node: " + node)
            if node not in found:
                found.add(node)
                pending.extend(graph[node])
        return found

    root = declaration["root"]["drvPath"]
    actual = reachable(root)
    compiler = declaration["compiler"]["drvPath"]
    if compiler not in actual:
        raise ValueError("compiler is absent from the actual root graph")
    packages = declaration.get("packages")
    if not isinstance(packages, list) or not packages:
        raise ValueError("no Haskell dependency records")
    by_drv = {}
    for package in packages:
        drv = package["drvPath"]
        if drv in by_drv:
            raise ValueError("duplicate Haskell derivation record: " + drv)
        if drv not in actual:
            raise ValueError("Haskell package is absent from the actual root graph: " + package["name"])
        if not package.get("name") or not package.get("version") or not package.get("componentRoles"):
            raise ValueError("incomplete Haskell package identity")
        by_drv[drv] = package
    if root not in by_drv:
        raise ValueError("root has no Haskell package record")
    for drv, package in by_drv.items():
        dependencies = reachable(drv)
        for dependency in package["dependencies"]:
            if dependency not in by_drv:
                raise ValueError("missing Haskell dependency record: " + dependency)
            if dependency == drv or dependency not in dependencies:
                raise ValueError("Haskell dependency edge is absent from the actual derivation graph: " + dependency)
    for package in declaration.get("nativePackages", []):
        if package.get("role") != "native" or package["drvPath"] not in actual:
            raise ValueError("unverifiable native dependency record")
    result = copy.deepcopy(declaration)
    result["derivationGraph"] = graph
    result["graphVerified"] = True
    return result


def verify(manifest):
    graph = manifest.get("derivationGraph")
    if not isinstance(graph, dict):
        raise ValueError("missing exported derivation graph evidence")
    return construct(manifest, {"derivationGraph": [
        {"path": path, "references": references} for path, references in graph.items()
    ]})


def compare_manifests(before, after):
    before, after = verify(before), verify(after)
    changes = []
    for key in ["system", "compiler", "root"]:
        if before.get(key) != after.get(key):
            changes.append("changed " + key + ": " + json.dumps(before.get(key), sort_keys=True)
                           + " -> " + json.dumps(after.get(key), sort_keys=True))
    fields = ["version", "drvPath", "outputPath", "source", "metadata", "configuration"]

    def identities(manifest):
        result = {}
        for package in manifest["packages"]:
            key = (package.get("role", "haskell"), package["name"])
            result.setdefault(key, []).append({field: package.get(field) for field in fields})
        return {key: sorted(rows, key=lambda row: json.dumps(row, sort_keys=True)) for key, rows in result.items()}

    left, right = identities(before), identities(after)
    for role, name in sorted(left.keys() | right.keys()):
        old, new = left.get((role, name), []), right.get((role, name), [])
        if old == new:
            continue
        changed_fields = [field for field in fields if [row[field] for row in old] != [row[field] for row in new]]
        paths = {row["drvPath"] for row in old + new}
        users = sorted({package["name"] for manifest in [before, after] for package in manifest["packages"]
                        if paths.intersection(package["dependencies"])})
        changes.append(f"changed {role} {name}: inputs={','.join(changed_fields)} users={','.join(users) or '<root>'}"
                       + " before=" + json.dumps(old, sort_keys=True) + " after=" + json.dumps(new, sort_keys=True))
    return changes


if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and sys.argv[1] in ["--verify", "--compare"]:
            parser = argparse.ArgumentParser(description=__doc__)
            modes = parser.add_mutually_exclusive_group(required=True)
            modes.add_argument("--verify", metavar="MANIFEST")
            modes.add_argument("--compare", nargs=2, metavar=("BEFORE", "AFTER"))
            args = parser.parse_args()
            if args.verify:
                verify(json.loads(Path(args.verify).read_text()))
                print("Manifest derivation graph verified")
            else:
                changes = compare_manifests(*(json.loads(Path(path).read_text()) for path in args.compare))
                if changes:
                    print("\n".join(changes), file=sys.stderr)
                    sys.exit(1)
                print("Manifest build identities match")
        else:
            declaration, exported, output = sys.argv[1:]
            result = construct(json.loads(Path(declaration).read_text()), json.loads(Path(exported).read_text()))
            Path(output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    except (ValueError, KeyError, OSError) as error:
        print(f"cohort-manifest: {error}", file=sys.stderr)
        sys.exit(1)
