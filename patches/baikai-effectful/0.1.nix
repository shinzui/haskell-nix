# baikai-effectful 0.3.0.1 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "baikai-effectful";
  ver = "0.3.0.1";
  sha256 = "sha256-ug/b9xQDt/GL6XUB8DqJiVqjfqVv4hhNEcsTzUxHXVY=";
} {}))
