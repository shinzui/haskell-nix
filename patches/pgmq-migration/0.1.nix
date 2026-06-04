# pgmq-migration 0.3.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-migration";
  ver = "0.3.0.0";
  sha256 = "sha256-JuWsNk+BFK4qmXC48BHBlpTA6NHBaXIJUMSlkDArnTQ=";
} {}))
