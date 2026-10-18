# Measure the ordinary producer output, including its real package ownership.
# Owner: mori://shinzui/rei. The optional split manifest is validation evidence,
# outside the producer sources; it never enters the application derivation.
{ source }:
let
  app = builtins.getFlake "git+file://${source}";
  system = "aarch64-darwin";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (builtins.toPath source + "/nix/runtime-selection.json")));
  scope = runtime.mkApplicationScope pkgs
    (app.lib.haskellExtension pkgs.haskell.lib.compose pkgs);
  packages = app.packages.${system};
  package = packages.default;
in
assert package.pname == "rei-cli";
assert package.drvPath == scope.rei-cli.drvPath;
{
  inherit package;
  identity = {
    root = package.drvPath;
    core = packages.rei-core.drvPath;
    compiler = package.compiler.drvPath;
    registrationCompiler = (scope.ghcWithPackages (packages: [ packages.rei-cli ])).drvPath;
    component = "cli";
    experimentMode = "package-split";
    packageSplit = packages ? rei-cli-foundation;
    foundation = if packages ? rei-cli-foundation then packages.rei-cli-foundation.drvPath else null;
    splitManifest = builtins.getEnv "MP4_APPLICATION_SPLIT_MANIFEST";
    compatibilityReport = {
      enabled = false;
      accepted = false;
      reason = "Ordinary producer default; no intermediate checkpoint";
    };
  };
}
