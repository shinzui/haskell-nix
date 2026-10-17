{ lib }:
let
  pkgs = { haskell.lib.compose = { }; stdenv.hostPlatform.system = "fixture-system"; };
  package = {
    version = "1.0";
    src = "selected-source";
    drvPath = "fixture-package.drv";
    compiler.drvPath = "selected-compiler.drv";
    doCheck = true;
    jailbreak = false;
    testHaskellDepends = [{ type = "derivation"; drvPath = "fixture-test-dependency.drv"; }];
  };
  construct = change: args:
    assert args.policyProfile == "strict-v1";
    package // lib.optionalAttrs (args.disabledEntryIds != [ ]) change;
  validate = args: (import ../lib/mkPackageValidation.nix { inherit lib; }) ({
    inherit pkgs; entryId = "fixture-entry";
    mkRecipe = construct { };
  } // args);
  rejects = change: { expr = !(builtins.tryEval (builtins.deepSeq (validate { mkRecipe = construct change; }) true)).success; expected = true; };
in
{
  testStrictValidationStagesUnverifiedRequests = {
    expr = (validate { }).context.status;
    expected = "unverified";
  };
  testStrictValidationCannotClaimCompleteGraph = {
    expr = (validate { }).context.graphStatus;
    expected = "unverified";
  };
  testStrictValidationInventoriesTestInputs = {
    expr = (validate { }).context.candidate.effective.dependencies.testHaskellDepends;
    expected = [{ derivation = "fixture-test-dependency.drv"; output = "out"; }];
  };
  testStrictValidationBlocksMissingServiceBeforeConstruction = {
    expr = (validate { requiredServices = [ "fixture-service" ]; mkRecipe = _: throw "must stay lazy"; }).context.status;
    expected = "blocked";
  };
  testStrictValidationServiceDeclarationIsNotPassedEvidence = {
    expr = (validate { requiredServices = [ "fixture-service" ]; providedServices.fixture-service.drvPath = "service-probe.drv"; }).context.status;
    expected = "unverified";
  };
  testStrictValidationRejectsSkippedTests = rejects { doCheck = false; };
  testStrictValidationRejectsRelaxedBounds = rejects { jailbreak = true; };
  testStrictValidationRejectsNoopCheckPhase = rejects { checkPhase = "true"; };
  testStrictValidationRejectsEmptyTestTargets = rejects { testTargets = [ ]; };
  testStrictValidationRejectsPartialTestTargets = rejects { testTargets = [ "only-one-suite" ]; };
  testStrictValidationRejectsFilteredTests = rejects { testFlags = [ "--test-options=skip-all" ]; };
  testStrictValidationRejectsChangedSource = rejects { src = "another-source"; };
  testStrictValidationRejectsChangedMetadata = rejects { revision = "1"; editedCabalFile = "another-metadata-hash"; };
  testStrictValidationRejectsChangedCompiler = rejects { compiler.drvPath = "another-compiler.drv"; };
  testStrictValidationRejectsWrongTestDependency = rejects { testHaskellDepends = [{ type = "derivation"; drvPath = "wrong-instance.drv"; }]; };
  testStrictValidationRejectsOmittedTestDependency = rejects { testHaskellDepends = [ ]; };
  testStrictValidationRejectsCorrectAndWrongInstancesTogether = rejects {
    testHaskellDepends = package.testHaskellDepends ++ [{ type = "derivation"; drvPath = "wrong-instance.drv"; }];
  };
  testStrictValidationRejectsChangedNativeDependency = rejects {
    extraLibraries = [{ type = "derivation"; drvPath = "unselected-native.drv"; }];
  };
}
