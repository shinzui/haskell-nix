# pgmq-hasql 0.3.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-hasql";
  ver = "0.3.0.0";
  sha256 = "sha256-sijBGf4LOON4Tok7DXQtvXfxoKyM/CSeBTOb+w8/eCo=";
} {}))
