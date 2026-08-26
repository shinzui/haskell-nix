# crypto-token 0.2.0 — upstream Git tag pin.
# Hackage still exposes 0.1.2, which depends on `memory` and caps crypton < 1.1.
# Upstream 0.2.0 moves to `ram` and supports the crypton 1.1.x stack.
# mori://kazu-yamamoto/crypto-token (registry registration pending)
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callCabal2nix "crypto-token"
  (builtins.fetchTarball {
    url = "https://github.com/kazu-yamamoto/crypto-token/archive/9e535d9015015f58ceacae3c757bc7e52d499d15.tar.gz";
    sha256 = "sha256-rEbz14R0bBEAJRkhIQTjRahGs2aJKzefDQ/bElCpoao=";
  })
  { })
