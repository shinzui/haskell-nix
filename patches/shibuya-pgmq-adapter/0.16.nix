# shibuya-pgmq-adapter 0.16.0.0 — pin from Hackage.
#
# Keiro 0.17 requires the adapter's HeadPerGroup consumer mode and the PGMQ
# 0.6 family. Cabal bounds do not select versions under Nix, so the shared
# channel must select the matching adapter explicitly.
{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
{
  pkg = "shibuya-pgmq-adapter";
  ver = "0.16.0.0";
  sha256 = "sha256-KLG/pXSgGycic339TsjC/tn1m0iPM5i78bNDgnUFXmE=";
}
{ }))
