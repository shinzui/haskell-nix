import importlib.util
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "application_build_pairs", Path(__file__).resolve().parents[1] / "verify-application-build-pairs.py"
)
pairs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pairs)


class LeafMarkerTests(unittest.TestCase):
    def test_declared_application_marker_and_trial_are_required(self):
        summary = {"replacement": ["before", 'content = "MP4 paired Mori leaf {trial} v1\\n" <> embedded']}
        self.assertEqual(pairs.leaf_marker(summary, 2), b"MP4 paired Mori leaf 2 v1")
        self.assertNotIn(pairs.leaf_marker(summary, 2), b"MP4 paired Mori leaf 1 v1\n")

    def test_complete_declared_rei_marker_is_checked(self):
        summary = {"replacement": ["before", 'content = "MP4 paired leaf {trial} delivery-v1\\n" <> embedded']}
        self.assertEqual(pairs.leaf_marker(summary, 3), b"MP4 paired leaf 3 delivery-v1")

    def test_legacy_receipts_keep_the_original_probe(self):
        self.assertEqual(pairs.leaf_marker({}, 4), b"MP4 paired leaf 4")


if __name__ == "__main__":
    unittest.main()
