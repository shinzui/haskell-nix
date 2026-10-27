{ root, system, oldFamilies }:
let
  f = builtins.getFlake root;
  lib = f.inputs.nixpkgs.lib;
  pkgs = import f.inputs.nixpkgs { inherit system; };
  channels = [ "github" "hackage" ];
  firstParty = lib.genAttrs channels (channel: lib.genAttrs f.lib.supportedGhcs (ghc:
    let
      selected = f.lib.mkFirstPartyPackageSet { packageSet = "default"; inherit channel; };
      scope = (pkgs.extend selected.overlay).haskell.packages.${ghc};
      packages = lib.concatMap (snapshot: builtins.filter (package: channel == "github" || package.hackage != null) snapshot.packages)
        (builtins.filter (snapshot: builtins.elem snapshot.family oldFamilies) selected.selectedFamilies);
    in
    lib.listToAttrs (map (package: { name = package.name; value = scope.${package.name}.drvPath; }) packages)));
  runtimes = lib.listToAttrs (lib.concatMap
    (record: map
      (channel:
        let
          p = import (builtins.fetchTree record.toolchainInputs.nixpkgs).outPath { inherit system; };
          selections = lib.filterAttrs (group: _: !(builtins.hasAttr group record.selections)) f.lib.firstPartyPackageSets.default.selections;
          selected = f.lib.mkRuntimePackageSet { runtime = "keiro-runtime"; inherit (record) generation; inherit channel; applicationSelections = selections; };
          scope = selected.mkApplicationScope p (_: _: { });
          names = builtins.attrNames (lib.filterAttrs (_: value: value.source != "Boot") record.ownership);
        in
        {
          name = "${toString record.generation}-${channel}";
          value = lib.genAttrs names (name: if (scope.${name} or null) == null then null else scope.${name}.drvPath);
        })
      channels)
    f.lib.runtimePackageSets.keiro-runtime);
in
{ inherit firstParty runtimes; }
