module HaskellNix.Update.Plan
  ( planRefresh,
    planPackageSetRefresh,
    clonePackageSet,
    clonePackageSetWithSupport,
    selectGroupGeneration,
    selectGroupFromPackageSet,
    selectGroupCompatibilityProfile,
    setPackageSetSupportLevel,
    renderChanges,
  )
where

import Control.Monad (foldM, unless)
import Data.List (find, sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Pretty (prettyShow)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Catalog (resolveUpdateGroups)
import HaskellNix.Update.PackageLock (validatePackageLock, validatePackageSetLock)
import HaskellNix.Update.Types

planRefresh :: FamilyCatalog -> PackageLock -> [ObservedFamily] -> Either UpdateError RefreshPlan
planRefresh catalog previousLock observations = do
  rejectDuplicateObservations observations
  replacements <- traverse (buildReplacement previousByName) observations
  let replacementMap = Map.fromList [(name, pair) | pair@(LockedFamily {name}, _) <- replacements]
      unknownNames = Map.keysSet replacementMap `Set.difference` Map.keysSet configuredByName
  if Set.null unknownNames
    then pure ()
    else Left (UpdateError ("observed unknown families: " <> renderFamilyNames (Set.toAscList unknownNames)))
  let nextFamilies =
        sortOn familyKey
          ( [ maybe oldFamily fst (Map.lookup name replacementMap)
              | oldFamily@LockedFamily {name} <- previousFamilies
            ]
              <> [ family
                   | (name, (family, _)) <- Map.toAscList replacementMap,
                     name `Map.notMember` previousByName
                 ]
          )
  let nextPackageLock = PackageLock {schemaVersion = 1, families = nextFamilies}
      familyChanges = concatMap snd replacements
  _ <- firstUpdateError (validatePackageLock catalog nextPackageLock)
  pure RefreshPlan {familyChanges, nextPackageLock}
  where
    FamilyCatalog _ configuredFamilies _ = catalog
    PackageLock _ previousFamilies = previousLock
    configuredByName = Map.fromList [(name, family) | family@FamilyConfig {name} <- configuredFamilies]
    previousByName = Map.fromList [(name, family) | family@LockedFamily {name} <- previousFamilies]
    familyKey LockedFamily {name} = name

buildReplacement :: Map FamilyName LockedFamily -> ObservedFamily -> Either UpdateError (LockedFamily, [FamilyChange])
buildReplacement previousByName ObservedFamily {config, githubRev, packages = observedPackages} = do
  let FamilyConfig {name = familyName, githubInput, packageOverrides} = config
      packageNames = [name | ObservedPackage {discovered = DiscoveredPackage {name}} <- observedPackages]
  if Set.size (Set.fromList packageNames) == length packageNames
    then pure ()
    else Left (UpdateError ("family " <> familyNameText familyName <> " discovered duplicate package names"))
  let lockedPackages = sortOn packageKey (map (lockPackage packageOverrides) observedPackages)
      nextFamily = LockedFamily {name = familyName, githubInput, githubRev, packages = lockedPackages}
      changes =
        maybe
          (concatMap (newPackageChanges familyName) observedPackages)
          (compareFamily familyName githubRev observedPackages)
          (Map.lookup familyName previousByName)
  pure (nextFamily, changes)
  where
    packageKey LockedPackage {name} = name

lockPackage :: Map PackageName PackageOverride -> ObservedPackage -> LockedPackage
lockPackage overrides ObservedPackage {discovered = DiscoveredPackage {name, path, version}, hackage} =
  LockedPackage
    { name,
      path,
      version,
      cabal2nixOptions = maybe "" overrideOptions (Map.lookup name overrides),
      hackage
    }
  where
    overrideOptions PackageOverride {cabal2nixOptions} = cabal2nixOptions

compareFamily :: FamilyName -> GitRevision -> [ObservedPackage] -> LockedFamily -> [FamilyChange]
compareFamily familyName nextRevision observedPackages LockedFamily {githubRev = previousRevision, packages = previousPackages} =
  revisionChanges <> packageChanges <> removedChanges
  where
    previousByName = Map.fromList [(name, package) | package@LockedPackage {name} <- previousPackages]
    nextNames = Set.fromList [name | ObservedPackage {discovered = DiscoveredPackage {name}} <- observedPackages]
    revisionChanges =
      [GitHubRevisionChanged familyName previousRevision nextRevision | previousRevision /= nextRevision]
    packageChanges = concatMap compareObserved observedPackages
    compareObserved observed@ObservedPackage {discovered = DiscoveredPackage {name}} =
      case Map.lookup name previousByName of
        Nothing -> newPackageChanges familyName observed
        Just previousPackage -> comparePackage familyName observed previousPackage
    removedChanges =
      [ PackageRemoved familyName name
        | LockedPackage {name} <- previousPackages,
          name `Set.notMember` nextNames
      ]

newPackageChanges :: FamilyName -> ObservedPackage -> [FamilyChange]
newPackageChanges familyName ObservedPackage {discovered = DiscoveredPackage {name}, hackage, usedHackageFallback} =
  PackageAdded familyName name : fallbackChange familyName name hackage usedHackageFallback

comparePackage :: FamilyName -> ObservedPackage -> LockedPackage -> [FamilyChange]
comparePackage
  familyName
  ObservedPackage
    { discovered = DiscoveredPackage {name, version = nextVersion},
      hackage = nextHackage,
      usedHackageFallback
    }
  LockedPackage {version = previousVersion, hackage = previousHackage} =
    githubChanges
      <> hackageChanges familyName name previousHackage nextHackage
      <> fallbackChange familyName name nextHackage usedHackageFallback
    where
      githubChanges =
        [GitHubVersionChanged familyName name previousVersion nextVersion | previousVersion /= nextVersion]

hackageChanges :: FamilyName -> PackageName -> Maybe HackagePin -> Maybe HackagePin -> [FamilyChange]
hackageChanges familyName packageName previousPin nextPin =
  case (previousPin, nextPin) of
    (Nothing, Nothing) -> []
    (Nothing, Just HackagePin {version}) -> [HackagePublished familyName packageName version]
    (Just HackagePin {version}, Nothing) -> [HackageUnpublished familyName packageName version]
    (Just HackagePin {version = previousVersion, hash = previousHash}, Just HackagePin {version = nextVersion, hash = nextHash}) ->
      [HackageVersionChanged familyName packageName previousVersion nextVersion | previousVersion /= nextVersion]
        <> [HackageHashChanged familyName packageName previousHash nextHash | previousHash /= nextHash]

fallbackChange :: FamilyName -> PackageName -> Maybe HackagePin -> Bool -> [FamilyChange]
fallbackChange familyName packageName hackagePin usedFallback =
  case (usedFallback, hackagePin) of
    (True, Just HackagePin {version}) -> [HackageFallbackUsed familyName packageName version]
    _ -> []

renderChanges :: [FamilyChange] -> Text
renderChanges [] = "No changes."
renderChanges changes = Text.unlines (map (("- " <>) . renderChange) changes)

renderChange :: FamilyChange -> Text
renderChange = \case
  GitHubRevisionChanged familyName previous next ->
    familyNameText familyName <> ": GitHub revision " <> revisionText previous <> " -> " <> revisionText next
  PackageAdded familyName packageName -> familyPackage familyName packageName <> ": added"
  PackageRemoved familyName packageName -> familyPackage familyName packageName <> ": removed"
  GitHubVersionChanged familyName packageName previous next ->
    familyPackage familyName packageName <> ": GitHub version " <> versionText previous <> " -> " <> versionText next
  HackagePublished familyName packageName version ->
    familyPackage familyName packageName <> ": published on Hackage at " <> versionText version
  HackageUnpublished familyName packageName version ->
    familyPackage familyName packageName <> ": no longer published on Hackage (was " <> versionText version <> ")"
  HackageVersionChanged familyName packageName previous next ->
    familyPackage familyName packageName <> ": Hackage version " <> versionText previous <> " -> " <> versionText next
  HackageHashChanged familyName packageName previous next ->
    familyPackage familyName packageName <> ": Hackage hash " <> hashText previous <> " -> " <> hashText next
  HackageFallbackUsed familyName packageName version ->
    familyPackage familyName packageName <> ": Hackage has no normal release; using " <> versionText version

rejectDuplicateObservations :: [ObservedFamily] -> Either UpdateError ()
rejectDuplicateObservations observations =
  let names = [name | ObservedFamily {config = FamilyConfig {name}} <- observations]
   in if sort names == Set.toAscList (Set.fromList names)
        then Right ()
        else Left (UpdateError "observed family names must be unique")

familyPackage :: FamilyName -> PackageName -> Text
familyPackage familyName packageName = familyNameText familyName <> "/" <> packageNameText packageName

familyNameText :: FamilyName -> Text
familyNameText (FamilyName name) = name

packageNameText :: PackageName -> Text
packageNameText (PackageName name) = name

revisionText :: GitRevision -> Text
revisionText (GitRevision revision) = revision

hashText :: SriHash -> Text
hashText (SriHash hash) = hash

versionText :: Version -> Text
versionText = Text.pack . prettyShow

renderFamilyNames :: [FamilyName] -> Text
renderFamilyNames = Text.intercalate ", " . map familyNameText

firstUpdateError :: Either Text value -> Either UpdateError value
firstUpdateError = either (Left . UpdateError) Right

planPackageSetRefresh :: FamilyCatalog -> PackageSetLock -> Text -> [(UpdateGroup, Text, [SnapshotObservation])] -> Either UpdateError PackageSetRefreshPlan
planPackageSetRefresh catalog previousLock targetSetName targets = do
  validated <- firstUpdateError (validatePackageSetLock catalog previousLock)
  resolvedGroups <- firstUpdateError (resolveUpdateGroups catalog)
  targetSet <- findPackageSet targetSetName validated
  unless (supportLevel targetSet == Curated) $
    Left (UpdateError ("cannot refresh historical package set " <> targetSetName))
  rejectDuplicateTargetGroups targets
  let resolvedByName = Map.fromList [(name, group) | group@UpdateGroup {name} <- resolvedGroups]
  (familiesAfter, familySelections) <-
    foldM (planTargetFamilies resolvedByName) (familySnapshots validated, Map.empty) targets
  (groupsAfter, groupSelections) <-
    foldM (planTargetGroup familySelections) (groupSnapshots validated, Map.empty) targets
  let movedSet =
        targetSet
          { groups =
              sortOn groupSelectionKey
                [ Map.findWithDefault selection group groupSelections
                | selection@GroupSelection {group} <- groups targetSet
                ]
          }
      candidate =
        validated
          { familySnapshots = sortOn familySnapshotKey familiesAfter,
            groupSnapshots = sortOn groupSnapshotKey groupsAfter,
            packageSets =
              sortOn packageSetKey
                (movedSet : filter ((/= targetSetName) . packageSetKey) (packageSets validated))
          }
  nextPackageSetLock <- firstUpdateError (validatePackageSetLock catalog candidate)
  pure
    PackageSetRefreshPlan
      { nextPackageSetLock,
        selectedFamilySnapshots = sortOn familySelectionKey (Map.elems familySelections),
        selectedGroupSnapshots = sortOn groupSelectionKey (Map.elems groupSelections)
      }
  where
    planTargetFamilies resolvedByName (snapshots, selections) (requestedGroup@UpdateGroup {name = groupName}, _, observations) = do
      resolved <-
        maybe
          (Left (UpdateError ("unknown update group " <> groupNameText groupName)))
          Right
          (Map.lookup groupName resolvedByName)
      unless (requestedGroup == resolved) $
        Left (UpdateError ("update group membership does not match catalog for " <> groupNameText groupName))
      let UpdateGroup {families = expectedNames} = resolved
          observedNames = sort [name | SnapshotObservation {config = FamilyConfig {name}} <- observations]
      unless (observedNames == expectedNames) $
        Left (UpdateError ("observations do not cover update group " <> groupNameText groupName))
      foldM planFamily (snapshots, selections) observations
    planFamily (snapshots, selections) observation@SnapshotObservation {config = FamilyConfig {name}} = do
      candidate <- snapshotFromObservation observation
      let selected =
            case find (sameFamilySnapshotContent candidate) snapshots of
              Just existing -> existing
              Nothing -> withFamilyGeneration (nextFamilyGeneration name snapshots) candidate
          nextSnapshots =
            if any ((== familySnapshotKey selected) . familySnapshotKey) snapshots
              then snapshots
              else selected : snapshots
          FamilySnapshot {generation = selectedGeneration} = selected
          selection = FamilySnapshotSelection {family = name, generation = selectedGeneration}
      pure (nextSnapshots, Map.insert name selection selections)
    planTargetGroup familySelections (snapshots, selections) (UpdateGroup {name = groupName, families = memberNames}, profile, _) = do
      members <- traverse lookupMember memberNames
      let candidate =
            GroupSnapshot
              { group = groupName,
                generation = SnapshotGeneration 1,
                families = members,
                compatibilityProfile = profile
              }
          selected =
            case find (sameGroupSnapshotContent candidate) snapshots of
              Just existing -> existing
              Nothing -> withGroupGeneration (nextGroupGeneration groupName snapshots) candidate
          nextSnapshots =
            if any ((== groupSnapshotKey selected) . groupSnapshotKey) snapshots
              then snapshots
              else selected : snapshots
          GroupSnapshot {generation = selectedGeneration} = selected
          selection = GroupSelection {group = groupName, generation = selectedGeneration}
      unless (not (Text.null profile)) $
        Left (UpdateError "compatibility profile must not be empty")
      pure (nextSnapshots, Map.insert groupName selection selections)
      where
        lookupMember familyName =
          maybe
            (Left (UpdateError ("missing family observation for " <> familyNameText familyName)))
            Right
            (Map.lookup familyName familySelections)

clonePackageSet :: Text -> Text -> PackageSetLock -> Either UpdateError PackageSetLock
clonePackageSet sourceName targetName = clonePackageSetWithSupport sourceName targetName Historical

clonePackageSetWithSupport :: Text -> Text -> PackageSetSupportLevel -> PackageSetLock -> Either UpdateError PackageSetLock
clonePackageSetWithSupport sourceName targetName targetSupport lock@PackageSetLock {packageSets}
  | Text.null targetName = Left (UpdateError "target package-set name must not be empty")
  | any ((== targetName) . packageSetKey) packageSets = Left (UpdateError ("package set already exists: " <> targetName))
  | otherwise = do
      sourceSet <- findPackageSet sourceName lock
      let cloned = sourceSet {name = targetName, supportLevel = targetSupport}
      pure lock {packageSets = sortOn packageSetKey (cloned : packageSets)}

selectGroupGeneration :: Text -> UpdateGroupName -> SnapshotGeneration -> PackageSetLock -> Either UpdateError PackageSetLock
selectGroupGeneration targetName groupName targetGeneration lock@PackageSetLock {groupSnapshots} = do
  unless (targetGeneration > SnapshotGeneration 0) $
    Left (UpdateError "group generation must be positive")
  unless (any ((== (groupName, targetGeneration)) . groupSnapshotKey) groupSnapshots) $
    Left (UpdateError "selected group generation does not exist")
  replacePackageSet targetName (replaceSelection groupName targetGeneration) lock

selectGroupFromPackageSet :: Text -> UpdateGroupName -> Text -> PackageSetLock -> Either UpdateError PackageSetLock
selectGroupFromPackageSet targetName groupName sourceName lock = do
  sourceSet <- findPackageSet sourceName lock
  sourceSelection <- findGroupSelection groupName sourceSet
  let GroupSelection {generation = sourceGeneration} = sourceSelection
  selectGroupGeneration targetName groupName sourceGeneration lock

selectGroupCompatibilityProfile :: Text -> UpdateGroupName -> Text -> PackageSetLock -> Either UpdateError PackageSetLock
selectGroupCompatibilityProfile targetName groupName profile lock@PackageSetLock {groupSnapshots}
  | Text.null profile = Left (UpdateError "compatibility profile must not be empty")
  | otherwise = do
      targetSet <- findPackageSet targetName lock
      currentSelection <- findGroupSelection groupName targetSet
      currentSnapshot <- findGroupSnapshot currentSelection lock
      let candidate = currentSnapshot {generation = SnapshotGeneration 1, compatibilityProfile = profile}
          selected =
            case find (sameGroupSnapshotContent candidate) groupSnapshots of
              Just existing -> existing
              Nothing -> withGroupGeneration (nextGroupGeneration groupName groupSnapshots) candidate
          nextGroups =
            if any ((== groupSnapshotKey selected) . groupSnapshotKey) groupSnapshots
              then groupSnapshots
              else sortOn groupSnapshotKey (selected : groupSnapshots)
      let GroupSnapshot {generation = selectedGeneration} = selected
      moved <- selectGroupGeneration targetName groupName selectedGeneration (lock {groupSnapshots = nextGroups})
      pure moved

setPackageSetSupportLevel :: Text -> PackageSetSupportLevel -> PackageSetLock -> Either UpdateError PackageSetLock
setPackageSetSupportLevel targetName targetSupport lock@PackageSetLock {defaultPackageSet}
  | targetName == defaultPackageSet && targetSupport /= Curated =
      Left (UpdateError "cannot demote the default package set")
  | otherwise = replacePackageSet targetName (\packageSet -> packageSet {supportLevel = targetSupport}) lock

snapshotFromObservation :: SnapshotObservation -> Either UpdateError FamilySnapshot
snapshotFromObservation SnapshotObservation {config, sourceDescriptor, packages = observedPackages} = do
  let FamilyConfig {name = familyName, packageOverrides, excludedPackages} = config
      packageNames = [name | ObservedPackage {discovered = DiscoveredPackage {name}} <- observedPackages]
  unless (sort packageNames == Set.toAscList (Set.fromList packageNames)) $
    Left (UpdateError ("family " <> familyNameText familyName <> " discovered duplicate package names"))
  pure
    FamilySnapshot
      { family = familyName,
        generation = SnapshotGeneration 1,
        discoveryPolicy = DiscoveryPolicy {packageOverrides, excludedPackages},
        source = sourceDescriptor,
        packages = sortOn lockedPackageKey (map (lockPackage packageOverrides) observedPackages)
      }

replacePackageSet :: Text -> (PackageSet -> PackageSet) -> PackageSetLock -> Either UpdateError PackageSetLock
replacePackageSet targetName transform lock@PackageSetLock {packageSets} = do
  target <- findPackageSet targetName lock
  let replacement = transform target
  pure lock {packageSets = sortOn packageSetKey (replacement : filter ((/= targetName) . packageSetKey) packageSets)}

replaceSelection :: UpdateGroupName -> SnapshotGeneration -> PackageSet -> PackageSet
replaceSelection groupName targetGeneration packageSet@PackageSet {groups} =
  packageSet
    { groups =
        sortOn groupSelectionKey
          [ if group == groupName
              then GroupSelection {group, generation = targetGeneration}
              else selection
          | selection@GroupSelection {group} <- groups
          ]
    }

findPackageSet :: Text -> PackageSetLock -> Either UpdateError PackageSet
findPackageSet requestedName PackageSetLock {packageSets} =
  maybe
    (Left (UpdateError ("package set not found: " <> requestedName)))
    Right
    (find ((== requestedName) . packageSetKey) packageSets)

findGroupSelection :: UpdateGroupName -> PackageSet -> Either UpdateError GroupSelection
findGroupSelection requestedGroup PackageSet {name, groups} =
  maybe
    (Left (UpdateError ("package set " <> name <> " does not select group " <> groupNameText requestedGroup)))
    Right
    (find ((== requestedGroup) . groupSelectionKey) groups)

findGroupSnapshot :: GroupSelection -> PackageSetLock -> Either UpdateError GroupSnapshot
findGroupSnapshot selection PackageSetLock {groupSnapshots} =
  maybe (Left (UpdateError "selected group snapshot does not exist")) Right
    (find ((== groupSelectionSnapshotKey selection) . groupSnapshotKey) groupSnapshots)

rejectDuplicateTargetGroups :: [(UpdateGroup, Text, [SnapshotObservation])] -> Either UpdateError ()
rejectDuplicateTargetGroups targets =
  let names = [name | (UpdateGroup {name}, _, _) <- targets]
   in unless (sort names == Set.toAscList (Set.fromList names)) $
        Left (UpdateError "target update groups must be unique")

sameFamilySnapshotContent :: FamilySnapshot -> FamilySnapshot -> Bool
sameFamilySnapshotContent
  FamilySnapshot {family = leftFamily, discoveryPolicy = leftPolicy, source = leftSource, packages = leftPackages}
  FamilySnapshot {family = rightFamily, discoveryPolicy = rightPolicy, source = rightSource, packages = rightPackages} =
    leftFamily == rightFamily
      && leftPolicy == rightPolicy
      && leftSource == rightSource
      && leftPackages == rightPackages

sameGroupSnapshotContent :: GroupSnapshot -> GroupSnapshot -> Bool
sameGroupSnapshotContent
  GroupSnapshot {group = leftGroup, families = leftFamilies, compatibilityProfile = leftProfile}
  GroupSnapshot {group = rightGroup, families = rightFamilies, compatibilityProfile = rightProfile} =
    leftGroup == rightGroup
      && leftFamilies == rightFamilies
      && leftProfile == rightProfile

nextFamilyGeneration :: FamilyName -> [FamilySnapshot] -> SnapshotGeneration
nextFamilyGeneration familyName snapshots =
  nextGeneration [generation | FamilySnapshot {family, generation} <- snapshots, family == familyName]

nextGroupGeneration :: UpdateGroupName -> [GroupSnapshot] -> SnapshotGeneration
nextGroupGeneration groupName snapshots =
  nextGeneration [generation | GroupSnapshot {group, generation} <- snapshots, group == groupName]

nextGeneration :: [SnapshotGeneration] -> SnapshotGeneration
nextGeneration [] = SnapshotGeneration 1
nextGeneration generations = SnapshotGeneration (1 + maximum [value | SnapshotGeneration value <- generations])

familySnapshotKey :: FamilySnapshot -> (FamilyName, SnapshotGeneration)
familySnapshotKey FamilySnapshot {family, generation} = (family, generation)

groupSnapshotKey :: GroupSnapshot -> (UpdateGroupName, SnapshotGeneration)
groupSnapshotKey GroupSnapshot {group, generation} = (group, generation)

groupSelectionSnapshotKey :: GroupSelection -> (UpdateGroupName, SnapshotGeneration)
groupSelectionSnapshotKey GroupSelection {group, generation} = (group, generation)

familySelectionKey :: FamilySnapshotSelection -> FamilyName
familySelectionKey FamilySnapshotSelection {family} = family

groupSelectionKey :: GroupSelection -> UpdateGroupName
groupSelectionKey GroupSelection {group} = group

packageSetKey :: PackageSet -> Text
packageSetKey PackageSet {name} = name

lockedPackageKey :: LockedPackage -> PackageName
lockedPackageKey LockedPackage {name} = name

groupNameText :: UpdateGroupName -> Text
groupNameText (UpdateGroupName name) = name

withFamilyGeneration :: SnapshotGeneration -> FamilySnapshot -> FamilySnapshot
withFamilyGeneration generation FamilySnapshot {family, discoveryPolicy, source, packages} =
  FamilySnapshot {family, generation, discoveryPolicy, source, packages}

withGroupGeneration :: SnapshotGeneration -> GroupSnapshot -> GroupSnapshot
withGroupGeneration generation GroupSnapshot {group, families, compatibilityProfile} =
  GroupSnapshot {group, generation, families, compatibilityProfile}
