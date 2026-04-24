# shibuya-pgmq-adapter — from shinzui/shibuya monorepo with cabal-version patch
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya";
    rev = "549776fc9b4055fabab206e53c054d0d7f7adbee";
    hash = "sha256-hXPMS5MsZ+dthHyNNDPuEc9c/ErhUlgHz1e9ZKRkVNs=";
  };

  patched = pkgs.runCommand "shibuya-pgmq-adapter-patched" { } ''
    cp -r ${src}/shibuya-pgmq-adapter $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^cabal-version: *3\.14/cabal-version: 3.4/' $out/shibuya-pgmq-adapter.cabal
  '';
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-pgmq-adapter" patched {}))
