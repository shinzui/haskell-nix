{ lib, pkgs, scope, cohortCompare }:
let
  root = scope.callCabal2nix "tiny" ./fixtures/cabal-version/3.14 { };
  manifest = (import ../lib/mkCohortManifest.nix { inherit lib; }) {
    inherit pkgs scope root;
    context = { fixture = true; };
  };
in
pkgs.runCommand "cohort-manifest-fixtures"
{
  nativeBuildInputs = [ pkgs.python3 cohortCompare ];
  manifestFile = manifest;
}
  ''
    python3 - <<'PY'
    import copy
    import importlib.util
    import json
    import os
    from pathlib import Path
    import unittest
    spec = importlib.util.spec_from_file_location('cohort_manifest', '${../scripts/cohort-manifest.py}')
    tool = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tool)
    class GraphProof(unittest.TestCase):
        def fixture(self):
            declaration = {'schemaVersion': 1, 'root': {'drvPath': 'app'},
                'compiler': {'drvPath': 'ghc'}, 'packages': [
                {'name': 'app', 'version': '1', 'drvPath': 'app', 'componentRoles': ['root'], 'dependencies': ['static-library']},
                {'name': 'lib', 'version': '1', 'drvPath': 'static-library', 'componentRoles': ['libraryHaskellDepends'], 'dependencies': []}]}
            graph = {'derivationGraph': [{'path': 'app', 'references': ['static-library', 'ghc']},
                {'path': 'static-library', 'references': ['ghc']}, {'path': 'ghc', 'references': []}]}
            return declaration, graph
        def test_actual_native_construction(self):
            actual = json.loads(Path(os.environ['manifestFile']).read_text())
            self.assertTrue(actual['graphVerified'])
            self.assertEqual(actual['root']['name'], 'tiny')
            self.assertEqual(actual['packages'][0]['name'], 'tiny')
            self.assertEqual(actual['packages'][0]['role'], 'local')
        def test_static_library_is_proven_by_derivation(self):
            declaration, graph = self.fixture()
            self.assertTrue(tool.construct(declaration, graph)['graphVerified'])
        def test_missing_static_library_fails(self):
            declaration, graph = self.fixture()
            graph['derivationGraph'][0]['references'] = ['ghc']
            with self.assertRaisesRegex(ValueError, 'absent from the actual root graph'):
                tool.construct(declaration, graph)
        def test_missing_record_fails(self):
            declaration, graph = self.fixture()
            declaration['packages'].pop()
            with self.assertRaisesRegex(ValueError, 'missing Haskell dependency record'):
                tool.construct(declaration, graph)
        def test_unrelated_correct_package_cannot_hide_wrong_instance(self):
            declaration, graph = self.fixture()
            other = copy.deepcopy(declaration['packages'][1])
            other.update(version='2', drvPath='other')
            declaration['packages'].append(other)
            graph['derivationGraph'].append({'path': 'other', 'references': ['ghc']})
            with self.assertRaisesRegex(ValueError, 'absent from the actual root graph'):
                tool.construct(declaration, graph)
        def test_claimed_edge_between_unrelated_siblings_fails(self):
            declaration, graph = self.fixture()
            graph['derivationGraph'][0]['references'].append('other')
            graph['derivationGraph'].append({'path': 'other', 'references': ['ghc']})
            other = copy.deepcopy(declaration['packages'][1])
            other.update(name='other', drvPath='other')
            declaration['packages'].append(other)
            declaration['packages'][1]['dependencies'] = ['other']
            with self.assertRaisesRegex(ValueError, 'edge is absent'):
                tool.construct(declaration, graph)
        def test_empty_graph_fails(self):
            declaration, _ = self.fixture()
            with self.assertRaisesRegex(ValueError, 'missing actual derivation graph'):
                tool.construct(declaration, {'derivationGraph': []})
        def test_native_homonyms_keep_a_separate_role(self):
            declaration, graph = self.fixture()
            graph['derivationGraph'][0]['references'].append('native-lib')
            graph['derivationGraph'].append({'path': 'native-lib', 'references': []})
            declaration['nativePackages'] = [{'name': 'lib', 'version': '99', 'role': 'native', 'drvPath': 'native-lib'}]
            actual = tool.construct(declaration, graph)
            self.assertEqual(actual['packages'][1]['version'], '1')
            self.assertEqual(actual['nativePackages'][0]['role'], 'native')
        def test_identical_builds_compare_equal(self):
            declaration, graph = self.fixture()
            manifest = tool.construct(declaration, graph)
            self.assertEqual(tool.compare_manifests(manifest, copy.deepcopy(manifest)), [])
        def test_same_version_source_and_policy_changes_are_reported(self):
            declaration, graph = self.fixture()
            before = tool.construct(declaration, graph)
            after = copy.deepcopy(before)
            after['packages'][1]['source'] = {'hash': 'changed'}
            after['packages'][1]['configuration'] = {'jailbreak': True}
            changes = '\n'.join(tool.compare_manifests(before, after))
            self.assertIn('inputs=source,configuration', changes)
            self.assertIn('users=app', changes)
        def test_correct_and_wrong_instances_do_not_compare_equal(self):
            declaration, graph = self.fixture()
            before = tool.construct(declaration, graph)
            other = copy.deepcopy(declaration['packages'][1])
            other.update(drvPath='wrong', version='2')
            declaration['packages'].append(other)
            graph['derivationGraph'][0]['references'].append('wrong')
            graph['derivationGraph'].append({'path': 'wrong', 'references': ['ghc']})
            after = tool.construct(declaration, graph)
            self.assertTrue(tool.compare_manifests(before, after))
    unittest.main()
    PY
    cohort-compare --compare-manifests "$manifestFile" "$manifestFile"
    touch "$out"
  ''
