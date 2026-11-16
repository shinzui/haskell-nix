# mori://shinzui/cmark-gfm-hs: same extension-registration fix as the Cabal cohort.
{ hself, haskellLib, pkgs, ... }:
haskellLib.dontCheck (hself.callCabal2nix "cmark-gfm"
  (pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "cmark-gfm-hs";
    rev = "a9014e8c4974d636e7c8f85cd97812905d217faf";
    hash = "sha256-NPzWjJQH/4IInSezr2nqI8sn0HtjBhqGP7oIP5FcPec=";
  })
{ })
