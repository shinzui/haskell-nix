# openai 2.5.4 — latest Hackage release of MercuryTechnologies/openai.
# baikai-openai requires `openai ^>=2.5`; the haskell-nix-dev nixpkgs ships
# 2.5.3, older nixpkgs 2.2.1.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "openai";
  ver = "2.5.4";
  sha256 = "sha256-DN++TyDWVP3AU8QGzan+g4eTIioYZGjGLFuvi1Z4mZA=";
} { }))
