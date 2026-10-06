# Exact compatibility backport from upstream f741afffafc3131cc5a8dd896749c35ed49bfd0a.
# mori://dhall-lang/dhall-haskell, dhall/dhall.cabal and
# dhall/src/Dhall/Syntax/Instances/Lift.hs at that commit; artifact URIs pending.
# https://github.com/dhall-lang/dhall-haskell/commit/f741afffafc3131cc5a8dd896749c35ed49bfd0a
# Retire when the selected published source/metadata contains this fix.
{ pkg, lib, haskellLib, hself, ... }:
if pkg.version != "1.42.3"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        # Original released metadata selected by nixpkgs, normalized before postPatch.
        echo '3a812cc88343be8eb65ebab48f08bed694f3f33fe9bfc6c4a262fe53f4b55b5d  dhall.cabal' | sha256sum --check
        echo 'a21a173e02a5335e9f0b3d5ad97c16b40fad38aaee0a01fea5b933236a1b9ab9  src/Dhall/Syntax/Instances/Lift.hs' | sha256sum --check
        substituteInPlace dhall.cabal \
          --replace-fail 'template-haskell            >= 2.13.0.0 && < 2.24' 'template-haskell            >= 2.13.0.0 && < 2.25' \
          --replace-fail 'time                        >= 1.9      && < 1.15' 'time                        >= 1.9      && < 1.16'
        substituteInPlace src/Dhall/Syntax/Instances/Lift.hs \
          --replace-fail 'import qualified Data.Time as Time' '#if !MIN_VERSION_time(1,15,0)
        import qualified Data.Time as Time
        #endif' \
          --replace-fail 'deriving instance Lift Time.TimeOfDay
        deriving instance Lift Time.TimeZone' '#if !MIN_VERSION_time(1,15,0)
        deriving instance Lift Time.TimeOfDay
        deriving instance Lift Time.TimeZone
        #endif'
        echo 'Applied exact upstream Dhall GHC 9.14/time 1.15 compatibility backport.'
      '';
    })
    pkg
