# Hackage revision 2 admits base 4.22 and records GHC 9.14.1 testing.
# https://hackage.haskell.org/package/dec-0.0.6/revisions/
# mori://phadej/dec, dec.cabal; artifact-level URI pending.
# Retire once the selected package metadata supplies this revision or newer.
{ pkg, lib, haskellLib, hself, ... }:
if pkg.version != "0.0.6"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (_: {
      revision = "2";
      editedCabalFile = "bad2c5f159ee81d2c2fd11e7957d76c4f37f3a40c9866f76014b131575aa35fe";
    })
    pkg
