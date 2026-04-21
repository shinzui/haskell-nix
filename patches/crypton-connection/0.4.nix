# crypton-connection 0.4.6 — Hackage pin (paired with tls 2.3.1).
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "crypton-connection";
  ver = "0.4.6";
  sha256 = "0q1h8npbka73nkgf7hp24w4yfd12bf91psvayrqi22js830cdrq7";
} {}))
