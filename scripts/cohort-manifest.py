#!/usr/bin/env python3
"""Verify composed Haskell records against Nix's exported derivation graph."""

import json
import argparse
import copy
import re
import hashlib
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


def load_resolved_flags(declaration):
    result = copy.deepcopy(declaration)
    for package in result["packages"]:
        path = package.pop("configurationReplay")
        flags = {}
        for line in (Path(path) / "flags").read_text().splitlines():
            name, separator, value = line.partition("=")
            if not separator or not name or name in flags or value not in ["True", "False"]:
                raise ValueError("invalid resolved flag evidence for " + package["name"])
            flags[name] = value == "True"
        package["flags"] = flags
        programs = {}
        for line in (Path(path) / "programs").read_text().splitlines():
            name, version, executable = line.split("\t")
            if name in programs or not executable.startswith("/"):
                raise ValueError("invalid configured program evidence")
            programs[name] = {"version": version, "path": executable}
        package["programs"] = programs
        package["flagsEvidence"] = {"method": "exact-configure-replay", "outputPath": path, "file": "flags"}
        package["configuration"]["patchHashes"] = [hashlib.sha256(Path(patch).read_bytes()).hexdigest()
                                                    for patch in package["configuration"].get("patches", [])]
        for field, filename in [("originalHash", "original-metadata-sha256"), ("patchedHash", "patched-metadata-sha256")]:
            digest = (Path(path) / filename).read_text().strip()
            if not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise ValueError("invalid Cabal metadata digest for " + package["name"])
            package["metadata"][field] = digest
    return result


def load_compiler_packages(text):
    packages = {}
    for entry in text.split():
        name, separator, version = entry.rpartition("-")
        if not separator or not name or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", version) or name in packages:
            raise ValueError("invalid or duplicate compiler package record")
        packages[name] = version
    if not packages:
        raise ValueError("empty compiler package database")
    return packages


def owned(record):
    return (isinstance(record, dict) and isinstance(record.get("owner"), str)
            and record["owner"].startswith("mori://") and isinstance(record.get("reason"), str)
            and bool(record["reason"].strip()))


