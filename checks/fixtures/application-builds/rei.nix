# Application source owns its recipes; retain its original dependency inputs.
# MP4_REI_CHECKOUT locates mori://shinzui/rei (source-file artifact URIs pending).
{ source
, applicationRevision ? "99b882ee6d9cdc77ee0e8dead8962736bd3c4d0a"
, revision ? builtins.substring 0 7 applicationRevision
, system ? "aarch64-darwin"
}:
let
  checkout = builtins.getEnv "MP4_REI_CHECKOUT";
  app = builtins.getFlake "git+file://${checkout}?rev=${applicationRevision}";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  sourcePath = builtins.toPath source;
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (sourcePath + "/nix/runtime-selection.json")));
  scope = runtime.mkApplicationScope pkgs (import (sourcePath + "/nix/haskell-overlay.nix") {
    inherit pkgs;
    haskellLib = pkgs.haskell.lib.compose;
    gitRev = revision;
  });
in
assert checkout != "";
{
  package = scope.rei-cli;
  core = scope.rei-core;
  identity = {
    root = scope.rei-cli.drvPath;
    core = scope.rei-core.drvPath;
    compiler = scope.ghc.drvPath;
  };
}
