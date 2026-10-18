{ lib }:
let
  mk = import ../lib/mkGeneratedRecipeExtension.nix { inherit lib; };
  recipes = ./fixtures/generated-recipes/binding;
  tool = { drvPath = "converter.drv"; outPath = "converter-bin"; };
  compiler = { version = "9.12.4"; drvPath = "compiler.drv"; };
  pkgs = {
    stdenv.hostPlatform.system = "aarch64-darwin";
    buildPackages.haskellPackages.cabal2nix-unstable.bin = tool;
    haskell.packages.ghc9124.ghc = compiler;
    fetchzip = args: args;
    fetchFromGitHub = args: args // { outPath = "source"; };
    native.zlib = "native-zlib";
  };
  context = {
    schemaVersion = 2;
    generationContext.sources.recipe-pinned.version = "1.0";
    configuration = {
      system = "aarch64-darwin";
      channel = "github";
      compilerKey = "ghc9124";
      compilerVersion = compiler.version;
      nixpkgsRevision = "selected-nixpkgs";
      policyIdentity = "reviewed-policy";
      converter = { derivation = tool.drvPath; output = tool.outPath; version = "selected-converter"; };
    };
    packages.recipe-pinned = {
      unpackedHash = "selected-source-hash";
      revision = { number = 2; sha256 = "selected-metadata"; time = "selected-cutoff"; };
      nativeArguments.zlib = "native.zlib";
    };
  };
  entry = context.packages.recipe-pinned // {
    recipeSha256 = builtins.hashFile "sha256" (recipes + "/packages/recipe-pinned.nix");
    convertedMetadata = { name = "recipe-pinned"; version = "1.0"; revision = "2"; };
    dependenciesByComponent = {
      libraryHaskellDepends = [ "base" ];
      setupHaskellDepends = [ "base" "Cabal" ];
      librarySystemDepends = [ "zlib" ];
    };
  };
  manifest = {
    schemaVersion = 2;
    inherit (context) generationContext configuration;
    packages.recipe-pinned = entry;
  };
  hl.overrideCabal = change: package: package // change package;
  scope = {
    ghc = compiler;
    callPackage = path: arguments: (import path) ({
      mkDerivation = attrs: attrs;
      base = "selected-base";
      Cabal = "selected-Cabal";
      lib.meta.getLicenseFromSpdxId = text: text;
    } // arguments);
  };
  policy = _final: previous: {
    recipe-pinned = previous.recipe-pinned // { policyApplications = (previous.recipe-pinned.policyApplications or 0) + 1; };
  };
  select = overrides: selectedPkgs: final:
    (mk ({ inherit manifest recipes context; policyExtension = policy; } // overrides) hl selectedPkgs final { }).recipe-pinned;
  package = select { } pkgs scope;
  rejects = value: { expr = (builtins.tryEval (builtins.deepSeq value true)).success; expected = false; };
  changedEntry = update: manifest // { packages.recipe-pinned = entry // update; };
  pinInput = context.packages.recipe-pinned // {
    revision = null;
    sourcePin = {
      repository = "https://github.com/example/pinned.git";
      revision = "immutable-revision";
      subdirectory = "subdir";
      metadataSha256 = "archive-metadata";
      archiveSha256 = "archive-source";
    };
  };
  pinContext = context // { packages.recipe-pinned = pinInput; };
  pinRecipes = ./fixtures/generated-recipes/binding-pin;
  pinEntry = pinInput // {
    inherit (entry) dependenciesByComponent;
    recipeSha256 = builtins.hashFile "sha256" (pinRecipes + "/packages/recipe-pinned.nix");
    convertedMetadata = entry.convertedMetadata // { revision = null; };
  };
  pinManifest = manifest // { packages.recipe-pinned = pinEntry; };
  pinPackage = select { manifest = pinManifest; context = pinContext; recipes = pinRecipes; } pkgs scope;
  layerContext = context // {
    generationContext = context.generationContext // { freeze = { indexState = "selected-index"; flags = { }; }; };
    packages.recipe-pinned = context.packages.recipe-pinned // { nativeArguments = { }; };
  };
  layerManifest = manifest // {
    inherit (layerContext) generationContext;
    packages.recipe-pinned = entry // { nativeArguments = { }; };
  };
  cohort = {
    ghc = compiler.version;
    nixpkgsBase = context.configuration.nixpkgsRevision;
    indexState = "selected-index";
    flags = { };
    sourceManifest = layerContext.generationContext.sources;
    packages.recipe-pinned = {
      version = "1.0";
      sha256 = "selected-source-hash";
      revision = { number = "2"; sha256 = "selected-metadata"; };
    };
  };
  layer = selectedCohort: channel:
    (import ../lib/mkCohortVersionLayer.nix {
      inherit lib channel;
      generatedRecipes = { inherit recipes; context = layerContext; manifest = layerManifest; };
    }) selectedCohort
      (hl // { dontCheck = package: package // { doCheck = false; policyApplications = (package.policyApplications or 0) + 1; }; })
      pkgs
      (scope // { callPackage = path: args: scope.callPackage path ({ zlib = "scope-zlib"; } // args); })
      { };
in
{
  testGeneratedBindingResolvesNativeAndSetupDependencies = {
    expr = { inherit (package) setupHaskellDepends librarySystemDepends revision editedCabalFile policyApplications; };
    expected = {
      setupHaskellDepends = [ "selected-base" "selected-Cabal" ];
      librarySystemDepends = [ "native-zlib" ];
      revision = "2";
      editedCabalFile = "selected-metadata";
      policyApplications = 1;
    };
  };
  testGeneratedBindingPreservesSourceIdentity = { expr = package.src.sha256; expected = "selected-source-hash"; };
  testGeneratedBindingRejectsSourceDrift = rejects (select { manifest = changedEntry { unpackedHash = "different"; }; } pkgs scope);
  testGeneratedBindingRejectsRecipeDrift = rejects (select { manifest = changedEntry { recipeSha256 = "different"; }; } pkgs scope);
  testGeneratedBindingRejectsRoleDrift = rejects (select { manifest = changedEntry { dependenciesByComponent = { }; }; } pkgs scope);
  testGeneratedBindingRejectsMetadataDrift = rejects (select { manifest = changedEntry { convertedMetadata = entry.convertedMetadata // { version = "2.0"; }; }; } pkgs scope);
  testGeneratedBindingRejectsNativeMappingDrift = rejects (select { manifest = changedEntry { nativeArguments.zlib = "other"; }; } pkgs scope);
  testGeneratedBindingRejectsCoverageDrift = rejects (select { manifest = manifest // { packages = { }; }; } pkgs scope);
  testGeneratedBindingRejectsContextDrift = rejects (select { manifest = manifest // { generationContext = { }; }; } pkgs scope);
  testGeneratedBindingRejectsPolicyDrift = rejects (select { manifest = manifest // { configuration = context.configuration // { policyIdentity = "other"; }; }; } pkgs scope);
  testGeneratedBindingRejectsFormatOne = rejects (select { manifest = manifest // { schemaVersion = 1; }; } pkgs scope);
  testGeneratedBindingRejectsWrongSystem = rejects (select { } (pkgs // { stdenv.hostPlatform.system = "x86_64-linux"; }) scope);
  testGeneratedBindingRejectsWrongConverter = rejects (select { } (pkgs // { buildPackages.haskellPackages.cabal2nix-unstable.bin = tool // { drvPath = "other.drv"; }; }) scope);
  testGeneratedBindingRejectsWrongCompiler = rejects (select { } pkgs (scope // { ghc = compiler // { drvPath = "other.drv"; }; }));
  testGeneratedBindingPreservesPinnedSourceAndSubdirectory = {
    expr = {
      src = pinPackage.src;
      inherit (pinPackage.passthru.cohortSourceOrigin.source) owner repo rev hash;
      inherit (pinPackage.passthru.cohortSourceOrigin) subdirectory;
      policyApplications = pinPackage.policyApplications;
    };
    expected = {
      src = "source/subdir";
      owner = "example";
      repo = "pinned";
      rev = "immutable-revision";
      hash = "selected-source-hash";
      subdirectory = "subdir";
      policyApplications = 1;
    };
  };
  testGeneratedBindingDoesNotInventPinnedHackageRevision = { expr = pinPackage ? revision; expected = false; };
  testGeneratedBindingRejectsRelabeledRevision = rejects (select
    {
      context = context // { packages.recipe-pinned = context.packages.recipe-pinned // { revision = context.packages.recipe-pinned.revision // { number = 0; }; }; };
      manifest = changedEntry { revision = context.packages.recipe-pinned.revision // { number = 0; }; };
    }
    pkgs
    scope);
  testGeneratedCohortLayerAppliesSelectedPolicyOnce = {
    expr = { inherit ((layer cohort "github").recipe-pinned) doCheck policyApplications revision editedCabalFile; };
    expected = { doCheck = false; policyApplications = 1; revision = "2"; editedCabalFile = "selected-metadata"; };
  };
  testGeneratedCohortLayerRejectsOtherChannel = rejects (layer cohort "hackage");
  testGeneratedCohortLayerRejectsOtherCompiler = rejects (layer (cohort // { ghc = "9.14.1"; }) "github");
  testGeneratedCohortLayerRejectsOtherNixpkgs = rejects (layer (cohort // { nixpkgsBase = "other-nixpkgs"; }) "github");
  testGeneratedCohortLayerRejectsOtherIndexState = rejects (layer (cohort // { indexState = "other-index"; }) "github");
  testGeneratedCohortLayerRejectsOtherSourceFacts = rejects (layer (cohort // { sourceManifest.recipe-pinned.version = "2"; }) "github");
  testGeneratedCohortLayerRejectsOtherFlags = rejects (layer (cohort // { flags.recipe-pinned.use-text = true; }) "github");
  testGeneratedCohortLayerRejectsOtherRevision = rejects (layer (cohort // { packages.recipe-pinned = cohort.packages.recipe-pinned // { revision.number = "3"; revision.sha256 = "other"; }; }) "github");
}
