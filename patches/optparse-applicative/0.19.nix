# optparse-applicative 0.19 — fetch from Hackage for GHC 9.12 compatibility
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "optparse-applicative"
  (builtins.fetchTarball {
    url = "https://hackage.haskell.org/package/optparse-applicative-0.19.0.0/optparse-applicative-0.19.0.0.tar.gz";
    sha256 = "sha256-dhqvRILfdbpYPMxC+WpAyO0KUfq2nLopGk1NdSN2SDM=";
  })
  { }))
