# Exercise the producing project's current recipe with explicit archived sources.
# Owners: mori://shinzui/rei and mori://shinzui/mori; source-file URIs pending.
{ source
, seedSource
, application
, applicationRevision
, revision ? builtins.substring 0 7 applicationRevision
, seedRevision ? revision
, policy ? "incremental"
, system ? "aarch64-darwin"
}:
let
  checkout = builtins.getEnv "MP4_APPLICATION_CHECKOUT";
  app = builtins.getFlake "git+file://${checkout}?rev=${applicationRevision}";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (builtins.toPath source + "/nix/runtime-selection.json")));
  result = (import ../../../lib/mkApplicationIncrementalPackage.nix { inherit (pkgs) lib; }) {
    inherit pkgs revision seedRevision;
    source = builtins.toPath source;
    seedSource = builtins.toPath seedSource;
    packageName = "${application}-cli";
    enabled = policy == "incremental";
    trackedDataFile = name: pkgs.lib.hasPrefix "help/" name && pkgs.lib.hasSuffix ".md" name;
    mkScope = runtime.mkApplicationScope pkgs;
    overlayFor = { source, revision }: import (builtins.toPath checkout + "/nix/haskell-overlay.nix") ({
      inherit pkgs;
      haskellLib = pkgs.haskell.lib.compose;
      sourceRoot = source;
      gitRev = revision;
    } // pkgs.lib.optionalAttrs (application == "mori") {
      inherit (app.inputs) mori-schema-src;
    });
  };
in
assert builtins.elem application [ "rei" "mori" ];
assert builtins.elem policy [ "clean" "incremental" ];
assert checkout != "";
assert !result.compatibilityReport.accepted || result.checkpoint.drvPath == result.seed.drvPath;
{
  inherit (result) package seed clean compatibilityReport;
  identity = {
    root = result.package.drvPath;
    core = result.scope.${application + "-core"}.drvPath;
    compiler = result.scope.ghc.drvPath;
    inherit (result) compatibilityReport currentCompatibility seedCompatibility;
  };
}
