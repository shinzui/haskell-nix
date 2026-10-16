# Exact metadata-only GHC 9.14 changes from upstream commit 7bc38dd4463b7275e9c97c4b2ac308df73278dad.
# mori://fizruk/http-api-data, http-api-data.cabal at that commit; artifact-level URI pending.
# https://github.com/fizruk/http-api-data/commit/7bc38dd4463b7275e9c97c4b2ac308df73278dad
# Preserve 0.6.3 source/API and all other bounds. Retire when admitting metadata is selected.
{ pkg, lib, haskellLib, hself, ... }:
if pkg.version != "0.6.3"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        echo '21704c5bcaeb997594fdda9c73dd0a19ddcc1134dd40e9c2a2587a5b8f1dba89  http-api-data.cabal' | sha256sum --check
        substituteInPlace http-api-data.cabal \
          --replace-fail '< 4.22' '< 4.23' \
          --replace-fail '< 0.8' '< 0.9'
        echo 'Applied verified upstream http-api-data base/containers bound fix for GHC 9.14.'
      '';
    })
    pkg
