{ lib, pkgs, updater, manifest, record }:
let
  recipes = ../. + "/${record.recipeDirectory}";
  contributors = pkgs.writeText "runtime-proof-contributors.json" (builtins.toJSON [{
    name = "runtime-proof";
    mori = "mori://shinzui/haskell-nix";
    revision = record.fingerprint;
    role = "application";
    ownPackages = [ "runtime-proof" ];
    excludedDependencies = [ ];
    cabalFiles = [ "runtime-proof.cabal" ];
    indexStateOverride = null;
    deployedAttr = "keiro-runtime-proof";
    configurations = [{ name = "default"; flags = { }; }];
  }]);
in
pkgs.runCommand "retained-runtime-frozen-parity"
{
  nativeBuildInputs = [ updater pkgs.python3 ];
} ''
  haskell-nix-update cohort comparison-context \
    --freeze ${recipes}/cabal/cohort.freeze \
    --sources ${recipes}/cabal/cohort-sources.json \
    --contributors ${contributors} > context.json
  set -o pipefail
  python3 ${../scripts/cohort-manifest.py} --compare-freeze context.json ${manifest} \
    --nix-policy ${recipes}/cabal/cohort-nix-policy.json | tee "$out"
''
