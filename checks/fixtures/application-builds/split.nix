# Disposable independently cached Cabal-package pilot owned by mori://shinzui/rei.
# No production application recipe, runtime ownership record or default changes.
{ source }:
let
  path = builtins.toPath source;
  config = builtins.fromJSON (builtins.readFile (path + "/.mp4-pilot.json"));
  original = import ./owned.nix ((builtins.removeAttrs config [ "packageSplit" "splitManifest" ]) // {
    source = if config.packageSplit then config.seedSource else source;
    policy = "clean";
    component = "cli";
  });
  checkout = builtins.getEnv "MP4_APPLICATION_CHECKOUT";
  app = builtins.getFlake "git+file://${checkout}?rev=${config.applicationRevision}";
  pkgs = import app.inputs.nixpkgs { system = config.system or "aarch64-darwin"; };
  hlib = pkgs.haskell.lib.compose;
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (path + "/nix/runtime-selection.json")));
  overlay = import (builtins.toPath checkout + "/nix/haskell-overlay.nix") {
    inherit pkgs;
    haskellLib = hlib;
    sourceRoot = path;
    gitRev = config.revision or (builtins.substring 0 7 config.applicationRevision);
  };
  scope = runtime.mkApplicationScope pkgs (pkgs.lib.composeExtensions overlay (final: _: {
    rei-cli-foundation = hlib.dontHaddock (hlib.disableLibraryProfiling
      (hlib.dontCheck (final.callCabal2nix "rei-cli-foundation"
        (builtins.path { path = path + "/rei-cli-foundation"; name = "rei-cli-foundation-source"; })
        { })));
  }));
  selected = if config.packageSplit then scope else runtime.mkApplicationScope pkgs overlay;
  package = if config.packageSplit then scope.rei-cli else original.clean;
  registrationCompiler = selected.ghcWithPackages (packages: [ packages.rei-cli ]);
in
assert config.application == "rei";
{
  inherit package registrationCompiler;
  identity = (builtins.removeAttrs original.identity [ "currentCompatibility" "seedCompatibility" ]) // {
    root = package.drvPath;
    experimentMode = "package-split";
    packageSplit = config.packageSplit;
    foundation = if config.packageSplit then scope.rei-cli-foundation.drvPath else null;
    splitManifest = config.splitManifest;
    registrationCompiler = registrationCompiler.drvPath;
    compatibilityReport = { enabled = false; accepted = false; reason = "clean separate-package boundary experiment; no seed"; };
  };
}
