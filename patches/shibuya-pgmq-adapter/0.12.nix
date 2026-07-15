# shibuya-pgmq-adapter 0.12.0.0 — pin from Hackage.
{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
{
  pkg = "shibuya-pgmq-adapter";
  ver = "0.12.0.0";
  sha256 = "sha256-LkHn7uJSonCFRI3tE4CUY2JNoZ/1l3RVOUuR3ty+75c=";
}
{ }))
