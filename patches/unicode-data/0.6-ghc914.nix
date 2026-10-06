# Exact metadata-only base changes from da6c4ece0d8cbf43498cd310c64c15d55e116d96.
# mori://composewell/unicode-data, unicode-data/unicode-data.cabal; artifact-level URI pending.
# https://github.com/composewell/unicode-data/commit/da6c4ece0d8cbf43498cd310c64c15d55e116d96
# Retire when admitting package metadata is selected; preserve Unicode 0.6 data/API.
{ pkg, lib, haskellLib, hself, ... }:
if pkg.version != "0.6.0"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        echo 'bc653b4380dd9a1cc7f7cf6f11c9e6cf2d9457423a8938b5dba85dd9fa7e2bf4  unicode-data.cabal' | sha256sum --check
        substituteInPlace unicode-data.cabal --replace-fail '< 4.22' '< 4.23'
        echo 'Applied verified upstream unicode-data base bound fix for GHC 9.14.'
      '';
    })
    pkg
