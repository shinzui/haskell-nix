{ mkDerivation, base, lib, recipe-leaf, recipe-pinned, src }:
mkDerivation {
  pname = "recipe-consumer";
  version = "1.0";
  src = src;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [ base recipe-leaf recipe-pinned ];
  license = lib.meta.getLicenseFromSpdxId "BSD-3-Clause";
  mainProgram = "recipe-consumer";
}
