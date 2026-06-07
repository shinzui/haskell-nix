# shibuya-core — from shinzui/shibuya monorepo with cabal-version patch
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya";
    rev = "8ed1257a91f355fee44cc011e74a53a0a69db75e"; # v0.7.0.0
    hash = "sha256-wK/R/ALIPhKg3p0mzM1vPurZnlrke9czIn3LsrjeW9A=";
  };

  patched = pkgs.runCommand "shibuya-core-patched" { } ''
    cp -r ${src}/shibuya-core $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^cabal-version: *3\.14/cabal-version: 3.4/' $out/shibuya-core.cabal
  '';
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-core" patched {}))
