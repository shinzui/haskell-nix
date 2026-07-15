# baikai-claude 0.3.0.1 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "baikai-claude";
  ver = "0.3.0.1";
  sha256 = "sha256-77bDSzeGfYlnKDmjHwpNaXezqOSgQUbO26hDoGYyP8w=";
} {}))
