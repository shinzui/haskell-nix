# tls 2.3.1 — Hackage pin.
# nixpkgs' 2.1.8 caps crypton < 1.1; 2.3.1 is the first release that works
# against the crypton 1.1.x stack.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "tls";
  ver = "2.3.1";
  sha256 = "1a7k5fjgh39hy73napwn331wcgfi8q4b3z14qvl7ix19pd2gi8zs";
} {}))
