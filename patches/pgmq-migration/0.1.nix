# pgmq-migration 0.2.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-migration";
  ver = "0.2.0.0";
  sha256 = "sha256-lZtJHtJWGyDj6ErCRvZRrS2tVcHcmO8KLJ75yeZC29I=";
} {}))
