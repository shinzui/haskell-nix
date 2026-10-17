{ mkDerivation, base, bytestring, directory, filepath, lib, src
, template-haskell
}:
mkDerivation {
  pname = "file-embed";
  version = "0.0.16.0";
  src = src;
  libraryHaskellDepends = [
    base bytestring directory filepath template-haskell
  ];
  testHaskellDepends = [ base bytestring filepath ];
  homepage = "https://github.com/snoyberg/file-embed";
  description = "Use Template Haskell to embed file contents directly";
  license = lib.licenses.bsd2;
}
