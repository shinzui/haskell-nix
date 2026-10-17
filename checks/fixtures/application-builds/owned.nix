# Exercise the producing project's current recipe with explicit archived sources.
# Owners: mori://shinzui/rei and mori://shinzui/mori; source-file URIs pending.
{ source
, seedSource
, application
, applicationRevision
, revision ? builtins.substring 0 7 applicationRevision
, seedRevision ? revision
, validatedCheckpointFile ? null
, validatedCheckpoint ? if validatedCheckpointFile == null then null
  else builtins.fromJSON (builtins.readFile (builtins.toPath validatedCheckpointFile))
, component ? "cli"
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
    inherit pkgs revision seedRevision validatedCheckpoint;
    source = builtins.toPath source;
    seedSource = builtins.toPath seedSource;
    packageName = "${application}-${component}";
    enabled = policy == "incremental";
    trackedDataFile = name: component == "cli" && pkgs.lib.hasPrefix "help/" name && pkgs.lib.hasSuffix ".md" name;
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
  cleanScope = runtime.mkApplicationScope pkgs
    (import (builtins.toPath checkout + "/nix/haskell-overlay.nix") ({
      inherit pkgs;
      haskellLib = pkgs.haskell.lib.compose;
      sourceRoot = builtins.toPath source;
      gitRev = revision;
    } // pkgs.lib.optionalAttrs (application == "mori") {
      inherit (app.inputs) mori-schema-src;
    }));
  package = result.scope.${application + "-cli"};
  probeSource = pkgs.runCommand "${application}-core-behavior-source" { } ''
    mkdir "$out"
    cat > "$out/Main.hs" <<'HS'
    ${if application == "rei" then "import qualified Rei.Infrastructure.CategoryStream as Core" else "import qualified Mori.Automation.ConfigHash as Core"}
    main :: IO ()
    main = print (Core.${if application == "rei" then "parseEither" else "sha256HexOfLazy"} mempty)
    HS
    cat > "$out/core-probe.cabal" <<'CABAL'
    cabal-version: 2.4
    name: core-probe
    version: 1.0
    build-type: Simple
    executable core-probe
      main-is: Main.hs
      build-depends: base, ${application}-core
      default-language: Haskell2010
    CABAL
  '';
  probe = result.scope.callPackage
    ({ mkDerivation, base }: mkDerivation {
      pname = "core-probe";
      version = "1.0";
      src = probeSource;
      isLibrary = false;
      isExecutable = true;
      executableHaskellDepends = [ base result.scope.${application + "-core"} ];
      doCheck = false;
      doHaddock = false;
      license = pkgs.lib.licenses.bsd3;
    })
    { };
in
assert builtins.elem component [ "cli" "core" ];
assert builtins.elem application [ "rei" "mori" ];
assert builtins.elem policy [ "clean" "incremental" ];
assert checkout != "";
assert !result.compatibilityReport.accepted || result.checkpoint.drvPath == result.seed.drvPath;
assert component != "cli" || package.drvPath == result.package.drvPath;
{
  inherit package;
  checkpointDeclaration = {
    schemaVersion = 1;
    derivation = result.checkpoint.drvPath;
    compatibility = result.seedCompatibility;
  };
  inherit (result) seed compatibilityReport;
  clean = cleanScope.${application + "-cli"};
  inherit probe;
  identity = {
    root = package.drvPath;
    behaviorProbe = if component == "core" then probe.drvPath else null;
    inherit component;
    core = result.scope.${application + "-core"}.drvPath;
    compiler = result.scope.ghc.drvPath;
    inherit (result) compatibilityReport currentCompatibility seedCompatibility;
  };
}
