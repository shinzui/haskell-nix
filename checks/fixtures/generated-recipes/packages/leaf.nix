{ mkDerivation, base, lib, src }:
mkDerivation {
  pname = "recipe-leaf";
  version = "1.0";
  src = src;
  libraryHaskellDepends = [ base ];
  license = lib.meta.getLicenseFromSpdxId "BSD-3-Clause";
}
