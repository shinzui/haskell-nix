{ lib, pkgs, scope, cohortCompare }:
let
  root = scope.mkDerivation {
    pname = "cohort-flags";
    version = "0.1.0.0";
    src = ./fixtures/cohort/flags;
    isLibrary = true;
    isExecutable = false;
    libraryHaskellDepends = [ scope.base ];
    configureFlags = [ "-f-retained" ];
    license = lib.licenses.bsd3;
  };
  manifest = (import ../lib/mkCohortManifest.nix { inherit lib; }) {
    inherit pkgs scope root;
    context = { fixture = true; };
  };
  unrecorded = (import ../lib/mkCohortManifest.nix { inherit lib; }) {
    inherit pkgs scope;
    root = root.overrideAttrs (_: { postPatch = "echo unrecorded-source-edit"; });
    context = { fixture = true; };
  };
in
pkgs.runCommand "cohort-manifest-fixtures"
{
  nativeBuildInputs = [ pkgs.python3 cohortCompare ];
  manifestFile = manifest;
  rejectsUnrecordedOverride =
    if (builtins.tryEval ((builtins.head unrecorded.declaration.packages).metadata.hash)).success
    then "no" else "yes";
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
        def frozen_fixture(self):
            declaration, graph = self.fixture()
            declaration['system'] = 'aarch64-darwin'
            declaration['compiler'].update(version='9.12.4', packages={'base': '4.21.0.0'})
            declaration['packages'][0]['role'] = 'local'
            package = declaration['packages'][1]
            source_hash = 'sha256-' + 'A' * 43 + '='
            package.update(role='haskell', source={'hash': source_hash},
                metadata={'hash': None, 'revision': None, 'originalHash': 'b' * 64, 'patchedHash': 'b' * 64},
                flags={}, flagsEvidence={'method': 'exact-configure-replay'}, configuration={})
            sources = {'lib': {'version': '1', 'source': 'Hackage', 'identities': [{'flags': {}, 'pkg-src-sha256': 'a' * 64, 'pkg-cabal-sha256': 'b' * 64}], 'dependencies': []}}
            policy = {'schemaVersion': 1, 'packages': {}}
            expected = {'compiler': 'ghc-9.12.4', 'indexState': 'cutoff', 'sources': sources, 'flags': {}, 'localPackages': ['app']}
            declaration['context'] = {'nixpkgsRevision': 'nixpkgs', 'configurationPolicy': copy.deepcopy(policy), 'versions': {
                'sourceManifest': copy.deepcopy(sources), 'flags': {}, 'indexState': 'cutoff', 'ghc': '9.12.4',
                'nixpkgsBase': 'nixpkgs', 'firstParty': [], 'policy': {},
                'packages': {'lib': {'version': '1', 'sha256': source_hash, 'revision': None}}}}
            return expected, tool.construct(declaration, graph), policy
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
            self.assertEqual(actual['root']['name'], 'cohort-flags')
            self.assertEqual(actual['packages'][0]['name'], 'cohort-flags')
            self.assertEqual(actual['packages'][0]['role'], 'local')
            self.assertEqual(actual['packages'][0]['flags'], {'automatic': True, 'retained': False})
            self.assertEqual(actual['packages'][0]['flagsEvidence']['method'], 'exact-configure-replay')
        def test_actual_unrecorded_derivation_override_fails(self):
            self.assertEqual(os.environ['rejectsUnrecordedOverride'], 'yes')
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
        def test_frozen_source_metadata_flags_and_graph_match(self):
            expected, manifest, policy = self.frozen_fixture()
            self.assertIn('matches 1', tool.compare_freeze(expected, manifest, policy))
        def test_frozen_wrong_and_correct_instances_fail(self):
            expected, manifest, policy = self.frozen_fixture()
            wrong = copy.deepcopy(manifest['packages'][1])
            wrong.update(version='2', drvPath='wrong')
            manifest['packages'].append(wrong)
            manifest['derivationGraph']['app'].append('wrong')
            manifest['derivationGraph']['wrong'] = ['ghc']
            with self.assertRaisesRegex(ValueError, 'version mismatch'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_same_version_source_change_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            manifest['packages'][1]['source']['hash'] = 'sha256-changed'
            with self.assertRaisesRegex(ValueError, 'Hackage source differs'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_same_version_metadata_change_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            manifest['packages'][1]['metadata']['originalHash'] = 'c' * 64
            with self.assertRaisesRegex(ValueError, 'metadata differs'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_same_version_flag_change_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            manifest['packages'][1]['flags']['extra'] = True
            with self.assertRaisesRegex(ValueError, 'resolved flags differ'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_missing_resolved_flag_proof_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            del manifest['packages'][1]['flagsEvidence']
            with self.assertRaisesRegex(ValueError, 'missing resolved'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_missing_static_dependency_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            expected['sources']['other'] = copy.deepcopy(expected['sources']['lib'])
            expected['sources']['lib']['dependencies'] = ['other']
            manifest['context']['versions']['sourceManifest'] = copy.deepcopy(expected['sources'])
            with self.assertRaisesRegex(ValueError, 'missing static/build dependency edge'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_native_homonym_does_not_change_haskell_version(self):
            expected, manifest, policy = self.frozen_fixture()
            manifest['nativePackages'] = [{'name': 'lib', 'version': '99', 'role': 'native', 'drvPath': 'native-lib'}]
            manifest['derivationGraph']['app'].append('native-lib')
            manifest['derivationGraph']['native-lib'] = []
            self.assertIn('matches 1', tool.compare_freeze(expected, manifest, policy))
        def test_frozen_unowned_difference_cannot_hide_flags(self):
            expected, manifest, policy = self.frozen_fixture()
            policy['packages']['lib'] = {'flags': {'extra': True}}
            manifest['context']['configurationPolicy'] = copy.deepcopy(policy)
            with self.assertRaisesRegex(ValueError, 'unowned'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_undeclared_build_patch_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            manifest['packages'][1]['configuration']['postPatch'] = 'alter-source'
            with self.assertRaisesRegex(ValueError, 'missing owned build-patch policy'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_wrong_toolchain_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            manifest['context']['nixpkgsRevision'] = 'other'
            with self.assertRaisesRegex(ValueError, 'Nixpkgs differs'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_undeclared_configure_source_edit_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            manifest['packages'][1]['configuration']['hooks'] = {'preConfigure': 'alter-source'}
            with self.assertRaisesRegex(ValueError, 'missing owned build-patch policy'):
                tool.compare_freeze(expected, manifest, policy)
        def pinned_root_fixture(self):
            expected, manifest, policy = self.frozen_fixture()
            frozen = expected['sources']['lib']
            frozen['source'] = 'SourcePin'
            frozen['identities'][0]['pkg-src'] = {'type': 'source-repo', 'source-repo': {
                'location': 'https://github.com/owner/repo', 'tag': 'a' * 40}}
            manifest['context']['versions']['sourceManifest'] = copy.deepcopy(expected['sources'])
            manifest['context']['versions']['policy']['lib'] = {
                'owner': 'mori://shinzui/haskell-nix', 'reason': 'Retained source', 'sourcePinned': True}
            manifest['packages'][1]['source'].update(subdirectory='.', urls=[
                'https://github.com/owner/repo/archive/' + 'a' * 40 + '.tar.gz'])
            return expected, manifest, policy
        def test_pinned_repository_root_matches_omitted_cabal_subdir(self):
            self.assertIn('matches 1', tool.compare_freeze(*self.pinned_root_fixture()))
        def test_pinned_child_does_not_match_repository_root(self):
            expected, manifest, policy = self.pinned_root_fixture()
            manifest['packages'][1]['source']['subdirectory'] = 'child'
            with self.assertRaisesRegex(ValueError, 'revision/subdirectory mismatch'):
                tool.compare_freeze(expected, manifest, policy)
        def owned_patch_fixture(self):
            expected, manifest, policy = self.frozen_fixture()
            package = manifest['packages'][1]
            package['configuration']['postPatch'] = 'verified-bound-repair'
            policy['packages']['lib'] = {'owner': 'mori://shinzui/haskell-nix', 'reason': 'Verified compatibility repair', 'codeHash': tool.code_hash(package)}
            manifest['context']['configurationPolicy'] = copy.deepcopy(policy)
            return expected, manifest, policy
        def test_frozen_owned_patch_passes(self):
            self.assertIn('matches 1', tool.compare_freeze(*self.owned_patch_fixture()))
        def test_frozen_changed_owned_patch_fails(self):
            expected, manifest, policy = self.owned_patch_fixture()
            manifest['packages'][1]['configuration']['postPatch'] += '-changed'
            with self.assertRaisesRegex(ValueError, 'missing owned build-patch policy'):
                tool.compare_freeze(expected, manifest, policy)
        def compiler_tool_fixture(self):
            expected, manifest, policy = self.frozen_fixture()
            expected['sources']['hsc2hs'] = {'version': '0.68.10', 'source': 'Hackage', 'identities': [], 'dependencies': []}
            expected['sources']['lib']['dependencies'] = ['hsc2hs']
            manifest['context']['versions']['sourceManifest'] = copy.deepcopy(expected['sources'])
            manifest['compiler']['outputPath'] = '/compiler'
            manifest['packages'][1]['programs'] = {'hsc2hs': {'version': '0.68.10', 'path': '/compiler/bin/hsc2hs'}}
            policy['packages']['hsc2hs'] = {'owner': 'mori://shinzui/haskell-nix', 'reason': 'Compiler tool', 'compilerTool': True}
            manifest['context']['configurationPolicy'] = copy.deepcopy(policy)
            return expected, manifest, policy
        def test_frozen_owned_compiler_tool_passes(self):
            self.assertIn('matches 1', tool.compare_freeze(*self.compiler_tool_fixture()))
        def test_frozen_versioned_compiler_tool_path_passes(self):
            expected, manifest, policy = self.compiler_tool_fixture()
            manifest['packages'][1]['programs']['hsc2hs']['path'] = '/compiler/bin/hsc2hs-ghc-9.12.4'
            self.assertIn('matches 1', tool.compare_freeze(expected, manifest, policy))
        def test_frozen_wrong_compiler_tool_version_fails(self):
            expected, manifest, policy = self.compiler_tool_fixture()
            manifest['packages'][1]['programs']['hsc2hs']['version'] = '0.1'
            with self.assertRaisesRegex(ValueError, 'missing static/build dependency'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_wrong_compiler_tool_provider_fails(self):
            expected, manifest, policy = self.compiler_tool_fixture()
            manifest['packages'][1]['programs']['hsc2hs']['path'] = '/other/bin/hsc2hs'
            with self.assertRaisesRegex(ValueError, 'missing static/build dependency'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_unowned_compiler_tool_fails(self):
            expected, manifest, policy = self.compiler_tool_fixture()
            del policy['packages']['hsc2hs']
            manifest['context']['configurationPolicy'] = copy.deepcopy(policy)
            with self.assertRaisesRegex(ValueError, 'missing static/build dependency'):
                tool.compare_freeze(expected, manifest, policy)
        def test_frozen_wrong_boot_dependency_fails(self):
            expected, manifest, policy = self.frozen_fixture()
            expected['sources']['base'] = {'version': '4.22', 'source': 'Boot', 'identities': [], 'dependencies': []}
            expected['sources']['lib']['dependencies'] = ['base']
            manifest['context']['versions']['sourceManifest'] = copy.deepcopy(expected['sources'])
            with self.assertRaisesRegex(ValueError, 'compiler boot dependency differs'):
                tool.compare_freeze(expected, manifest, policy)
    unittest.main()
    PY
    cohort-compare --compare-manifests "$manifestFile" "$manifestFile"
    touch "$out"
  ''
