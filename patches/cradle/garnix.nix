{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "cradle"
  (pkgs.fetchFromGitHub {
    owner = "garnix-io";
    repo = "cradle";
    rev = "711c441fa8f190a8964c56a3bae864cd5321c5c5";
    hash = "sha256-wg1/WMu624PQuzrSEE2SP31AbzrIQmUZm4dcCQ/yvYk=";
  })
{ }))
