{ lib, pkgs, scope }:
let
  hl = pkgs.haskell.lib.compose;
  entryId = "fixture-compatibility-repair";
  construct = variant: { policyProfile, disabledEntryIds, providedServices }:
    let
      raw = scope.callCabal2nix "package-validation-fixture" (./fixtures/package-validation + "/${variant}") { };
      policy = (import ../lib/applyPackageBuildPolicy.nix) policyProfile hl raw;
      settings = hl.overrideCabal (_: { doHaddock = false; enableLibraryProfiling = false; }) policy;
    in
    if builtins.elem entryId disabledEntryIds then hl.disableCabalFlag "compatibility-repair" settings
    else hl.enableCabalFlag "compatibility-repair" settings;
  validate = variant: (import ../lib/mkPackageValidation.nix { inherit lib; }) {
    inherit pkgs entryId;
    mkRecipe = construct variant;
  };
  needed = validate "needs-repair";
  fixed = validate "fixed";
  manifest = package: (import ../lib/mkCohortManifest.nix { inherit lib; }) {
    inherit pkgs scope;
    root = package;
    context = { purpose = "explicit strict-validation fixture"; inherit entryId; };
  };
  manifests = {
    neededBaseline = manifest needed.baseline;
    fixedBaseline = manifest fixed.baseline;
    fixedCandidate = manifest fixed.candidate;
  };
  blocked = (import ../lib/mkPackageValidation.nix { inherit lib; }) {
    inherit pkgs entryId;
    mkRecipe = _: throw "missing service must block before recipe construction";
    requiredServices = [ "fixture-service" ];
  };
  check = pkgs.runCommand "package-validation-fixtures" { } ''
    test -e ${manifests.neededBaseline}
    test -e ${manifests.fixedBaseline}
    test -e ${manifests.fixedCandidate}
    test "$(${needed.baseline}/bin/validation-probe)" = 42
    test "$(${fixed.baseline}/bin/validation-probe)" = 42
    test "$(${fixed.candidate}/bin/validation-probe)" = 42
    mkdir "$out"
    cp ${pkgs.writeText "needed-validation-context.json" (builtins.toJSON needed.context)} "$out/needed.json"
    cp ${pkgs.writeText "fixed-validation-context.json" (builtins.toJSON fixed.context)} "$out/fixed.json"
    cp ${pkgs.writeText "blocked-validation-context.json" (builtins.toJSON blocked.context)} "$out/blocked.json"
  '';
in
{ inherit needed fixed blocked manifests check; }
