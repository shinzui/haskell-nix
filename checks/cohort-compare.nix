{ pkgs, cohortCompare }:
pkgs.runCommand "cohort-compare-fixtures"
{
  nativeBuildInputs = [ cohortCompare pkgs.python3 ];
}
  ''
    python3 - <<'PY'
    import json
    from pathlib import Path
    Path('cohort.freeze').write_text('-- Compiler: ghc-9.12.4\nindex-state: 2026-10-06T00:00:00Z\nconstraints: any.lib ==1\n')
    row = {'id': 'lib', 'type': 'configured', 'pkg-name': 'lib', 'pkg-version': '1',
           'pkg-src': {'type': 'repo-tar'}, 'pkg-src-sha256': 'a' * 64,
           'pkg-cabal-sha256': 'b' * 64, 'flags': {}}
    Path('cohort-sources.json').write_text(json.dumps({'lib': {'version': '1', 'source': 'Hackage', 'identities': [row], 'dependencies': []}}))
    Path('contributors.json').write_text('[]')
    Path('good.json').write_text(json.dumps({'compiler-id': 'ghc-9.12.4', 'install-plan': [row]}))
    row['pkg-version'] = '2'
    Path('bad.json').write_text(json.dumps({'compiler-id': 'ghc-9.12.4', 'install-plan': [row]}))
    Path('consumer.lock').write_text(json.dumps({'root': 'application', 'nodes': {
        'application': {'inputs': {'library': 'lib', 'channel': ['library', 'channel']}},
        'lib': {'inputs': {'channel': 'shared'}},
        'shared': {'locked': {'type': 'git', 'rev': 'a' * 40}}
    }}))
    Path('cycle.lock').write_text(json.dumps({'root': 'application', 'nodes': {
        'application': {'inputs': {'channel': ['channel']}}
    }}))
    Path('cabal.project').write_text('import: https://raw.githubusercontent.com/shinzui/haskell-nix/' + 'a' * 40 + '/cabal/cohort.freeze\n')
    Path('stale.project').write_text('import: https://raw.githubusercontent.com/shinzui/haskell-nix/' + 'b' * 40 + '/cabal/cohort.freeze\n')
    PY
    expect_status() {
      expected=$1
      shift
      actual=0
      "$@" >stdout 2>stderr || actual=$?
      if [ "$actual" -ne "$expected" ]; then
        cat stdout stderr
        echo "expected $expected, got $actual: $*" >&2
        exit 1
      fi
    }
    expect_status 0 cohort-compare --resolve-channel-lock consumer.lock --input-path channel
    test "$(cat stdout)" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    expect_status 0 cohort-compare --resolve-channel-lock consumer.lock --input-path library/channel
    expect_status 0 cohort-compare --verify-import cabal.project --lock consumer.lock --input-path channel
    expect_status 1 cohort-compare --verify-import stale.project --lock consumer.lock --input-path library/channel
    grep -q 'stale or missing cohort import' stderr
    expect_status 1 cohort-compare --verify-import cabal.project --lock cycle.lock --input-path channel
    expect_status 2 cohort-compare --verify-import cabal.project --input-path channel
    expect_status 2 cohort-compare --verify-import cabal.project --lock consumer.lock --input-path channel --plan-json good.json
    expect_status 1 cohort-compare --resolve-channel-lock cycle.lock --input-path channel
    expect_status 1 cohort-compare --resolve-channel-lock consumer.lock --input-path missing
    expect_status 2 cohort-compare --input-path channel
    expect_status 2 cohort-compare --freeze cohort.freeze --plan-json good.json --input-path channel
    expect_status 2 cohort-compare --freeze cohort.freeze --freeze other --plan-json good.json
    expect_status 2 cohort-compare --nix-manifest future.json
    expect_status 2 cohort-compare --compare-manifests before.json
    expect_status 2 cohort-compare --compare-manifests before.json after.json --all
    expect_status 0 cohort-compare --freeze cohort.freeze --plan-json good.json --all
    grep -q 'ok lib 1' stdout
    expect_status 1 cohort-compare --freeze cohort.freeze --plan-json bad.json
    grep -q 'mismatch lib expected=1 actual=2' stderr
    expect_status 1 cohort-compare --freeze missing.freeze --plan-json good.json
    touch "$out"
  ''
