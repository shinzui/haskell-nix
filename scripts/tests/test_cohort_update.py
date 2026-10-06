"""Snapshot and promotion regressions; these never invoke Cabal or Nix."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("cohort_update", Path(__file__).parents[1] / "cohort-update.py")
updater = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updater)


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "root"
        self.stage = Path(self.temporary.name) / "stage"
        self.runtime = Path(self.temporary.name) / "external-runtime.freeze"
        names = ["cabal/" + name for name in [
            "cohort.freeze", "cohort-sources.json", "common.config", "floors.config",
            "contributors.json", "inventory-inputs.json", "policy-floors.json",
            "compiler-boot-packages.json",
        ]] + ["flake.nix", "flake.lock", "cabal.project", "packages/first-party-lock.json",
              "config/first-party-families.json", "cabal/inventory/one.json",
              "cabal/rei-family-cohort/rei-family-cohort.cabal", "nix/tooling.nix"]
        for name in names:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("original " + name)
        (self.root / "cabal/inventory-inputs.json").write_text(json.dumps({
            "indexState": "2026-10-05T22:39:44Z", "channelRevision": "recorded-revision",
            "compiler": "ghc-9.12.4",
        }))
        self.runtime.write_text("original runtime")

    def test_changed_removed_and_added_inputs_invalidate_snapshot(self):
        mutations = [
            ("cabal/inventory/one.json", "delete"),
            ("cabal/inventory/new.json", "write"),
            ("cabal/rei-family-cohort/rei-family-cohort.cabal", "write"),
            ("cabal/rei-family-cohort/new.cabal", "write"),
            ("flake.lock", "write"),
            ("nix/tooling.nix", "write"),
            ("overlays/new.nix", "write"),
        ]
        for name, operation in mutations:
            with self.subTest(name=name):
                baseline = updater.capture_inputs(self.root, self.runtime)
                path = self.root / name
                before = path.read_bytes() if path.exists() else None
                if operation == "delete":
                    path.unlink()
                else:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text("changed")
                self.assertNotEqual(updater.capture_inputs(self.root, self.runtime), baseline)
                if before is None:
                    path.unlink()
                else:
                    path.write_bytes(before)
        baseline = updater.capture_inputs(self.root, self.runtime)
        self.runtime.write_text("changed runtime")
        self.assertNotEqual(updater.capture_inputs(self.root, self.runtime), baseline)

    def test_staging_uses_captured_bytes_after_live_inputs_change(self):
        baseline = updater.capture_inputs(self.root, self.runtime)
        (self.root / "cabal/common.config").write_text("new live config")
        self.runtime.write_text("new live runtime")
        captured, runtime = updater.stage_inputs(self.root, self.stage, baseline, self.runtime)
        self.assertEqual((self.stage / "common.config").read_bytes(), baseline[self.root / "cabal/common.config"])
        self.assertEqual((captured / "cabal/inventory/one.json").read_bytes(), baseline[self.root / "cabal/inventory/one.json"])
        self.assertEqual(runtime.read_text(), "original runtime")

    def test_runtime_can_also_be_the_existing_cohort_freeze(self):
        runtime = self.root / "cabal/cohort.freeze"
        baseline = updater.capture_inputs(self.root, runtime)
        captured, staged_runtime = updater.stage_inputs(self.root, self.stage, baseline, runtime)
        self.assertEqual((captured / "cabal/cohort.freeze").read_bytes(), baseline[runtime])
        self.assertEqual(staged_runtime.read_bytes(), baseline[runtime])

    def run_workflow(self, mutate=None, reject_retained=False):
        commands = []

        def option(command, name):
            return Path(command[command.index(name) + 1])

        def fake_run(command, **kwargs):
            commands.append(command)
            if command[:2] == ["cabal", "build"]:
                return
            name = command[2]
            if name == "normalise-freeze":
                option(command, "--out").write_text("candidate freeze")
                (self.stage / "cohort-sources.json").write_text("candidate sources")
            elif name in ["report", "impact", "update-constraints"]:
                option(command, "--out").write_text("candidate " + name)
            elif name == "check-retained" and reject_retained:
                raise subprocess.CalledProcessError(1, command)

        def fake_solve(command, **kwargs):
            if mutate is not None:
                mutate()
            return subprocess.CompletedProcess(command, 0)

        with patch.object(updater.Path, "cwd", return_value=self.root), \
             patch.object(updater.tempfile, "mkdtemp", return_value=str(self.stage)), \
             patch.object(updater, "run", side_effect=fake_run), \
             patch.object(updater.subprocess, "run", side_effect=fake_solve), \
             patch.object(updater.subprocess, "check_output", return_value="/fake/cli\n"), \
             patch("sys.argv", ["cohort-update.py", "leaf", "--runtime-freeze", str(self.runtime)]):
            updater.main()
        return commands

    def test_reports_and_checks_use_captured_inputs_before_promotion(self):
        commands = self.run_workflow()
        report = next(command for command in commands if command[2] == "report")
        impact = next(command for command in commands if command[2] == "impact")
        retained = next(command for command in commands if command[2] == "check-retained")
        for command, option in [(report, "--inventory"), (report, "--lock"), (report, "--catalog"),
                                (report, "--policy-floors"), (impact, "--before"),
                                (impact, "--inventory"), (retained, "--before")]:
            self.assertTrue(Path(command[command.index(option) + 1]).is_relative_to(self.stage / "inputs"))
        for command in commands:
            if command[2] in ["normalise-freeze", "check"]:
                self.assertEqual(command[command.index("--compiler") + 1], "ghc-9.12.4")
        self.assertEqual((self.root / "cabal/cohort.freeze").read_text(), "candidate freeze")

    def test_new_inventory_aborts_without_promoting(self):
        original = (self.root / "cabal/cohort.freeze").read_bytes()
        with self.assertRaisesRegex(SystemExit, "Recorded inputs changed"):
            self.run_workflow(mutate=lambda: (self.root / "cabal/inventory/new.json").write_text("new"))
        self.assertEqual((self.root / "cabal/cohort.freeze").read_bytes(), original)
        self.assertFalse((self.root / "cabal/cohort-impact.txt").exists())

    def test_retained_identity_failure_aborts_without_promoting(self):
        original = (self.root / "cabal/cohort.freeze").read_bytes()
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_workflow(reject_retained=True)
        self.assertEqual((self.root / "cabal/cohort.freeze").read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
