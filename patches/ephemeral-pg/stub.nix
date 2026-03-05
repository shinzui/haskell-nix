# ephemeral-pg — null stub package (test-only dep, all consumers use dontCheck)
{ hself, pkgs, ... }:

hself.callPackage
  ({ mkDerivation }:
    mkDerivation {
      pname = "ephemeral-pg";
      version = "0.0.0";
      license = pkgs.lib.licenses.bsd3;
      libraryHaskellDepends = [ ];
      src = pkgs.emptyDirectory;
    })
  { }
