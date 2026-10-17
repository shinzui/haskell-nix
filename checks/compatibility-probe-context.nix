{ lib }:
let
  package.drvPath = "selected-package.drv";
  validation = {
    baseline = package;
    candidate = package;
    context = { status = "unverified"; compiler = "selected-compiler.drv"; system = "fixture-system"; };
  };
  graph = {
    drvPath = "selected-graph-check.drv";
    declaration = {
      root.drvPath = package.drvPath;
      compiler.drvPath = validation.context.compiler;
      system = validation.context.system;
    };
  };
  arguments = {
    inherit validation;
    graphs = { baseline = graph; candidate = graph; };
    requiredSuites = [ "all-tests" ];
    behaviorProbes = { baseline.cli.drvPath = "baseline-behavior.drv"; candidate.cli.drvPath = "candidate-behavior.drv"; };
    channel = "github";
    policyIdentity = builtins.hashString "sha256" "strict-policy";
  };
  construct = changes: (import ../lib/mkCompatibilityProbeContext.nix { inherit lib; }) (arguments // changes);
  rejects = changes: { expr = !(builtins.tryEval (builtins.deepSeq (construct changes) true)).success; expected = true; };
in
{
  testNativeProbeExportsExplicitGraph = { expr = (construct { }).phases.candidate.graph.derivation; expected = graph.drvPath; };
  testNativeProbeRejectsBlockedConstruction = rejects { validation = validation // { context = validation.context // { status = "blocked"; }; }; };
  testNativeProbeRejectsEmptySuites = rejects { requiredSuites = [ ]; };
  testNativeProbeRejectsDuplicateSuites = rejects { requiredSuites = [ "suite" "suite" ]; };
  testNativeProbeRejectsInvalidChannel = rejects { channel = "other"; };
  testNativeProbeRejectsMissingPolicyIdentity = rejects { policyIdentity = ""; };
  testNativeProbeRejectsEmptyBehaviorChecks = rejects { behaviorProbes = arguments.behaviorProbes // { candidate = { }; }; };
  testNativeProbeRejectsWrongGraphRoot = rejects { graphs = arguments.graphs // { candidate = graph // { declaration = graph.declaration // { root.drvPath = "wrong-root.drv"; }; }; }; };
  testNativeProbeRejectsWrongGraphCompiler = rejects { graphs = arguments.graphs // { candidate = graph // { declaration = graph.declaration // { compiler.drvPath = "wrong-ghc.drv"; }; }; }; };
  testNativeProbeRejectsWrongGraphSystem = rejects { graphs = arguments.graphs // { candidate = graph // { declaration = graph.declaration // { system = "wrong-system"; }; }; }; };
}
