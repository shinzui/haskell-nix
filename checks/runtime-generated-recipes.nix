{ lib }:
let
  mk = import ../lib/mkRuntimeGeneratedRecipes.nix { inherit lib; };
  systems = [ "aarch64-darwin" "x86_64-linux" ];
  channels = [ "github" "hackage" ];
  configurations = lib.concatMap
    (system: map (channel: { inherit system channel; compiler = "ghc9124"; disableProfiling = true; disableHaddock = true; }) channels)
    systems;
  directory = cfg: "config/recipes/${cfg.system}/${cfg.channel}";
  rows = map (cfg: cfg // { contextFile = "${directory cfg}/inputs/context.json"; recipeDirectory = "${directory cfg}/recipes"; }) configurations;
  definition = { basePolicyFingerprint = "retained-base"; configurations = rows; };
  selection = { schemaVersion = 1; runtimes.fixture = definition; };
  recipeDirectory = "packages/runtimes/fixture/4/recipes";
  files = builtins.listToAttrs (lib.concatMap
    (row: [
      {
        name = row.contextFile;
        value.configuration = {
          compilerKey = "ghc9124"; inherit (row) system channel;
          policyIdentity = "retained-base";
          nixpkgsRevision = "pinned-nixpkgs";
        };
      }
      { name = "${row.recipeDirectory}/manifest.json"; value.selectedCell = "${row.system}/${row.channel}"; }
    ])
    rows);
  record = {
    generation = 4;
    nixpkgsRevision = "pinned-nixpkgs";
    inherit recipeDirectory configurations;
    projections = builtins.listToAttrs (map
      (path: { name = "${recipeDirectory}/${path}"; value = "projection-hash"; })
      (builtins.attrNames files));
  };
  defaults = {
    recipeRoot = ./fixtures/generated-recipes;
    inherit selection record;
    runtime = "fixture";
    history = [{ generation = 3; fingerprint = "retained-base"; }];
    channel = "github";
    disableProfiling = true;
    disableHaddock = true;
    readJSON = path: files.${path};
  };
  load = overrides: system: mk (defaults // overrides) { stdenv.hostPlatform = { inherit system; }; };
  reject = overrides: { expr = (builtins.tryEval (builtins.deepSeq (load overrides "aarch64-darwin") true)).success; expected = false; };
  changedRows = values: selection // { runtimes.fixture = definition // { configurations = values; }; };
  changedContext = changes: {
    readJSON = path: let value = files.${path}; in if value ? configuration then value // { configuration = value.configuration // changes; } else value;
  };
in
{
  testRuntimeRecipesSelectAllFourCapturedCells = {
    expr = lib.concatMap
      (system: map (channel: (load { inherit channel; } system).manifest.selectedCell) channels)
      systems;
    expected = [ "aarch64-darwin/github" "aarch64-darwin/hackage" "x86_64-linux/github" "x86_64-linux/hackage" ];
  };
  testRuntimeRecipesRejectUnknownSchema = reject { selection = selection // { schemaVersion = 2; }; };
  testRuntimeRecipesRejectMissingRuntime = reject { runtime = "unknown"; };
  testRuntimeRecipesRejectUnknownBase = reject { history = [ ]; };
  testRuntimeRecipesRejectSameGenerationBase = reject { history = [{ generation = 4; fingerprint = "retained-base"; }]; };
  testRuntimeRecipesRejectMissingCell = reject { selection = changedRows (builtins.tail rows); };
  testRuntimeRecipesRejectDuplicateCell = reject { selection = changedRows (rows ++ [ (builtins.head rows) ]); };
  testRuntimeRecipesRejectUncapturedContext = reject { record = record // { projections = { }; }; };
  testRuntimeRecipesRejectAbsolutePath = reject { selection = changedRows ([ ((builtins.head rows) // { contextFile = "/tmp/context.json"; }) ] ++ builtins.tail rows); };
  testRuntimeRecipesRejectParentPath = reject { selection = changedRows ([ ((builtins.head rows) // { recipeDirectory = "../recipes"; }) ] ++ builtins.tail rows); };
  testRuntimeRecipesRejectOtherPolicy = reject (changedContext { policyIdentity = "other"; });
  testRuntimeRecipesRejectOtherNixpkgs = reject (changedContext { nixpkgsRevision = "other"; });
  testRuntimeRecipesRejectOtherChannelContext = reject (changedContext { channel = "hackage"; });
  testRuntimeRecipesRejectOtherCompilerContext = reject (changedContext { compilerKey = "ghc9141"; });
  testRuntimeRecipesRejectProfilingChange = reject { disableProfiling = false; };
  testRuntimeRecipesRejectHaddockChange = reject { disableHaddock = false; };
  testRuntimeRecipesRejectUnsupportedSystem = {
    expr = (builtins.tryEval (builtins.deepSeq (load { } "aarch64-linux") true)).success;
    expected = false;
  };
}
