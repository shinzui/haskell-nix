{ mkDerivation, base, lib, src, text }:
mkDerivation {
  pname = "recipe-leaf";
  version = "1.0";
  src = src;
  configureFlags = [ "-fuse-text" ];
  libraryHaskellDepends = [ base text ];
  license = lib.meta.getLicenseFromSpdxId "BSD-3-Clause";
}
