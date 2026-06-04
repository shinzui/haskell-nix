# pgmq-effectful 0.3.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-effectful";
  ver = "0.3.0.0";
  sha256 = "sha256-AMZPHLONvIZ6D/PVIN6hPYlpyB2ENrJX1u7Y/BpzUBk=";
} {}))
