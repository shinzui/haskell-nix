# hasql-migration — shinzui fork tip (GHC 9.12 compat + crypton 1.x / ram
# in place of memory). Bumped past ab66f6a to pick up the memory → ram swap.
{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "hasql-migration"
  (pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "hasql-migration";
    rev = "4aaff6c0919d1fe8e1c248c3ce4ce05775c59c8c";
    hash = "sha256-yMAFb9WEMTaqbKD17fz/Oi9Unw4sRlrUHBnv+iXK2o4=";
  })
  {}))
