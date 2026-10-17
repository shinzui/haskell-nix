# Disposable package boundary owned by mori://shinzui/mori; no checkpoint reuse.
{ source }:
let
  path = builtins.toPath source;
  config = builtins.fromJSON (builtins.readFile (path + "/.mp4-pilot.json"));
  checkout = builtins.getEnv "MP4_APPLICATION_CHECKOUT";
  app = builtins.getFlake "git+file://${checkout}?rev=${config.applicationRevision}";
  pkgs = import app.inputs.nixpkgs { system = config.system or "aarch64-darwin"; };
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (path + "/nix/runtime-selection.json")));
  # The disposable overlay only adds the reviewed owned foundation recipe.
  overlayRoot = if config.packageSplit then path else builtins.toPath checkout;
  scope = runtime.mkApplicationScope pkgs (import (overlayRoot + "/nix/haskell-overlay.nix") {
    inherit pkgs;
    inherit (app.inputs) mori-schema-src;
    haskellLib = pkgs.haskell.lib.compose;
    sourceRoot = path;
    gitRev = config.revision;
  });
  package = scope.mori-cli;
  registrationCompiler = scope.ghcWithPackages (packages: [ packages.mori-core ]);
  probeSource = pkgs.runCommand "mori-core-split-probe-source" { } ''
    mkdir "$out"
    cat > "$out/Main.hs" <<'HS'
    import qualified Mori.Automation.ConfigHash as Core
    main :: IO ()
    main = print (Core.sha256HexOfLazy mempty)
    HS
    cat > "$out/core-probe.cabal" <<'CABAL'
    cabal-version: 2.4
    name: core-probe
    version: 1.0
    build-type: Simple
    executable core-probe
      main-is: Main.hs
      build-depends: base, mori-core
      default-language: Haskell2010
    CABAL
  '';
  probe = scope.callPackage
    ({ mkDerivation, base }: mkDerivation {
      pname = "core-probe";
      version = "1.0";
      src = probeSource;
      isLibrary = false;
      isExecutable = true;
      executableHaskellDepends = [ base scope.mori-core ];
      doCheck = false;
      doHaddock = false;
      license = pkgs.lib.licenses.bsd3;
    })
    { };
in
assert config.application == "mori";
assert checkout != "";
assert !(config.apiUsesFoundation or false) || config.packageSplit;
{
  inherit package probe registrationCompiler;
  identity = {
    root = package.drvPath;
    compiler = scope.ghc.drvPath;
    core = scope.mori-core.drvPath;
    api = scope.mori-api.drvPath;
    component = "core";
    experimentMode = "package-split";
    packageSplit = config.packageSplit;
    apiUsesFoundation = config.apiUsesFoundation or false;
    foundation = if config.packageSplit then scope.mori-core-foundation.drvPath else null;
    splitManifest = config.splitManifest;
    registrationCompiler = registrationCompiler.drvPath;
    behaviorProbe = probe.drvPath;
    compatibilityReport = { enabled = false; accepted = false; reason = "clean core package boundary; no checkpoint"; };
  };
}
