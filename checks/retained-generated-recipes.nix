{ lib, pkgs, updater, mkRuntimePackageSet, runtimePackageSets }:
let
  record = builtins.head (builtins.filter (entry: entry.generation == 4) runtimePackageSets.keiro-runtime);
  retained = builtins.path { path = ../. + "/${record.recipeDirectory}"; name = "retained-recipe-checks"; };
  selection = builtins.fromJSON (builtins.readFile (retained + "/config/runtime-generated-recipes.json"));
  rows = builtins.filter (row: row.system == pkgs.stdenv.hostPlatform.system)
    selection.runtimes.keiro-runtime.configurations;
  runtime = generation: channel: mkRuntimePackageSet {
    runtime = "keiro-runtime";
    inherit generation channel;
    inherit (record) applicationSelections;
  };
  scoped = channel: pkgs.haskell.packages.ghc9124.override {
    overrides = (runtime 4 channel).haskellExtension pkgs.haskell.lib.compose pkgs;
  };
  roots = map (row: (scoped row.channel).base64-bytestring.drvPath) rows;
  converter = pkgs.buildPackages.haskellPackages.cabal2nix-unstable.bin;
  comparison = row:
    let
      before = (runtime 3 row.channel).mkApplicationScope pkgs (_: _: { });
      after = (runtime 4 row.channel).mkApplicationScope pkgs (_: _: { });
      names = builtins.filter (name: record.ownership.${name}.source != "Boot") (builtins.attrNames record.ownership);
    in
    assert builtins.all (name: before.${name}.drvPath == after.${name}.drvPath) names;
    { inherit (row) channel; packagesCompared = builtins.length names; root = after.base64-bytestring.drvPath; };
in
{
  fresh = assert builtins.deepSeq roots true;
    pkgs.runCommand "generated-recipes-fresh"
      { nativeBuildInputs = [ updater pkgs.python3 converter ]; }
      (lib.concatStringsSep "\n"
        (map
          (row: ''
            haskell-nix-update cohort recipes commands --context ${retained + "/${row.contextFile}"} > commands-${row.channel}.json
            python3 ${../scripts/check-generated-recipe-freshness.py} \
              --commands commands-${row.channel}.json \
              --inputs ${builtins.dirOf (retained + "/${row.contextFile}")} \
              --recipes ${retained + "/${row.recipeDirectory}"} \
              --converter ${converter}/bin/cabal2nix
          '')
          rows) + ''
        touch "$out"
      '');
  noIfd = assert builtins.deepSeq roots true;
    pkgs.runCommand "retained-generated-recipes-no-ifd" { } ''
      echo '${builtins.toJSON roots}'
      touch "$out"
    '';
  parity =
    let results = map comparison rows;
    in assert builtins.deepSeq results true;
    pkgs.runCommand "retained-generated-recipes-parity" { } ''
      echo '${builtins.toJSON results}'
      touch "$out"
    '';
}
