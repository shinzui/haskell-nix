# Locally verified compatibility, not upstream endorsement.
# mori://UnkindPartition/tasty/packages/tasty-hspec corpus matches released example.
# Hackage 1.2.0.4 r8 and upstream HEAD 69545e04d9c32b84d39e54cb090db7d957e9c77c
# still exclude base 4.22. Add only that branch, retaining every existing bound.
# Released example preserves success and intentional pending/failure propagation.
# Retire when an admitting upstream release/revision is selected.
{ pkg, lib, haskellLib, hself, ... }:
if pkg.version != "1.2.0.4"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        echo 'a8fa8ec5e3a0594400d52ad13f823f2eaddccf01505c5924df21e4c8aa7ce5c9  tasty-hspec.cabal' | sha256sum --check
        substituteInPlace tasty-hspec.cabal --replace-fail '^>= 4.21,' '^>= 4.21 || ^>= 4.22,'
      '';
    })
    pkg
