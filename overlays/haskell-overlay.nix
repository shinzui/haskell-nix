# Default Haskell overlay — wires the registry to mkHaskellOverlay.
#
# This is what `overlays.default` points to in the flake.
{ lib }:

let
  mkHaskellOverlay = import ../lib/mkHaskellOverlay.nix { inherit lib; };
  registry = import ./registry.nix;
in
mkHaskellOverlay { inherit registry; }
