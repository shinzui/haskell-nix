#!/usr/bin/env python3
"""Inventory an owned Cabal package before proposing independently cached packages.

This deliberately conservative source inventory includes both CPP branches. It
is not a Cabal or Haskell compiler: confirm any proposed boundary by compiling
separate Cabal packages with the selected compiler and production flags.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path


def without_comments(text):
    # Preserve strings (including resource paths) and line numbers. Nested block
    # comments and pragmas must not introduce fictitious module/import edges.
    out, depth, quoted, escaped, i = [], 0, False, False, 0
    while i < len(text):
        pair = text[i:i + 2]
        char = text[i]
        if depth:
            if pair == "{-":
                depth += 1
                out.extend("  ")
                i += 2
            elif pair == "-}":
                depth -= 1
                out.extend("  ")
                i += 2
            else:
                out.append("\n" if char == "\n" else " ")
                i += 1
        elif quoted:
            out.append(char)
            if char == '"' and not escaped:
                quoted = False
            escaped = char == "\\" and not escaped
            i += 1
        elif pair == "{-":
            depth = 1
            out.extend("  ")
            i += 2
        elif pair == "--":
            end = text.find("\n", i)
            end = len(text) if end == -1 else end
            out.extend(" " * (end - i))
            i = end
        else:
            quoted = char == '"'
            escaped = False
            out.append(char)
            i += 1
    return "".join(out)


def components(edges):
    index, stack, active, indices, low, result = 0, [], set(), {}, {}, []

    def visit(node):
        nonlocal index
        indices[node] = low[node] = index
        index += 1
        stack.append(node)
        active.add(node)
        for child in edges[node]:
            if child not in indices:
                visit(child)
                low[node] = min(low[node], low[child])
            elif child in active:
                low[node] = min(low[node], indices[child])
        if low[node] == indices[node]:
            group = []
            while True:
                child = stack.pop()
                active.remove(child)
                group.append(child)
                if child == node:
                    break
            result.append(sorted(group))

    for node in sorted(edges):
        if node not in indices:
            visit(node)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--source-dir", action="append", required=True,
                        help="An explicit source directory of the selected Cabal component; repeat as needed")
    parser.add_argument("--project-uri", required=True)
    parser.add_argument("--group-prefix", action="append", default=[],
                        help="Inspect a proposed foundation prefix without moving files")
    parser.add_argument("--compiler-log", type=Path, help="Existing native build log for module-name coverage")
    parser.add_argument("--compiler-prefix", help="Nix build-log prefix of the selected owned package")
    parser.add_argument("--module-list", type=Path,
                        help="JSON array containing exact module names for one proposed foundation")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"mori://[^/]+/[^/]+", args.project_uri):
        parser.error("--project-uri must be a canonical project URI")
    package = args.package.resolve()
    cabal = sorted(package.glob("*.cabal"))
    if len(cabal) != 1:
        parser.error("--package must contain exactly one Cabal file")
    modules = {}
    for relative in args.source_dir:
        source = (package / relative).resolve()
        if not source.is_relative_to(package):
            parser.error("Source directory escapes package")
        for path in sorted(source.rglob("*.hs")):
            if not path.resolve().is_relative_to(package):
                parser.error("Source file escapes package through a symlink")
            text = path.read_text()
            stripped = without_comments(text)
            name_match = re.search(r"^\s*module\s+([A-Z][\w.]*)\b", stripped, re.M)
            name = name_match.group(1) if name_match else "Main"
            if name in modules:
                parser.error(f"Duplicate module {name}; select one Cabal component")
            imports = re.findall(r'^\s*import\s+(?:safe\s+)?(?:qualified\s+)?(?:"[^"]+"\s+)?([A-Z][\w.]*)', stripped, re.M)
            modules[name] = {
                "file": str(path.relative_to(package)),
                "source_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                "imports": sorted(set(imports)),
                "cpp": bool(re.search(r"^\s*#\s*(if|ifdef|ifndef|include)\b", text, re.M)),
                "template_haskell": "TemplateHaskell" in text or "$(" in stripped or "[d|" in stripped,
                "source_import": bool(re.search(r"\bimport\s+\{-#\s*SOURCE\b", text)),
                "resource_calls": sorted(set(re.findall(r'\b(embed\w*|addDependentFile|makeRelativeToProject)\s+"([^"]+)"', stripped))),
            }
    edges = {name: sorted(set(row["imports"]) & modules.keys()) for name, row in modules.items()}
    reverse = {name: [] for name in modules}
    for name, dependencies in edges.items():
        for dependency in dependencies:
            reverse[dependency].append(name)

    def reachable(start, graph):
        seen, pending = set(), list(start)
        while pending:
            node = pending.pop()
            if node not in seen:
                seen.add(node)
                pending.extend(graph[node])
        return seen

    proposals = []
    groups = [(prefix, {name for name in modules if name == prefix or name.startswith(prefix + ".")})
              for prefix in args.group_prefix]
    if args.module_list:
        names = json.loads(args.module_list.read_text())
        if (not isinstance(names, list) or not all(isinstance(name, str) for name in names)
                or len(set(names)) != len(names) or set(names) - modules.keys()):
            parser.error("--module-list must contain unique known module names")
        groups.append(("explicit foundation", set(names)))
    for prefix, selected in groups:
        if not selected:
            parser.error(f"Proposed group is empty: {prefix}")
        closure = reachable(selected, edges)
        reverse_edges = sorted((name, dependency) for name in selected for dependency in edges[name] if dependency not in selected)
        proposals.append({"prefix": prefix, "selected_modules": sorted(selected),
                          "required_internal_closure": sorted(closure),
                          "dependencies_outside_group": reverse_edges,
                          "downstream_rebuild_modules": sorted(reachable(selected, reverse)),
                          "boundary_closed": selected == closure,
                          "hazard_modules": sorted(name for name in closure if any(modules[name][flag] for flag in ["cpp", "template_haskell", "source_import"]))})
    for name, row in modules.items():
        row["internal_imports"] = edges[name]
        row["internal_dependents"] = sorted(reverse[name])
        row["transitive_dependents_count"] = len(reachable([name], reverse)) - 1
    result = {"schema_version": 1, "project_uri": args.project_uri,
              "package_directory": package.name, "cabal_sha256": hashlib.sha256(cabal[0].read_bytes()).hexdigest(),
              "source_directories": args.source_dir, "module_count": len(modules), "modules": modules,
              "cycles": [group for group in components(edges) if len(group) > 1 or group[0] in edges[group[0]]],
              "proposals": proposals, "compiler_validation": "pending: conservative source inventory only",
              "limits": "Both CPP branches included; generated modules and arbitrary Template Haskell may add edges. Module names/imports are a source inventory, not a replacement Cabal parser. Validate separately built package boundaries with the actual compiler, production flags, resources, tests and owned-package manifests."}
    if args.compiler_log:
        if not args.compiler_prefix:
            parser.error("--compiler-log requires --compiler-prefix")
        log = args.compiler_log.read_text()
        compiled = set(re.findall(r"^" + re.escape(args.compiler_prefix) + r"> \[\s*\d+ of\s*\d+\] Compiling ([A-Z][\w.]*)", log, re.M))
        missing = sorted(modules.keys() - compiled)
        if missing:
            parser.error(f"Native compiler log lacks source modules: {missing}")
        result["compiler_validation"] = {
            "status": "source module-name coverage passed; edges remain conservative",
            "log_sha256": hashlib.sha256(args.compiler_log.read_bytes()).hexdigest(),
            "package_prefix": args.compiler_prefix,
            "source_modules_compiled": len(modules),
            "extra_compiled_names": sorted(compiled - modules.keys()),
            "limits": "An existing successful native log verifies module-name coverage, not a proposed package split or each conditional/generated dependency edge."}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"module_count": len(modules), "cycles": result["cycles"],
                      "proposals": [{key: value for key, value in proposal.items() if key in ["prefix", "boundary_closed", "hazard_modules"]} for proposal in proposals]}))


if __name__ == "__main__":
    main()
