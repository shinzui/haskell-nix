# Select an exact published, admitting Cabal revision without changing sources,
# other dependency bounds or test policy. Retire when nixpkgs supplies the revision.
{ version, revision, sha256, exceptionId ? null }:
{ pkg, lib, haskellLib, hself, ... }:
if !(if exceptionId == null then
  pkg.version == version && lib.versionAtLeast hself.ghc.version "9.14" && lib.versionOlder hself.ghc.version "9.15"
else
  (import ../../lib/compatibilityEntryApplies.nix { inherit lib; }) exceptionId {
    version = pkg.version;
    compiler = hself.ghc.version;
  })
then pkg
else
  haskellLib.overrideCabal
    (_: {
      inherit revision;
      editedCabalFile = sha256;
    })
    pkg
