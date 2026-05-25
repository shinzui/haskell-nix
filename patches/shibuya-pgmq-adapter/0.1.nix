# shibuya-pgmq-adapter — extracted from the shibuya monorepo into its own repo
# (shinzui/shibuya-pgmq-adapter); the package lives under the shibuya-pgmq-adapter/
# subdir. cabal-version 3.14 is downgraded to 3.4 for the nixpkgs Cabal.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya-pgmq-adapter";
    rev = "6bec220f21fd073813af2992b3eef4170b236c68";
    hash = "sha256-ehPQzcvsfvuehW67ZZs3RDcfmqQUJzoSEWc1DF522a4=";
  };

  patched = pkgs.runCommand "shibuya-pgmq-adapter-patched" { } ''
    cp -r ${src}/shibuya-pgmq-adapter $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^cabal-version: *3\.14/cabal-version: 3.4/' $out/shibuya-pgmq-adapter.cabal
  '';
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-pgmq-adapter" patched {}))
