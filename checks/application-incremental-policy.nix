{ lib }:
let
  make = import ../lib/mkApplicationIncrementalBuild.nix { inherit lib; };
  record = {
    schemaVersion = 1;
    packageName = "application";
    packageVersion = "1";
    compilerIdentity = "compiler";
    recipeIdentity = "recipe";
    metadataIdentity = "metadata";
    sourceLayoutIdentity = "layout";
    generatedInputPolicy = "none";
  };
  package = {
    pname = "application";
    version = "1";
    compiler.drvPath = "compiler";
    identity = "ordinary-clean";
  };
  # Model only the builder attributes inspected here; native fixture checks
  # independently exercise the actual Nixpkgs builder and stale-input rejection.
  pkgs.haskell.lib.compose.overrideCabal = update: previous:
    previous // update previous // { intermediates = "clean-seed-intermediates"; };
  run = extra: make ({
    inherit pkgs package;
    seedPackage = package // { previousIntermediates = "old-chain"; };
    currentCompatibility = record;
    seedCompatibility = record;
  } // extra);
  rejected = extra:
    let result = run extra;
    in result.package == package && result.seed == null && !result.compatibilityReport.accepted;
in
{
  testApplicationIncrementalAcceptsMatchingInputs = {
    expr = (run { }).package.previousIntermediates;
    expected = "clean-seed-intermediates";
  };
  testApplicationIncrementalSeedHasNoPredecessor = {
    expr = (run { }).seed.previousIntermediates;
    expected = null;
  };
  testApplicationIncrementalDisabledDoesNotForceSeed = {
    expr = (run {
      enabled = false;
      seedPackage = throw "disabled seed evaluated";
      seedCompatibility = throw "disabled record evaluated";
    }).package;
    expected = package;
  };
  testApplicationIncrementalRejectsForgedCompilerRecord = {
    expr = rejected {
      currentCompatibility = record // { compilerIdentity = "other-compiler"; };
      seedCompatibility = record // { compilerIdentity = "other-compiler"; };
    };
    expected = true;
  };
  testApplicationIncrementalIncompatibleDoesNotForceSeed = {
    expr = rejected {
      seedPackage = throw "incompatible seed evaluated";
      seedCompatibility = record // { recipeIdentity = "another configuration"; };
    };
    expected = true;
  };
  testApplicationIncrementalRejectsMissingActualCompiler = {
    expr = rejected { seedPackage = builtins.removeAttrs package [ "compiler" ]; };
    expected = true;
  };
  testApplicationIncrementalRejectsMalformedRecord = {
    expr = rejected { currentCompatibility = builtins.removeAttrs record [ "recipeIdentity" ]; };
    expected = true;
  };
  testApplicationIncrementalRejectsUnknownMetadata = {
    expr = rejected { currentCompatibility = record // { reportTimestamp = "now"; }; };
    expected = true;
  };
} // lib.genAttrs
  (map (field: "testApplicationIncrementalRejects-${field}") [
    "packageName"
    "packageVersion"
    "compilerIdentity"
    "recipeIdentity"
    "metadataIdentity"
    "sourceLayoutIdentity"
    "generatedInputPolicy"
  ])
  (name:
    let field = lib.removePrefix "testApplicationIncrementalRejects-" name;
    in {
      expr = rejected { currentCompatibility = record // { ${field} = "changed"; }; };
      expected = true;
    })
