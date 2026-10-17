#!/usr/bin/env python3
"""Exercise source routing and failure atomicity without invoking a compiler."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


HELPER = Path(__file__).resolve().parents[1] / "checks/fixtures/application-builds/mori-core-scaffold.py"


class SourceLayoutTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mori-core-layout-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        shutil.copyfile(HELPER, self.root / "scripts/scaffold-core-sources.py")
        for package, module in [("mori-core", "A"), ("mori-core-foundation", "B")]:
            directory = self.root / package / "src/Mori"
            directory.mkdir(parents=True)
            (directory / (module + ".hs")).write_text("module Mori." + module + " where\n")
            (directory.parent / "keiro-dsl-ledger.txt").write_text("original ledger\n")
            (self.root / package / (package + ".cabal")).write_text(
                "name: " + package + "\n\nlibrary\n  exposed-modules:\n    Mori." + module + "\n\n"
                + ("  reexported-modules:\n    mori-core-foundation:Mori.B\n" if package == "mori-core" else ""))
        goldens = self.root / "mori-core/test/fixtures/golden/events"
        goldens.mkdir(parents=True)
        (goldens / "event.json").write_text('{"version":1}\n')
        tools = self.root / "tools"
        tools.mkdir()
        just = tools / "just"
        just.write_text("#!" + sys.executable + "\n" + '''import os, sys
from pathlib import Path
Path("just-called").write_text("called")
output = Path(sys.argv[sys.argv.index("--out") + 1])
action = os.environ.get("SCAFFOLD_TEST_ACTION", "noop")
if action in ("change", "fail"):
    (output / "Mori/B.hs").write_text("module Mori.B where\\nvalue = 2\\n")
if action == "ledger":
    (output / "keiro-dsl-ledger.txt").write_text("updated ledger\\n")
if action == "new":
    (output / "Mori/C.hs").write_text("module Mori.C where\\n")
if action == "executable":
    (output / "keiro-dsl-ledger.txt").chmod(0o755)
if action == "fail":
    raise SystemExit(7)
''')
        just.chmod(0o755)
        self.environment = os.environ | {"PATH": str(tools) + os.pathsep + os.environ["PATH"]}

    def run_helper(self, action="noop", check=False):
        return subprocess.run([sys.executable, str(self.root / "scripts/scaffold-core-sources.py")]
                              + (["--check"] if check else []),
                              capture_output=True, text=True,
                              env=self.environment | {"SCAFFOLD_TEST_ACTION": action})

    def test_unchanged_combined_tree(self):
        self.assertEqual(self.run_helper(check=True).returncode, 0)

    def test_check_drift_is_read_only_and_apply_keeps_owner(self):
        source = self.root / "mori-core-foundation/src/Mori/B.hs"
        original = source.read_bytes()
        self.assertNotEqual(self.run_helper("change", check=True).returncode, 0)
        self.assertEqual(source.read_bytes(), original)
        self.assertEqual(self.run_helper("change").returncode, 0)
        self.assertIn(b"value = 2", source.read_bytes())
        self.assertFalse((self.root / "mori-core/src/Mori/B.hs").exists())
        self.assertEqual(self.run_helper(check=True).returncode, 0)

    def test_generator_failure_preserves_sources(self):
        source = self.root / "mori-core-foundation/src/Mori/B.hs"
        original = source.read_bytes()
        self.assertNotEqual(self.run_helper("fail").returncode, 0)
        self.assertEqual(source.read_bytes(), original)

    def test_duplicate_resources_are_updated_together(self):
        self.assertEqual(self.run_helper("ledger").returncode, 0)
        contents = [(self.root / name / "src/keiro-dsl-ledger.txt").read_text()
                    for name in ("mori-core", "mori-core-foundation")]
        self.assertEqual(contents, ["updated ledger\n"] * 2)

    def test_conflicting_duplicates_and_symlinks_fail_before_generator(self):
        ledger = self.root / "mori-core-foundation/src/keiro-dsl-ledger.txt"
        ledger.write_text("conflicting ledger\n")
        self.assertNotEqual(self.run_helper().returncode, 0)
        self.assertFalse((self.root / "just-called").exists())
        ledger.write_text("original ledger\n")
        outside = self.root / "outside.txt"
        outside.write_text("outside")
        (ledger.parent / "unsafe-link").symlink_to(outside)
        self.assertNotEqual(self.run_helper().returncode, 0)
        self.assertFalse((self.root / "just-called").exists())

    def test_new_module_updates_both_cabal_inventories_and_check_detects_drift(self):
        self.assertNotEqual(self.run_helper("new", check=True).returncode, 0)
        self.assertFalse((self.root / "mori-core-foundation/src/Mori/C.hs").exists())
        self.assertEqual(self.run_helper("new").returncode, 0)
        self.assertTrue((self.root / "mori-core-foundation/src/Mori/C.hs").exists())
        self.assertFalse((self.root / "mori-core/src/Mori/C.hs").exists())
        cabal = self.root / "mori-core-foundation/mori-core-foundation.cabal"
        self.assertIn("    Mori.C\n", cabal.read_text())
        cabal = self.root / "mori-core/mori-core.cabal"
        self.assertIn("    mori-core-foundation:Mori.C\n", cabal.read_text())
        self.assertEqual(self.run_helper(check=True).returncode, 0)

    def test_source_root_symlink_fails_before_generator(self):
        source = self.root / "mori-core-foundation/src"
        elsewhere = self.root / "elsewhere"
        source.rename(elsewhere)
        source.symlink_to(elsewhere, target_is_directory=True)
        self.assertNotEqual(self.run_helper().returncode, 0)
        self.assertFalse((self.root / "just-called").exists())

    def test_mode_only_change_is_detected_and_preserved_for_both_owners(self):
        self.assertNotEqual(self.run_helper("executable", check=True).returncode, 0)
        self.assertEqual(self.run_helper("executable").returncode, 0)
        for name in ("mori-core", "mori-core-foundation"):
            self.assertTrue((self.root / name / "src/keiro-dsl-ledger.txt").stat().st_mode & 0o111)

    def test_private_modules_are_not_automatically_exposed(self):
        package = self.root / "mori-core-foundation"
        (package / "src/Mori/Private.hs").write_text("module Mori.Private where\n")
        cabal = package / "mori-core-foundation.cabal"
        cabal.write_text(cabal.read_text() + "  other-modules:\n    Mori.Private\n")
        original = cabal.read_bytes()
        self.assertNotEqual(self.run_helper().returncode, 0)
        self.assertFalse((self.root / "just-called").exists())
        self.assertEqual(cabal.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
