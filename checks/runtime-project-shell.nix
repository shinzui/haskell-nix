# Real retained runtime and public toolchain API, evaluated without changing pins.
{ pkgs, toolchainLib, mkProjectDevShell, mkRuntimePackageSet }:
let
  selection = {
    name = "keiro-runtime";
    generation = 2;
    channel = "github";
    configuration = { compiler = "ghc9124"; disableHaddock = true; disableProfiling = true; };
  };
  applicationSelections = {
    kioku = 8;
    okf = 5;
    openapi-hs = 1;
    relay-pagination = 3;
    servant-openapi-hs = 1;
    shikumi-baikai = 9;
  } // import ../lib/catalogApplicationComplements.nix;
  source = builtins.path { path = ./fixtures/runtime-app-a; name = "runtime-shell-app-source"; };
  applicationOverrides = final: _: { runtime-app-a = final.callCabal2nix "runtime-app-a" source { }; };
  arguments = {
    inherit pkgs toolchainLib applicationSelections applicationOverrides;
    runtimeSelection = selection;
    ownPackages = [ "runtime-app-a" ];
    withHls = false;
  };
  shell = mkProjectDevShell arguments;
  toolEdit = mkProjectDevShell (arguments // { extraNativeBuildInputs = [ pkgs.hello ]; });
  hookEdit = mkProjectDevShell (arguments // { shellHook = "echo runtime-shell-hook"; });
  inheritedEdit = mkProjectDevShell (arguments // { inputsFrom = [ (pkgs.mkShell { shellHook = "echo inherited-shell-hook"; }) ]; });
  prior = mkRuntimePackageSet {
    runtime = selection.name;
    inherit (selection) generation channel;
    inherit applicationSelections;
  };
  production = prior.mkApplicationScope pkgs applicationOverrides;
  reject = changes: !(builtins.tryEval (mkProjectDevShell (arguments // changes)).drvPath).success;
  directShell = toolchainLib.mkProjectShell {
    inherit pkgs;
    haskellPackages = shell.applicationScope;
    packages = selected: [ selected.runtime-app-a ];
    withHls = false;
  };
  rawIdentity = {
    system = pkgs.stdenv.hostPlatform.system;
    shell = shell.drvPath;
    toolEdit = toolEdit.drvPath;
    hookEdit = hookEdit.drvPath;
    inheritedEdit = inheritedEdit.drvPath;
    production = production.runtime-app-a.drvPath;
    suppliedProduction = shell.applicationScope.runtime-app-a.drvPath;
    compiler = shell.compilerIdentity;
    packageSetIdentity = shell.packageSetIdentity;
    diagnosticMetadataPreservesShell = shell.drvPath == directShell.drvPath;
    unchangedIdentities = builtins.all (other: other.packageSetIdentity == shell.packageSetIdentity)
      [ toolEdit hookEdit inheritedEdit ];
    negative = {
      missingComplement = reject { applicationSelections = { }; };
      wrongCompiler = reject { runtimeSelection = selection // { configuration = selection.configuration // { compiler = "ghc9141"; }; }; };
      runtimeOverride = reject {
        applicationOverrides = final: previous: (applicationOverrides final previous) // {
          keiki = pkgs.haskell.lib.compose.overrideCabal (_: { postPatch = "changed-runtime"; }) previous.keiki;
        };
      };
      wrongSystem = reject { toolchainLib = toolchainLib // { toolchainCapabilities = toolchainLib.toolchainCapabilities // { system = "wrong-system"; }; }; };
    };
  };
  identity = builtins.fromJSON
    (builtins.unsafeDiscardStringContext (builtins.toJSON rawIdentity));
  check = pkgs.runCommand "project-shell-identity" { } ''
    echo '${builtins.toJSON identity}'
    touch "$out"
  '';
in
assert identity.production == identity.suppliedProduction;
assert identity.unchangedIdentities;
assert identity.diagnosticMetadataPreservesShell;
assert builtins.all (other: other.drvPath != shell.drvPath) [ toolEdit hookEdit inheritedEdit ];
assert builtins.all (value: value) (builtins.attrValues identity.negative);
{ inherit shell identity check; }
