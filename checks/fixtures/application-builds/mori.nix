# MP4_MORI_CHECKOUT locates mori://shinzui/mori; source-file URIs pending.
{ source
, applicationRevision ? "364f9a27f9927d2449e6f1e5ad878020487bab50"
, revision ? builtins.substring 0 7 applicationRevision
, system ? "aarch64-darwin"
}:
let
  checkout = builtins.getEnv "MP4_MORI_CHECKOUT";
  app = builtins.getFlake "git+file://${checkout}?rev=${applicationRevision}";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  sourcePath = builtins.toPath source;
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (sourcePath + "/nix/runtime-selection.json")));
  scope = runtime.mkApplicationScope pkgs (import (sourcePath + "/nix/haskell-overlay.nix") {
    inherit pkgs;
    inherit (app.inputs) mori-schema-src;
    haskellLib = pkgs.haskell.lib.compose;
    gitRev = revision;
  });
in
assert checkout != "";
{
  package = scope.mori-cli;
  core = scope.mori-core;
  identity = {
    root = scope.mori-cli.drvPath;
    core = scope.mori-core.drvPath;
    compiler = scope.ghc.drvPath;
  };
}
