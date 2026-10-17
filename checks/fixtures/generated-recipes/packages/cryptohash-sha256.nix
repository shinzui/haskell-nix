{ mkDerivation, base, base16-bytestring, bytestring, criterion, lib
, SHA, src, tasty, tasty-hunit, tasty-quickcheck
}:
mkDerivation {
  pname = "cryptohash-sha256";
  version = "0.11.102.1";
  src = src;
  revision = "6";
  editedCabalFile = "01s12sl5mxvraj5fj3cs0pkb03pm8xpjz13y09dpl7i6rv6f578f";
  configureFlags = [ "-f-exe" "-fuse-cbits" ];
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [ base bytestring ];
  testHaskellDepends = [
    base base16-bytestring bytestring SHA tasty tasty-hunit
    tasty-quickcheck
  ];
  benchmarkHaskellDepends = [ base bytestring criterion SHA ];
  homepage = "https://github.com/haskell-hvr/cryptohash-sha256";
  description = "Fast, pure and practical SHA-256 implementation";
  license = lib.licenses.bsd3;
}
