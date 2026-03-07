# shibuya-pgmq-adapter — from shinzui/shibuya monorepo with cabal-version patch
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya";
    rev = "100f086ba586e7e376c4ffc7699c0da0c252c9fe";
    hash = "sha256-VpyDFAzvZv20mysqCivMG1VeaVsLL/33NBsULsCY25s=";
  };

  patched = pkgs.runCommand "shibuya-pgmq-adapter-patched" { } ''
    cp -r ${src}/shibuya-pgmq-adapter $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^cabal-version: *3\.14/cabal-version: 3.4/' $out/shibuya-pgmq-adapter.cabal
  '';
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-pgmq-adapter" patched {}))
