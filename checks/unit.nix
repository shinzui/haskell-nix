{ lib }:
let
  runtimeConfig = builtins.fromJSON (builtins.readFile ./fixtures/runtime-package-sets/config.json);
  runtimeLock = builtins.fromJSON (builtins.readFile ./fixtures/runtime-package-sets/lock.json);
  runtimeRecord = builtins.head runtimeLock.runtimes.fixture;
  validateRuntime = config: lock: import ../lib/validateRuntimePackageSetLock.nix { inherit lib; } {
    inherit config lock;
    firstPartyLock.groupSnapshots = [{ group = "core"; generation = 1; }];
    readProjection = _: "fixture";
  };
  runtimeCandidate = record: runtimeLock // { runtimes.fixture = [ record ]; };
  rejectRuntime = record: rejectsPackageSetConstruction (validateRuntime runtimeConfig (runtimeCandidate record));
  composeRuntime = import ../lib/composeRuntimeSelections.nix { inherit lib; };
  consumerOverlayReport = import ../lib/consumerOverlayReport.nix { inherit lib; };
  overlayReport = args: consumerOverlayReport ({ channelPackages = [ ]; overlayPackages = [ ]; ownPackages = [ ]; } // args);
  doctestTickerRepair = system: compiler: version: import ../patches/doctest/0.24.3-ghc9124-ticker.nix {
    inherit lib;
    patchFile = "fixture.patch";
    pkg = { inherit version; src = "released-source"; doCheck = true; postPatch = "existing hook\n"; };
    pkgs.stdenv.hostPlatform = { inherit system; };
    hself.ghc.version = compiler;
    haskellLib.overrideCabal = update: drv: drv // update drv;
  };
  cborgMetadataRepair = compiler: version: import ../patches/cborg-json/0.2.6-ghc914.nix {
    inherit lib;
    pkg = { inherit version; postPatch = "existing hook\n"; };
    hself.ghc.version = compiler;
    haskellLib.overrideCabal = update: drv: drv // update drv;
  };
  kiokuCompilerRepair = compiler: version: import ../patches/kioku-core/0.8.0.2-ghc9141.nix {
    inherit lib;
    pkg = { inherit version; src = "selected-source"; configureFlags = [ "existing-flag" ]; postPatch = "existing hook\n"; doCheck = true; enableLibraryProfiling = true; jailbreak = false; };
    hself.ghc.version = compiler;
    haskellLib.overrideCabal = update: drv: drv // update drv;
  };
  kiokuCliCompilerRepair = compiler: version: import ../patches/kioku-cli/0.8.0.2-ghc9141.nix {
    inherit lib;
    pkg = { inherit version; src = "selected-source"; configureFlags = [ "existing-flag" ]; postPatch = "existing hook\n"; doCheck = true; enableLibraryProfiling = true; jailbreak = false; };
    hself.ghc.version = compiler;
    haskellLib.overrideCabal = update: drv: drv // update drv;
  };
  admittingRevisionFixture = compiler: version: import ../patches/metadata/admitting-revision-ghc914.nix
    {
      version = "1.2.3";
      revision = "2";
      sha256 = "published-hash";
    }
    {
      inherit lib;
      pkg = { inherit version; revision = "1"; doCheck = true; };
      hself.ghc.version = compiler;
      haskellLib.overrideCabal = update: drv: drv // update drv;
    };
  ephemeralSelectionFixture = version:
    (builtins.head (import ../overlays/registry.nix).ephemeral-pg).patch {
      inherit lib;
      pkg = { inherit version; source = "generation"; };
      hself.callHackageDirect = _: _: throw "build policy must not choose a Hackage version";
      haskellLib.markUnbroken = drv: drv // { broken = false; };
      haskellLib.dontCheck = drv: drv // { doCheck = false; };
      haskellLib.doJailbreak = _: throw "ephemeral selection must preserve bounds";
    };
  fixtures = ./fixtures/first-party;
  readJson = name: builtins.fromJSON (builtins.readFile (fixtures + "/${name}"));
  mkRegistries = import ../lib/mkFirstPartyRegistries.nix { inherit lib; };
  config = readJson "valid-config.json";
  lock = readJson "valid-lock.json";
  # Registry construction must validate metadata without evaluating source trees.
  sources.example-src = throw "unit tests must not fetch a source";
  registries = mkRegistries { inherit config lock sources; };
  packageSetFixtures = ./fixtures/package-sets;
  packageSetConfig = builtins.fromJSON (builtins.readFile (packageSetFixtures + "/valid-config.json"));
  packageSetLock = builtins.fromJSON (builtins.readFile (packageSetFixtures + "/valid-lock.json"));
  validatePackageSet = config: lock: import ../lib/validateFirstPartyPackageSetLock.nix {
    inherit lib config lock;
  };
  validatedPackageSet = validatePackageSet packageSetConfig packageSetLock;
  mkHaskellExtension = import ../lib/mkHaskellExtension.nix { inherit lib; };
  mkHaskellOverlay = import ../lib/mkHaskellOverlay.nix { inherit lib; };
  mkPackageSetFactory = import ../lib/mkFirstPartyPackageSet.nix {
    inherit lib mkHaskellExtension mkHaskellOverlay;
    mkFirstPartyRegistries = mkRegistries;
  };
  throwingFetcher = _: throw "package-set metadata must not fetch a source";
  mkPackageSetWith =
    { candidateLock ? packageSetLock
    , profiles ? { default = { }; }
    , fetchSource ? throwingFetcher
    , commonRegistry ? { common-example = [ ]; }
    , cohortVersions ? { packages = { }; }
    }:
    mkPackageSetFactory {
      config = packageSetConfig;
      lock = candidateLock;
      inherit commonRegistry cohortVersions;
      compatibilityProfiles = profiles;
      supportedGhcs = [ ];
      inherit fetchSource;
    };
  mkPackageSet = mkPackageSetWith { };
  firstPartyCompatibilityFixture = afterFirstParty:
    let
      candidate = (mkPackageSetWith {
        fetchSource = locked: { inherit (locked) rev; outPath = /tmp; };
        commonRegistry.okf = [{
          always = true;
          inherit afterFirstParty;
          patch = { pkg, ... }: pkg // { stages = pkg.stages ++ [ "compatibility" ]; };
        }];
      }) { packageSet = "default"; };
    in
    (builtins.head candidate.registry.okf).patch {
      pkgs = { };
      hself.callCabal2nix = _: source: _: { version = "2.0"; inherit source; stages = [ "selected-source" ]; };
      haskellLib.doJailbreak = drv: drv // { stages = drv.stages ++ [ "existing-jailbreak" ]; };
      haskellLib.dontCheck = drv: drv // { stages = drv.stages ++ [ "existing-test-policy" ]; };
    };
  defaultSelections = {
    baikai-shikumi = 1;
    keiro = 1;
    okf = 2;
  };
  rejectsPackageSetConstruction = expression: {
    expr = (builtins.tryEval (builtins.deepSeq expression true)).success;
    expected = false;
  };
  invalidConfigs = [
    "invalid-config-duplicate-family.json"
    "invalid-config-unknown-override-key.json"
  ];
  invalidLocks = [
    "invalid-lock-absolute-path.json"
    "invalid-lock-parent-path.json"
    "invalid-lock-dot-segment-path.json"
    "invalid-lock-mismatched-family.json"
    "invalid-lock-mismatched-input.json"
    "invalid-lock-malformed-version.json"
    "invalid-lock-malformed-hash.json"
    "invalid-lock-duplicate-package.json"
  ];
  rejects = candidate: {
    expr = (builtins.tryEval (builtins.deepSeq
      {
        github = builtins.attrNames candidate.github;
        hackage = builtins.attrNames candidate.hackage;
      }
      true)).success;
    expected = false;
  };
  rejectsPackageSet = candidateConfig: candidateLock: {
    expr = (builtins.tryEval (builtins.deepSeq
      (validatePackageSet candidateConfig candidateLock)
      true)).success;
    expected = false;
  };
  mapPackageSets = f: candidate: candidate // {
    packageSets = map f candidate.packageSets;
  };
  mapSetGroups = f: packageSet: packageSet // {
    groups = f packageSet.groups;
  };
  mapGroupSnapshots = f: candidate: candidate // {
    groupSnapshots = map f candidate.groupSnapshots;
  };
  mapFamilySnapshots = f: candidate: candidate // {
    familySnapshots = map f candidate.familySnapshots;
  };
  replaceOkfGroup = selection:
    if selection.group == "okf" then selection // { group = "unknown"; }
    else selection;
  packageSetProjection = name: map
    (snapshot: { inherit (snapshot) family generation; })
    (validatedPackageSet.select name);
  invalidPackageSetCases = {
    unknown-group = mapPackageSets
      (mapSetGroups (map replaceOkfGroup))
      packageSetLock;
    missing-group = mapPackageSets
      (mapSetGroups (builtins.filter (selection: selection.group != "okf")))
      packageSetLock;
    wrong-group-membership = mapGroupSnapshots
      (snapshot:
        if snapshot.group == "baikai-shikumi"
        then snapshot // { families = [ builtins.head snapshot.families ]; }
        else snapshot)
      packageSetLock;
    missing-family-generation = mapGroupSnapshots
      (snapshot:
        if snapshot.group == "okf" && snapshot.generation == 1
        then snapshot // { families = map (selection: selection // { generation = 99; }) snapshot.families; }
        else snapshot)
      packageSetLock;
    duplicate-family-snapshot = packageSetLock // {
      familySnapshots = packageSetLock.familySnapshots ++ [ builtins.head packageSetLock.familySnapshots ];
    };
    non-positive-generation = mapFamilySnapshots
      (snapshot:
        if snapshot.family == "baikai"
        then snapshot // { generation = 0; }
        else snapshot)
      packageSetLock;
    unknown-source-field = mapFamilySnapshots
      (snapshot:
        if snapshot.family == "baikai"
        then snapshot // { source = snapshot.source // { mutable = true; }; }
        else snapshot)
      packageSetLock;
    unknown-support-level = mapPackageSets
      (packageSet:
        if packageSet.name == "historical"
        then packageSet // { supportLevel = "unsupported"; }
        else packageSet)
      packageSetLock;
    historical-default = mapPackageSets
      (packageSet:
        if packageSet.name == "default"
        then packageSet // { supportLevel = "historical"; }
        else packageSet)
      packageSetLock;
    default-not-found = packageSetLock // { defaultPackageSet = "missing"; };
    duplicate-package-provider = mapFamilySnapshots
      (snapshot:
        if snapshot.family == "keiro"
        then snapshot // { packages = map (package: package // { name = "baikai"; }) snapshot.packages; }
        else snapshot)
      packageSetLock;
    snapshot-policy-mismatch = mapFamilySnapshots
      (snapshot:
        if snapshot.family == "okf" && snapshot.generation == 1
        then snapshot // { packages = map (package: package // { cabal2nixOptions = "wrong"; }) snapshot.packages; }
        else snapshot)
      packageSetLock;
  };
