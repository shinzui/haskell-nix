# postgresql-binary 0.15.0.1 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "postgresql-binary";
  ver = "0.15.0.1";
  sha256 = "sha256-q5t2OgiDxyt8WU+zHVxpyVhFF9PtDu2BlQRfuPpBkgk=";
} {}))
