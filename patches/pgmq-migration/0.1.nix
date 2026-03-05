# pgmq-migration 0.1.2.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-migration";
  ver = "0.1.2.0";
  sha256 = "sha256-A+M7XM+TYqVW7V+kMggCqm/mk6aFzirzh+x7PPZfHVM=";
} {}))
