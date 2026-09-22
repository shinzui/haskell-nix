# Construct a composable first-party package set from a schema-version-2
# catalog. The package-set label and generation numbers select immutable
# records, but are intentionally absent from package derivation inputs.
{ lib
, mkFirstPartyRegistries
, mkHaskellExtension
, mkHaskellOverlay
}:

{ config
, lock
, commonRegistry
, compatibilityProfiles
, supportedGhcs
, fetchSource ? builtins.fetchTree
}:

{ packageSet ? null
, selections ? null
, channel ? "github"
, disableProfiling ? true
, disableHaddock ? true
}:

let
  validated = import ./validateFirstPartyPackageSetLock.nix {
    inherit lib config lock;
  };
  resolvedGroupNames = map (group: group.name) validated.resolvedGroups;

  findOne = description: predicate: values:
    let matches = builtins.filter predicate values;
    in if builtins.length matches == 1
    then builtins.head matches
    else throw "mkFirstPartyPackageSet: expected one ${description}";

  namedSelection = packageSet != null && selections == null;
  explicitSelection = packageSet == null && selections != null;
  selectionModeValid = namedSelection || explicitSelection;
  channelValid = builtins.elem channel [ "github" "hackage" ];
  explicitSelectionValid =
    builtins.isAttrs selections
    && builtins.attrNames selections == resolvedGroupNames
    && builtins.all
      (generation: builtins.isInt generation && generation > 0)
      (builtins.attrValues selections);

  namedPackageSet =
    if namedSelection then
      findOne "package set ${toString packageSet}"
        (candidate: candidate.name == packageSet)
        lock.packageSets
    else null;

  normalizedSelections =
    if namedSelection then
      lib.listToAttrs
        (map
          (selection: {
            name = selection.group;
            value = selection.generation;
          })
          namedPackageSet.groups)
    else selections;

  selectedGroupSnapshots = map
    (groupName:
      findOne
        "group snapshot ${groupName}#${toString normalizedSelections.${groupName}}"
        (snapshot:
          snapshot.group == groupName
          && snapshot.generation == normalizedSelections.${groupName})
        lock.groupSnapshots)
    resolvedGroupNames;

  selectedFamilyReferences = lib.concatMap
    (snapshot: snapshot.families)
    selectedGroupSnapshots;
  selectedFamilies = lib.sort
    (left: right: left.family < right.family)
    (map
      (selection:
        findOne
          "family snapshot ${selection.family}#${toString selection.generation}"
          (snapshot:
            snapshot.family == selection.family
            && snapshot.generation == selection.generation)
          lock.familySnapshots)
      selectedFamilyReferences);

  configByName = lib.listToAttrs (map
    (family: {
      name = family.name;
      value = family;
    })
    config.families);

  projectedConfig = {
    schemaVersion = 1;
    families = map
      (snapshot:
        let configured = configByName.${snapshot.family};
        in {
          inherit (configured) name moriProject github githubInput;
          inherit (snapshot.discoveryPolicy) packageOverrides excludedPackages;
        })
      selectedFamilies;
  };

  projectedLock = {
    schemaVersion = 1;
    families = map
      (snapshot: {
        name = snapshot.family;
        githubInput = configByName.${snapshot.family}.githubInput;
        githubRev = snapshot.source.rev;
        inherit (snapshot) packages;
      })
      selectedFamilies;
  };

  fetchLockedSource = snapshot:
    let
      fetched = fetchSource {
        inherit (snapshot.source) type owner repo rev narHash;
      };
      fetchedRevision = fetched.rev or null;
    in
    if fetchedRevision != snapshot.source.rev then
      throw "mkFirstPartyPackageSet: fetched revision for ${snapshot.family} does not match its locked revision"
    else
      fetched.outPath;

  sources = lib.listToAttrs (map
    (snapshot: {
      name = configByName.${snapshot.family}.githubInput;
      value = fetchLockedSource snapshot;
    })
    selectedFamilies);

  firstPartyRegistries = mkFirstPartyRegistries {
    inherit sources;
    config = projectedConfig;
    lock = projectedLock;
  };
  firstPartyRegistry = firstPartyRegistries.${channel};
  selectedPackageNames = lib.concatMap
    (snapshot: map (package: package.name) snapshot.packages)
    selectedFamilies;
  githubOnlyPackageNames = lib.concatMap
    (snapshot: map (package: package.name)
      (builtins.filter (package: package.hackage == null) snapshot.packages))
    selectedFamilies;

  selectedProfileNames = lib.unique (map
    (snapshot: snapshot.compatibilityProfile)
    selectedGroupSnapshots);
  profilesExist = builtins.all
    (name: builtins.hasAttr name compatibilityProfiles)
    selectedProfileNames;
  selectedProfiles = map (name: compatibilityProfiles.${name}) selectedProfileNames;
  mergeProfile = state: profile:
    let overlap = lib.intersectLists (builtins.attrNames state) (builtins.attrNames profile);
    in if overlap != [ ] then
      throw "mkFirstPartyPackageSet: compatibility profiles overlap on ${lib.concatStringsSep ", " overlap}"
    else state // profile;
  profileRegistry = lib.foldl' mergeProfile { } selectedProfiles;
  profilePackageConflicts = lib.intersectLists
    (builtins.attrNames profileRegistry)
    selectedPackageNames;

  registry = commonRegistry // profileRegistry // firstPartyRegistry;
  hackageDependencyOverrides = _: _:
    lib.genAttrs githubOnlyPackageNames (_: null);
  extraOverrides =
    if channel == "hackage" then hackageDependencyOverrides
    else (_: _: { });
  haskellExtension = mkHaskellExtension {
    inherit registry extraOverrides disableProfiling disableHaddock;
  };
  overlay = mkHaskellOverlay {
    inherit registry extraOverrides disableProfiling disableHaddock;
    compilers = supportedGhcs;
  };

  validation = builtins.deepSeq validated (
    if !selectionModeValid then
      throw "mkFirstPartyPackageSet: pass exactly one of packageSet or selections"
    else if !channelValid then
      throw "mkFirstPartyPackageSet: channel must be github or hackage"
    else if explicitSelection && !explicitSelectionValid then
      throw "mkFirstPartyPackageSet: selections must be a complete group-to-positive-generation mapping"
    else if !profilesExist then
      throw "mkFirstPartyPackageSet: a selected compatibility profile is not defined"
    else if profilePackageConflicts != [ ] then
      throw "mkFirstPartyPackageSet: compatibility profiles conflict with selected packages: ${lib.concatStringsSep ", " profilePackageConflicts}"
    else true
  );
in
builtins.seq validation {
  selections = normalizedSelections;
  inherit selectedFamilies registry haskellExtension overlay;
}
