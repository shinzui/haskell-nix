# pgmq-hasql 0.3.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-hasql";
  ver = "0.3.0.0";
  sha256 = "sha256-zEctngv+rmh75WxvGGYhgf2l04LUl3MQ+UEbBhifBrY=";
} {}))
