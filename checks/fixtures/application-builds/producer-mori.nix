# Measure the ordinary producer output, including its real package ownership.
# Owner: mori://shinzui/mori. The optional split manifest is validation evidence,
# outside the producer sources; it never enters the application derivation.
{ source }:
let
  app = builtins.getFlake "git+file://${source}";
  system = "aarch64-darwin";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (builtins.toPath source + "/nix/runtime-selection.json")));
  scope = app.legacyPackages.${system}.haskellPackages;
  packages = app.packages.${system};
  package = packages.default;
  experiment = builtins.getEnv "MP4_APPLICATION_BUILD_EXPERIMENT";
  executable = pkgs.haskell.lib.compose.overrideCabal
    (_: {
      enableSharedLibraries = false;
      enableStaticLibraries = false;
    })
    scope.mori-cli;
in
assert package.pname == "mori-cli";
assert builtins.elem experiment [ "" "executable" ];
assert package.drvPath == scope.mori-cli.drvPath
  || (experiment == "executable" && package.drvPath == executable.drvPath);
{
  inherit package;
  identity = {
    root = package.drvPath;
    core = packages.mori-core.drvPath;
    compiler = package.compiler.drvPath;
    registrationCompiler = (scope.ghcWithPackages (_: [ package ])).drvPath;
    component = "cli";
    experimentMode = if experiment == "" then "package-split" else experiment;
    packageSplit = packages ? mori-cli-foundation;
    foundation = if packages ? mori-cli-foundation then packages.mori-cli-foundation.drvPath else null;
    splitManifest = builtins.getEnv "MP4_APPLICATION_SPLIT_MANIFEST";
    compatibilityReport = {
      enabled = false;
      accepted = false;
      reason = "Ordinary producer default; no intermediate checkpoint";
    };
  } // pkgs.lib.optionalAttrs (experiment == "executable") {
    libraryReference = scope.mori-cli.drvPath;
    executableReference = executable.drvPath;
    sdkRegistrationCompiler = (scope.ghcWithPackages (packages: [ packages.mori-cli ])).drvPath;
  };
}
