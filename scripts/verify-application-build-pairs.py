#!/usr/bin/env python3
"""Verify completed paired leaf trials through executable behavior and Nix metadata.

Reads local receipts and Nix JSON only. Executables are invoked, never inspected.
Run after the measurement campaign, with an output directory outside source trees.
"""

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    summary = json.loads(args.summary.read_text())
    applications = {"mori://shinzui/rei": ("rei", "time"), "mori://shinzui/mori": ("mori", "sealed-evaluation")}
    if summary["project_uri"] not in applications:
        parser.error("Only the declared Rei and Mori pilots are supported")
    application, topic = applications[summary["project_uri"]]
    destination = args.output_dir.resolve()
    if destination.is_relative_to(Path(__file__).resolve().parent.parent):
        parser.error("Keep evidence outside the source tree")
    for row in summary["trials"]:
        source = Path(row["command"][row["command"].index("source") + 1]).resolve()
        if destination.is_relative_to(source):
            parser.error("Keep evidence outside application source trees")
    destination.mkdir(parents=True, exist_ok=False)
    receipt = {"schema_version": 1, "project_uri": summary["project_uri"],
               "summary_sha256": digest(args.summary.read_bytes()), "pairs": []}
    rows = {(row["trial"], row["label"]): row for row in summary["trials"]}
    trials = sorted({trial for trial, _ in rows})
    if len(trials) < 5 or len(rows) != len(trials) * 2:
        raise ValueError("At least five complete pairs are required")
    with tempfile.TemporaryDirectory(prefix="mp4-behavior-home-") as home:
        # Help/version dispatch has been audited to avoid database services.
        environment = {key: value for key, value in os.environ.items()
                       if not any(term in key for term in ["DATABASE", "PG_CONNECTION", "REI_CONFIG", "MORI_CONFIG"])}
        environment.update({"HOME": home, "XDG_CONFIG_HOME": home, "NO_COLOR": "1", "TERM": "dumb"})
        for trial in trials:
            behavior, shared, owners, roots, settings = {}, {}, {}, {}, {}
            if rows[trial, "baseline"]["source_variant_sha256"] != rows[trial, "candidate"]["source_variant_sha256"]:
                raise ValueError("Pair does not use identical changed source bytes")
            for label in ["baseline", "candidate"]:
                row = rows[trial, label]
                if not row["phase_events"] or not sum(row["compiled_modules"].values()):
                    raise ValueError("Changed-code trial reused an already built target")
                drv = row["identity"]["root"]
                if row["exit_code"] != 0 or row["build_result"][0]["drvPath"] != drv:
                    raise ValueError("Build result does not match measured root")
                if label == "candidate" and not row["identity"]["compatibilityReport"]["accepted"]:
                    raise ValueError("Candidate did not accept its explicit seed")
                output = row["build_result"][0]["outputs"]["out"]
                behavior[label] = []
                for command in [["--version"], ["--help"], ["help", topic], ["--bash-completion-script", application]]:
                    result = subprocess.run([output + "/bin/" + application, *command], capture_output=True,
                                            env=environment, timeout=30)
                    if result.returncode:
                        raise ValueError(f"Behavior probe failed: {label} {command}: {result.stderr[-500:]!r}")
                    if command == ["help", topic] and f"MP4 paired leaf {trial}".encode() not in result.stdout:
                        raise ValueError("Changed leaf behavior missing or stale")
                    behavior[label].append({"command": command, "exit_code": result.returncode,
                                            "stdout_sha256": digest(result.stdout), "stderr_sha256": digest(result.stderr)})
                exported, nodes, absolute = graph(drv)
                graph_file = destination / f"pair-{trial}-{label}.graph.json"
                graph_file.write_text(json.dumps(exported, sort_keys=True) + "\n")
                shared[label] = {key: value for key, value in nodes.items()
                                 if value["env"].get("pname") != application + "-cli"}
                owners[label] = {key: value for key, value in nodes.items() if key not in shared[label]}
                settings[label] = {"configureFlags": nodes[drv]["env"]["configureFlags"].replace(output, "<application-output>"),
                                   "doCheck": nodes[drv]["env"].get("doCheck"), "system": nodes[drv]["system"],
                                   "builder": nodes[drv]["builder"], "source": nodes[drv]["env"].get("src"),
                                   "buildWays": {key: nodes[drv]["env"].get(key) for key in [
                                       "doHaddock", "enableLibraryProfiling", "enableExecutableProfiling",
                                       "enableSharedLibraries", "enableSharedExecutables", "enableStaticLibraries",
                                       "enableStaticExecutables", "enableParallelBuilding"]}}
                roots[label] = {"derivation": drv, "output": output, "graph_sha256": digest(graph_file.read_bytes())}
                info = query(["nix", "path-info", "--json", "--recursive", output])
                if isinstance(info, list):
                    info = {record["path"]: record for record in info}
                intermediates = [absolute(node["outputs"]["intermediates"]["path"])
                                 for node in owners[label].values() if "intermediates" in node["outputs"]]
                if any(path in info for path in intermediates):
                    raise ValueError("Runtime closure retains intermediate compiler products")
                seed_outputs = [absolute(node["outputs"]["out"]["path"])
                                for key, node in owners[label].items() if key != drv]
                if any(path in info for path in seed_outputs):
                    raise ValueError("Runtime closure retains the clean checkpoint executable output")
                roots[label]["runtime_closure_nar_bytes"] = sum(record["narSize"] for record in info.values())
                roots[label]["intermediates_absent_from_runtime_closure"] = True
                roots[label]["seed_outputs_absent_from_runtime_closure"] = True
                if label == "candidate":
                    sizes = query(["nix", "path-info", "--json", *intermediates])
                    if isinstance(sizes, list):
                        sizes = {record["path"]: record for record in sizes}
                    roots[label]["intermediate_nar_bytes"] = {path: record["narSize"] for path, record in sizes.items()}
                    retained = query(["nix", "path-info", "--json", "--recursive", *intermediates])
                    if isinstance(retained, list):
                        retained = {record["path"]: record for record in retained}
                    roots[label]["all_intermediate_roots_marginal_closure_nar_bytes"] = sum(
                        record["narSize"] for path, record in retained.items() if path not in info)
            if behavior["baseline"] != behavior["candidate"]:
                raise ValueError(f"Clean and candidate behavior differ in pair {trial}")
            if settings["baseline"] != settings["candidate"]:
                raise ValueError("Compiler/build settings differ between clean and candidate")
            if shared["baseline"] != shared["candidate"]:
                missing = sorted(set(shared["baseline"]) - set(shared["candidate"]))
                added = sorted(set(shared["candidate"]) - set(shared["baseline"]))
                raise ValueError(f"Shared dependency graph changed: removed {missing}, added {added}")
            if len(owners["baseline"]) != 1 or len(owners["candidate"]) != 2:
                raise ValueError("Expected one clean root and exactly one additional clean seed")
            receipt["pairs"].append({"trial": trial, "behavior": behavior["baseline"], "roots": roots,
                                     "settings": settings["baseline"],
                                     "shared_graph_nodes_unchanged": len(shared["baseline"]),
                                     "shared_haskell_instances_unchanged": sum("setupCompilerEnvironmentPhase" in node["env"] for node in shared["baseline"].values()),
                                     "seed_chain": "one clean seed; no predecessor"})
    for label in ["baseline", "candidate"]:
        if len({row["identity"]["root"] for (trial, side), row in rows.items() if side == label}) != len(trials):
            raise ValueError("Each changed-code trial needs a distinct target derivation")
    receipt["status"] = "passed"
    (destination / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"Verified {len(trials)} behavior/graph pairs: {destination / 'receipt.json'}")


if __name__ == "__main__":
    main()
