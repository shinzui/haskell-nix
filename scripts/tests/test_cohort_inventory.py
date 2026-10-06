"""Inventory review/promotion guards; no contributor or Nix builds."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

scripts = Path(__file__).parents[1]
sys.path.insert(0, str(scripts))
spec = importlib.util.spec_from_file_location("cohort_inventory", scripts / "cohort-inventory.py")
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


class InventoryTests(unittest.TestCase):
    def test_policy_roots_are_captured_and_toolchain_file_membership_is_guarded(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in inventory.INPUT_FILES:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("recorded")
            baseline = inventory.capture_inputs(root)
            self.assertEqual(baseline[root / "cabal/policy-roots.json"], b"recorded")
            for name in inventory.INPUT_DIRECTORIES:
                with self.subTest(directory=name):
                    added = root / name / "new-input.nix"
                    added.parent.mkdir(parents=True, exist_ok=True)
                    added.write_text("new input")
                    self.assertNotEqual(inventory.capture_inputs(root), baseline)
                    added.unlink()
                    self.assertEqual(inventory.capture_inputs(root), baseline)

    def test_removed_or_changed_toolchain_inputs_invalidate_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in inventory.INPUT_FILES:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("recorded")
            module = root / "lib/toolchain.nix"
            module.parent.mkdir()
            module.write_text("original")
            baseline = inventory.capture_inputs(root)
            module.write_text("changed")
            self.assertNotEqual(inventory.capture_inputs(root), baseline)
            module.unlink()
            self.assertNotEqual(inventory.capture_inputs(root), baseline)

    def test_removed_and_lowered_historical_floors_are_reported(self):
        delta = inventory.floor_delta({"removed": "2", "lowered": "1.10", "raised": "1"},
                                      {"lowered": "1.9", "raised": "2", "new": "1"})
        self.assertEqual(delta["removed"], ["removed"])
        self.assertEqual(delta["lowered"], ["lowered"])
        self.assertEqual(delta["added"], ["new"])

    def test_floor_reader_rejects_partial_or_duplicate_records(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "floors.config"
            for text in ["constraints:\n any.a >=1\n , any.b <2\n",
                         "constraints:\n any.a >=1\n , any.a >=2\n"]:
                path.write_text(text)
                with self.assertRaises(ValueError):
                    inventory.read_floors(path)
            path.write_text("-- Generated\nconstraints:\n any.a >=1.10\n , any.b >=2\n")
            self.assertEqual(inventory.read_floors(path), {"a": "1.10", "b": "2"})

    def test_canonical_identity_order_does_not_hide_metadata_changes(self):
        before = {"packages": {"a": {"version": "1", "identities": [{"hash": "one"}, {"hash": "two"}]}}}
        reordered = {"packages": {"a": {"version": "1", "identities": [{"hash": "two"}, {"hash": "one"}, {"hash": "one"}]}}}
        self.assertEqual(inventory.canonical_inventory(before), inventory.canonical_inventory(reordered))
        reordered["packages"]["a"]["identities"][0]["hash"] = "changed"
        self.assertNotEqual(inventory.canonical_inventory(before), inventory.canonical_inventory(reordered))

    def test_concurrent_record_membership_change_prevents_promotion(self):
        with tempfile.TemporaryDirectory() as directory:
            recorded = Path(directory) / "recorded"
            staged = Path(directory) / "staged"
            recorded.mkdir(); staged.mkdir()
            (recorded / "a.json").write_bytes(b"old")
            expected = {"a.json": b"old"}
            (staged / "a.json").write_bytes(b"new")
            (recorded / "added.json").write_bytes(b"concurrent")
            with self.assertRaisesRegex(RuntimeError, "changed during capture"):
                inventory.promote_inventories(recorded, staged, expected)
            self.assertEqual((recorded / "a.json").read_bytes(), b"old")

    def test_failed_promotion_restores_recorded_files(self):
        with tempfile.TemporaryDirectory() as directory:
            recorded = Path(directory) / "recorded"
            staged = Path(directory) / "staged"
            recorded.mkdir(); staged.mkdir()
            expected = {"a.json": b"old-a", "b.json": b"old-b"}
            for name, data in expected.items():
                (recorded / name).write_bytes(data)
                (staged / name).write_bytes(b"new")
            original = inventory.os.replace
            calls = 0

            def fail_second(source, destination):
                nonlocal calls
                calls += 1
                if calls == 2:
                    raise OSError("interrupted promotion")
                original(source, destination)

            with patch.object(inventory.os, "replace", side_effect=fail_second):
                with self.assertRaises(OSError):
                    inventory.promote_inventories(recorded, staged, expected)
            self.assertEqual({path.name: path.read_bytes() for path in recorded.glob("*.json")}, expected)


if __name__ == "__main__":
    unittest.main()
