# codd - official mzabani/codd (codd 0.1.8, hasql-1.10 compatible).
#
# Required by kiroku-store-migrations (`codd >=0.1.8 && <0.2`); codd is not in
# the nixpkgs haskell package set, so provide it from upstream. Pinned to
# master, which is the revision the local mori corpus mirrors.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "mzabani";
    repo = "codd";
    rev = "c32d365b56a7da482647410e68ed763e73fe4442";
    hash = "sha256-F1Jx+GhzlJmEhJE41K/WHYW+7FZ4a/e2XHwafaJ2GqA=";
  };
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "codd" src { }))
