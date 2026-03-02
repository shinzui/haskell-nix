# streamly 0.11 — fetch from Hackage for GHC 9.12 compatibility
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "streamly"
  (builtins.fetchTarball {
    url = "https://hackage.haskell.org/package/streamly-0.11.0/streamly-0.11.0.tar.gz";
    sha256 = "sha256-JMZAwJHqmDxN/CCDFhfuv77xmAx1JVhvYFDxMKyQoGk=";
  })
  { }))
