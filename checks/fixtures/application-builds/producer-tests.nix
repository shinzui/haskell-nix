# Complete existing Rei suites with real services and declared tools.
# Owner: mori://shinzui/rei. No test selection or production database.
{ source, revision ? null, qualificationLabel ? null }:
let
  app = builtins.getFlake ("git+file://${source}"
    + (if revision == null then "" else "?rev=${revision}"));
  path = app.outPath;
  system = "aarch64-darwin";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  hlib = pkgs.haskell.lib.compose;
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (path + "/nix/runtime-selection.json")));
  selected = runtime.mkApplicationScope pkgs (app.lib.haskellExtension hlib pkgs);
  production = app.packages.${system}.default;
  toolsScript = builtins.readFile (path + "/scripts/with-api-test-tools.sh");
  hinagata = (builtins.getFlake "github:shinzui/hinagata/35485e70ba323eb8d41e85f70c993b3fb41274a4").packages.${system}.default;
  hurlWorkbenchSource = builtins.getFlake "github:shinzui/hurl-workbench/5f2cff25c2c974ea3b9e4f1af1e693b8c8b73343";
  hurlWorkbench = hurlWorkbenchSource.packages.${system}.default;
  absoluteTestPath = package:
    let
      parts = pkgs.lib.splitString "--test-wrapper=" package.checkPhase;
      originalWrapper = builtins.head (pkgs.lib.splitString "\"" (builtins.elemAt parts 1));
      wrapper = pkgs.writeShellScript "rei-owned-test-path" (
        pkgs.lib.optionalString (qualificationLabel != null)
          "export NATIVE_QUALIFICATION_LABEL=${pkgs.lib.escapeShellArg qualificationLabel}\n" + ''
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
        ''
      );
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
        ++ pkgs.lib.optionals (builtins.elem role [ "core" "api" "cli" ]) [ "+RTS" "-N4" "-RTS" ];
      testToolDepends = (args.testToolDepends or [ ])
        ++ pkgs.lib.optionals (builtins.elem role [ "core" "api" "cli" ]) [
        pkgs.postgresql_18
        pkgs.git
      ] ++ pkgs.lib.optional (builtins.elem role [ "api" "cli" ]) production
        ++ pkgs.lib.optional (role == "api") pkgs.hurl
        ++ pkgs.lib.optional (role == "core") pkgs.z3
        ++ pkgs.lib.optionals (role == "api") [ hinagata hurlWorkbench ];
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
        mkdir -p ../rei-core
        cp -R ${builtins.path { path = path + "/rei-core/migrations"; name = "rei-owned-suite-migrations"; }} ../rei-core/migrations
        substituteInPlace test/hurl/hurl-workbench.dhall \
          --replace-fail 'https://raw.githubusercontent.com/shinzui/hurl-workbench/5f2cff25c2c974ea3b9e4f1af1e693b8c8b73343/schema/package.dhall' '${hurlWorkbenchSource}/schema/package.dhall'
        mkdir -p ../docs/api
        cp ${builtins.path {
          path = path + "/docs/api/openapi.json";
          name = "rei-owned-suite-openapi.json";
        }} ../docs/api/openapi.json
      '';
    })
    package);
in
assert pkgs.lib.hasInfix "github:shinzui/hinagata/35485e70ba323eb8d41e85f70c993b3fb41274a4#default" toolsScript;
assert pkgs.lib.hasInfix "github:shinzui/hurl-workbench/5f2cff25c2c974ea3b9e4f1af1e693b8c8b73343#default" toolsScript;
{
  core = checked "core" selected.rei-core;
  api = checked "api" selected.rei-api;
  cli = checked "cli" production;
  sdk = checked "cli" selected.rei-cli;
  contract = checked "contract" selected.rei-api-contract;
  client = checked "client" selected.rei-api-client;
  keiro = selected.keiro-dsl;
}
