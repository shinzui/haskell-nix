# shibuya-pgmq-adapter — extracted from the shibuya monorepo into its own repo
# (shinzui/shibuya-pgmq-adapter); the package lives under the shibuya-pgmq-adapter/
# subdir. cabal-version 3.14 is downgraded to 3.4 for the nixpkgs Cabal.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya-pgmq-adapter";
    rev = "d81ce94464ae1fe914ff9eec0e313e0e758f7525"; # v0.6.0.0
    hash = "sha256-1PT+59Obwrj+B2ZyFih4wwLBMBACZNzE7BZd3ZjWtEE=";
  };

  patched = pkgs.runCommand "shibuya-pgmq-adapter-patched" { } ''
    cp -r ${src}/shibuya-pgmq-adapter $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^cabal-version: *3\.14/cabal-version: 3.4/' $out/shibuya-pgmq-adapter.cabal
  '';
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-pgmq-adapter" patched {}))
