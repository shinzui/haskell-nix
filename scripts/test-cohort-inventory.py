#!/usr/bin/env python3
"""Regression fixtures for Haskell/native roles in Nix derivation metadata."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("cohort_inventory", Path(__file__).with_name("cohort-inventory.py"))
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


def haskell(package, version):
    # Phase fields captured from the recorded deployment's generic builder.
    return {"env": {
        "pname": package,
        "version": version,
        "prePhases": "setupCompilerEnvironmentPhase",
        "preConfigurePhases": "compileBuildDriverPhase",
        "setupCompilerEnvironmentPhase": "runHook preSetupCompilerEnvironment",
        "compileBuildDriverPhase": "./Setup configure",
    }}


class DeploymentRoles(unittest.TestCase):
    def test_native_library_compiler_and_rust_homonyms_are_not_haskell(self):
        graph = {
            "haskell-zlib.drv": haskell("zlib", "0.7.1.1"),
            "native-zlib.drv": {"env": {"pname": "zlib", "version": "1.3.2", "name": "zlib-1.3.2"}},
            "rust-either.drv": {"env": {"name": "either-1.15.0", "buildCommand": "tar xf crate-either; touch .cargo-checksum.json"}},
            "ghc.drv": {"env": {}},
        }
        for metadata in (graph, {"version": 4, "derivations": graph}):
            self.assertEqual(inventory.deployed_haskell_versions(metadata, ["zlib", "either", "ghc"]), {"zlib": "0.7.1.1"})

    def test_maximum_uses_only_haskell_instances(self):
        graph = {"old": haskell("zlib", "0.7.1.1"), "new": haskell("zlib", "0.7.1.2")}
        self.assertEqual(inventory.deployed_haskell_versions(graph, ["zlib"]), {"zlib": "0.7.1.2"})
        self.assertEqual(inventory.deployed_haskell_versions(graph, []), {})

    def test_both_phase_markers_and_scripts_are_required(self):
        for key in ("prePhases", "preConfigurePhases", "setupCompilerEnvironmentPhase", "compileBuildDriverPhase"):
            record = haskell("zlib", "0.7.1.1")
            del record["env"][key]
            self.assertEqual(inventory.deployed_haskell_versions({"incomplete": record}, ["zlib"]), {})
        with self.assertRaisesRegex(ValueError, "invalid Haskell derivation version"):
            inventory.deployed_haskell_versions({"bad": haskell("zlib", "not-a-version")}, ["zlib"])


if __name__ == "__main__":
    unittest.main()
