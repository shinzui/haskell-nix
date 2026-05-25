# shibuya-core — from shinzui/shibuya monorepo with cabal-version patch
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya";
    rev = "f2441d45f52bdd57c8463f3771eedb1d79a01e8b";
    hash = "sha256-gB0AWaHFMqC9AQIMxrRkN76UeCbzVmzkebaUKE/vjLo=";
  };

  patched = pkgs.runCommand "shibuya-core-patched" { } ''
    cp -r ${src}/shibuya-core $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^cabal-version: *3\.14/cabal-version: 3.4/' $out/shibuya-core.cabal
  '';
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-core" patched {}))
