# validateFirstPartyPackageSetLock ::
#   { config : FamilyCatalogV2, lock : PackageSetLockV2 }
#   -> { resolvedGroups : [ UpdateGroup ], select : String -> [ FamilySnapshot ] }
{ lib }:

{ config, lock }:

let
  exactAttrs = required: optional: value:
    builtins.isAttrs value
    && builtins.all (name: builtins.hasAttr name value) required
    && builtins.all
      (name: builtins.elem name (required ++ optional))
      (builtins.attrNames value);

  nonEmptyString = value: builtins.isString value && value != "";
  allUnique = values: builtins.length values == builtins.length (lib.unique values);
  isSorted = values: values == lib.sort builtins.lessThan values;
  isSortedBy = less: values: values == lib.sort less values;
  positiveGeneration = value: builtins.isInt value && value > 0;
  validRevision = value:
    nonEmptyString value && builtins.match "[0-9a-fA-F]{40}" value != null;
  validHash = value:
    nonEmptyString value && builtins.match "sha256-[A-Za-z0-9+/]{43}=" value != null;
  validVersion = value:
    nonEmptyString value && builtins.match "[0-9]+(\\.[0-9]+)*" value != null;
  validRelativePath = value:
    value == "."
    || (
      nonEmptyString value
      && !(lib.hasPrefix "/" value)
      && builtins.all
        (segment: segment != "" && segment != "." && segment != "..")
        (lib.splitString "/" value)
    );

  validOverride = value:
    exactAttrs [ ] [ "cabal2nixOptions" ] value
    && builtins.isString (value.cabal2nixOptions or "");

  validConfigFamily = family:
    exactAttrs
      [ "name" "moriProject" "github" "githubInput" "packageOverrides" "excludedPackages" ]
      [ ]
      family
    && nonEmptyString family.name
    && nonEmptyString family.moriProject
    && builtins.match "[^/]+/[^/]+" family.github != null
    && family.githubInput == "${family.name}-src"
    && builtins.isAttrs family.packageOverrides
    && builtins.all validOverride (builtins.attrValues family.packageOverrides)
    && builtins.isList family.excludedPackages
    && builtins.all nonEmptyString family.excludedPackages
    && allUnique family.excludedPackages
    && isSorted family.excludedPackages
    && builtins.all
      (name: !(builtins.hasAttr name family.packageOverrides))
      family.excludedPackages;

  validExplicitGroup = group:
    exactAttrs [ "name" "families" ] [ ] group
    && nonEmptyString group.name
    && builtins.isList group.families
    && builtins.length group.families >= 2
    && builtins.all nonEmptyString group.families
    && allUnique group.families
    && isSorted group.families;

  configTopValid =
    exactAttrs [ "schemaVersion" "families" "updateGroups" ] [ ] config
    && config.schemaVersion == 2
    && builtins.isList config.families
    && builtins.isList config.updateGroups;

  configRecordsValid =
    configTopValid
    && builtins.all validConfigFamily config.families
    && builtins.all validExplicitGroup config.updateGroups;

  configFamilyNames =
    if configRecordsValid then map (family: family.name) config.families else [ ];
  explicitGroupNames =
    if configRecordsValid then map (group: group.name) config.updateGroups else [ ];
  explicitMembers =
    if configRecordsValid then lib.concatMap (group: group.families) config.updateGroups else [ ];

  configValid =
    configRecordsValid
    && allUnique configFamilyNames
    && isSorted configFamilyNames
    && allUnique explicitGroupNames
    && isSorted explicitGroupNames
    && allUnique explicitMembers
    && builtins.all (name: builtins.elem name configFamilyNames) explicitMembers
    && builtins.all (name: !(builtins.elem name configFamilyNames)) explicitGroupNames;

  singletonGroups = map
    (name: { inherit name; families = [ name ]; })
    (builtins.filter (name: !(builtins.elem name explicitMembers)) configFamilyNames);
  resolvedGroups = lib.sort
    (left: right: left.name < right.name)
    (config.updateGroups ++ singletonGroups);
  resolvedGroupNames = map (group: group.name) resolvedGroups;
  configByName = lib.listToAttrs (map (family: { name = family.name; value = family; }) config.families);
  groupsByName = lib.listToAttrs (map (group: { name = group.name; value = group; }) resolvedGroups);

  validHackage = value:
    exactAttrs [ "version" "hash" ] [ ] value
    && validVersion value.version
    && validHash value.hash;
  validPackage = package:
    exactAttrs [ "name" "path" "version" "cabal2nixOptions" "hackage" ] [ ] package
    && nonEmptyString package.name
    && validRelativePath package.path
    && validVersion package.version
    && builtins.isString package.cabal2nixOptions
    && (package.hackage == null || validHackage package.hackage);
  validPolicy = policy:
    exactAttrs [ "packageOverrides" "excludedPackages" ] [ ] policy
    && builtins.isAttrs policy.packageOverrides
    && builtins.all validOverride (builtins.attrValues policy.packageOverrides)
    && builtins.isList policy.excludedPackages
    && builtins.all nonEmptyString policy.excludedPackages
    && allUnique policy.excludedPackages
    && isSorted policy.excludedPackages
    && builtins.all
      (name: !(builtins.hasAttr name policy.packageOverrides))
      policy.excludedPackages;
  validSource = source:
    exactAttrs [ "type" "owner" "repo" "rev" "narHash" ] [ ] source
    && source.type == "github"
    && nonEmptyString source.owner
    && nonEmptyString source.repo
    && validRevision source.rev
    && validHash source.narHash;

  validFamilySnapshot = snapshot:
    exactAttrs [ "family" "generation" "discoveryPolicy" "source" "packages" ] [ ] snapshot
    && nonEmptyString snapshot.family
    && positiveGeneration snapshot.generation
    && builtins.hasAttr snapshot.family configByName
    && validPolicy snapshot.discoveryPolicy
    && validSource snapshot.source
    && "${snapshot.source.owner}/${snapshot.source.repo}" == configByName.${snapshot.family}.github
    && builtins.isList snapshot.packages
    && builtins.all validPackage snapshot.packages
    && isSorted (map (package: package.name) snapshot.packages)
    && allUnique (map (package: package.name) snapshot.packages)
    && builtins.all
      (name: builtins.elem name (map (package: package.name) snapshot.packages))
      (builtins.attrNames snapshot.discoveryPolicy.packageOverrides)
    && builtins.all
      (name: !(builtins.elem name (map (package: package.name) snapshot.packages)))
      snapshot.discoveryPolicy.excludedPackages
    && builtins.all
      (package:
        package.cabal2nixOptions
        == (snapshot.discoveryPolicy.packageOverrides.${package.name}.cabal2nixOptions or ""))
      snapshot.packages;

  familySnapshotLess = left: right:
    left.family < right.family
    || (left.family == right.family && left.generation < right.generation);
  familySnapshotKey = snapshot: "${snapshot.family}#${toString snapshot.generation}";
  familySnapshotKeys =
    if lockTopValid then map familySnapshotKey lock.familySnapshots else [ ];
  familySnapshotFamilies =
    if lockTopValid then lib.unique (map (snapshot: snapshot.family) lock.familySnapshots) else [ ];

  validFamilySelection = selection:
    exactAttrs [ "family" "generation" ] [ ] selection
    && nonEmptyString selection.family
    && positiveGeneration selection.generation;
  validGroupSnapshot = snapshot:
    exactAttrs [ "group" "generation" "families" "compatibilityProfile" ] [ ] snapshot
    && nonEmptyString snapshot.group
    && positiveGeneration snapshot.generation
    && builtins.hasAttr snapshot.group groupsByName
    && builtins.isList snapshot.families
    && builtins.all validFamilySelection snapshot.families
    && map (selection: selection.family) snapshot.families == groupsByName.${snapshot.group}.families
    && builtins.all
      (selection: builtins.elem "${selection.family}#${toString selection.generation}" familySnapshotKeys)
      snapshot.families
    && nonEmptyString snapshot.compatibilityProfile;
  groupSnapshotLess = left: right:
    left.group < right.group
    || (left.group == right.group && left.generation < right.generation);
  groupSnapshotKey = snapshot: "${snapshot.group}#${toString snapshot.generation}";
  groupSnapshotKeys =
    if lockTopValid then map groupSnapshotKey lock.groupSnapshots else [ ];
  groupSnapshotGroups =
    if lockTopValid then lib.unique (map (snapshot: snapshot.group) lock.groupSnapshots) else [ ];

  validGroupSelection = selection:
    exactAttrs [ "group" "generation" ] [ ] selection
    && nonEmptyString selection.group
    && positiveGeneration selection.generation;
  validPackageSet = packageSet:
    exactAttrs [ "name" "supportLevel" "groups" ] [ ] packageSet
    && nonEmptyString packageSet.name
    && builtins.elem packageSet.supportLevel [ "curated" "historical" ]
    && builtins.isList packageSet.groups
    && builtins.all validGroupSelection packageSet.groups
    && map (selection: selection.group) packageSet.groups == resolvedGroupNames
    && builtins.all
      (selection: builtins.elem "${selection.group}#${toString selection.generation}" groupSnapshotKeys)
      packageSet.groups;

  lockTopValid =
    exactAttrs [ "schemaVersion" "familySnapshots" "groupSnapshots" "packageSets" "defaultPackageSet" ] [ ] lock
    && lock.schemaVersion == 2
    && builtins.isList lock.familySnapshots
    && builtins.isList lock.groupSnapshots
    && builtins.isList lock.packageSets
    && nonEmptyString lock.defaultPackageSet;
  lockRecordsValid =
    lockTopValid
    && builtins.all validFamilySnapshot lock.familySnapshots
    && builtins.all validGroupSnapshot lock.groupSnapshots
    && builtins.all validPackageSet lock.packageSets;

  findOne = description: predicate: values:
    let matches = builtins.filter predicate values;
    in if builtins.length matches == 1
    then builtins.head matches
    else throw "validateFirstPartyPackageSetLock: expected one ${description}";

  project = packageSet:
    let
      selectedGroupSnapshots = map
        (selection: findOne
          "group snapshot ${selection.group}#${toString selection.generation}"
          (snapshot: snapshot.group == selection.group && snapshot.generation == selection.generation)
          lock.groupSnapshots)
        packageSet.groups;
      selectedFamilySnapshots = map
        (selection: findOne
          "family snapshot ${selection.family}#${toString selection.generation}"
          (snapshot: snapshot.family == selection.family && snapshot.generation == selection.generation)
          lock.familySnapshots)
        (lib.concatMap (snapshot: snapshot.families) selectedGroupSnapshots);
      sorted = lib.sort (left: right: left.family < right.family) selectedFamilySnapshots;
      packageNames = lib.concatMap
        (snapshot: map (package: package.name) snapshot.packages)
        sorted;
    in
    if !allUnique packageNames then
      throw "validateFirstPartyPackageSetLock: selected package names must be globally unique"
    else
      sorted;

  packageSetNames = if lockTopValid then map (packageSet: packageSet.name) lock.packageSets else [ ];
  defaultSet =
    if lockTopValid && builtins.elem lock.defaultPackageSet packageSetNames
    then findOne "default package set" (packageSet: packageSet.name == lock.defaultPackageSet) lock.packageSets
    else null;
  projectedSetsValid =
    lockRecordsValid
    && builtins.all (packageSet: builtins.deepSeq (project packageSet) true) lock.packageSets;

  validation =
    if !configTopValid then
      throw "validateFirstPartyPackageSetLock: family config must use schemaVersion 2 and exact top-level fields"
    else if !configValid then
      throw "validateFirstPartyPackageSetLock: family config or update-group partition is invalid"
    else if !lockTopValid then
      throw "validateFirstPartyPackageSetLock: package-set lock must use schemaVersion 2 and exact top-level fields"
    else if !lockRecordsValid then
      throw "validateFirstPartyPackageSetLock: a snapshot, reference, package set, or policy is invalid"
    else if !isSortedBy familySnapshotLess lock.familySnapshots || !allUnique familySnapshotKeys then
      throw "validateFirstPartyPackageSetLock: family snapshot keys must be unique and sorted"
    else if familySnapshotFamilies != configFamilyNames then
      throw "validateFirstPartyPackageSetLock: catalog topology migration required: configured families differ from retained snapshots"
    else if !isSortedBy groupSnapshotLess lock.groupSnapshots || !allUnique groupSnapshotKeys then
      throw "validateFirstPartyPackageSetLock: group snapshot keys must be unique and sorted"
    else if groupSnapshotGroups != resolvedGroupNames then
      throw "validateFirstPartyPackageSetLock: catalog topology migration required: resolved groups differ from retained snapshots"
    else if !isSorted packageSetNames || !allUnique packageSetNames then
      throw "validateFirstPartyPackageSetLock: package set names must be unique and sorted"
    else if defaultSet == null then
      throw "validateFirstPartyPackageSetLock: defaultPackageSet does not name a declared set"
    else if defaultSet.supportLevel != "curated" then
      throw "validateFirstPartyPackageSetLock: defaultPackageSet must be curated"
    else if !projectedSetsValid then
      throw "validateFirstPartyPackageSetLock: package-set projection failed"
    else
      true;

  select = name:
    project (findOne "package set ${name}" (packageSet: packageSet.name == name) lock.packageSets);
in
builtins.seq validation {
  inherit resolvedGroups select;
}
