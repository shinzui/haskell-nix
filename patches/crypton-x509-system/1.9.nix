# crypton-x509-system 1.9.0 — Hackage pin (paired with crypton-x509 1.9.0).
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "crypton-x509-system";
  ver = "1.9.0";
  sha256 = "1yw0h3k3dxnb35ma5x7qb2hpxf1rvag8c2hjqx2qbidmjfzffykb";
} {})
