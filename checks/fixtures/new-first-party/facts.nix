{ root, system }:
let
  f = builtins.getFlake root;
  lib = f.inputs.nixpkgs.lib;
  names = [ "heni" "hinagata" "shoko" "typesafe-hs" ];
  cells = map
    (cell:
      let
        selected = f.lib.mkFirstPartyPackageSet { packageSet = "default"; inherit (cell) channel; };
        packages = lib.concatMap
          (family: builtins.filter
            (package: cell.channel == "github" || package.hackage != null)
            family.packages)
          (builtins.filter (family: builtins.elem family.family names) selected.selectedFamilies);
        expected = lib.listToAttrs (map
          (package: lib.nameValuePair package.name
            (if cell.channel == "github" then package.version else package.hackage.version))
          packages);
        actual = lib.mapAttrs (name: _: cell.result.scope.${name}.version) expected;
      in
      {
        inherit (cell) channel ghc;
        compiler = cell.result.scope.ghc.version;
        check = cell.result.outPath;
        versions = actual;
        versionMismatches = builtins.filter (name: actual.${name} != expected.${name}) (builtins.attrNames expected);
        dependencies = lib.genAttrs [ "aeson" "crypton" "hspec-core" "hspec-api" "tasty" "QuickCheck" ] (name: cell.result.scope.${name}.version);
        shokoAbsentFromHackage = cell.channel != "hackage" || builtins.all
          (name: !(builtins.hasAttr name selected.registry)) [ "shoko-core" "shoko-adapters" "shoko-cli" ];
      })
    f.checks.${system}.new-first-party-support.cells;
in
{
  inherit system cells;
  curatedMatrix = f.checks.${system}.package-set-default.results;
}
