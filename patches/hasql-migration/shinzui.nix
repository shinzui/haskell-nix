# hasql-migration — shinzui fork with GHC 9.12 compatibility
{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "hasql-migration"
  (pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "hasql-migration";
    rev = "ab66f6ae93e40065f8532dd9d497ecb15c91122e";
    hash = "sha256-A6jAeU5WrDCpJ5RJn5EYC7BnwGVtswwREnPdVfdlUpg=";
  })
  {}))
