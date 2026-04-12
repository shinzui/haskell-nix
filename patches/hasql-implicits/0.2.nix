{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "hasql-implicits";
  ver = "0.2.0.2";
  sha256 = "sha256-XlaxnhdXChDgojn44kaoil+M8Debc4RHP5Gw/KpJ31s=";
} {}))
