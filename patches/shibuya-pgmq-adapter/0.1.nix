# shibuya-pgmq-adapter — extracted from the shibuya monorepo into its own repo
# (shinzui/shibuya-pgmq-adapter); the package lives under the shibuya-pgmq-adapter/
# subdir. cabal-version 3.14 is downgraded to 3.4 for the nixpkgs Cabal.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya-pgmq-adapter";
    rev = "8e6f6e93e729bac129d7a9f2f8917f40fa4d6d9c"; # v0.7.0.0
    hash = "sha256-ar/28pQDT7k1If8V1lA0nXnGxddgm2k7XATY52YMBRw=";
  };

  patched = pkgs.runCommand "shibuya-pgmq-adapter-patched" { } ''
    cp -r ${src}/shibuya-pgmq-adapter $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^cabal-version: *3\.14/cabal-version: 3.4/' $out/shibuya-pgmq-adapter.cabal
  '';
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-pgmq-adapter" patched {}))
