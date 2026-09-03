{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
  {
    pkg = "claude";
    ver = "1.5.0";
    sha256 = "sha256-Jng3pCOl9d9XqXbHomBJNiXDMViKZYymj9AKTWwHhvY=";
  }
  { }))
