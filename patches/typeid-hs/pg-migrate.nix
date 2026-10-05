# Source pin: not on Hackage; the generated version layer does not own it.
{ hself, haskellLib, pkgs, ... }@args:
haskellLib.dontCheck (haskellLib.doJailbreak
  (hself.callCabal2nix "typeid-hs-pg-migrate" "${import ./source.nix args}/typeid-hs-pg-migrate" { }))
