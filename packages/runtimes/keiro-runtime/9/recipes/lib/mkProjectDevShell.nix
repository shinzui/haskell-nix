# Retained runtime owns scope construction and validation. Tooling only consumes it.
{ lib, mkRuntimePackageSet, auditConsumerOverlay }:
{ runtimeSelection
, applicationSelections
, ownPackages
, pkgs
, toolchainLib
, applicationOverrides ? (_: _: { })
, applicationCohort ? null
, applicationRegistry ? { }
, withHls ? null
, extraNativeBuildInputs ? [ ]
, extraBuildInputs ? [ ]
, inputsFrom ? [ ]
, shellHook ? ""
}:
let
  require = condition: message: lib.assertMsg condition "mkProjectDevShell: ${message}";
  configuration = runtimeSelection.configuration;
  system = pkgs.stdenv.hostPlatform.system;
  runtime = mkRuntimePackageSet {
    runtime = runtimeSelection.name;
    inherit (runtimeSelection) generation channel;
    inherit applicationSelections applicationCohort applicationRegistry;
    inherit (configuration) disableProfiling disableHaddock;
  };
  declared = configuration // { inherit system; inherit (runtimeSelection) channel; };
  scope = runtime.mkApplicationScope pkgs applicationOverrides;
  audit = auditConsumerOverlay {
    inherit pkgs ownPackages;
    # Reuse the established audit and diagnostics while inspecting exactly the
    # checked scope. The audit's default live scope is not forced by this adapter.
    overlay = _: _: applicationOverrides scope scope;
    registry = runtime.registry;
    ghc = configuration.compiler;
    frozenPackages = builtins.attrNames runtime.comparisonContext.versions.sourceManifest;
    runtimePackages = builtins.attrNames runtime.metadata.ownership;
  };
  shell = toolchainLib.mkProjectShell {
    inherit pkgs withHls extraNativeBuildInputs extraBuildInputs inputsFrom shellHook;
    haskellPackages = scope;
    packages = selected: map (name: selected.${name}) ownPackages;
  };
  rawIdentity = {
    inherit runtimeSelection applicationSelections system;
    compiler = scope.ghc.drvPath;
    runtimeFingerprint = runtime.metadata.fingerprint;
    ownPackages = lib.genAttrs ownPackages (name: scope.${name}.drvPath);
    dependencies = lib.mapAttrs
      (name: ownership:
        if builtins.hasAttr name scope && scope.${name} != null then { derivation = scope.${name}.drvPath; }
        else { kind = "compiler-provided"; compiler = scope.ghc.drvPath; inherit ownership; })
      runtime.metadata.ownership;
  };
  # Diagnostics must not turn drvPath observations into output build requests.
  packageSetIdentity = builtins.fromJSON
    (builtins.unsafeDiscardStringContext (builtins.toJSON rawIdentity));
in
assert require
  (builtins.isAttrs runtimeSelection
    && builtins.attrNames runtimeSelection == [ "channel" "configuration" "generation" "name" ])
  "runtimeSelection requires exactly name, generation, configuration and channel";
assert require
  (builtins.isString runtimeSelection.name && runtimeSelection.name != ""
    && builtins.isInt runtimeSelection.generation && runtimeSelection.generation > 0
    && builtins.elem runtimeSelection.channel [ "github" "hackage" ]) "invalid explicit runtime selection";
assert require
  (builtins.isAttrs configuration
    && builtins.attrNames configuration == [ "compiler" "disableHaddock" "disableProfiling" ]
    && builtins.isString configuration.compiler
    && builtins.isBool configuration.disableHaddock && builtins.isBool configuration.disableProfiling)
  "configuration requires compiler, disableHaddock and disableProfiling";
assert require
  (builtins.isAttrs applicationSelections && builtins.isAttrs applicationRegistry
    && builtins.isFunction applicationOverrides) "invalid application selection or overlay";
assert require
  (builtins.isList ownPackages && ownPackages != [ ]
    && builtins.all (name: builtins.isString name && name != "") ownPackages
    && lib.unique ownPackages == ownPackages) "ownPackages must be a nonempty unique package-name list";
assert require
  (builtins.isAttrs toolchainLib && toolchainLib ? mkProjectShell
    && toolchainLib ? toolchainCapabilities) "the matching toolchain library must export the project-shell and capability APIs";
assert require (toolchainLib.toolchainCapabilities.system == system) "toolchain library has the wrong system";
assert require (builtins.elem declared runtime.metadata.configurations) "configuration is not retained by this runtime generation";
assert require ((toolchainLib.toolchainCapabilities.compilers.${configuration.compiler}.tools.compiler.drvPath or null) == scope.ghc.drvPath)
  "toolchain capability compiler differs from the retained runtime";
builtins.seq audit.drvPath (shell.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit packageSetIdentity;
    applicationScope = scope;
  };
}))
