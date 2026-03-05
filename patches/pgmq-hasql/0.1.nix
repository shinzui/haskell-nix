# pgmq-hasql 0.1.2.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-hasql";
  ver = "0.1.2.0";
  sha256 = "sha256-mt2OfLhvhrNuyY1hjm1xpLl6/sPhAZLGlkIRBovrbso=";
} {}))
