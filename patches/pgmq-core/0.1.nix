# pgmq-core 0.3.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-core";
  ver = "0.3.0.0";
  sha256 = "sha256-rI22yBfCRbkx1xrN6jluYLlcBiDO7WHGiU64UNRmocI=";
} {}))
