# crypton-x509-validation 1.9.0 — Hackage pin (paired with crypton-x509 1.9.0).
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "crypton-x509-validation";
  ver = "1.9.0";
  sha256 = "07xmh65ml9r51ijz0sv6rk3s46flmmafcka5ik63pqxhn2za20w0";
} {})
