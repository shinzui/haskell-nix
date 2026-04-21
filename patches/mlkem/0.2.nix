# mlkem 0.2.0.0 — Hackage pin (nixpkgs ghc9122 has 0.1.1.0).
# tls 2.3.1 requires mlkem >= 0.2.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "mlkem";
  ver = "0.2.0.0";
  sha256 = "17gg2dlljk0igh2192hvnjbkar1kshgzrqpqbnnxa76yig812784";
} {})
