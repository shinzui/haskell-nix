# pgmq-effectful 0.2.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-effectful";
  ver = "0.2.0.0";
  sha256 = "sha256-KCGbPGzXv3ANe7R6ENlNCaZsJToyHBN2Ax9B52SPiwU=";
} {}))
