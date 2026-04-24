# pgmq-core 0.2.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-core";
  ver = "0.2.0.0";
  sha256 = "sha256-bGKwcqWuN+Zlz8q5yBET/xjlPMJ/ZsqhRTdQULziSYo=";
} {}))