def code_hash(package, normalization=None):
    config = package.get("configuration", {})
    pre_patch = config.get("prePatch", "")
    if normalization:
        expected = normalization.get("prePatch", "")
        if not pre_patch.startswith(expected):
            raise ValueError("source normalization differs from the retained snapshot")
        pre_patch = pre_patch[len(expected):]
    patches = config.get("patches", [])
    hashes = config.get("patchHashes", [])
    if len(patches) != len(hashes):
        raise ValueError("missing patch content hashes")
    value = {"prePatch": pre_patch, "postPatch": config.get("postPatch", ""), "patches": hashes}
    hooks = {name: text for name, text in config.get("hooks", {}).items() if text}
    if hooks:
        value["hooks"] = hooks
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def compare_freeze(expected, manifest, policy):
    manifest = verify(manifest)
    context = manifest["context"]
    retained = context["versions"]
    if retained["sourceManifest"] != expected["sources"] or retained["flags"] != expected["flags"]:
        raise ValueError("manifest source/flag context differs from the frozen cohort")
    if retained["indexState"] != expected["indexState"]:
        raise ValueError("manifest metadata cutoff differs from the freeze")
    if "ghc-" + retained["ghc"] != expected["compiler"] or "ghc-" + manifest["compiler"]["version"] != expected["compiler"]:
        raise ValueError("manifest compiler differs from the freeze")
    if context["nixpkgsRevision"] != retained["nixpkgsBase"]:
        raise ValueError("manifest Nixpkgs differs from the retained toolchain")
    if policy.get("schemaVersion") != 1 or not isinstance(policy.get("packages"), dict):
        raise ValueError("unsupported Nix difference policy")
    if context.get("configurationPolicy", {"schemaVersion": 1, "packages": {}}) != policy:
        raise ValueError("manifest configuration policy differs from the declared policy")
    sources = expected["sources"]
    for name, entry in policy["packages"].items():
        if name not in sources or not owned(entry) or set(entry) - {"owner", "reason", "flags", "codeHash", "compilerTool"}:
            raise ValueError("unowned or unknown Nix difference policy: " + name)
        if "compilerTool" in entry and (name != "hsc2hs" or entry["compilerTool"] is not True):
            raise ValueError("unknown compiler tool difference: " + name)
        if "codeHash" in entry and not re.fullmatch(r"[0-9a-f]{64}", str(entry["codeHash"])):
            raise ValueError("invalid build-patch policy digest: " + name)
        variants = [identity.get("flags", {}) for identity in sources[name]["identities"]]
        for flag, enabled in entry.get("flags", {}).items():
            if not isinstance(enabled, bool) or not variants or any(flag not in variant for variant in variants):
                raise ValueError("unknown flag difference: " + name + ":" + flag)
    packages = manifest["packages"]
    by_name = {}
    for package in packages:
        by_name.setdefault(package["name"], []).append(package)
    graph = manifest["derivationGraph"]

    def reachable(path):
        found, pending = set(), [path]
        while pending:
            node = pending.pop()
            if node not in found:
                found.add(node)
                pending.extend(graph[node])
        return found

    def pinned_source(actual, identity):
        pinned = identity.get("pkg-src", {}).get("source-repo", {})
        location, revision = pinned.get("location", "").removesuffix(".git").rstrip("/"), pinned.get("tag")
        if not location or not revision or not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", actual.get("hash", "")):
            return False
        if actual.get("subdirectory", "") != pinned.get("subdir", ""):
            return False
        urls = [location + "/archive/" + revision + ".tar.gz"]
        if location.startswith("https://github.com/"):
            urls.append("https://api.github.com/repos/" + location.removeprefix("https://github.com/") + "/tarball/" + revision)
        return any(url in urls for url in actual.get("urls", []))

    def check(package):
        name = package["name"]
        if package["role"] == "local":
            if name not in expected["localPackages"] or name in sources:
                raise ValueError("undeclared or overlapping local ownership")
            return
        if package["role"] != "haskell" or name not in sources:
            raise ValueError("undeclared Haskell dependency")
        frozen = sources[name]
        if frozen["source"] == "Hackage" and (not frozen["identities"] or any(
                not all(re.fullmatch(r"[0-9a-f]{64}", identity.get(key, "")) for key in ["pkg-src-sha256", "pkg-cabal-sha256"])
                for identity in frozen["identities"])):
            raise ValueError("incomplete frozen source evidence")
        if package["version"] != frozen["version"]:
            raise ValueError("version mismatch expected=" + frozen["version"] + " actual=" + package["version"])
        actual_source = package["source"]
        metadata = package["metadata"]
        if not all(re.fullmatch(r"[0-9a-f]{64}", metadata.get(key, "")) for key in ["originalHash", "patchedHash"]):
            raise ValueError("missing actual Cabal metadata hashes")
        first_party = context.get("sourceContext", {}).get(name)
        normalization = None
        if name in retained["firstParty"]:
            if not owned(first_party) or not first_party.get("source"):
                raise ValueError("missing owned first-party source snapshot")
            selected = first_party["source"]
            if selected["kind"] == "github":
                if any(actual_source.get(key) != selected.get(key) for key in ["path", "uri", "revision", "hash", "subdirectory"]):
                    raise ValueError("first-party source differs from its retained snapshot")
                normalization = first_party.get("normalization")
            elif selected["kind"] == "hackage":
                if actual_source.get("hash") != selected["hash"]:
                    raise ValueError("first-party Hackage source hash differs")
            else:
                raise ValueError("unsupported first-party source channel")
        elif frozen["source"] == "SourcePin":
            ownership = retained["policy"].get(name)
            if not owned(ownership) or not ownership.get("sourcePinned"):
                raise ValueError("missing source-pin ownership")
            if metadata.get("hash") is not None or not any(pinned_source(actual_source, identity) for identity in frozen["identities"]):
                raise ValueError("source revision/subdirectory mismatch")
        elif frozen["source"] == "Hackage":
            recipe = retained["packages"].get(name)
            if (not recipe or recipe["version"] != frozen["version"]
                    or not re.fullmatch(r"sha256-[A-Za-z0-9+/]{43}=", recipe.get("sha256", ""))
                    or actual_source.get("hash") != recipe["sha256"]):
                raise ValueError("Hackage source differs or lacks generated hash evidence")
            revision = recipe["revision"]
            if str(metadata.get("revision") or "0") != str(revision["number"] if revision else "0"):
                raise ValueError("selected metadata revision differs")
        else:
            raise ValueError("unexpected non-library source class")
        github_first_party = first_party and first_party["source"]["kind"] == "github"
        if frozen["source"] == "Hackage" and not github_first_party:
            digest = metadata.get("hash") or metadata["originalHash"]
            if not any(identity.get("pkg-cabal-sha256") == digest for identity in frozen["identities"]):
                raise ValueError("Cabal metadata differs from the frozen index")
        if (package.get("flagsEvidence", {}).get("method") != "exact-configure-replay"
                or not isinstance(package.get("flags"), dict) or not all(isinstance(value, bool) for value in package["flags"].values())):
            raise ValueError("missing resolved Cabal flag evidence")
        difference = policy["packages"].get(name, {})
        variants = [dict(identity.get("flags", {}), **difference.get("flags", {})) for identity in frozen["identities"]]
        if package["flags"] not in variants:
            raise ValueError("resolved flags differ from the frozen configuration")
        empty_code = code_hash({"configuration": {}})
        actual_code = code_hash(package, normalization)
        if actual_code != empty_code and difference.get("codeHash") != actual_code:
            raise ValueError("missing owned build-patch policy codeHash=" + actual_code)
        descendants = reachable(package["drvPath"])
        for dependency in frozen["dependencies"]:
            if dependency == name:
                continue
            if dependency not in sources:
                raise ValueError("unknown frozen dependency: " + dependency)
            selected = sources[dependency]
            if selected["source"] == "Boot":
                if manifest["compiler"].get("packages", {}).get(dependency) != selected["version"]:
                    raise ValueError("compiler boot dependency differs: " + dependency)
            elif not any(row["drvPath"] in descendants for row in by_name.get(dependency, [])):
                tool = package.get("programs", {}).get(dependency, {})
                compiler = manifest["compiler"]
                program = compiler.get("outputPath", "") + "/bin/" + dependency
                if not (policy["packages"].get(dependency, {}).get("compilerTool") is True
                        and tool.get("version") == selected["version"]
                        and tool.get("path") in [program, program + "-ghc-" + compiler["version"]]
                        and compiler["drvPath"] in descendants):
                    raise ValueError("missing static/build dependency edge: " + dependency)

    errors, checked = [], 0
    for package in packages:
        try:
            check(package)
            checked += package["role"] == "haskell"
        except ValueError as error:
            errors.append(package["name"] + ": " + str(error))
    if errors:
        raise ValueError("\n".join(errors))
    if not checked:
        raise ValueError("manifest contains no verifiable cohort dependencies")
    return f"Nix manifest matches {checked} frozen Haskell dependency instances"