in
{
  testRuntimeProjectionHashesAcceptCapturedBinaryInputs = {
    expr = builtins.deepSeq
      ((import ../lib/validateRuntimePackageSetLock.nix { inherit lib; }) {
        config = builtins.fromJSON (builtins.readFile ../config/runtime-package-sets.json);
        lock = builtins.fromJSON (builtins.readFile ../packages/runtime-lock.json);
        firstPartyLock = builtins.fromJSON (builtins.readFile ../packages/first-party-lock.json);
      })
      true;
    expected = true;
  };
  testCohortRootOriginUsesRepositoryRoot = { expr = (import ../lib/cohortSource.nix { inherit lib; }).originPath { source = "/fixture-source"; subdirectory = "."; }; expected = "/fixture-source"; };
  testCohortNestedOriginKeepsPackageDirectory = { expr = (import ../lib/cohortSource.nix { inherit lib; }).originPath { source = "/fixture-source"; subdirectory = "library"; }; expected = "/fixture-source/library"; };
  testCohortSourceFactsRetainActualNarEvidence = {
    expr = let source = (import ../lib/cohortSource.nix { inherit lib; }).record { outPath = "/fixture-source"; outputHash = "fixed-nar-hash"; outputHashMode = "recursive"; urls = [ "https://example.test/archive" ]; }; in { inherit (source) hash hashMode urls; };
    expected = { hash = "fixed-nar-hash"; hashMode = "recursive"; urls = [ "https://example.test/archive" ]; };
  };
  testRuntimeValidOwnership = { expr = (validateRuntime runtimeConfig runtimeLock).schemaVersion; expected = 1; };
  testRuntimeMissingDependency = rejectRuntime (runtimeRecord // { ownership = builtins.removeAttrs runtimeRecord.ownership [ "base" ]; });
  testRuntimeMissingRoot = rejectRuntime (runtimeRecord // { roots = [ ]; });
  testRuntimeMissingRoles = rejectRuntime (runtimeRecord // { roles = { }; });
  testRuntimeUnknownGeneration = rejectRuntime (runtimeRecord // { selections.core = 2; });
  testRuntimeProjectionTampering = rejectRuntime (runtimeRecord // { projections = runtimeRecord.projections // { "fixture/policy" = lib.concatStrings (lib.replicate 64 "0"); }; });
  testRuntimeUnsupportedCompiler = rejectRuntime (runtimeRecord // { configurations = map (c: c // { compiler = "ghc9141"; }) runtimeRecord.configurations; });
  testRuntimeSourceConflict = rejectRuntime (runtimeRecord // { ownership = runtimeRecord.ownership // { shared = runtimeRecord.ownership.shared // { identities = runtimeRecord.ownership.shared.identities ++ [{ pkg-name = "shared"; pkg-version = "1.0"; flags.changed = true; }]; }; }; });
  testRuntimeUnownedSourceComponent = rejectRuntime (runtimeRecord // { components.unowned = { }; });
  testRuntimeDuplicateGeneration = rejectsPackageSetConstruction (validateRuntime runtimeConfig (runtimeLock // { runtimes.fixture = [ runtimeRecord runtimeRecord ]; }));
  testRuntimeMissingKeiki = rejectsPackageSetConstruction (import ../lib/validateRuntimePackageSetLock.nix { inherit lib; } {
    config = let original = builtins.fromJSON (builtins.readFile ../config/runtime-package-sets.json); in original // { runtimes.keiro-runtime = original.runtimes.keiro-runtime // { roots = builtins.removeAttrs original.runtimes.keiro-runtime.roots [ "keiki-codec-json" ]; }; };
    lock = builtins.fromJSON (builtins.readFile ../packages/runtime-lock.json);
    firstPartyLock = builtins.fromJSON (builtins.readFile ../packages/first-party-lock.json);
  });
  testRuntimeExplicitComplement = { expr = composeRuntime { groups = [ "core" "application" ]; runtimeSelections.core = 1; applicationSelections = { core = 1; application = 3; }; }; expected = { core = 1; application = 3; }; };
  testRuntimeMissingComplement = rejectsPackageSetConstruction (composeRuntime { groups = [ "core" "application" ]; runtimeSelections.core = 1; });
  testRuntimeConflictingComplement = rejectsPackageSetConstruction (composeRuntime { groups = [ "core" ]; runtimeSelections.core = 1; applicationSelections.core = 2; });
  testDoctestTickerRepairKeepsSourceAndTests = {
    expr =
      let repaired = doctestTickerRepair "x86_64-linux" "9.12.4" "0.24.3";
      in { inherit (repaired) src doCheck; guarded = lib.hasPrefix "existing hook\n" repaired.postPatch && lib.hasInfix "23f0224c088382bef245b77a261fbb153127ce58ccecdae3625db4f23c2a5e9d" repaired.postPatch; };
    expected = { src = "released-source"; doCheck = true; guarded = true; };
  };
  testDoctestTickerRepairLeavesDarwinUnchanged = { expr = (doctestTickerRepair "aarch64-darwin" "9.12.4" "0.24.3").postPatch; expected = "existing hook\n"; };
  testDoctestTickerRepairLeavesGhc914Unchanged = { expr = (doctestTickerRepair "x86_64-linux" "9.14.1" "0.24.3").postPatch; expected = "existing hook\n"; };
  testDoctestTickerRepairRetiresOnNewCompiler = { expr = (doctestTickerRepair "x86_64-linux" "9.12.5" "0.24.3").postPatch; expected = "existing hook\n"; };
  testDoctestTickerRepairRetiresOnNewRelease = { expr = (doctestTickerRepair "x86_64-linux" "9.12.4" "0.25.0.2").postPatch; expected = "existing hook\n"; };
  testFirstPartyCompatibilityRunsAfterSourceAndExistingPolicy = {
    expr = (firstPartyCompatibilityFixture true).stages;
    expected = [ "selected-source" "existing-jailbreak" "existing-test-policy" "compatibility" ];
  };
  testOrdinarySharedSourceRecipeDoesNotOverrideFirstParty = {
    expr = (firstPartyCompatibilityFixture false).stages;
    expected = [ "selected-source" "existing-jailbreak" "existing-test-policy" ];
  };
  testFirstPartyCompatibilityPreservesSource = { expr = (firstPartyCompatibilityFixture true).source; expected = /tmp; };
  testKiokuCompilerFlagAppendsOnlySupportedSwitch = { expr = (kiokuCompilerRepair "9.14.1" "0.8.0.2").configureFlags; expected = [ "existing-flag" "--ghc-option=-fno-opt-coercion" ]; };
  testKiokuPublishedCompilerRepair = { expr = (kiokuCompilerRepair "9.14.1" "0.9.0.2").configureFlags; expected = [ "existing-flag" "--ghc-option=-fno-opt-coercion" ]; };
  testKiokuPublishedCompilerRepairRetainsGhc912 = { expr = (kiokuCompilerRepair "9.12.4" "0.9.0.2").configureFlags; expected = [ "existing-flag" ]; };
  testKiokuPublishedCompilerRepairRetiresOnNextRelease = { expr = (kiokuCompilerRepair "9.14.1" "0.9.0.3").configureFlags; expected = [ "existing-flag" ]; };
  testKiokuPublishedCompilerRepairGuardsSource = {
    expr = lib.hasInfix "7743737627fc444dc6f623c337aa627b132aa188026bf2ead847ba544f81c8cd" (kiokuCompilerRepair "9.14.1" "0.9.0.2").postPatch;
    expected = true;
  };
  testKiokuCliCompilerFlagAppendsOnlySupportedSwitch = { expr = (kiokuCliCompilerRepair "9.14.1" "0.8.0.2").configureFlags; expected = [ "existing-flag" "--ghc-option=-fno-opt-coercion" ]; };
  testKiokuPublishedCliCompilerRepair = { expr = (kiokuCliCompilerRepair "9.14.1" "0.9.0.2").configureFlags; expected = [ "existing-flag" "--ghc-option=-fno-opt-coercion" ]; };
  testKiokuPublishedCliCompilerRepairRetainsGhc912 = { expr = (kiokuCliCompilerRepair "9.12.4" "0.9.0.2").configureFlags; expected = [ "existing-flag" ]; };
  testKiokuPublishedCliCompilerRepairRetiresOnNextRelease = { expr = (kiokuCliCompilerRepair "9.14.1" "0.9.0.3").configureFlags; expected = [ "existing-flag" ]; };
  testKiokuPublishedCliCompilerRepairGuardsSource = {
    expr = lib.hasInfix "843f7b9593b93d2ccd0f4a00f47c8c64d6ce22543651063cfc3eb1acafca984b" (kiokuCliCompilerRepair "9.14.1" "0.9.0.2").postPatch;
    expected = true;
  };
  testKiokuCliCompilerRepairRetainsGhc912 = { expr = (kiokuCliCompilerRepair "9.12.4" "0.8.0.2").configureFlags; expected = [ "existing-flag" ]; };
  testKiokuCliCompilerRepairRetiresOnNewCompiler = { expr = (kiokuCliCompilerRepair "9.14.2" "0.8.0.2").configureFlags; expected = [ "existing-flag" ]; };
  testKiokuCliCompilerRepairRetiresOnFutureVersion = { expr = (kiokuCliCompilerRepair "9.14.1" "0.8.0.3").configureFlags; expected = [ "existing-flag" ]; };
  testKiokuCliCompilerRepairPreservesOtherPolicy = {
    expr = let repaired = kiokuCliCompilerRepair "9.14.1" "0.8.0.2"; in { inherit (repaired) src doCheck enableLibraryProfiling jailbreak; };
    expected = { src = "selected-source"; doCheck = true; enableLibraryProfiling = true; jailbreak = false; };
  };
  testKiokuCliCompilerRepairGuardsLibraryAndExecutableSource = {
    expr = let hook = (kiokuCliCompilerRepair "9.14.1" "0.8.0.2").postPatch; in lib.hasPrefix "existing hook\n" hook && lib.hasInfix "find src app" hook && lib.hasInfix "4e6e34bc9816db4c9fe78fe38ecfbc07fbcb3e09a57f378cd9aa6a369403a298" hook;
    expected = true;
  };
  testKiokuCompilerRepairRetainsGhc912 = { expr = kiokuCompilerRepair "9.12.4" "0.8.0.2"; expected = kiokuCompilerRepair "9.14.2" "0.8.0.2"; };
  testKiokuCompilerRepairRetiresOnFutureVersion = { expr = (kiokuCompilerRepair "9.14.1" "0.8.0.3").configureFlags; expected = [ "existing-flag" ]; };
  testKiokuCompilerRepairPreservesOtherPolicy = {
    expr = let repaired = kiokuCompilerRepair "9.14.1" "0.8.0.2"; in { inherit (repaired) src doCheck enableLibraryProfiling jailbreak; };
    expected = { src = "selected-source"; doCheck = true; enableLibraryProfiling = true; jailbreak = false; };
  };
  testKiokuCompilerRepairPreservesHookAndGuardsSource = {
    expr = let hook = (kiokuCompilerRepair "9.14.1" "0.8.0.2").postPatch; in lib.hasPrefix "existing hook\n" hook && lib.hasInfix "524df9cc52fa48fc1c6326fc398070667ee9ad5d6490f8e42b7d88069b9af055" hook;
    expected = true;
  };
  testCborgMetadataUnchangedOnGhc912 = { expr = (cborgMetadataRepair "9.12.4" "0.2.6.0").postPatch; expected = "existing hook\n"; };
  testCborgMetadataUnchangedOnGhc915 = { expr = (cborgMetadataRepair "9.15.0" "0.2.6.0").postPatch; expected = "existing hook\n"; };
  testCborgMetadataUnchangedOnNewVersion = { expr = (cborgMetadataRepair "9.14.1" "0.2.6.1").postPatch; expected = "existing hook\n"; };
  testCborgMetadataRepairPreservesHook = { expr = lib.hasPrefix "existing hook\n" (cborgMetadataRepair "9.14.1" "0.2.6.0").postPatch; expected = true; };
  testAdmittingRevisionUnchangedOnGhc912 = { expr = (admittingRevisionFixture "9.12.4" "1.2.3").revision; expected = "1"; };
  testAdmittingRevisionUnchangedOnNewVersion = { expr = (admittingRevisionFixture "9.14.1" "1.2.4").revision; expected = "1"; };
  testAdmittingRevisionPreservesTests = { expr = admittingRevisionFixture "9.14.1" "1.2.3"; expected = { version = "1.2.3"; revision = "2"; editedCabalFile = "published-hash"; doCheck = true; }; };
  testEphemeralPolicyPreservesSelectedSource = { expr = ephemeralSelectionFixture "0.2.1.0"; expected = { version = "0.2.1.0"; source = "generation"; broken = false; doCheck = false; }; };
  testEphemeralCohortSourceRetained = { expr = (ephemeralSelectionFixture "0.3.1.0").source; expected = "generation"; };
  testEphemeralFutureSelectionRetained = { expr = (ephemeralSelectionFixture "0.4.0.0").version; expected = "0.4.0.0"; };
  testConsumerOverlayClean = { expr = (overlayReport { overlayPackages = [ "app" ]; ownPackages = [ "app" ]; }).ok; expected = true; };
  testConsumerOverlayShadowing = { expr = (overlayReport { channelPackages = [ "shared" ]; overlayPackages = [ "shared" ]; }).shadowing; expected = [ "shared" ]; };
  testConsumerOverlayShadowingNotExcused = { expr = (overlayReport { channelPackages = [ "shared" ]; overlayPackages = [ "shared" ]; exceptions.shared = "reason"; }).shadowing; expected = [ "shared" ]; };
  testConsumerOverlayUndeclared = { expr = (overlayReport { overlayPackages = [ "unknown" ]; }).undeclared; expected = [ "unknown" ]; };
  testConsumerOverlayUnusedDeclaration = { expr = (overlayReport { ownPackages = [ "gone" ]; }).unusedDeclarations; expected = [ "gone" ]; };
  testConsumerOverlayEmptyReason = { expr = (overlayReport { overlayPackages = [ "x" ]; exceptions.x = ""; }).invalidDeclarations; expected = [ "x" ]; };
  testConsumerOverlayInvalidReason = { expr = (overlayReport { exceptions = { spaces = "  \t"; number = 42; }; }).invalidDeclarations; expected = [ "number" "spaces" ]; };
  testConsumerOverlayDuplicateDeclaration = { expr = (overlayReport { overlayPackages = [ "app" ]; ownPackages = [ "app" ]; siblingPackages = [ "app" ]; }).invalidDeclarations; expected = [ "app" ]; };
  testConsumerOverlayRuntimeCannotBeOwned = { expr = (overlayReport { overlayPackages = [ "runtime-lib" ]; ownPackages = [ "runtime-lib" ]; runtimePackages = [ "runtime-lib" ]; }).shadowing; expected = [ "runtime-lib" ]; };
  testConsumerOverlayAllOwnershipLayers = { expr = (overlayReport { overlayPackages = [ "source" "frozen" "generated" ]; ownPackages = [ "source" "frozen" "generated" ]; generatedPackages = [ "generated" ]; frozenPackages = [ "frozen" ]; sourcePackages = [ "source" ]; }).shadowing; expected = [ "frozen" "generated" "source" ]; };
  testConsumerOverlayDeterministic = { expr = overlayReport { overlayPackages = [ "z" "a" "z" ]; }; expected = { shadowing = [ ]; undeclared = [ "a" "z" ]; unusedDeclarations = [ ]; invalidDeclarations = [ ]; ok = false; }; };

  testGithubInventoryWithoutFetching = {
    expr = builtins.attrNames registries.github;
    expected = [ "example-core" "example-dev" "example-special" ];
  };
  testHackageOmitsUnpublishedWithoutFetching = {
    expr = builtins.attrNames registries.hackage;
    expected = [ "example-core" "example-special" ];
  };
  testRepositoryRootPackage = {
    expr = builtins.attrNames (mkRegistries {
      config = readJson "valid-root-config.json";
      lock = readJson "valid-root-lock.json";
      sources.example-root-src = throw "root metadata must not force sources";
    }).github;
    expected = [ "example-root" ];
  };
  testPackageSetDefaultProjection = {
    expr = packageSetProjection "default";
    expected = [
      { family = "baikai"; generation = 1; }
      { family = "keiro"; generation = 1; }
      { family = "okf"; generation = 2; }
      { family = "shikumi"; generation = 1; }
    ];
  };
  testPackageSetHistoricalRetainsKeiro = {
    expr = packageSetProjection "historical";
    expected = [
      { family = "baikai"; generation = 1; }
      { family = "keiro"; generation = 1; }
      { family = "okf"; generation = 1; }
      { family = "shikumi"; generation = 1; }
    ];
  };
  testNamedAndExplicitSelectionsAgreeWithoutFetching = {
    expr = {
      named = (mkPackageSet { packageSet = "default"; }).selections;
      explicit = (mkPackageSet { selections = defaultSelections; }).selections;
    };
    expected = {
      named = defaultSelections;
      explicit = defaultSelections;
    };
  };
  testCohortCannotReplaceSelectedFirstPartyPackage = rejectsPackageSetConstruction
    ((mkPackageSetWith { cohortVersions.packages.okf = { }; }) { packageSet = "default"; });
  testSelectedFamilyVersionsWithoutFetching = {
    expr = map
      (snapshot: {
        inherit (snapshot) family generation;
        versions = map (package: package.version) snapshot.packages;
      })
      (mkPackageSet { packageSet = "historical"; }).selectedFamilies;
    expected = [
      { family = "baikai"; generation = 1; versions = [ "1.0" ]; }
      { family = "keiro"; generation = 1; versions = [ "1.0" ]; }
      { family = "okf"; generation = 1; versions = [ "1.0" ]; }
      { family = "shikumi"; generation = 1; versions = [ "1.0" ]; }
    ];
  };
  testBothChannelsExposeSelectedInventoryWithoutFetching = {
    expr = {
      github = builtins.attrNames (mkPackageSet {
        packageSet = "historical";
        channel = "github";
      }).registry;
      hackage = builtins.attrNames (mkPackageSet {
        packageSet = "historical";
        channel = "hackage";
      }).registry;
    };
    expected = {
      github = [ "baikai" "common-example" "keiro" "okf" "shikumi" ];
      hackage = [ "baikai" "common-example" "keiro" "okf" "shikumi" ];
    };
  };
  testRepeatedCompatibilityProfileIsDeduplicated = {
    expr = builtins.attrNames (mkPackageSet {
      packageSet = "default";
    }).registry;
    expected = [ "baikai" "common-example" "keiro" "okf" "shikumi" ];
  };
  testRejectPackageSetBothSelectionForms = rejectsPackageSetConstruction
    (mkPackageSet {
      packageSet = "default";
      selections = defaultSelections;
    });
  testRejectPackageSetIncompleteSelection = rejectsPackageSetConstruction
    (mkPackageSet {
      selections = builtins.removeAttrs defaultSelections [ "okf" ];
    });
  testRejectPackageSetUnknownChannel = rejectsPackageSetConstruction
    (mkPackageSet {
      packageSet = "default";
      channel = "archive";
    });
  testRejectPackageSetMissingProfile = rejectsPackageSetConstruction
    ((mkPackageSetWith { profiles = { }; }) { packageSet = "default"; });
  testRejectProfileSelectedPackageConflict = rejectsPackageSetConstruction
    ((mkPackageSetWith {
      profiles.default.okf = [ ];
    }) { packageSet = "default"; });
  testRejectDistinctProfileOverlap =
    let
      candidateLock = packageSetLock // {
        groupSnapshots = map
          (snapshot:
            if snapshot.group == "baikai-shikumi" then
              snapshot // { compatibilityProfile = "first"; }
            else if snapshot.group == "keiro" then
              snapshot // { compatibilityProfile = "second"; }
            else snapshot)
          packageSetLock.groupSnapshots;
      };
      candidate = (mkPackageSetWith {
        inherit candidateLock;
        profiles = {
          default = { };
          first.shared = [ ];
          second.shared = [ ];
        };
      }) { packageSet = "default"; };
    in
    rejectsPackageSetConstruction candidate;
  testRejectFetchedRevisionMismatch =
    let
      candidate = (mkPackageSetWith {
        fetchSource = _: {
          rev = "cccccccccccccccccccccccccccccccccccccccc";
          outPath = packageSetFixtures;
        };
      }) {
        packageSet = "default";
        channel = "github";
      };
      patch = (builtins.head candidate.registry.okf).patch;
    in
    rejectsPackageSetConstruction (patch {
      hself.callCabal2nix = _: source: _: builtins.seq source { };
      haskellLib = {
        doJailbreak = value: value;
        dontCheck = value: value;
      };
    });
  testSnapshotPolicyIgnoresCurrentPolicy = {
    expr = (validatePackageSet
      (packageSetConfig // {
        families = map
          (family:
            if family.name == "okf"
            then family // { excludedPackages = [ "retired" ]; }
            else family)
          packageSetConfig.families;
      })
      packageSetLock).select "historical" != [ ];
    expected = true;
  };
  testRejectTopologyChange = rejectsPackageSet
    (packageSetConfig // {
      families = packageSetConfig.families ++ [{
        name = "zeta";
        moriProject = "shinzui/zeta";
        github = "shinzui/zeta";
        githubInput = "zeta-src";
        packageOverrides = { };
        excludedPackages = [ ];
      }];
    })
    packageSetLock;
} // lib.listToAttrs (map
  (name: {
    name = "testReject-${name}";
    value = rejects (mkRegistries {
      inherit lock sources;
      config = readJson name;
    });
  })
  invalidConfigs) // lib.listToAttrs (map
  (name: {
    name = "testReject-${name}";
    value = rejects (mkRegistries {
      inherit config sources;
      lock = readJson name;
    });
  })
  invalidLocks) // lib.mapAttrs'
  (name: candidate: lib.nameValuePair "testRejectPackageSet-${name}" (rejectsPackageSet packageSetConfig candidate))
  invalidPackageSetCases // import ./cohort-freeze-parser.nix { inherit lib; }
// import ./cohort-generated.nix { inherit lib; }
// import ./cohort-layer.nix { inherit lib; }
// import ./generated-recipe-flags.nix { inherit lib; }
// import ./generated-recipe-binding.nix { inherit lib; }
// import ./runtime-generated-recipes.nix { inherit lib; }
// import ./cohort-build-policy.nix { inherit lib; }
// import ./application-incremental-policy.nix { inherit lib; }
// import ./compatibility-policy.nix { inherit lib; }
// import ./compatibility-report.nix { inherit lib; }
// import ./capture-compatibility.nix { inherit lib; }
// import ./package-validation-contract.nix { inherit lib; }
// import ./compatibility-probe-context.nix { inherit lib; }
// import ./project-shell-runtime-contract.nix { inherit lib; }

  // import ./application-checkpoint-policy.nix { inherit lib; }
