# Apply only upstream's base upper-bound change from commit
# 06cdc44be7497fe5be02b62697bc9268c6699134, without importing HEAD code/other bounds.
# mori://well-typed/cborg, cborg-json/cborg-json.cabal at that commit;
# artifact-level URI pending.
# https://github.com/well-typed/cborg/commit/06cdc44be7497fe5be02b62697bc9268c6699134
# Retire when Hackage publishes an admitting revision/release and nixpkgs selects it.
{ pkg, lib, haskellLib, hself, ... }:
if pkg.version != "0.2.6.0"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        # Hackage r4 raw hash is a01a16807fb9b08c656ed256afa6a70278a436549b203777360ec9b351c7f21a.
        # generic-builder normalizes CRLF in prePatch; guard those exact bytes.
        echo '9eefa257002b7d43b2f7cf47339367e78421d0814af6a2856c0d5809c574e0ed  cborg-json.cabal' | sha256sum --check
        substituteInPlace cborg-json.cabal --replace-fail '< 4.22' '< 4.23'
        echo 'Applied verified upstream cborg-json base bound fix for GHC 9.14.'
      '';
    })
    pkg
