# Compose a retained runtime with an explicit application complement in one scope.
{ lib, root ? ../. }:
{ runtime
, generation
, applicationSelections
, channel ? "github"
, disableProfiling ? true
, disableHaddock ? true
, applicationCohort ? null
, applicationRegistry ? { }
, captureCompatibility ? false
}:
let
  read = path: builtins.fromJSON (builtins.readFile (root + "/${path}"));
  liveLock = read "packages/first-party-lock.json";
  lock = import ./validateRuntimePackageSetLock.nix { inherit lib; } {
    config = read "config/runtime-package-sets.json";
    lock = read "packages/runtime-lock.json";
    firstPartyLock = liveLock;
    inherit root;
  };
  matches = builtins.filter (record: record.generation == generation) (lock.runtimes.${runtime} or [ ]);
  record =
    if builtins.length matches == 1 then builtins.head matches
    else throw "mkRuntimePackageSet: unknown runtime generation ${runtime}#${toString generation}";
  recipes = builtins.path { path = root + "/${record.recipeDirectory}"; name = "keiro-runtime-recipes"; };
  retainedLock = builtins.fromJSON (builtins.readFile (recipes + "/packages/first-party-lock.json"));
  liveConfig = read "config/first-party-families.json";
  retainedConfig = builtins.fromJSON (builtins.readFile (recipes + "/config/first-party-families.json"));
  runtimeFamilies = map (reference: reference.family) retainedFamilies;
  config = liveConfig // {
    families = map
      (configured:
        if builtins.elem configured.name runtimeFamilies then
          builtins.head (builtins.filter (family: family.name == configured.name) retainedConfig.families)
        else configured)
      liveConfig.families;
  };
  catalog = import ./validateFirstPartyPackageSetLock.nix { inherit lib config; lock = liveLock; };
  groups = map (group: group.name) catalog.resolvedGroups;
  selections = (import ./composeRuntimeSelections.nix { inherit lib; }) {
    inherit groups applicationSelections;
    runtimeSelections = record.selections;
  };
  snapshot = source: group: builtins.filter (row: row.group == group && row.generation == record.selections.${group}) source.groupSnapshots;
  retainedFamilies = lib.concatMap (group: lib.concatMap (row: row.families) (snapshot retainedLock group)) (builtins.attrNames record.selections);
  family = source: reference: builtins.filter (row: row.family == reference.family && row.generation == reference.generation) source.familySnapshots;
  changedGroups = builtins.filter (group: snapshot liveLock group != snapshot retainedLock group) (builtins.attrNames record.selections);
  changedFamilies = builtins.filter (ref: family liveLock ref != family retainedLock ref) retainedFamilies;
  baseline = import (recipes + "/generated/cohort-versions.nix");
  owned = builtins.attrNames record.ownership;
  candidate = if applicationCohort == null then baseline else applicationCohort;
  fields = [ "packages" "sourceManifest" "flags" "policy" ];
  changedPackages = builtins.filter
    (name: builtins.any
      (field:
        (candidate.${field}.${name} or null) != (baseline.${field}.${name} or null))
      fields)
    owned;
  registryConflicts = lib.intersectLists owned (builtins.attrNames applicationRegistry);
  retainedLib = import ((builtins.fetchTree record.toolchainInputs.nixpkgs).outPath + "/lib");
  mk = file: import (recipes + "/lib/${file}") { lib = retainedLib; };
  factory = import (recipes + "/lib/mkFirstPartyPackageSet.nix") {
    lib = retainedLib;
    mkFirstPartyRegistries = mk "mkFirstPartyRegistries.nix";
    mkHaskellExtension = mk "mkHaskellExtension.nix";
    mkHaskellOverlay = mk "mkHaskellOverlay.nix";
  };
  profiles = import (recipes + "/overlays/compatibility-profiles.nix");
  recipeSelection = recipes + "/config/runtime-generated-recipes.json";
  generatedRecipes = if !(builtins.pathExists recipeSelection) then null else
  (import (recipes + "/lib/mkRuntimeGeneratedRecipes.nix") { lib = retainedLib; }) {
    recipeRoot = recipes;
    selection = builtins.fromJSON (builtins.readFile recipeSelection);
    inherit runtime record channel disableProfiling disableHaddock;
    history = lock.runtimes.${runtime};
  };
  generatedArguments = lib.optionalAttrs (builtins.pathExists recipeSelection) { inherit generatedRecipes; };
  retainedRegistry = import (recipes + "/overlays/registry.nix");
  captureSupported = builtins.pathExists (recipes + "/lib/capturedCompatibilityReport.nix");
  retainedPolicy =
    if !captureSupported then
      throw "mkRuntimePackageSet: retained generation predates compatibility capture"
    else (import (recipes + "/lib/mkCompatibilityPolicy.nix") { lib = retainedLib; }) retainedRegistry;
  applicationGroups = lib.subtractLists (builtins.attrNames record.selections) groups;
  # These new application-only dependencies were absent from captured cohorts.
  # Keep runtime-owned recipes immutable while giving new complements the live,
  # independently owned source selections they require in the same fixed point.
  liveRegistry = import ../overlays/registry.nix;
  applicationDependencyRegistry = lib.filterAttrs
    (name: _: !(builtins.elem name owned) && (
      (name == "hspec-api" && builtins.elem "heni" applicationGroups)
        || (name == "rdkafka-hs" && channel == "github" && builtins.elem "shoko" applicationGroups)
    ))
    liveRegistry;
  construction = import ./projectRetainedDiscoveryPolicy.nix { inherit config; lock = liveLock; };
  applicationSnapshots = lib.concatMap
    (group:
      builtins.filter (row: row.group == group && row.generation == selections.${group}) liveLock.groupSnapshots)
    applicationGroups;
  profileConflicts = lib.intersectLists owned (lib.concatMap
    (snapshot:
      builtins.attrNames profiles.${snapshot.compatibilityProfile})
    applicationSnapshots);
  reference = factory
    ({
      config = retainedConfig;
      lock = retainedLock;
      cohortVersions = baseline;
      commonRegistry = import (recipes + "/overlays/registry.nix");
      compatibilityProfiles = profiles;
      supportedGhcs = [ "ghc9124" ];
    } // generatedArguments)
    {
      packageSet = retainedLock.defaultPackageSet;
      inherit channel disableProfiling disableHaddock;
    };
  selected = factory
    ({
      inherit (construction) config lock;
      cohortVersions = candidate;
      commonRegistry = (if captureCompatibility then retainedPolicy.registry else retainedRegistry) // applicationDependencyRegistry // applicationRegistry;
      compatibilityProfiles = import (recipes + "/overlays/compatibility-profiles.nix");
      supportedGhcs = [ "ghc9124" ];
    } // generatedArguments)
    ({ inherit selections channel disableProfiling disableHaddock; }
      // lib.optionalAttrs captureCompatibility { captureCompatibility = true; });
  configuration = system: {
    inherit system channel disableProfiling disableHaddock;
    compiler = "ghc9124";
  };
  check = pkgs:
    if !(builtins.elem (configuration pkgs.stdenv.hostPlatform.system) record.configurations) then
      throw "mkRuntimePackageSet: unsupported configuration for ${runtime}#${toString generation}"
    else if let
      expected = import (builtins.fetchTree record.toolchainInputs.nixpkgs).outPath {
        system = pkgs.stdenv.hostPlatform.system;
      };
    in
    pkgs.haskell.packages.ghc9124.ghc.drvPath != expected.haskell.packages.ghc9124.ghc.drvPath
    || pkgs.stdenv.drvPath != expected.stdenv.drvPath then
      throw "mkRuntimePackageSet: nixpkgs does not match the retained runtime toolchain"
    else true;
  validation =
    if captureCompatibility && !captureSupported then
      throw "mkRuntimePackageSet: retained generation predates compatibility capture"
    else if changedGroups != [ ] || changedFamilies != [ ] then
      throw "mkRuntimePackageSet: retained runtime family history was rewritten"
    else if changedPackages != [ ] then throw "mkRuntimePackageSet: application changes runtime packages: ${lib.concatStringsSep ", " changedPackages}"
    else if profileConflicts != [ ] then throw "mkRuntimePackageSet: application compatibility policy changes runtime packages: ${lib.concatStringsSep ", " profileConflicts}"
    else if registryConflicts != [ ] then throw "mkRuntimePackageSet: application policy conflicts with runtime packages: ${lib.concatStringsSep ", " registryConflicts}"
    else if !(builtins.elem channel [ "github" "hackage" ]) || !disableProfiling || !disableHaddock then
      throw "mkRuntimePackageSet: unsupported runtime build configuration"
    else true;
in
builtins.seq validation (selected // rec {
  inherit selections;
  # Expose authoritative retained metadata even when an older constructor needed
  # a narrower discovery-policy shape internally.
  selectedFamilies = map
    (projected: builtins.head (builtins.filter
      (snapshot: snapshot.family == projected.family && snapshot.generation == projected.generation)
      liveLock.familySnapshots))
    selected.selectedFamilies;
  runtimeSelections = record.selections;
  metadata = record // { inherit runtime; };
  haskellExtension = haskellLib: pkgs: builtins.seq (check pkgs) (selected.haskellExtension haskellLib pkgs);
  overlay = final: prev: builtins.seq (check prev) (selected.overlay final prev);
  validateApplicationScope = pkgs: scope:
    let
      pinned = import (builtins.fetchTree record.toolchainInputs.nixpkgs).outPath {
        system = pkgs.stdenv.hostPlatform.system;
      };
      expected = pinned.haskell.packages.ghc9124.override {
        overrides = reference.haskellExtension pinned.haskell.lib.compose pinned;
      };
      conflicts = builtins.filter
        (name: !(builtins.hasAttr name scope)
          || scope.${name} == null
          || scope.${name}.drvPath != expected.${name}.drvPath)
        (builtins.filter (name: record.ownership.${name}.source != "Boot") owned);
    in
    builtins.seq (check pkgs) (if scope.ghc.drvPath != expected.ghc.drvPath then
      throw "mkRuntimePackageSet: application scope changes the runtime compiler"
    else if conflicts == [ ] then true
    else throw "mkRuntimePackageSet: application scope changes runtime packages: ${lib.concatStringsSep ", " conflicts}");
  mkApplicationScope = pkgs: applicationOverrides:
    let
      scope = pkgs.haskell.packages.ghc9124.override {
        overrides = lib.composeExtensions
          (haskellExtension pkgs.haskell.lib.compose pkgs)
          applicationOverrides;
      };
    in
    assert validateApplicationScope pkgs scope; scope;
  mkApplicationManifest = { pkgs, scope, root, localPackages ? [ root.pname ] }:
    assert validateApplicationScope pkgs scope;
    (import ./mkCohortManifest.nix { inherit lib; }) {
      inherit pkgs scope root localPackages;
      context = comparisonContext;
    };
  compatibilityReport = { pkgs, scope, names, requiredEvidence ? [ ] }:
    if !captureCompatibility then
      throw "mkRuntimePackageSet: enable captureCompatibility for a retained report"
    else assert validateApplicationScope pkgs scope;
    (import (recipes + "/lib/capturedCompatibilityReport.nix") {
      lib = retainedLib;
      policy = retainedPolicy;
    }) {
      inherit scope names channel requiredEvidence;
      packageSet = "${runtime}#${toString generation}";
      system = pkgs.stdenv.hostPlatform.system;
      runtimeConfiguration = {
        inherit runtime generation disableProfiling disableHaddock;
        inherit (record) fingerprint;
      };
    };
  comparisonContext = {
    versions = candidate;
    boot = import (recipes + "/generated/ghc-boot-packages.nix");
    configurationPolicy = builtins.fromJSON (builtins.readFile (recipes + "/cabal/cohort-nix-policy.json"));
    nixpkgsRevision = record.nixpkgsRevision;
    inherit channel;
    sourceContext = selected.sourceContext;
    runtime = { inherit runtime generation; fingerprint = record.fingerprint; };
  };
})
