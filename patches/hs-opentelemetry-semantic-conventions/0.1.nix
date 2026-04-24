# hs-opentelemetry-semantic-conventions 0.1.0.0 — pin from Hackage
# Not present in nixpkgs' ghc9122 set; pgmq-effectful 0.2+ depends on it.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "hs-opentelemetry-semantic-conventions";
  ver = "0.1.0.0";
  sha256 = "sha256-VMmuu2tGfEUvaDmqvEINYMWkg0+DzJpUiT5cYz/0ee8=";
} {}))
