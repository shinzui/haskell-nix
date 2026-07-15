# shikumi-cache 0.1.2.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "shikumi-cache";
  ver = "0.1.2.0";
  sha256 = "sha256-ut8xLUnZHiBUTElI9ciukCz4aPFbYJf3uxxzHnQQEsw=";
} {}))
