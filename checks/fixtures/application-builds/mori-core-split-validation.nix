# Explicit validation of the disposable mori://shinzui/mori package boundary.
# Production package policy and retained runtime definitions remain unchanged.
{ source, system ? "aarch64-darwin" }:
let
  path = builtins.toPath source;
  config = builtins.fromJSON (builtins.readFile (path + "/.mp4-pilot.json"));
  checkout = builtins.getEnv "MP4_APPLICATION_CHECKOUT";
  app = builtins.getFlake "git+file://${checkout}?rev=${config.applicationRevision}";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  hl = pkgs.haskell.lib.compose;
  runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (path + "/nix/runtime-selection.json")));
  scope = runtime.mkApplicationScope pkgs (import (path + "/nix/haskell-overlay.nix") {
    inherit pkgs;
    inherit (app.inputs) mori-schema-src;
    haskellLib = hl;
    sourceRoot = path;
    gitRev = config.revision;
  });
  checked = tools: package: hl.overrideCabal
    (args: {
      doCheck = true;
      jailbreak = false;
      testToolDepends = (args.testToolDepends or [ ]) ++ tools;
    })
    package;
  checkedApplication = package: hl.overrideCabal
    (args: {
      preCheck = (args.preCheck or "") + ''
        export HOME="$TMPDIR/owned-test-home"
        mkdir -p "$HOME"
        mkdir -p ../mori-core/test ../docs/api ../docs/diagrams
        if ! test -d ../mori-core/test/fixtures; then
          cp -R ${builtins.path { path = path + "/mori-core/test/fixtures"; name = "mori-suite-fixtures"; }} ../mori-core/test/fixtures
        fi
        cp ${builtins.path { path = path + "/docs/api/openapi.json"; name = "mori-suite-openapi.json"; }} ../docs/api/openapi.json
        cp ${builtins.path { path = path + "/docs/diagrams/domain-lifecycles.md"; name = "mori-suite-domain-lifecycles.md"; }} ../docs/diagrams/domain-lifecycles.md
      '';
    })
    (checked [ pkgs.postgresql_18 pkgs.git ] package);
  core = checkedApplication scope.mori-core;
  api = checkedApplication scope.mori-api;
  cli = checkedApplication scope.mori-cli;
  conformance = checked [ pkgs.z3 ] (hl.dontHaddock (hl.disableLibraryProfiling
    (scope.callCabal2nix "keiro-mori-conformance"
      (builtins.path {
        path = path + "/mori-core/src/keiro-dsl-conformance.workspace.mori";
        name = "mori-conformance-source";
      })
      { })));
  facts = package: (import ../../../lib/packageRecipeFacts.nix { lib = pkgs.lib; }) {
    haskellLib = hl;
    inherit package;
    includeTestDependencies = true;
  };
in
assert config.application == "mori" && config.packageSplit && config.apiUsesFoundation;
assert checkout != "";
{
  inherit core api cli conformance;
  package = scope.mori-cli;
  tool = scope.keiro-dsl;
  solver = pkgs.z3;
  context = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON {
    purpose = "Explicit complete owned-suite and scaffold validation; no production test-policy promotion";
    inherit system;
    compiler = scope.ghc.drvPath;
    production = pkgs.lib.genAttrs [ "mori-core" "mori-api" "mori-cli" ] (name: facts scope.${name});
    validation = { core = facts core; api = facts api; cli = facts cli; conformance = facts conformance; };
    requiredSuites = {
      core = [ "mori-core-test" "mori-core-diagrams" ];
      api = [ "mori-api-test" ];
      cli = [ "mori-cli-test" ];
      conformance = [ "conformance" ];
    };
    services = "The existing owned-suite harness starts and stops disposable PostgreSQL instances; no production database is used.";
    nativeTools = { postgresql = pkgs.postgresql_18.drvPath; z3 = pkgs.z3.drvPath; keiro = scope.keiro-dsl.drvPath; };
  }));
}
