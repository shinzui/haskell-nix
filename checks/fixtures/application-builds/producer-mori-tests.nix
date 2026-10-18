# Complete existing Mori suites with real services and declared tools.
# Owner: mori://shinzui/mori. No test selection or production database.
{ source, revision ? null, qualificationLabel ? null }:
let
  app = builtins.getFlake ("git+file://${source}"
    + (if revision == null then "" else "?rev=${revision}"));
  path = app.outPath;
  system = "aarch64-darwin";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  hlib = pkgs.haskell.lib.compose;
  selected = app.legacyPackages.${system}.haskellPackages;
  production = app.packages.${system}.default;
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
  checked = role: package: absoluteTestPath (hlib.overrideCabal
    (args: {
      doCheck = true;
      jailbreak = false;
      # The shared fixture's default PostgreSQL connection limit cannot host
      # concurrent tests with several independent projection-owner pools.
      testFlags = (args.testFlags or [ ]) ++ [ "--num-threads=1" ]
        ++ pkgs.lib.optionals (builtins.elem role [ "core" "api" "cli" ]) [ "+RTS" "-N4" "-RTS" ];
      testToolDepends = (args.testToolDepends or [ ]) ++ [ pkgs.postgresql_18 pkgs.git ];
      preCheck = (args.preCheck or "") + ''
        export HOME="$TMPDIR/mori-owned-test-home"
        export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        mkdir -p "$HOME" ../docs/api ../docs/diagrams ../mori-core/test
        if ! test -d ../mori-core/test/fixtures; then
          cp -R ${builtins.path { path = path + "/mori-core/test/fixtures"; name = "mori-owned-suite-fixtures"; }} ../mori-core/test/fixtures
        fi
        cp ${builtins.path { path = path + "/docs/api/openapi.json"; name = "mori-owned-suite-openapi.json"; }} ../docs/api/openapi.json
        cp ${builtins.path { path = path + "/docs/diagrams/domain-lifecycles.md"; name = "mori-owned-suite-domain-lifecycles.md"; }} ../docs/diagrams/domain-lifecycles.md
      '';

    })
    package);
in
{
  # Export the compiled complete core suites for execution from the real
  # disposable repository, where the owned nix-develop integration can run.
  # This derivation is a runner build; its success is not test acceptance.
  coreRunner = hlib.overrideCabal
    (args: {
      checkPhase = "echo 'Complete core-suite runners exported; execute externally for acceptance.'";
      postInstall = (args.postInstall or "") + ''
        cp dist/build/mori-core-test/mori-core-test "$out/bin/mori-core-test"
        cp dist/build/mori-core-diagrams/mori-core-diagrams "$out/bin/mori-core-diagrams"
      '';
    })
    (checked "core" selected.mori-core);
  api = checked "api" selected.mori-api;
  cli = checked "cli" production;
  sdk = checked "cli" selected.mori-cli;
  types = checked "types" selected.mori-types;
}
