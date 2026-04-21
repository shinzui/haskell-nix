# crypton-x509-store 1.9.0 — Hackage pin (paired with crypton-x509 1.9.0).
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "crypton-x509-store";
  ver = "1.9.0";
  sha256 = "0m0awxdc91lkjrzhdkrpm538hsv0546zr8b4v1wd71wq6c8041qr";
} {})
