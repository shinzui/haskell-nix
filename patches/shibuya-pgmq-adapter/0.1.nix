# shibuya-pgmq-adapter 0.8.0.0 — pin from Hackage.
{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
{
  pkg = "shibuya-pgmq-adapter";
  ver = "0.8.0.0";
  sha256 = "sha256-N/XWLXSuH1QCZgjvjaAzJ8f4LGpE1WcTh3dlftzLDIk=";
}
{ }))
