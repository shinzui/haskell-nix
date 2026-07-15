# baikai-openai 0.3.0.1 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "baikai-openai";
  ver = "0.3.0.1";
  sha256 = "sha256-meDqBNMvjlhTWFHVji0yJmg1381bB6HwQdo3SfWLm/w=";
} {}))
