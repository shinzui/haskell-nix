# Haskell overlay — wires a supplied registry to mkHaskellOverlay.
{ lib, registry, compilers ? null, extraOverrides ? (_: _: { }) }:

let
  mkHaskellOverlay = import ../lib/mkHaskellOverlay.nix { inherit lib; };
in
mkHaskellOverlay ({ inherit registry extraOverrides; }
  // lib.optionalAttrs (compilers != null) { inherit compilers; })
