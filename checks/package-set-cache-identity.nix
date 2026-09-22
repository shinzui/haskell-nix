{ lib
, pkgs
, defaultGhc
, supportedGhcs
, mkFirstPartyPackageSet
}:

let
  fixtureRoot = ./fixtures/package-sets;
  config = builtins.fromJSON (builtins.readFile (fixtureRoot + "/cache-config.json"));
  lock = builtins.fromJSON (builtins.readFile (fixtureRoot + "/cache-lock.json"));
  sourceRoot = fixtureRoot + "/source";
  fetchSource = descriptor: {
    inherit (descriptor) rev;
    outPath = sourceRoot + "/${
      if descriptor.repo == "okf-like" then
        if descriptor.rev == "2222222222222222222222222222222222222222"
        then "okf-like-v1"
        else "okf-like-v2"
      else if descriptor.repo == "runtime"
        && descriptor.rev == "6666666666666666666666666666666666666666"
      then "runtime-v2"
      else descriptor.repo
    }";
  };
  mkConstructor = candidateLock: profiles: mkFirstPartyPackageSet {
    inherit config fetchSource;
    lock = candidateLock;
    commonRegistry = { };
    compatibilityProfiles = profiles;
    inherit supportedGhcs;
  };
  defaultProfiles.default = { };
  emptyExtension = _: _: { };
  mkScope =
    { channel
    , selector
    , candidateLock ? lock
    , profiles ? defaultProfiles
    , ghc ? defaultGhc
    , preExistingExtension ? emptyExtension
    , consumerExtension ? emptyExtension
    }:
    let
      selected = (mkConstructor candidateLock profiles) (selector // { inherit channel; });
      base = pkgs.haskell.packages.${ghc}.override {
        overrides = preExistingExtension;
      };
      selectedThenConsumer = lib.composeExtensions
        (selected.haskellExtension pkgs.haskell.lib.compose pkgs)
        consumerExtension;
    in
    base.override (old: {
      overrides = lib.composeExtensions
        (old.overrides or emptyExtension)
        selectedThenConsumer;
    });
  paths = packages: {
    runtime = packages.tasty.drvPath;
    changed = packages.tasty-bench.drvPath;
    dependent =
      if packages ? package-set-dependent && packages.package-set-dependent != null
      then packages.package-set-dependent.drvPath
      else null;
  };
  namedPaths = channel: packageSet:
    paths (mkScope {
      inherit channel;
      selector = { inherit packageSet; };
    });
  githubA = namedPaths "github" "set-a";
  githubB = namedPaths "github" "set-b";
  hackageA = namedPaths "hackage" "set-a";
  hackageB = namedPaths "hackage" "set-b";

  explicitB = paths (mkScope {
    channel = "github";
    selector.selections = {
      dependent = 1;
      okf-like = 2;
      runtime = 1;
    };
  });

  renamedLock = lock // {
    packageSets = [
      ((builtins.elemAt lock.packageSets 1) // { name = "renamed"; })
      (builtins.elemAt lock.packageSets 0)
    ];
    defaultPackageSet = "renamed";
  };
  renamedB = paths (mkScope {
    channel = "github";
    selector.packageSet = "renamed";
    candidateLock = renamedLock;
  });

  unselectedSnapshot =
    let
      generation3 = (builtins.elemAt lock.familySnapshots 2) // {
        generation = 3;
        source = (builtins.elemAt lock.familySnapshots 2).source // {
          rev = "5555555555555555555555555555555555555555";
        };
      };
    in
    lock // {
      familySnapshots = lib.take 3 lock.familySnapshots
      ++ [ generation3 ]
      ++ lib.drop 3 lock.familySnapshots;
    };
  unselectedSnapshotB = paths (mkScope {
    channel = "github";
    selector.packageSet = "set-b";
    candidateLock = unselectedSnapshot;
  });

  irrelevantPolicy = lock // {
    familySnapshots = map
      (snapshot:
        if snapshot.family == "runtime" then
          snapshot // {
            discoveryPolicy = snapshot.discoveryPolicy // {
              excludedPackages = [ "retired-runtime-example" ];
            };
          }
        else snapshot)
      lock.familySnapshots;
  };
  irrelevantPolicyB = paths (mkScope {
    channel = "github";
    selector.packageSet = "set-b";
    candidateLock = irrelevantPolicy;
  });

  runtimeGeneration2Snapshot = (builtins.elemAt lock.familySnapshots 3) // {
    generation = 2;
    source = (builtins.elemAt lock.familySnapshots 3).source // {
      rev = "6666666666666666666666666666666666666666";
    };
  };
  runtimeGeneration2Group = (builtins.elemAt lock.groupSnapshots 3) // {
    generation = 2;
    families = [{ family = "runtime"; generation = 2; }];
  };
  runtimeGenerationLock = lock // {
    familySnapshots = lock.familySnapshots ++ [ runtimeGeneration2Snapshot ];
    groupSnapshots = lock.groupSnapshots ++ [ runtimeGeneration2Group ];
  };
  runtimeGeneration2Paths = paths (mkScope {
    channel = "github";
    candidateLock = runtimeGenerationLock;
    selector.selections = {
      dependent = 1;
      okf-like = 2;
      runtime = 2;
    };
  });

  profileLock = lock // {
    groupSnapshots = map
      (snapshot:
        if snapshot.group == "runtime" then
          snapshot // { compatibilityProfile = "tagged-shift"; }
        else snapshot)
      lock.groupSnapshots;
  };
  profileRegistry.tagged = [{
    always = true;
    patch = { pkg, ... }: pkg.overrideAttrs (old: {
      packageSetProfileMarker = "changed";
      passthru = (old.passthru or { }) // { packageSetProfileMarker = true; };
    });
  }];
  profilePaths = paths (mkScope {
    channel = "github";
    selector.packageSet = "set-b";
    candidateLock = profileLock;
    profiles = defaultProfiles // { tagged-shift = profileRegistry; };
  });

  withHaddockPaths = paths (mkScope {
    channel = "github";
    selector = {
      packageSet = "set-b";
      disableHaddock = false;
    };
  });
  otherGhc = builtins.head (builtins.filter (ghc: ghc != defaultGhc) supportedGhcs);
  otherGhcPaths = paths (mkScope {
    channel = "github";
    selector.packageSet = "set-b";
    ghc = otherGhc;
  });

  preExistingExtension = _: _: {
    preExistingMarker = "preserved";
  };
  consumerExtension = _: hsuper: {
    consumerMarker = "preserved";
    tagged = hsuper.tagged.overrideAttrs (old: {
      packageSetConsumerMarker = "changed";
      passthru = (old.passthru or { }) // { packageSetConsumerMarker = true; };
    });
  };
  overridden = mkScope {
    channel = "github";
    selector.packageSet = "set-b";
    inherit preExistingExtension consumerExtension;
  };
  overriddenPaths = paths overridden;

  results = {
    githubRuntimeEqual = githubA.runtime == githubB.runtime;
    hackageRuntimeEqual = hackageA.runtime == hackageB.runtime;
    githubOkfDifferent = githubA.changed != githubB.changed;
    hackageOkfDifferent = hackageA.changed != hackageB.changed;
    githubDependentDifferent = githubA.dependent != githubB.dependent;
    hackageOmitsUnpublishedDependent = hackageA.dependent == null && hackageB.dependent == null;
    explicitLabelInvariant = explicitB == githubB;
    renamedPackageSetInvariant = renamedB == githubB;
    unselectedSnapshotInvariant = unselectedSnapshotB == githubB;
    irrelevantPolicyInvariant = irrelevantPolicyB == githubB;
    channelChangesRuntime = githubB.runtime != hackageB.runtime;
    ghcChangesRuntime = githubB.runtime != otherGhcPaths.runtime;
    runtimeGenerationChangesRuntime = githubB.runtime != runtimeGeneration2Paths.runtime;
    buildSettingsChangeRuntime = githubB.runtime != withHaddockPaths.runtime;
    compatibilityProfileChangesRuntime = githubB.runtime != profilePaths.runtime;
    preExistingOverrideSurvives = overridden.preExistingMarker == "preserved";
    consumerOverrideSurvives = overridden.consumerMarker == "preserved";
    consumerDependencyOverrideChangesRuntime = overriddenPaths.runtime != githubB.runtime;
  };
  failures = builtins.filter
    (name: !results.${name})
    (builtins.attrNames results);
in
assert failures == [ ];
pkgs.runCommand "package-set-cache-identity"
{
  passthru = { inherit results; };
} ''
  echo '${builtins.unsafeDiscardStringContext (builtins.toJSON results)}'
  touch "$out"
''
