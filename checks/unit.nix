{ lib }:
let
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
  validatePackageSet = import ../lib/validateFirstPartyPackageSetLock.nix { inherit lib; };
  validatedPackageSet = validatePackageSet { config = packageSetConfig; lock = packageSetLock; };
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
      (validatePackageSet { config = candidateConfig; lock = candidateLock; })
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
  testSnapshotPolicyIgnoresCurrentPolicy = {
    expr = (validatePackageSet {
      config = packageSetConfig // {
        families = map
          (family:
            if family.name == "okf"
            then family // { excludedPackages = [ "retired" ]; }
            else family)
          packageSetConfig.families;
      };
      lock = packageSetLock;
    }).select "historical" != [ ];
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
  invalidPackageSetCases
