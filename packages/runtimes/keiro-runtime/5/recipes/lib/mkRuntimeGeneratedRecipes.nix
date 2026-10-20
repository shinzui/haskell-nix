# Resolve a captured recipe selection after the target platform is known.
# Projection hashes and the retained factory remain the runtime lock's owners.
{ lib }:
{ recipeRoot
, selection
, runtime
, record
, history
, channel
, disableProfiling
, disableHaddock
, readJSON ? (path: builtins.fromJSON (builtins.readFile (recipeRoot + "/${path}")))
}:
pkgs:
let
  require = condition: message: if condition then true else throw "runtime generated recipes: ${message}";
  exact = fields: value: builtins.isAttrs value
    && builtins.attrNames value == builtins.sort builtins.lessThan fields;
  relative = path: builtins.isString path && path != "" && !(lib.hasPrefix "/" path)
    && builtins.all (part: !(builtins.elem part [ "" "." ".." ])) (lib.splitString "/" path);
  keys = [ "system" "compiler" "channel" "disableProfiling" "disableHaddock" ];
  definition = selection.runtimes.${runtime};
  rows = definition.configurations;
  configuration = row: builtins.listToAttrs (map (name: { inherit name; value = row.${name}; }) keys);
  configurations = map configuration rows;
  base = builtins.filter
    (prior: prior.fingerprint == definition.basePolicyFingerprint && prior.generation < record.generation)
    history;
  selectedConfiguration = {
    system = pkgs.stdenv.hostPlatform.system;
    compiler = "ghc9124";
    inherit channel disableProfiling disableHaddock;
  };
  matches = builtins.filter (row: configuration row == selectedConfiguration) rows;
  selected = builtins.head matches;
  projected = path: builtins.hasAttr "${record.recipeDirectory}/${path}" record.projections;
  context = readJSON selected.contextFile;
  manifestFile = "${selected.recipeDirectory}/manifest.json";
  validation =
    require
      (exact [ "schemaVersion" "runtimes" ] selection && selection.schemaVersion == 1
      && builtins.isAttrs selection.runtimes) "unsupported selection schema"
    && require (builtins.hasAttr runtime selection.runtimes) "missing runtime selection"
    && require (exact [ "basePolicyFingerprint" "configurations" ] definition) "invalid selection definition"
    && require (builtins.length base == 1) "base policy must identify one earlier retained generation"
    && require
      (builtins.isList rows && rows != [ ] && builtins.all
        (row: exact (keys ++ [ "contextFile" "recipeDirectory" ]) row
        && relative row.contextFile && relative row.recipeDirectory
        && projected row.contextFile && projected "${row.recipeDirectory}/manifest.json")
        rows) "invalid or uncaptured recipe selection"
    && require
      (lib.unique configurations == configurations
      && builtins.length configurations == builtins.length record.configurations
      && builtins.all (cfg: builtins.elem cfg record.configurations) configurations) "selection does not cover the retained configurations exactly"
    && require (builtins.length matches == 1) "unsupported selected configuration"
    && require (context.configuration.policyIdentity == definition.basePolicyFingerprint) "reviewed base policy identity mismatch"
    && require
      (context.configuration.compilerKey == selected.compiler
      && context.configuration.system == selected.system && context.configuration.channel == selected.channel
      && context.configuration.nixpkgsRevision == record.nixpkgsRevision) "captured context configuration mismatch";
in
builtins.seq validation {
  inherit context;
  manifest = readJSON manifestFile;
  recipes = recipeRoot + "/${selected.recipeDirectory}";
}
