#!/usr/bin/env python3
"""Verify completed paired leaf trials through executable behavior and Nix metadata.

Reads local receipts and Nix JSON only. Executables are invoked, never inspected.
Run after the measurement campaign, with an output directory outside source trees.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def query(command):
    return json.loads(subprocess.check_output(command))


def graph(drv):
    exported = query(["nix", "derivation", "show", "--recursive", drv])
    directory = str(Path(drv).parent)
    absolute = lambda path: path if path.startswith("/") else directory + "/" + path
    # Nix's versioned derivation JSON uses store basenames; older releases use
    # full paths in an unversioned object. Preserve the full exported evidence.
    nodes = {absolute(key): value for key, value in exported.get("derivations", exported).items()}
    return exported, nodes, absolute


def main():
    validation_started = time.perf_counter()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    summary = json.loads(args.summary.read_text())
    applications = {"mori://shinzui/rei": ("rei", "time"), "mori://shinzui/mori": ("mori", "sealed-evaluation")}
    if summary["project_uri"] not in applications:
        parser.error("Only the declared Rei and Mori pilots are supported")
    application, topic = applications[summary["project_uri"]]
    component = summary["trials"][0]["identity"].get("component", "cli")
    experiment_mode = summary["trials"][0]["identity"].get("experimentMode", "intermediates")
    if experiment_mode not in ["intermediates", "parallelism", "package-split"]:
        raise ValueError("Unknown experiment mode")
    if component not in ["cli", "core"]:
        raise ValueError("Unknown owned component")
    owned_names = [application + "-cli"]
    if component == "core":
        owned_names += [application + "-core"] + (["mori-api"] if application == "mori" else [])
    current_owned_names = list(owned_names)
    boundary_package = application + "-" + component
    foundation_package = boundary_package + "-foundation"
    if experiment_mode == "package-split":
        if (application, component) not in [("rei", "cli"), ("mori", "core")]:
            raise ValueError("Only the declared Rei CLI and Mori core boundary pilots are supported")
        owned_names += [foundation_package]
    destination = args.output_dir.resolve()
    if destination.is_relative_to(Path(__file__).resolve().parent.parent):
        parser.error("Keep evidence outside the source tree")
    for row in summary["trials"]:
        source = Path(row["command"][row["command"].index("source") + 1]).resolve()
        if destination.is_relative_to(source):
            parser.error("Keep evidence outside application source trees")
    destination.mkdir(parents=True, exist_ok=False)
    receipt = {"schema_version": 1, "project_uri": summary["project_uri"],
               "summary_sha256": digest(args.summary.read_bytes()), "component": component, "experiment_mode": experiment_mode, "pairs": []}
    rows = {(row["trial"], row["label"]): row for row in summary["trials"]}
    trials = sorted({trial for trial, _ in rows})
    if len(trials) < 5 or len(rows) != len(trials) * 2:
        raise ValueError("At least five complete pairs are required")
    if len({row["identity"]["compiler"] for row in rows.values()}) != 1:
        raise ValueError("Compiler identity changed during the campaign")
    compatibility_contexts = {json.dumps(row["identity"].get("currentCompatibility"), sort_keys=True) for row in rows.values()}
    if len(compatibility_contexts) != 1:
        raise ValueError("Source-independent compatibility context changed during the campaign")
    if experiment_mode == "package-split":
        foundations = {row["identity"]["foundation"] for row in rows.values() if row["label"] == "candidate"}
        if len(foundations) != 1 or None in foundations:
            raise ValueError("The independent foundation changed during leaf trials")
        manifests = {Path(row["identity"]["splitManifest"]).read_bytes() for row in rows.values()}
        if len(manifests) != 1:
            raise ValueError("Boundary manifest changed during paired trials")
        manifest = json.loads(next(iter(manifests)))
        api_boundary = manifest.get("api_boundary")
        if api_boundary:
            if application != "mori" or component != "core":
                raise ValueError("API foundation narrowing requires the declared Mori core experiment")
            api_instances = {row["identity"].get("api") for row in rows.values() if row["label"] == "candidate"}
            if len(api_instances) != 1 or None in api_instances:
                raise ValueError("The foundation-only API changed across core leaf edits")
        for row in rows.values():
            source = Path(row["command"][row["command"].index("source") + 1]).resolve()
            package = source / (foundation_package if row["label"] == "candidate" else boundary_package)
            for item in manifest["moved_modules"]:
                path = package / item["file"]
                if not path.resolve().is_relative_to(package.resolve()) or digest(path.read_bytes()) != item["sha256"]:
                    raise ValueError("A moved module changed or escaped its declared package")
            for relative, expected in manifest.get("reviewed_resources", {}).items():
                resource = package / relative
                if (Path(relative).is_absolute() or ".." in Path(relative).parts
                        or resource.is_symlink() or not resource.is_file()
                        or not resource.resolve().is_relative_to(package.resolve())
                        or digest(resource.read_bytes()) != expected):
                    raise ValueError("A reviewed compile-time resource changed or escaped its declared package")
                # Compare with the original package, including executable bits;
                # resource relocation must preserve more than file contents.
                original_source = Path(rows[row["trial"], "baseline"]["command"][
                    rows[row["trial"], "baseline"]["command"].index("source") + 1])
                original_resource = original_source / boundary_package / relative
                if resource.stat().st_mode & 0o7777 != original_resource.stat().st_mode & 0o7777:
                    raise ValueError("A reviewed compile-time resource changed its file mode")
            if api_boundary:
                candidate = row["label"] == "candidate"
                if row["identity"].get("apiUsesFoundation") != candidate:
                    raise ValueError("Wrong API dependency selection")
                api = source / "mori-api"
                for name, expected in api_boundary["preserved_haskell_sources"].items():
                    path = api / name
                    if not path.resolve().is_relative_to(api.resolve()) or digest(path.read_bytes()) != expected:
                        raise ValueError("API Haskell source changed with the dependency boundary")
                expected = api_boundary["after_cabal_sha256" if candidate else "before_cabal_sha256"]
                if digest((api / "mori-api.cabal").read_bytes()) != expected:
                    raise ValueError("API metadata differs from the declared dependency change")
    reference_shared = None
    reference_settings = None
    with tempfile.TemporaryDirectory(prefix="mp4-behavior-home-") as home:
        # Help/version dispatch has been audited to avoid database services.
        environment = {key: value for key, value in os.environ.items()
                       if not any(term in key for term in ["DATABASE", "PG_CONNECTION", "REI_CONFIG", "MORI_CONFIG"])}
        environment.update({"HOME": home, "XDG_CONFIG_HOME": home, "NO_COLOR": "1", "TERM": "dumb"})
        for trial in trials:
            behavior, shared, owners, roots, settings = {}, {}, {}, {}, {}
            root_nodes = {}
            if rows[trial, "baseline"]["source_variant_sha256"] != rows[trial, "candidate"]["source_variant_sha256"]:
                raise ValueError("Pair does not use identical changed source bytes")
            for label in ["baseline", "candidate"]:
                row = rows[trial, label]
                if not row["phase_events"] or not sum(row["compiled_modules"].values()):
                    raise ValueError("Changed-code trial reused an already built target")
                drv = row["identity"]["root"]
                if row["exit_code"] != 0 or row["build_result"][0]["drvPath"] != drv:
                    raise ValueError("Build result does not match measured root")
                if experiment_mode == "intermediates" and label == "candidate" and not row["identity"]["compatibilityReport"]["accepted"]:
                    raise ValueError("Candidate did not accept its explicit seed")
                output = row["build_result"][0]["outputs"]["out"]
                behavior[label] = []
                commands = [["--version"], ["--help"], ["help", topic], ["--bash-completion-script", application]]
                if experiment_mode == "package-split" and application == "mori" and component == "core":
                    # Both routes are explicitly registry-free in the producer.
                    # Printing the complete embedded schema checks moved TH data.
                    commands += [["schema", "print"], ["schema", "pin"]]
                for command in commands:
                    result = subprocess.run([output + "/bin/" + application, *command], capture_output=True,
                                            env=environment, timeout=30)
                    if result.returncode:
                        raise ValueError(f"Behavior probe failed: {label} {command}: {result.stderr[-500:]!r}")
                    if component == "cli" and command == ["help", topic] and f"MP4 paired leaf {trial}".encode() not in result.stdout:
                        raise ValueError("Changed leaf behavior missing or stale")
                    behavior[label].append({"command": command, "exit_code": result.returncode,
                                            "stdout_sha256": digest(result.stdout), "stderr_sha256": digest(result.stderr)})
                if component == "core":
                    probe_drv = row["identity"]["behaviorProbe"]
                    started = time.perf_counter()
                    built_probe = query(["nix", "build", probe_drv + "^out", "--json", "--no-link", "--max-jobs", "1", "--cores", str(summary["cores"])])
                    probe = subprocess.run([built_probe[0]["outputs"]["out"] + "/bin/core-probe"],
                                           capture_output=True, env=environment, timeout=30, check=True)
                    if f"MP4 core {trial}".encode() not in probe.stdout:
                        raise ValueError("Changed core behavior is missing or stale")
                    _, probe_nodes, _ = graph(probe_drv)
                    if row["identity"]["core"] not in probe_nodes:
                        raise ValueError("Behavior probe did not link the measured core instance")
                    behavior[label].append({"command": ["core-probe"], "exit_code": probe.returncode,
                                            "stdout_sha256": digest(probe.stdout), "stderr_sha256": digest(probe.stderr)})
                    receipt.setdefault("validation_observations", []).append({"trial": trial, "label": label,
                        "derivation": probe_drv, "core": row["identity"]["core"],
                        "elapsed_seconds": time.perf_counter() - started})
                exported, nodes, absolute = graph(drv)
                graph_file = destination / f"pair-{trial}-{label}.graph.json"
                graph_file.write_text(json.dumps(exported, sort_keys=True) + "\n")
                boundary_drv = row["identity"]["core"] if experiment_mode == "package-split" and component == "core" else drv
                root_nodes[label] = nodes[boundary_drv]
                shared[label] = {key: value for key, value in nodes.items()
                                 if value["env"].get("pname") not in owned_names}
                owners[label] = {key: value for key, value in nodes.items() if key not in shared[label]}
                if experiment_mode == "package-split" and api_boundary and label == "candidate":
                    pending, api_graph = [row["identity"]["api"]], set()
                    while pending:
                        key = pending.pop()
                        if key in api_graph:
                            continue
                        api_graph.add(key)
                        node = nodes[key]
                        dependencies = node.get("inputs", {}).get("drvs", node.get("inputDrvs", {}))
                        pending.extend(absolute(dependency) for dependency in dependencies)
                    if (row["identity"]["foundation"] not in api_graph
                            or any(nodes[key]["env"].get("pname") == "mori-core" for key in api_graph)):
                        raise ValueError("The narrowed API still depends on volatile core or misses its foundation")
                settings[label] = {"configureFlags": nodes[drv]["env"]["configureFlags"].replace(output, "<application-output>"),
                                   "doCheck": nodes[drv]["env"].get("doCheck"), "system": nodes[drv]["system"],
                                   "builder": nodes[drv]["builder"], "source": nodes[drv]["env"].get("src"),
                                   "buildWays": {key: nodes[drv]["env"].get(key) for key in [
                                       "doHaddock", "enableLibraryProfiling", "enableExecutableProfiling",
                                       "enableSharedLibraries", "enableSharedExecutables", "enableStaticLibraries",
                                       "enableStaticExecutables", "enableParallelBuilding"]},
                                   "recipeHooks": {key: nodes[drv]["env"].get(key) for key in [
                                       "prePatch", "postPatch", "preConfigure", "postConfigure", "preBuild", "postBuild",
                                       "preInstall", "postInstall", "buildFlags", "setupCompileFlags", "doBenchmark"]}}
                if component == "core":
                    # Compare effective settings/source of every rebuilt owned
                    # package, while excluding the additional old checkpoint.
                    current_owned = {name: [(key, node) for key, node in owners[label].items()
                        if node["env"].get("pname") == name
                        and (name != application + "-core" or key == row["identity"]["core"])] for name in current_owned_names}
                    if any(len(values) != 1 for values in current_owned.values()):
                        raise ValueError("Duplicated or missing current owned dependency instance")
                    settings[label]["owned"] = {name: {
                        "source": values[0][1]["env"].get("src"),
                        "compiler": row["identity"]["compiler"],
                        "recipeHooks": {key: values[0][1]["env"].get(key) for key in [
                            "prePatch", "postPatch", "preConfigure", "postConfigure", "preBuild", "postBuild",
                            "preInstall", "postInstall", "buildFlags", "setupCompileFlags", "doBenchmark"]},
                        "doCheck": values[0][1]["env"].get("doCheck"),
                        "buildWays": {key: values[0][1]["env"].get(key) for key in [
                            "doHaddock", "enableLibraryProfiling", "enableExecutableProfiling",
                            "enableSharedLibraries", "enableSharedExecutables", "enableStaticLibraries",
                            "enableStaticExecutables", "enableParallelBuilding"]},
                        "configureFlags": values[0][1]["env"]["configureFlags"].replace(
                            absolute(values[0][1]["outputs"]["out"]["path"]), "<owned-output>")
                    } for name, values in current_owned.items()}
                    if experiment_mode == "package-split":
                        settings[label]["owned"][boundary_package]["source"] = "<declared-package-split>"
                        if api_boundary:
                            settings[label]["owned"]["mori-api"]["source"] = "<declared-foundation-dependency>"
                if experiment_mode == "parallelism":
                    limit = row["identity"]["maxBuildCores"]
                    cap = f"NIX_BUILD_CORES=$(( NIX_BUILD_CORES < {limit} ? NIX_BUILD_CORES : {limit} ))"
                    normalized_env = {key: value.replace(output, "<application-output>") for key, value in nodes[drv]["env"].items()}
                    if normalized_env.get("setupCompilerEnvironmentPhase", "").count(cap) != 1:
                        raise ValueError("The declared compiler cap is not enforced exactly once")
                    normalized_env["setupCompilerEnvironmentPhase"] = normalized_env["setupCompilerEnvironmentPhase"].replace(cap, "<declared-compiler-cap>")
                    log = (args.summary.parent / row["log"]).read_text()
                    if not re.search(r"configureFlags:.*--ghc-option=-j" + str(limit) + r"(?:\s|$)", log):
                        raise ValueError("The native GHC configuration did not use the declared cap")
                    settings[label]["normalized_complete_environment"] = normalized_env
                    settings[label]["inputs"] = nodes[drv].get("inputs", nodes[drv].get("inputDrvs"))
                    settings[label]["build_arguments"] = nodes[drv]["args"]
                    settings[label]["output_names"] = sorted(nodes[drv]["outputs"])
                roots[label] = {"derivation": drv, "output": output, "graph_sha256": digest(graph_file.read_bytes())}
                info = query(["nix", "path-info", "--json", "--recursive", output])
                if isinstance(info, list):
                    info = {record["path"]: record for record in info}
                intermediates = [absolute(node["outputs"]["intermediates"]["path"])
                                 for node in owners[label].values() if "intermediates" in node["outputs"]]
                if any(path in info for path in intermediates):
                    raise ValueError("Runtime closure retains intermediate compiler products")
                seed_outputs = ([absolute(node["outputs"]["out"]["path"])
                                 for key, node in owners[label].items() if key not in {drv, row["identity"]["core"]} and (component != "core" or node["env"].get("pname") == application + "-core")]
                                if experiment_mode == "intermediates" else [])
                if any(path in info for path in seed_outputs):
                    raise ValueError("Runtime closure retains the clean checkpoint executable output")
                roots[label]["runtime_closure_nar_bytes"] = sum(record["narSize"] for record in info.values())
                roots[label]["intermediates_absent_from_runtime_closure"] = True
                roots[label]["seed_outputs_absent_from_runtime_closure"] = True
                if label == "candidate" and intermediates:
                    sizes = query(["nix", "path-info", "--json", *intermediates])
                    if isinstance(sizes, list):
                        sizes = {record["path"]: record for record in sizes}
                    roots[label]["intermediate_nar_bytes"] = {path: record["narSize"] for path, record in sizes.items()}
                    retained = query(["nix", "path-info", "--json", "--recursive", *intermediates])
                    if isinstance(retained, list):
                        retained = {record["path"]: record for record in retained}
                    roots[label]["all_intermediate_roots_marginal_closure_nar_bytes"] = sum(
                        record["narSize"] for path, record in retained.items() if path not in info)
            if experiment_mode == "package-split":
                foundation = rows[trial, "candidate"]["identity"]["foundation"]
                if rows[trial, "baseline"]["identity"]["packageSplit"] or not rows[trial, "candidate"]["identity"]["packageSplit"]:
                    raise ValueError("Expected monolithic baseline and split candidate")
                if foundation not in owners["candidate"] or len(owners["candidate"]) != len(owned_names):
                    raise ValueError("Split graph must contain exactly the current owned packages and foundation")
                manifest = json.loads(Path(rows[trial, "candidate"]["identity"]["splitManifest"]).read_text())
                foundation_outputs = [absolute(value["path"]) for value in owners["candidate"][foundation]["outputs"].values()]
                foundation_node = owners["candidate"][foundation]
                library_fields = ["doCheck", "doHaddock", "enableLibraryProfiling", "enableSharedLibraries",
                                  "enableStaticLibraries", "enableParallelBuilding", "doBenchmark"]
                foundation_settings = {name: foundation_node["env"].get(name) for name in library_fields}
                baseline_library_settings = {name: root_nodes["baseline"]["env"].get(name) for name in library_fields}
                if (foundation_settings != baseline_library_settings
                        or foundation_node["builder"] != root_nodes["baseline"]["builder"]
                        or foundation_node["system"] != root_nodes["baseline"]["system"]):
                    raise ValueError("Foundation changed library build ways, tests, builder or system")
                compiler_options = lambda node: [word for word in node["env"]["configureFlags"].split()
                    if word.startswith(("--ghc-option", "--enable-optimization", "--disable-optimization",
                                        "--enable-library-", "--disable-library-", "--flags="))]
                if compiler_options(foundation_node) != compiler_options(root_nodes["baseline"]):
                    raise ValueError("Foundation changed compiler, optimization, library or Cabal flag settings")
                receipt.setdefault("foundation_validation", []).append({
                    "trial": trial, "derivation": foundation, "library_settings": foundation_settings,
                    "compiler_options": compiler_options(foundation_node),
                    "source_sha256s_preserved": len(manifest["moved_modules"]),
                    "reviewed_resource_bytes_and_modes_preserved": len(manifest.get("reviewed_resources", {}))})
                normalized = {}
                for label in ["baseline", "candidate"]:
                    node = root_nodes[label]
                    output = absolute(node["outputs"]["out"]["path"])
                    normalized[label] = {key: value.replace(output, "<application-output>")
                                         for key, value in node["env"].items() if key != "src"}
                    for key in ["buildInputs", "propagatedBuildInputs"]:
                        if key in normalized[label]:
                            normalized[label][key] = " ".join(word for word in normalized[label][key].split()
                                                              if word not in foundation_outputs)
                    inputs = node.get("inputs", {})
                    if "drvs" not in inputs:
                        raise ValueError("The boundary pilot requires versioned Nix derivation JSON")
                    normalized[label]["declared_driver_inputs"] = {
                        key: value for key, value in inputs["drvs"].items() if absolute(key) != foundation}
                    normalized[label]["other_source_inputs"] = sorted(
                        path for path in inputs["srcs"] if absolute(path) != node["env"]["src"])
                    if component == "cli":
                        settings[label]["source"] = "<declared-package-split>"
                if normalized["baseline"] != normalized["candidate"]:
                    (destination / "split-environment-difference.json").write_text(json.dumps(normalized, indent=2) + "\n")
                    raise ValueError("Split changed inputs beyond owned source and declared foundation dependency")
                # Public module access must work with only the original package exposed.
                # Building its compiler wrapper performs registration, not a new
                # dependency solve or a second compilation of the library.
                if trial == trials[0]:
                    for label in ["baseline", "candidate"]:
                        drv = rows[trial, label]["identity"]["registrationCompiler"]
                        _, registration_nodes, _ = graph(drv)
                        expected_library = rows[trial, label]["identity"]["core"] if component == "core" else rows[trial, label]["identity"]["root"]
                        if expected_library not in registration_nodes:
                            raise ValueError("Public module probe does not use the measured original library")
                        started = time.perf_counter()
                        built = query(["nix", "build", drv + "^out", "--json", "--no-link", "--max-jobs", "1"])
                        with tempfile.TemporaryDirectory(prefix="mp4-split-reexports-") as probe_dir:
                            source = Path(probe_dir) / "PublicModules.hs"
                            source.write_text("module PublicModules where\n" + "".join(
                                "import " + item["module"] + " ()\n" for item in manifest["moved_modules"]))
                            subprocess.run([built[0]["outputs"]["out"] + "/bin/ghc", "-fno-code", "-hide-all-packages",
                                            "-package", "base", "-package", boundary_package, str(source)],
                                           cwd=probe_dir, env=environment, capture_output=True, check=True, timeout=60)
                        receipt.setdefault("validation_observations", []).append({
                            "trial": trial, "label": label, "probe": "original public module reexports",
                            "module_count": len(manifest["moved_modules"]), "elapsed_seconds": time.perf_counter() - started})
            if behavior["baseline"] != behavior["candidate"]:
                raise ValueError(f"Clean and candidate behavior differ in pair {trial}")
            if settings["baseline"] != settings["candidate"]:
                raise ValueError("Compiler/build settings differ between clean and candidate")
            if shared["baseline"] != shared["candidate"]:
                missing = sorted(set(shared["baseline"]) - set(shared["candidate"]))
                added = sorted(set(shared["candidate"]) - set(shared["baseline"]))
                raise ValueError(f"Shared dependency graph changed: removed {missing}, added {added}")
            if reference_shared is None:
                reference_shared = shared["baseline"]
            elif reference_shared != shared["baseline"]:
                raise ValueError("Shared dependency graph changed between trial pairs")
            fixed_settings = json.loads(json.dumps(settings["baseline"]))
            if component == "core":
                fixed_settings["owned"][application + "-core"].pop("source")
            else:
                fixed_settings.pop("source")
            if experiment_mode == "parallelism":
                fixed_settings["normalized_complete_environment"].pop("src", None)
                inputs = fixed_settings["inputs"]
                if "srcs" in inputs:
                    target_source = settings["baseline"]["source"]
                    if sum(absolute(path) == target_source for path in inputs["srcs"]) != 1:
                        raise ValueError("Expected exactly one declared application source input")
                    inputs["srcs"] = sorted("<application-source>" if absolute(path) == target_source else path
                                             for path in inputs["srcs"])
            if reference_settings is None:
                reference_settings = fixed_settings
            elif reference_settings != fixed_settings:
                (destination / "settings-difference.json").write_text(json.dumps(
                    {"reference": reference_settings, "current": fixed_settings}, indent=2) + "\n")
                raise ValueError("Production settings or unrelated owned sources changed between trial pairs")
            expected_extra = 1 if experiment_mode == "intermediates" else 0
            baseline_count = len(current_owned_names) if experiment_mode == "package-split" else len(owned_names)
            candidate_count = len(owned_names) if experiment_mode == "package-split" else len(owned_names) + expected_extra
            if len(owners["baseline"]) != baseline_count or len(owners["candidate"]) != candidate_count:
                raise ValueError("Expected exactly the declared current owned packages and optional checkpoint/foundation")
            receipt["pairs"].append({"trial": trial, "behavior": behavior["baseline"], "roots": roots,
                                     "settings": settings["baseline"],
                                     "shared_graph_nodes_unchanged": len(shared["baseline"]),
                                     "shared_haskell_instances_unchanged": sum("setupCompilerEnvironmentPhase" in node["env"] for node in shared["baseline"].values()),
                                     "seed_chain": "one clean seed; no predecessor" if experiment_mode == "intermediates" else "no seed"})
    for label in ["baseline", "candidate"]:
        if len({row["identity"]["root"] for (trial, side), row in rows.items() if side == label}) != len(trials):
            raise ValueError("Each changed-code trial needs a distinct target derivation")
    receipt["total_validation_elapsed_seconds"] = time.perf_counter() - validation_started
    receipt["status"] = "passed"
    (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Verified {len(trials)} behavior/graph pairs: {destination / 'receipt.json'}")


if __name__ == "__main__":
    main()
