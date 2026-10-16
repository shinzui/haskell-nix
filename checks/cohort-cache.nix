{ pkgs }:
pkgs.runCommand "cohort-cache-contract"
{
  nativeBuildInputs = [ pkgs.python3 ];
}
  ''
    python3 - <<'PY'
    import importlib.util
    import unittest
    spec = importlib.util.spec_from_file_location('cohort_cache', '${../scripts/cohort-cache.py}')
    cache = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cache)
    class Contract(unittest.TestCase):
        def receipt(self):
            return {'schemaVersion': 1, 'cache': 'tan', 'roots': ['root'], 'paths': {
                'root': {'narHash': 'sha256-root', 'narSize': 1, 'references': ['library']},
                'library': {'narHash': 'sha256-library', 'narSize': 2, 'references': []}}}
        def test_complete_graph(self):
            roots, graph, uri = cache.validate_receipt(self.receipt())
            self.assertEqual(roots, ['root'])
            self.assertEqual(uri, 'https://tan.cachix.org')
            cache.require_equal(graph, graph.copy())
        def test_missing_static_library_is_rejected(self):
            receipt = self.receipt()
            del receipt['paths']['library']
            with self.assertRaisesRegex(ValueError, 'omits a dependency'):
                cache.validate_receipt(receipt)
        def test_missing_root_is_rejected(self):
            receipt = self.receipt()
            receipt['roots'] = ['other']
            with self.assertRaisesRegex(ValueError, 'omits a declared root'):
                cache.validate_receipt(receipt)
        def test_changed_remote_nar_is_rejected(self):
            expected = self.receipt()['paths']
            actual = self.receipt()['paths']
            actual['library']['narHash'] = 'sha256-changed'
            with self.assertRaisesRegex(ValueError, 'library'):
                cache.require_equal(expected, actual)
        def test_extra_or_missing_paths_are_rejected(self):
            graph = self.receipt()['paths']
            with self.assertRaisesRegex(ValueError, 'library'):
                cache.require_equal(graph, {'root': graph['root']})
        def test_empty_evidence_is_rejected(self):
            receipt = self.receipt()
            receipt['paths'] = {}
            with self.assertRaisesRegex(ValueError, 'no roots or dependency evidence'):
                cache.validate_receipt(receipt)
        def test_legacy_and_versioned_nix_metadata(self):
            rows = {'root.drv': {'system': 'aarch64-darwin'}}
            self.assertEqual(cache.derivation_systems(rows), ['aarch64-darwin'])
            self.assertEqual(cache.derivation_systems({'version': 3, 'derivations': rows}), ['aarch64-darwin'])
    unittest.main()
    PY
    touch "$out"
  ''
