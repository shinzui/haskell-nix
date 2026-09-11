# crypto-token 0.2.0 — nixpkgs ships 0.1.2, which depends on `memory` and caps
# crypton < 1.1. 0.2.0 moves to `ram` and supports the crypton 1.1.x stack.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "crypto-token";
  ver = "0.2.0";
  sha256 = "sha256-VkfRO42wTscwnaCj2wJ4CtfLVdsbCWxH73aANWEfgSY=";
} { })
