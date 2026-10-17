{ lib }:
let
  drv = name: { type = "derivation"; drvPath = "${name}.drv"; outPath = name; };
  compiler = drv "compiler";
  owned = (drv "app") // { pname = "app"; inherit compiler; };
  base = { ghc = compiler; keiki = drv "keiki"; };
  configuration = { compiler = "ghc9124"; disableHaddock = true; disableProfiling = true; };
  selection = { name = "retained"; generation = 2; channel = "github"; inherit configuration; };
  pkgs.stdenv.hostPlatform.system = "fixture-system";
  complement = { application-group = 3; };
  factory = args:
    assert args.runtime == "retained" && args.generation == 2 && args.channel == "github";
    assert args.applicationSelections == complement;
    assert args.applicationCohort == null && args.applicationRegistry == { };
    {
      metadata = {
        fingerprint = "retained-fingerprint";
        configurations = [ (configuration // { system = "fixture-system"; channel = "github"; }) ];
        ownership.keiki.source = "Github";
      };
      registry = { shared = null; };
      comparisonContext.versions.sourceManifest = { frozen = null; };
      mkApplicationScope = _: extension:
        let scope = base // extension base base; in
        assert scope.ghc.drvPath == compiler.drvPath && scope.keiki.drvPath == base.keiki.drvPath;
        scope;
    };
  report = import ../lib/consumerOverlayReport.nix { inherit lib; };
  audit = args:
    let
      result = report {
        channelPackages = builtins.attrNames args.registry;
        overlayPackages = builtins.attrNames (args.overlay null null);
        inherit (args) ownPackages frozenPackages runtimePackages;
      };
    in
    assert result.ok; drv "audit";
  shell = inputs:
    let
      result = (drv (builtins.hashString "sha256" (builtins.toJSON {
        inherit (inputs) shellHook;
        tools = map (input: input.drvPath) inputs.extraNativeBuildInputs;
      }))) // { receivedScope = inputs.haskellPackages; };
    in
    result // { overrideAttrs = modify: result // (modify { passthru = { }; }).passthru; };
  tools = {
    toolchainCapabilities = { system = "fixture-system"; compilers.ghc9124.tools.compiler.drvPath = compiler.drvPath; };
    mkProjectShell = shell;
  };
  arguments = {
    inherit pkgs;
    runtimeSelection = selection;
    applicationSelections = complement;
    ownPackages = [ "app" ];
    toolchainLib = tools;
    applicationOverrides = _: _: { app = owned; };
  };
  construct = changes: (import ../lib/mkProjectDevShell.nix {
    inherit lib;
    mkRuntimePackageSet = factory;
    auditConsumerOverlay = audit;
  }) (arguments // changes);
  rejects = changes: { expr = !(builtins.tryEval (builtins.deepSeq (construct changes) true)).success; expected = true; };
in
{
  testProjectShellUsesRuntimeScope = { expr = (construct { }).receivedScope.app.drvPath; expected = owned.drvPath; };
  testProjectShellExposesSameProductionScope = { expr = (construct { }).applicationScope.app.drvPath; expected = owned.drvPath; };
  testProjectShellBindsRuntimeFingerprint = { expr = (construct { }).packageSetIdentity.runtimeFingerprint; expected = "retained-fingerprint"; };
  testProjectShellCapturesActualDependency = { expr = (construct { }).packageSetIdentity.dependencies.keiki.derivation; expected = base.keiki.drvPath; };
  testProjectShellToolEditKeepsRuntimeIdentity = {
    expr = let a = construct { }; b = construct { extraNativeBuildInputs = [ (drv "extra") ]; }; in a.drvPath != b.drvPath && a.packageSetIdentity == b.packageSetIdentity;
    expected = true;
  };
  testProjectShellHookEditKeepsRuntimeIdentity = {
    expr = let a = construct { }; b = construct { shellHook = "echo changed"; }; in a.drvPath != b.drvPath && a.packageSetIdentity == b.packageSetIdentity;
    expected = true;
  };
  testProjectShellRejectsImplicitRuntime = rejects { runtimeSelection = builtins.removeAttrs selection [ "configuration" ]; };
  testProjectShellRejectsUnknownSelectionFields = rejects { runtimeSelection = selection // { default = true; }; };
  testProjectShellRejectsWrongConfiguration = rejects { runtimeSelection = selection // { configuration = configuration // { disableProfiling = false; }; }; };
  testProjectShellRejectsUnknownConfigurationFields = rejects { runtimeSelection = selection // { configuration = configuration // { extra = true; }; }; };
  testProjectShellRejectsMissingComplement = rejects { applicationSelections = { }; };
  testProjectShellRejectsWrongToolchainSystem = rejects { toolchainLib = tools // { toolchainCapabilities = tools.toolchainCapabilities // { system = "wrong"; }; }; };
  testProjectShellRejectsWrongToolchainCompiler = rejects { toolchainLib = tools // { toolchainCapabilities = tools.toolchainCapabilities // { compilers.ghc9124.tools.compiler.drvPath = "wrong.drv"; }; }; };
  testProjectShellRejectsMissingHelper = rejects { toolchainLib = builtins.removeAttrs tools [ "mkProjectShell" ]; };
  testProjectShellRejectsRuntimeOverride = rejects { applicationOverrides = _: _: { app = owned; keiki = drv "changed-runtime"; }; ownPackages = [ "app" "keiki" ]; };
  testProjectShellRejectsFrozenOverride = rejects { applicationOverrides = _: _: { app = owned; frozen = drv "changed-frozen"; }; ownPackages = [ "app" "frozen" ]; };
  testProjectShellRejectsChannelOverride = rejects { applicationOverrides = _: _: { app = owned; shared = drv "changed-shared"; }; ownPackages = [ "app" "shared" ]; };
  testProjectShellRejectsUndeclaredOverlay = rejects { applicationOverrides = _: _: { app = owned; unknown = drv "unknown"; }; };
  testProjectShellRejectsMissingOwnPackage = rejects { applicationOverrides = _: _: { }; };
  testProjectShellRejectsDuplicateOwnNames = rejects { ownPackages = [ "app" "app" ]; };
  testProjectShellRejectsEmptyOwnNames = rejects { ownPackages = [ ]; };
}
