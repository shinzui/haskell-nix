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
  absoluteTestPath = package:
    let
      parts = pkgs.lib.splitString "--test-wrapper=" package.checkPhase;
      originalWrapper = builtins.head (pkgs.lib.splitString "\"" (builtins.elemAt parts 1));
      wrapper = pkgs.writeShellScript "rei-owned-test-path" ''
        set -eu
        IFS=: read -r -a entries <<< "$PATH"
        absolute=()
        for entry in "''${entries[@]}"; do
          case "$entry" in
            /*) absolute+=("$entry") ;;
            *) absolute+=("$PWD/''${entry:-.}") ;;
          esac
        done
        PATH=$(IFS=:; printf '%s' "''${absolute[*]}")
        export PATH
        exec ${originalWrapper} "$@"
      '';
    in
    assert builtins.length parts == 2
      && pkgs.lib.hasSuffix "haskell-generic-builder-test-wrapper.sh" originalWrapper;
    hlib.overrideCabal
      (_: {
        # Preserve Setup's complete suite invocation and the pinned Nixpkgs
        # package-environment wrapper, normalizing only test executable lookup.
        checkPhase = pkgs.lib.replaceStrings
          [ "--test-wrapper=${originalWrapper}" ]
          [ "--test-wrapper=${wrapper}" ]
          package.checkPhase;
      })
      package;
  apiForTests = pkgs.writeShellScript "rei-api-owned-validation" ''
    export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    exec ${selected.rei-api}/bin/rei-api "$@"
  '';
  checked = role: package: absoluteTestPath (hlib.overrideCabal
    (args: {
      doCheck = true;
      jailbreak = false;
      # The shared fixture's default PostgreSQL connection limit cannot host
      # concurrent tests with several independent projection-owner pools.
      testFlags = (args.testFlags or [ ]) ++ [ "--num-threads=1" ]
        ++ pkgs.lib.optionals (role != "contract") [ "+RTS" "-N4" "-RTS" ];
      testToolDepends = (args.testToolDepends or [ ])
        ++ pkgs.lib.optionals (builtins.elem role [ "core" "api" "cli" ]) [
        pkgs.postgresql_18
        pkgs.git
      ] ++ pkgs.lib.optional (builtins.elem role [ "api" "cli" ]) selected.rei-cli
        ++ pkgs.lib.optional (role == "api") pkgs.hurl
        ++ pkgs.lib.optional (role == "core") pkgs.z3;
      preCheck = (args.preCheck or "") + ''
        export HOME="$TMPDIR/rei-owned-test-home"
        export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        mkdir -p "$HOME"
      '' + pkgs.lib.optionalString (role == "core") ''
        # Recreate the real repository paths used by the unmodified diagram
        # and migration tests around this isolated package source.
        ln -s "$PWD" ../rei-core
        cp ${builtins.path { path = path + "/cabal.project"; name = "rei-owned-suite-project"; }} ../cabal.project
        mkdir -p ../docs/dev/architecture
        cp ${builtins.path {
          path = path + "/docs/dev/architecture/transducer-diagrams.md";
          name = "rei-owned-suite-transducer-diagrams.md";
        }} ../docs/dev/architecture/transducer-diagrams.md
      '' + pkgs.lib.optionalString (role == "api") ''
        export REI_API_BIN=${apiForTests}
        mkdir -p ../docs/api
        cp ${builtins.path {
          path = path + "/docs/api/openapi.json";
          name = "rei-owned-suite-openapi.json";
        }} ../docs/api/openapi.json
      '';
    })
    package);
in
assert config.application == "rei";
{
  inherit package registrationCompiler;
  # Explicit complete suites, independent of the production test waiver. The
  # existing harnesses own disposable PostgreSQL and loopback HTTP services.
  validation = {
    core = checked "core" selected.rei-core;
    api = checked "api" selected.rei-api;
    cli = checked "cli" selected.rei-cli;
    contract = checked "contract" selected.rei-api-contract;
    client = checked "client" selected.rei-api-client;
  };
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
