# hasql 1.10.2.4 — pin from Hackage (replaces --flag=new-api approach)
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "hasql";
  ver = "1.10.2.4";
  sha256 = "sha256-mUQETQuvWW+AenCprqD3IPyfdpMIFO2Dzke3wz/ae24=";
} {}))
