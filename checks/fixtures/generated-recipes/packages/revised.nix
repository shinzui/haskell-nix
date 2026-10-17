{ mkDerivation, base, bytestring, lib, recipe-pinned, src }:
mkDerivation {
  pname = "recipe-leaf";
  version = "1.0";
  src = src;
  libraryHaskellDepends = [ base bytestring recipe-pinned ];
  license = lib.meta.getLicenseFromSpdxId "BSD-3-Clause";
}