def compare_manifests(before, after):
    before, after = verify(before), verify(after)
    changes = []
    for key in ["system", "compiler", "root"]:
        if before.get(key) != after.get(key):
            changes.append("changed " + key + ": " + json.dumps(before.get(key), sort_keys=True)
                           + " -> " + json.dumps(after.get(key), sort_keys=True))
    fields = ["version", "drvPath", "outputPath", "source", "metadata", "configuration", "flags", "programs"]

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
        if len(sys.argv) > 1 and sys.argv[1] in ["--verify", "--compare", "--compare-freeze"]:
            parser = argparse.ArgumentParser(description=__doc__)
            modes = parser.add_mutually_exclusive_group(required=True)
            modes.add_argument("--verify", metavar="MANIFEST")
            modes.add_argument("--compare", nargs=2, metavar=("BEFORE", "AFTER"))
            modes.add_argument("--compare-freeze", nargs=2, metavar=("CONTEXT", "MANIFEST"))
            parser.add_argument("--nix-policy", metavar="POLICY")
            args = parser.parse_args()
            if args.compare_freeze:
                if not args.nix_policy:
                    parser.error("frozen comparison requires --nix-policy")
                expected, manifest = (json.loads(Path(path).read_text()) for path in args.compare_freeze)
                print(compare_freeze(expected, manifest, json.loads(Path(args.nix_policy).read_text())))
            elif args.nix_policy:
                parser.error("--nix-policy requires frozen comparison")
            elif args.verify:
                verify(json.loads(Path(args.verify).read_text()))
                print("Manifest derivation graph verified")
            else:
                changes = compare_manifests(*(json.loads(Path(path).read_text()) for path in args.compare))
                if changes:
                    print("\n".join(changes), file=sys.stderr)
                    sys.exit(1)
                print("Manifest build identities match")
        else:
            declaration, exported, compiler_packages, output = sys.argv[1:]
            recorded = load_resolved_flags(json.loads(Path(declaration).read_text()))
            recorded["compiler"]["packages"] = load_compiler_packages(Path(compiler_packages).read_text())
            result = construct(recorded, json.loads(Path(exported).read_text()))
            Path(output).write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    except (ValueError, KeyError, OSError) as error:
        print(f"cohort-manifest: {error}", file=sys.stderr)
        sys.exit(1)
