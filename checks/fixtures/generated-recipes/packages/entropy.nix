{ mkDerivation, base, bytestring, Cabal, directory, filepath, lib
, process, src, unix
}:
mkDerivation {
  pname = "entropy";
  version = "0.4.1.11";
  src = src;
  revision = "1";
  editedCabalFile = "04vrqipcdr584wcn5vqc90x0mi0qrj2bxafpwrqpcvdsh9r1m6qv";
  configureFlags = [ "-f-donotgetentropy" ];
  setupHaskellDepends = [ base Cabal directory filepath process ];
  libraryHaskellDepends = [ base bytestring unix ];
  homepage = "https://github.com/TomMD/entropy";
  description = "A platform independent entropy source";
  license = lib.licenses.bsd3;
}
