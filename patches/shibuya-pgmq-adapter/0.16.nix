# shibuya-pgmq-adapter 0.16.1.0 — pin from Hackage.
#
# mori://shinzui/keiro requires the adapter's HeadPerGroup consumer mode and
# coordinated acknowledgement reliability fixes for the 0.20 cohort. Cabal
# bounds do not select versions under Nix, so the shared channel selects the
# released adapter explicitly.
{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
{
  pkg = "shibuya-pgmq-adapter";
  ver = "0.16.1.0";
  sha256 = "sha256-8yXtZ/qufiD4QdO1BtrxTIJWYfT8WbxkIMDA9a2svfI=";
}
{ }))
