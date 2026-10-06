# Select an exact published, admitting Cabal revision without changing sources,
# other dependency bounds or test policy. Retire when nixpkgs supplies the revision.
{ version, revision, sha256 }:
{ pkg, lib, haskellLib, hself, ... }:
if pkg.version != version
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (_: {
      inherit revision;
      editedCabalFile = sha256;
    })
    pkg
