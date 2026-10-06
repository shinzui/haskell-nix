# Locally verified compatibility; upstream still excludes base 4.22.
# mori://UnkindPartition/tasty/packages/tasty-wai preserves the released source/API.
# Hackage 0.1.2.0 r3, only two base upper bounds changed; five endpoint tests pass
# on GHC 9.14.1/base 4.22.0.0. No upstream endorsement or broad jailbreak.
# Retire when an admitting upstream release/revision is selected.
{ pkg, lib, haskellLib, hself, ... }:
if pkg.version != "0.1.2.0"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        echo '626eb98168de07a1f9e8938b851c96c244cf818e6d7a75005b272edb4597162b  tasty-wai.cabal' | sha256sum --check
        substituteInPlace tasty-wai.cabal --replace-fail '< 4.22' '< 4.23'
        echo 'Applied local, test-required tasty-wai base compatibility proof.'
      '';
    })
    pkg
