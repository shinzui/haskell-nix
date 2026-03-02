# streamly-core 0.3 — fetch from Hackage for GHC 9.12 compatibility
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "streamly-core"
  (builtins.fetchTarball {
    url = "https://hackage.haskell.org/package/streamly-core-0.3.0/streamly-core-0.3.0.tar.gz";
    sha256 = "sha256-IOrPT45LfuzU1zs4YXAsrVXYAauIKUwElgB8O7ZMk6Q=";
  })
  { }))
