# Haskell overlay — wires a supplied registry to mkHaskellOverlay.
{ lib, registry }:

let
  mkHaskellOverlay = import ../lib/mkHaskellOverlay.nix { inherit lib; };
in
mkHaskellOverlay { inherit registry; }
