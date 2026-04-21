# crypton 1.1.2 — Hackage pin.
# nixpkgs' ghc9122 set still pins 1.0.5 (uses `memory`); 1.1.x switched to
# `ram`. Bumping to 1.1.2 keeps the TLS / x509 / hpke stack instance-coherent.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "crypton";
  ver = "1.1.2";
  sha256 = "0lydqmcil3h1bbjbn90qvl6ldz4ar9vks7wr9s7588pj70jljicn";
} {})
