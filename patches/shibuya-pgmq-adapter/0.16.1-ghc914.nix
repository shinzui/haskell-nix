# mori://shinzui/shibuya-pgmq-adapter/packages/shibuya-pgmq-adapter
# Preserve released code and admit only the additional GHC 9.14 boot lines.
{ pkg, lib, haskellLib, hself, ... }:
if !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        substituteInPlace shibuya-pgmq-adapter.cabal \
          --replace-fail 'base ^>=4.21.0.0' 'base ^>=4.21.0.0 || ^>=4.22.0.0' \
          --replace-fail 'time ^>=1.14' 'time ^>=1.14 || ^>=1.15'
      '';
    })
    pkg
