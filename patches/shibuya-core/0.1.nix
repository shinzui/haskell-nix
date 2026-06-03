# shibuya-core — from shinzui/shibuya monorepo with cabal-version patch
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya";
    rev = "1b86540beae8c483a302cc121032504dce8a3601"; # v0.6.0.0
    hash = "sha256-tc89pY2BGMcTk0DiIYxVjtbMD5ftB62oeXnbCDEaeEE=";
  };

  patched = pkgs.runCommand "shibuya-core-patched" { } ''
    cp -r ${src}/shibuya-core $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^cabal-version: *3\.14/cabal-version: 3.4/' $out/shibuya-core.cabal
  '';
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-core" patched {}))
