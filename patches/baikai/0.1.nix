# baikai 0.3.1.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "baikai";
  ver = "0.3.1.0";
  sha256 = "sha256-xcyjJt0+YwlXhxXclAayaJh6i7AFvDGTZRPOgUURXBc=";
} {}))
