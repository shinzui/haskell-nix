# okf-core 0.1.2.0 — shikumi-okf dependency not yet present in Nixpkgs.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "okf-core";
  ver = "0.1.2.0";
  sha256 = "sha256-p2LC8DDdqeLnlQn/n8jBL6tt6Iid+bPK15zBRwIOnJg=";
} { }))
