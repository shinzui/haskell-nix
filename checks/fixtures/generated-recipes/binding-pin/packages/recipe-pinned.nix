{ mkDerivation, base, Cabal, lib, src, zlib }:
mkDerivation {
  pname = "recipe-pinned";
  version = "1.0";
  src = src;
  setupHaskellDepends = [ base Cabal ];
  libraryHaskellDepends = [ base ];
  librarySystemDepends = [ zlib ];
  license = lib.meta.getLicenseFromSpdxId "BSD-3-Clause";
}
