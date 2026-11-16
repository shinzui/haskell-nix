{ mkDerivation, base, bytestring, criterion, deepseq, HUnit, lib
, QuickCheck, src, test-framework, test-framework-hunit
, test-framework-quickcheck2
}:
mkDerivation {
  pname = "base64-bytestring";
  version = "1.2.1.0";
  src = src;
  revision = "1";
  editedCabalFile = "00wqskhc31agyxvm7546367qb33v5i3j31sibcw6vihli77mqc25";
  libraryHaskellDepends = [ base bytestring ];
  testHaskellDepends = [
    base bytestring HUnit QuickCheck test-framework
    test-framework-hunit test-framework-quickcheck2
  ];
  benchmarkHaskellDepends = [ base bytestring criterion deepseq ];
  homepage = "https://github.com/haskell/base64-bytestring";
  description = "Fast base64 encoding and decoding for ByteStrings";
  license = lib.licenses.bsd3;
}
