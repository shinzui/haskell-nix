import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("runtime_import", sys.argv[1])
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)
ROOT = Path(sys.argv[2])
sys.argv = [sys.argv[0]]


class ImportProof(unittest.TestCase):
    def prepare(self, transform=lambda path, value: value, channel="github"):
        return tool.prepare("a" * 40, "keiro-runtime", 1, channel,
                            lambda path: transform(path, (ROOT / path).read_bytes()))

    def test_both_channels_preserve_original_bytes_and_resolve_relative_imports(self):
        for channel in ("github", "hackage"):
            files = self.prepare(channel=channel)
            for name, value in files.items():
                if name not in ("selection.json", "comparison-sources.json"):
                    self.assertEqual(value, (ROOT / f"cabal/runtimes/keiro-runtime/1/{name}").read_bytes())
            self.assertIn(b"import: cohort.freeze", files[channel + ".project"])
            self.assertIn("cohort.freeze", files)
            self.assertIn("configuration.project", files)

    def test_comparison_sources_preserve_complement_and_selected_runtime(self):
        for channel in ("github", "hackage"):
            files = self.prepare(channel=channel)
            actual = json.loads(files["comparison-sources.json"])
            runtime = json.loads(files[channel + "-sources.json"])
            original = json.loads((ROOT / "cabal/cohort-sources.json").read_bytes())
            self.assertEqual(actual, original | runtime)
            self.assertEqual(actual["keiki"], runtime["keiki"])
            self.assertEqual(actual["cmark-gfm"], original["cmark-gfm"])

    def test_runtime_and_current_cohort_version_conflict_is_rejected(self):
        def conflict(path, value):
            if path == "cabal/cohort-sources.json":
                sources = json.loads(value)
                sources["keiki"]["version"] = "0.0.0"
                return json.dumps(sources).encode()
            return value
        with self.assertRaisesRegex(ValueError, "runtime/cohort version conflict: keiki"):
            self.prepare(conflict)

    def test_tampered_transport_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "hash mismatch"):
            self.prepare(lambda path, value: value + b"tamper" if path.endswith("cohort.freeze") else value)

    def test_unchanged_import_writes_nothing_and_check_requires_all_files(self):
        with tempfile.TemporaryDirectory() as directory:
            files = self.prepare()
            tool.publish(directory, files)
            before = {p.name: p.stat().st_mtime_ns for p in Path(directory).iterdir()}
            tool.publish(directory, files)
            tool.publish(directory, files, check=True)
            self.assertEqual(before, {p.name: p.stat().st_mtime_ns for p in Path(directory).iterdir()})
            (Path(directory) / "cohort.freeze").unlink()
            with self.assertRaisesRegex(ValueError, "missing or stale"):
                tool.publish(directory, files, check=True)

    def test_changed_projection_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            files = self.prepare()
            tool.publish(directory, files)
            path = Path(directory) / "cohort.freeze"
            path.write_bytes(b"user edit")
            with self.assertRaisesRegex(ValueError, "refusing to overwrite"):
                tool.publish(directory, files)
            self.assertEqual(path.read_bytes(), b"user edit")

    def test_symlink_projection_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "cohort.freeze").symlink_to("missing")
            with self.assertRaisesRegex(ValueError, "symlink"):
                tool.publish(directory, self.prepare())

    def test_partial_publication_failure_restores_all_previous_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            original = {"cohort.freeze": b"frozen", "selection.json": b"old selection"}
            tool.publish(directory, original)
            replace = Path.replace
            def fail_last(path, target):
                if path.name == "last.project":
                    raise OSError("injected final-file failure")
                return replace(path, target)
            with patch.object(Path, "replace", fail_last):
                with self.assertRaises(OSError):
                    tool.publish(directory, original | {"selection.json": b"new", "first.project": b"first", "last.project": b"last"})
            self.assertEqual({p.name: p.read_bytes() for p in Path(directory).iterdir()}, original)


unittest.main()
