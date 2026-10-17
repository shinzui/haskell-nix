# Bounded compiler-parallelism experiment; no intermediate checkpoint is used.
# The pinned builder caps NIX_BUILD_CORES with maxBuildCores before configuring
# GHC. Keep the Nix job/core allocation fixed while varying that package cap.
{ source }:
let
  config = builtins.fromJSON (builtins.readFile (builtins.toPath source + "/.mp4-pilot.json"));
  limit = config.maxBuildCores;
  application = import ./owned.nix ((builtins.removeAttrs config [ "maxBuildCores" ]) // {
    inherit source;
    policy = "clean";
    component = "cli";
  });
  checkout = builtins.getEnv "MP4_APPLICATION_CHECKOUT";
  app = builtins.getFlake "git+file://${checkout}?rev=${config.applicationRevision}";
  pkgs = import app.inputs.nixpkgs { system = config.system or "aarch64-darwin"; };
  package = pkgs.haskell.lib.compose.overrideCabal (_: { maxBuildCores = limit; }) application.clean;
in
assert builtins.elem limit [ 8 16 ];
{
  inherit package;
  identity = application.identity // {
    root = package.drvPath;
    behaviorProbe = null;
    component = "cli";
    experimentMode = "parallelism";
    maxBuildCores = limit;
    compatibilityReport = { enabled = false; accepted = false; reason = "clean bounded-parallelism comparison; no seed"; };
  };
}
