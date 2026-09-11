# claude 1.5.0 — Hackage release of MercuryTechnologies/claude. baikai-claude
# requires `claude ^>=1.5`; the haskell-nix-dev nixpkgs ships 1.4.0.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
  {
    pkg = "claude";
    ver = "1.5.0";
    sha256 = "sha256-Jng3pCOl9d9XqXbHomBJNiXDMViKZYymj9AKTWwHhvY=";
  }
  { }))
