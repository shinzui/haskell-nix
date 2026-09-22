module HaskellNix.Update.PackageLock
  ( decodePackageLock,
    decodePackageLockForRefresh,
    encodePackageLock,
    validatePackageLock,
    decodePackageSetLock,
    encodePackageSetLock,
    validatePackageSetLock,
    selectPackageSet,
    migrateLegacyPackageLock,
    importLegacyPackageLock,
  )
where

import Control.Monad (foldM, unless)
import Data.Aeson
import Data.Aeson.Encode.Pretty (Config (..), defConfig, encodePretty')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAlphaNum, isHexDigit)
import Data.Foldable (traverse_)
import Data.List (find, sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Pretty (prettyShow)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Catalog (resolveUpdateGroups, validateFamilyCatalog)
import HaskellNix.Update.Types
import System.FilePath (isAbsolute, splitDirectories)

decodePackageLock :: FamilyCatalog -> ByteString -> Either Text PackageLock
decodePackageLock catalog bytes = do
  packageLock <- decodePackageLockBytes bytes
  validatePackageLock catalog packageLock

decodePackageLockForRefresh :: FamilyCatalog -> ByteString -> Either Text PackageLock
decodePackageLockForRefresh catalog bytes = do
  packageLock <- decodePackageLockBytes bytes
  validatePackageLockForRefresh catalog packageLock

decodePackageLockBytes :: ByteString -> Either Text PackageLock
decodePackageLockBytes bytes = do
  value <- firstText (eitherDecodeStrict' bytes)
  firstText (parseEither parsePackageLock value)

encodePackageLock :: PackageLock -> LazyByteString.ByteString
encodePackageLock = (<> "\n") . encodePretty' prettyConfig . packageLockValue

validatePackageLock :: FamilyCatalog -> PackageLock -> Either Text PackageLock
validatePackageLock = validatePackageLockAgainstCatalog False

validatePackageLockForRefresh :: FamilyCatalog -> PackageLock -> Either Text PackageLock
validatePackageLockForRefresh = validatePackageLockAgainstCatalog True

validatePackageLockAgainstCatalog :: Bool -> FamilyCatalog -> PackageLock -> Either Text PackageLock
validatePackageLockAgainstCatalog allowMissingConfigured catalog packageLock@(PackageLock schemaVersion lockedFamilies)
  | schemaVersion /= 1 = Left "package lock schemaVersion must be 1"
  | lockedNames /= sort lockedNames = Left "package-lock families must be sorted by name"
  | Set.size (Set.fromList lockedNames) /= length lockedNames = Left "package-lock family names must be unique"
  | Set.size (Set.fromList packageNames) /= length packageNames = Left "package names must be globally unique"
  | allowMissingConfigured && not (lockedNameSet `Set.isSubsetOf` configuredNameSet) =
      Left "package lock contains a family absent from the family config"
  | not allowMissingConfigured && configuredNames /= lockedNames =
      Left "family config and package lock family names do not match"
  | otherwise = traverse_ validateCross lockedFamilies >> Right packageLock
  where
    FamilyCatalog _ configuredFamilies _ = catalog
    configuredNames = [name | FamilyConfig {name} <- configuredFamilies]
    lockedNames = [name | LockedFamily {name} <- lockedFamilies]
    configuredNameSet = Set.fromList configuredNames
    lockedNameSet = Set.fromList lockedNames
    packageNames = [name | LockedFamily {packages} <- lockedFamilies, LockedPackage {name} <- packages]
    configuredByName = Map.fromList [(name, family) | family@FamilyConfig {name} <- configuredFamilies]

    validateCross lockedFamily@LockedFamily {name} = do
      validateLockedFamily lockedFamily
      configuredFamily <- maybe (Left "package-lock family is not configured") Right (Map.lookup name configuredByName)
      validateFamilyAgreement configuredFamily lockedFamily

validateLockedFamily :: LockedFamily -> Either Text ()
validateLockedFamily LockedFamily {name = FamilyName familyName, githubInput, githubRev = GitRevision githubRev, packages}
  | Text.null familyName = Left "locked family name must not be empty"
  | Text.null githubInput = Left ("family " <> familyName <> " has an empty GitHub input")
  | not (validRevision githubRev) = Left ("family " <> familyName <> " has a malformed Git revision")
  | names /= sort names = Left ("family " <> familyName <> " packages must be sorted by name")
  | Set.size (Set.fromList names) /= length names = Left ("family " <> familyName <> " package names must be unique")
  | otherwise = traverse_ (validateLockedPackage familyName) packages
  where
    names = [name | LockedPackage {name} <- packages]

validateLockedPackage :: Text -> LockedPackage -> Either Text ()
validateLockedPackage familyName LockedPackage {name = PackageName packageName, path, hackage}
  | Text.null packageName = Left ("family " <> familyName <> " contains an empty package name")
  | not (validRelativePath path) = Left ("package " <> packageName <> " has an invalid relative path")
  | maybe False (not . validHackagePin) hackage = Left ("package " <> packageName <> " has an invalid Hackage pin")
  | otherwise = Right ()

validateFamilyAgreement :: FamilyConfig -> LockedFamily -> Either Text ()
validateFamilyAgreement
  FamilyConfig {name = FamilyName familyName, githubInput = configuredInput, packageOverrides}
  LockedFamily {githubInput = lockedInput, packages}
    | configuredInput /= lockedInput = Left ("family " <> familyName <> " GitHub input does not match the config")
    | any (`Set.notMember` packageNameSet) (Map.keysSet packageOverrides) = Left ("family " <> familyName <> " overrides an unknown package")
    | otherwise = traverse_ validateOptions packages
    where
      packageNameSet = Set.fromList [name | LockedPackage {name} <- packages]
      validateOptions LockedPackage {name, cabal2nixOptions}
        | cabal2nixOptions == expectedOptions name = Right ()
        | otherwise = Left ("package " <> packageNameText name <> " Cabal2nix options do not match the config")
      expectedOptions packageName =
        case Map.lookup packageName packageOverrides of
          Nothing -> ""
          Just PackageOverride {cabal2nixOptions} -> cabal2nixOptions

parsePackageLock :: Value -> Parser PackageLock
parsePackageLock = withObject "PackageLock" $ \fields -> do
  rejectUnknown "package lock" ["schemaVersion", "families"] fields
  schemaVersion <- fields .: "schemaVersion"
  familyValues <- fields .: "families"
  families <- traverse parseLockedFamily familyValues
  pure PackageLock {schemaVersion, families}

parseLockedFamily :: Value -> Parser LockedFamily
parseLockedFamily = withObject "LockedFamily" $ \fields -> do
  rejectUnknown "locked family" ["name", "githubInput", "githubRev", "packages"] fields
  name <- FamilyName <$> fields .: "name"
  githubInput <- fields .: "githubInput"
  githubRev <- GitRevision <$> fields .: "githubRev"
  packageValues <- fields .: "packages"
  packages <- traverse parseLockedPackage packageValues
  pure LockedFamily {name, githubInput, githubRev, packages}

parseLockedPackage :: Value -> Parser LockedPackage
parseLockedPackage = withObject "LockedPackage" $ \fields -> do
  rejectUnknown "locked package" ["name", "path", "version", "cabal2nixOptions", "hackage"] fields
  name <- PackageName <$> fields .: "name"
  path <- fields .: "path"
  versionText <- fields .: "version"
  version <- parseVersion versionText
  cabal2nixOptions <- fields .: "cabal2nixOptions"
  hackageValue <- fields .: "hackage"
  hackage <- traverse parseHackagePin hackageValue
  pure LockedPackage {name, path, version, cabal2nixOptions, hackage}

parseHackagePin :: Value -> Parser HackagePin
parseHackagePin = withObject "HackagePin" $ \fields -> do
  rejectUnknown "Hackage pin" ["version", "hash"] fields
  versionText <- fields .: "version"
  version <- parseVersion versionText
  hash <- SriHash <$> fields .: "hash"
  pure HackagePin {version, hash}

parseVersion :: Text -> Parser Version
parseVersion value =
  maybe (fail ("invalid dot-separated version: " <> Text.unpack value)) pure (simpleParsec (Text.unpack value))

packageLockValue :: PackageLock -> Value
packageLockValue PackageLock {schemaVersion, families} =
  object
    [ "schemaVersion" .= schemaVersion,
      "families" .= map lockedFamilyValue families
    ]

lockedFamilyValue :: LockedFamily -> Value
lockedFamilyValue LockedFamily {name = FamilyName name, githubInput, githubRev = GitRevision githubRev, packages} =
  object
    [ "name" .= name,
      "githubInput" .= githubInput,
      "githubRev" .= githubRev,
      "packages" .= map lockedPackageValue packages
    ]

lockedPackageValue :: LockedPackage -> Value
lockedPackageValue LockedPackage {name = PackageName name, path, version, cabal2nixOptions, hackage} =
  object
    [ "name" .= name,
      "path" .= path,
      "version" .= renderVersion version,
      "cabal2nixOptions" .= cabal2nixOptions,
      "hackage" .= fmap hackagePinValue hackage
    ]

hackagePinValue :: HackagePin -> Value
hackagePinValue HackagePin {version, hash = SriHash hash} =
  object
    [ "version" .= renderVersion version,
      "hash" .= hash
    ]

renderVersion :: Version -> Text
renderVersion = Text.pack . prettyShow

validRevision :: Text -> Bool
validRevision value = Text.length value == 40 && Text.all isHexDigit value

-- A package that occupies its whole repository records the root path "."; every
-- other package records a clean relative path below the repository root.
validRelativePath :: FilePath -> Bool
validRelativePath path =
  path == "."
    || ( not (null path)
           && not (isAbsolute path)
           && all validSegment (splitDirectories path)
       )
  where
    validSegment segment = not (null segment) && segment /= "." && segment /= ".."

validHackagePin :: HackagePin -> Bool
validHackagePin HackagePin {hash = SriHash hash} = validSriHash hash

validSriHash :: Text -> Bool
validSriHash value =
  case Text.stripPrefix "sha256-" value of
    Nothing -> False
    Just encoded ->
      Text.length encoded == 44
        && Text.last encoded == '='
        && Text.all validBase64Character (Text.init encoded)
  where
    validBase64Character character = isAlphaNum character || character == '+' || character == '/'

packageNameText :: PackageName -> Text
packageNameText (PackageName name) = name

rejectUnknown :: String -> [Text] -> Object -> Parser ()
rejectUnknown context allowed fields = do
  let allowedKeys = Set.fromList (map Key.fromText allowed)
      unknown = filter (`Set.notMember` allowedKeys) (KeyMap.keys fields)
  unless (null unknown) $ fail (context <> " contains unknown fields: " <> show (map Key.toText unknown))

prettyConfig :: Config
prettyConfig = defConfig {confCompare = compare}

firstText :: Either String value -> Either Text value
firstText = either (Left . Text.pack) Right

decodePackageSetLock :: FamilyCatalog -> ByteString -> Either Text PackageSetLock
decodePackageSetLock catalog bytes = do
  value <- firstText (eitherDecodeStrict' bytes)
  packageSetLock <- firstText (parseEither parsePackageSetLock value)
  validatePackageSetLock catalog packageSetLock

encodePackageSetLock :: PackageSetLock -> LazyByteString.ByteString
encodePackageSetLock = (<> "\n") . encodePretty' prettyConfig . packageSetLockValue

validatePackageSetLock :: FamilyCatalog -> PackageSetLock -> Either Text PackageSetLock
validatePackageSetLock catalog packageSetLock@PackageSetLock {schemaVersion, familySnapshots, groupSnapshots, packageSets, defaultPackageSet}
  | schemaVersion /= 2 = Left "package-set lock schemaVersion must be 2"
  | familySnapshotKeys /= sort familySnapshotKeys = Left "family snapshots must be sorted by family and generation"
  | not (allUnique familySnapshotKeys) = Left "family snapshot keys must be unique"
  | groupSnapshotKeys /= sort groupSnapshotKeys = Left "group snapshots must be sorted by group and generation"
  | not (allUnique groupSnapshotKeys) = Left "group snapshot keys must be unique"
  | packageSetNames /= sort packageSetNames = Left "package sets must be sorted by name"
  | not (allUnique packageSetNames) = Left "package set names must be unique"
  | configuredFamilyNames /= snapshotFamilyNames = topologyError "configured families differ from retained snapshot families"
  | otherwise = do
      _ <- validateFamilyCatalog catalog
      resolvedGroups <- resolveUpdateGroups catalog
      traverse_ (validateFamilySnapshot configuredByName) familySnapshots
      traverse_ (validateGroupSnapshot resolvedGroups familySnapshotKeySet) groupSnapshots
      let resolvedGroupNames = [name | UpdateGroup {name} <- resolvedGroups]
      unless (Set.fromList resolvedGroupNames == Set.fromList [group | GroupSnapshot {group} <- groupSnapshots]) $
        topologyError "resolved update groups differ from retained group snapshots"
      traverse_ (validatePackageSet resolvedGroupNames groupSnapshotKeySet) packageSets
      defaultSet <-
        maybe (Left "defaultPackageSet does not name a declared package set") Right
          (find (\PackageSet {name} -> name == defaultPackageSet) packageSets)
      unless (supportLevel defaultSet == Curated) $
        Left "defaultPackageSet must name a curated package set"
      traverse_ (validateProjectedPackageNames packageSetLock) packageSets
      Right packageSetLock
  where
    FamilyCatalog {families = configuredFamilies} = catalog
    configuredFamilyNames = Set.fromList [name | FamilyConfig {name} <- configuredFamilies]
    snapshotFamilyNames = Set.fromList [family | FamilySnapshot {family} <- familySnapshots]
    configuredByName = Map.fromList [(name, family) | family@FamilyConfig {name} <- configuredFamilies]
    familySnapshotKeys = map familySnapshotKey familySnapshots
    familySnapshotKeySet = Set.fromList familySnapshotKeys
    groupSnapshotKeys = map groupSnapshotKey groupSnapshots
    groupSnapshotKeySet = Set.fromList groupSnapshotKeys
    packageSetNames = [name | PackageSet {name} <- packageSets]
    validateProjectedPackageNames lock packageSet@PackageSet {name = packageSetName} = do
      projected <- projectPackageSet lock packageSet
      let packageNames = [name | FamilySnapshot {packages} <- projected, LockedPackage {name} <- packages]
      unless (allUnique packageNames) $
        Left ("package set " <> packageSetName <> " contains duplicate package providers")

validateFamilySnapshot :: Map FamilyName FamilyConfig -> FamilySnapshot -> Either Text ()
validateFamilySnapshot configuredByName snapshot@FamilySnapshot {family, generation, discoveryPolicy, source, packages} = do
  positiveGeneration "family snapshot" generation
  configured <- maybe (topologyError "snapshot family is not configured") Right (Map.lookup family configuredByName)
  validateLockedSource configured source
  validateSnapshotPackages family discoveryPolicy packages
  let FamilySnapshot {family = FamilyName familyName} = snapshot
  unless (not (Text.null familyName)) (Left "family snapshot name must not be empty")

validateLockedSource :: FamilyConfig -> LockedSource -> Either Text ()
validateLockedSource FamilyConfig {name = FamilyName familyName, github} LockedSource {sourceType, owner, repo, rev = GitRevision rev, narHash = SriHash narHash}
  | sourceType /= "github" = Left ("family " <> familyName <> " source type must be github")
  | Text.null owner || Text.null repo = Left ("family " <> familyName <> " source owner and repo must not be empty")
  | owner <> "/" <> repo /= github = topologyError ("family " <> familyName <> " source repository differs from the catalog")
  | not (validRevision rev) = Left ("family " <> familyName <> " source has a malformed Git revision")
  | not (validSriHash narHash) = Left ("family " <> familyName <> " source has a malformed NAR hash")
  | otherwise = Right ()

validateSnapshotPackages :: FamilyName -> DiscoveryPolicy -> [LockedPackage] -> Either Text ()
validateSnapshotPackages (FamilyName familyName) DiscoveryPolicy {packageOverrides, excludedPackages} packages
  | packageNames /= sort packageNames = Left ("family " <> familyName <> " packages must be sorted by name")
  | not (allUnique packageNames) = Left ("family " <> familyName <> " package names must be unique")
  | any (`Set.notMember` packageNameSet) (Map.keysSet packageOverrides) = Left ("family " <> familyName <> " snapshot policy overrides an unknown package")
  | not (Set.null (excludedPackages `Set.intersection` packageNameSet)) = Left ("family " <> familyName <> " snapshot policy excludes a retained package")
  | otherwise = traverse_ validatePackage packages
  where
    packageNames = [name | LockedPackage {name} <- packages]
    packageNameSet = Set.fromList packageNames
    validatePackage package@LockedPackage {name, cabal2nixOptions} = do
      validateLockedPackage familyName package
      unless (cabal2nixOptions == expectedOptions name) $
        Left ("package " <> packageNameText name <> " Cabal2nix options do not match snapshot policy")
    expectedOptions packageName =
      case Map.lookup packageName packageOverrides of
        Nothing -> ""
        Just PackageOverride {cabal2nixOptions} -> cabal2nixOptions

validateGroupSnapshot :: [UpdateGroup] -> Set.Set (FamilyName, SnapshotGeneration) -> GroupSnapshot -> Either Text ()
validateGroupSnapshot resolvedGroups familySnapshotKeys GroupSnapshot {group, generation, families, compatibilityProfile} = do
  positiveGeneration "group snapshot" generation
  expectedGroup <- maybe (topologyError "group snapshot names an unresolved update group") Right (Map.lookup group groupsByName)
  let expectedFamilies = [family | UpdateGroup {families = members} <- [expectedGroup], family <- members]
      selectedFamilies = [family | FamilySnapshotSelection {family} <- families]
      selectedKeys = [(family, selectedGeneration) | FamilySnapshotSelection {family, generation = selectedGeneration} <- families]
  unless (selectedFamilies == expectedFamilies) $
    topologyError "group snapshot membership differs from the resolved update group"
  unless (allUnique selectedKeys) $
    Left "group snapshot family selections must be unique"
  unless (all (`Set.member` familySnapshotKeys) selectedKeys) $
    Left "group snapshot refers to a missing family generation"
  unless (not (Text.null compatibilityProfile)) $
    Left "group snapshot compatibilityProfile must not be empty"
  where
    groupsByName = Map.fromList [(name, updateGroup) | updateGroup@UpdateGroup {name} <- resolvedGroups]

validatePackageSet :: [UpdateGroupName] -> Set.Set (UpdateGroupName, SnapshotGeneration) -> PackageSet -> Either Text ()
validatePackageSet resolvedGroupNames groupSnapshotKeys PackageSet {name, groups}
  | Text.null name = Left "package set name must not be empty"
  | selectedGroupNames /= sort selectedGroupNames = Left ("package set " <> name <> " groups must be sorted")
  | not (allUnique selectedGroupNames) = Left ("package set " <> name <> " selects an update group more than once")
  | selectedGroupNames /= resolvedGroupNames = Left ("package set " <> name <> " must select every resolved update group exactly once")
  | not (all (`Set.member` groupSnapshotKeys) selectedKeys) = Left ("package set " <> name <> " refers to a missing group generation")
  | otherwise = traverse_ (\GroupSelection {generation} -> positiveGeneration "package set selection" generation) groups
  where
    selectedGroupNames = [group | GroupSelection {group} <- groups]
    selectedKeys = [(group, generation) | GroupSelection {group, generation} <- groups]

selectPackageSet :: FamilyCatalog -> PackageSetLock -> Text -> Either Text [FamilySnapshot]
selectPackageSet catalog packageSetLock requestedName = do
  validated <- validatePackageSetLock catalog packageSetLock
  selected <-
    maybe (Left ("package set not found: " <> requestedName)) Right
      (find (\PackageSet {name} -> name == requestedName) (packageSets validated))
  projectPackageSet validated selected

projectPackageSet :: PackageSetLock -> PackageSet -> Either Text [FamilySnapshot]
projectPackageSet PackageSetLock {familySnapshots, groupSnapshots} PackageSet {groups} = do
  selectedGroups <- traverse lookupGroup groups
  selectedFamilies <- traverse lookupFamily (concatMap (\GroupSnapshot {families} -> families) selectedGroups)
  pure (sortOn familySnapshotKey selectedFamilies)
  where
    groupsByKey = Map.fromList [(groupSnapshotKey snapshot, snapshot) | snapshot <- groupSnapshots]
    familiesByKey = Map.fromList [(familySnapshotKey snapshot, snapshot) | snapshot <- familySnapshots]
    lookupGroup GroupSelection {group, generation} =
      maybe (Left "package set refers to a missing group generation") Right (Map.lookup (group, generation) groupsByKey)
    lookupFamily FamilySnapshotSelection {family, generation} =
      maybe (Left "group snapshot refers to a missing family generation") Right (Map.lookup (family, generation) familiesByKey)

migrateLegacyPackageLock :: FamilyCatalog -> Map FamilyName LockedSource -> LegacyPackageLock -> FamilyCatalog -> Text -> Either Text PackageSetLock
migrateLegacyPackageLock
  targetCatalog@FamilyCatalog {schemaVersion = targetSchemaVersion, families = targetFamilies}
  sources
  legacyLock@PackageLock {families = legacyLockedFamilies}
  legacyCatalog@FamilyCatalog {schemaVersion = legacySchemaVersion, families = legacyFamilies}
  targetSetName = do
  _ <- validateFamilyCatalog targetCatalog
  _ <- validateFamilyCatalog legacyCatalog
  unless (targetSchemaVersion == 2) (Left "migration target family catalog must use schemaVersion 2")
  unless (legacySchemaVersion == 1) (Left "migration source family catalog must use schemaVersion 1")
  _ <- validatePackageLock legacyCatalog legacyLock
  let targetNames = Set.fromList [name | FamilyConfig {name} <- targetFamilies]
      legacyNames = Set.fromList [name | FamilyConfig {name} <- legacyFamilies]
      legacyConfigs = Map.fromList [(name, family) | family@FamilyConfig {name} <- legacyFamilies]
  unless (targetNames == legacyNames) (topologyError "migration catalogs contain different families")
  unless (Map.keysSet sources == legacyNames) (Left "locked source map must contain exactly every legacy family")
  migratedFamilies <- traverse (migrateFamily legacyConfigs) legacyLockedFamilies
  resolvedGroups <- resolveUpdateGroups targetCatalog
  let migratedGroups = map migrateGroup resolvedGroups
      selectedGroups = [GroupSelection {group = groupName, generation = SnapshotGeneration 1} | UpdateGroup {name = groupName} <- resolvedGroups]
      migratedSet = PackageSet {name = targetSetName, supportLevel = Curated, groups = selectedGroups}
      migrated =
        PackageSetLock
          { schemaVersion = 2,
            familySnapshots = sortOn familySnapshotKey migratedFamilies,
            groupSnapshots = sortOn groupSnapshotKey migratedGroups,
            packageSets = [migratedSet],
            defaultPackageSet = targetSetName
          }
  validatePackageSetLock targetCatalog migrated
  where
    migrateFamily legacyConfigs LockedFamily {name, githubRev, packages} = do
      configured <- maybe (Left "legacy family is missing from its catalog") Right (Map.lookup name legacyConfigs)
      source <- maybe (Left "legacy family is missing its locked source") Right (Map.lookup name sources)
      unless (rev source == githubRev) $
        Left ("family " <> familyNameText name <> " source revision differs from the legacy lock")
      let FamilyConfig {packageOverrides, excludedPackages} = configured
      pure
        FamilySnapshot
          { family = name,
            generation = SnapshotGeneration 1,
            discoveryPolicy = DiscoveryPolicy {packageOverrides, excludedPackages},
            source,
            packages
          }
    migrateGroup UpdateGroup {name, families} =
      GroupSnapshot
        { group = name,
          generation = SnapshotGeneration 1,
          families = [FamilySnapshotSelection {family, generation = SnapshotGeneration 1} | family <- families],
          compatibilityProfile = "default"
        }

importLegacyPackageLock :: FamilyCatalog -> Map FamilyName LockedSource -> LegacyPackageLock -> FamilyCatalog -> Text -> PackageSetLock -> Either Text PackageSetLock
importLegacyPackageLock targetCatalog sources legacyLock legacyCatalog targetSetName existing = do
  validatedExisting <- validatePackageSetLock targetCatalog existing
  incoming <- migrateLegacyPackageLock targetCatalog sources legacyLock legacyCatalog "migration-import"
  (mergedFamilies, selectedFamilyGenerations) <-
    foldM mergeFamily (familySnapshots validatedExisting, Map.empty) (familySnapshots incoming)
  resolvedGroups <- resolveUpdateGroups targetCatalog
  (mergedGroups, selectedGroupGenerations) <-
    foldM (mergeGroup selectedFamilyGenerations) (groupSnapshots validatedExisting, Map.empty) resolvedGroups
  let importedSet =
        PackageSet
          { name = targetSetName,
            supportLevel = Historical,
            groups =
              [ GroupSelection {group = groupName, generation}
              | (groupName, generation) <- Map.toAscList selectedGroupGenerations
              ]
          }
      mergedSets = sortOn (\PackageSet {name} -> name) (importedSet : filter (\PackageSet {name} -> name /= targetSetName) (packageSets validatedExisting))
      merged =
        validatedExisting
          { familySnapshots = sortOn familySnapshotKey mergedFamilies,
            groupSnapshots = sortOn groupSnapshotKey mergedGroups,
            packageSets = mergedSets
          }
  validatePackageSetLock targetCatalog merged
  where
    mergeFamily (snapshots, generations) candidate@FamilySnapshot {family, discoveryPolicy, source, packages} =
      case find (sameFamilySnapshotContent candidate) snapshots of
        Just FamilySnapshot {generation} -> Right (snapshots, Map.insert family generation generations)
        Nothing ->
          let generation = nextFamilyGeneration family snapshots
              added = FamilySnapshot {family, generation, discoveryPolicy, source, packages}
           in Right (added : snapshots, Map.insert family generation generations)
    mergeGroup selectedFamilies (snapshots, generations) UpdateGroup {name = groupName, families = memberNames} =
      let selected =
            [ FamilySnapshotSelection {family, generation}
            | family <- memberNames,
              Just generation <- [Map.lookup family selectedFamilies]
            ]
          candidate =
            GroupSnapshot
              { group = groupName,
                generation = SnapshotGeneration 1,
                families = selected,
                compatibilityProfile = "default"
              }
       in if length selected /= length memberNames
            then Left "internal migration error: imported family selection is incomplete"
            else case find (sameGroupSnapshotContent candidate) snapshots of
              Just GroupSnapshot {generation} -> Right (snapshots, Map.insert groupName generation generations)
              Nothing ->
                let generation = nextGroupGeneration groupName snapshots
                    added =
                      GroupSnapshot
                        { group = groupName,
                          generation,
                          families = selected,
                          compatibilityProfile = "default"
                        }
                 in Right (added : snapshots, Map.insert groupName generation generations)

parsePackageSetLock :: Value -> Parser PackageSetLock
parsePackageSetLock = withObject "PackageSetLock" $ \fields -> do
  rejectUnknown "package-set lock" ["schemaVersion", "familySnapshots", "groupSnapshots", "packageSets", "defaultPackageSet"] fields
  schemaVersion <- fields .: "schemaVersion"
  familySnapshots <- fields .: "familySnapshots" >>= traverse parseFamilySnapshot
  groupSnapshots <- fields .: "groupSnapshots" >>= traverse parseGroupSnapshot
  packageSets <- fields .: "packageSets" >>= traverse parsePackageSet
  defaultPackageSet <- fields .: "defaultPackageSet"
  pure PackageSetLock {schemaVersion, familySnapshots, groupSnapshots, packageSets, defaultPackageSet}

parseFamilySnapshot :: Value -> Parser FamilySnapshot
parseFamilySnapshot = withObject "FamilySnapshot" $ \fields -> do
  rejectUnknown "family snapshot" ["family", "generation", "discoveryPolicy", "source", "packages"] fields
  family <- FamilyName <$> fields .: "family"
  generation <- SnapshotGeneration <$> fields .: "generation"
  discoveryPolicy <- fields .: "discoveryPolicy" >>= parseDiscoveryPolicy
  source <- fields .: "source" >>= parseLockedSource
  packages <- fields .: "packages" >>= traverse parseLockedPackage
  pure FamilySnapshot {family, generation, discoveryPolicy, source, packages}

parseDiscoveryPolicy :: Value -> Parser DiscoveryPolicy
parseDiscoveryPolicy = withObject "DiscoveryPolicy" $ \fields -> do
  rejectUnknown "discovery policy" ["packageOverrides", "excludedPackages"] fields
  overrideValue <- fields .: "packageOverrides"
  packageOverrides <- parsePackageOverridesValue overrideValue
  excludedNames <- fields .: "excludedPackages"
  unless (excludedNames == sort (excludedNames :: [Text]) && allUnique excludedNames) $
    fail "discovery policy excludedPackages must be sorted and unique"
  let excludedPackages = Set.fromList (map PackageName excludedNames)
  pure DiscoveryPolicy {packageOverrides, excludedPackages}

parsePackageOverridesValue :: Value -> Parser (Map PackageName PackageOverride)
parsePackageOverridesValue = withObject "packageOverrides" $ \fields ->
  Map.fromList <$> traverse parseEntry (KeyMap.toList fields)
  where
    parseEntry (key, value) = do
      packageOverride <- withObject "PackageOverride" parseOverride value
      pure (PackageName (Key.toText key), packageOverride)
    parseOverride fields = do
      rejectUnknown "package override" ["cabal2nixOptions"] fields
      cabal2nixOptions <- fields .:? "cabal2nixOptions" .!= ""
      pure PackageOverride {cabal2nixOptions}

parseLockedSource :: Value -> Parser LockedSource
parseLockedSource = withObject "LockedSource" $ \fields -> do
  rejectUnknown "locked source" ["type", "owner", "repo", "rev", "narHash"] fields
  sourceType <- fields .: "type"
  owner <- fields .: "owner"
  repo <- fields .: "repo"
  rev <- GitRevision <$> fields .: "rev"
  narHash <- SriHash <$> fields .: "narHash"
  pure LockedSource {sourceType, owner, repo, rev, narHash}

parseGroupSnapshot :: Value -> Parser GroupSnapshot
parseGroupSnapshot = withObject "GroupSnapshot" $ \fields -> do
  rejectUnknown "group snapshot" ["group", "generation", "families", "compatibilityProfile"] fields
  group <- UpdateGroupName <$> fields .: "group"
  generation <- SnapshotGeneration <$> fields .: "generation"
  families <- fields .: "families" >>= traverse parseFamilySnapshotSelection
  compatibilityProfile <- fields .: "compatibilityProfile"
  pure GroupSnapshot {group, generation, families, compatibilityProfile}

parseFamilySnapshotSelection :: Value -> Parser FamilySnapshotSelection
parseFamilySnapshotSelection = withObject "FamilySnapshotSelection" $ \fields -> do
  rejectUnknown "family snapshot selection" ["family", "generation"] fields
  family <- FamilyName <$> fields .: "family"
  generation <- SnapshotGeneration <$> fields .: "generation"
  pure FamilySnapshotSelection {family, generation}

parsePackageSet :: Value -> Parser PackageSet
parsePackageSet = withObject "PackageSet" $ \fields -> do
  rejectUnknown "package set" ["name", "supportLevel", "groups"] fields
  name <- fields .: "name"
  supportLevelText <- fields .: "supportLevel"
  supportLevel <- case (supportLevelText :: Text) of
    "curated" -> pure Curated
    "historical" -> pure Historical
    _ -> fail "package set supportLevel must be curated or historical"
  groups <- fields .: "groups" >>= traverse parseGroupSelection
  pure PackageSet {name, supportLevel, groups}

parseGroupSelection :: Value -> Parser GroupSelection
parseGroupSelection = withObject "GroupSelection" $ \fields -> do
  rejectUnknown "group selection" ["group", "generation"] fields
  group <- UpdateGroupName <$> fields .: "group"
  generation <- SnapshotGeneration <$> fields .: "generation"
  pure GroupSelection {group, generation}

packageSetLockValue :: PackageSetLock -> Value
packageSetLockValue PackageSetLock {schemaVersion, familySnapshots, groupSnapshots, packageSets, defaultPackageSet} =
  object
    [ "schemaVersion" .= schemaVersion,
      "familySnapshots" .= map familySnapshotValue familySnapshots,
      "groupSnapshots" .= map groupSnapshotValue groupSnapshots,
      "packageSets" .= map packageSetValue packageSets,
      "defaultPackageSet" .= defaultPackageSet
    ]

familySnapshotValue :: FamilySnapshot -> Value
familySnapshotValue FamilySnapshot {family = FamilyName family, generation = SnapshotGeneration generation, discoveryPolicy, source, packages} =
  object
    [ "family" .= family,
      "generation" .= generation,
      "discoveryPolicy" .= discoveryPolicyValue discoveryPolicy,
      "source" .= lockedSourceValue source,
      "packages" .= map lockedPackageValue packages
    ]

discoveryPolicyValue :: DiscoveryPolicy -> Value
discoveryPolicyValue DiscoveryPolicy {packageOverrides, excludedPackages} =
  object
    [ "packageOverrides" .= Object (KeyMap.fromList (map overrideEntry (Map.toAscList packageOverrides))),
      "excludedPackages" .= [name | PackageName name <- Set.toAscList excludedPackages]
    ]
  where
    overrideEntry (PackageName packageName, PackageOverride {cabal2nixOptions}) =
      (Key.fromText packageName, object ["cabal2nixOptions" .= cabal2nixOptions])

lockedSourceValue :: LockedSource -> Value
lockedSourceValue LockedSource {sourceType, owner, repo, rev = GitRevision rev, narHash = SriHash narHash} =
  object ["type" .= sourceType, "owner" .= owner, "repo" .= repo, "rev" .= rev, "narHash" .= narHash]

groupSnapshotValue :: GroupSnapshot -> Value
groupSnapshotValue GroupSnapshot {group = UpdateGroupName group, generation = SnapshotGeneration generation, families, compatibilityProfile} =
  object
    [ "group" .= group,
      "generation" .= generation,
      "families" .= map familySnapshotSelectionValue families,
      "compatibilityProfile" .= compatibilityProfile
    ]

familySnapshotSelectionValue :: FamilySnapshotSelection -> Value
familySnapshotSelectionValue FamilySnapshotSelection {family = FamilyName family, generation = SnapshotGeneration generation} =
  object ["family" .= family, "generation" .= generation]

packageSetValue :: PackageSet -> Value
packageSetValue PackageSet {name, supportLevel, groups} =
  object
    [ "name" .= name,
      "supportLevel" .= supportLevelValue supportLevel,
      "groups" .= map groupSelectionValue groups
    ]

supportLevelValue :: PackageSetSupportLevel -> Text
supportLevelValue Curated = "curated"
supportLevelValue Historical = "historical"

groupSelectionValue :: GroupSelection -> Value
groupSelectionValue GroupSelection {group = UpdateGroupName group, generation = SnapshotGeneration generation} =
  object ["group" .= group, "generation" .= generation]

familySnapshotKey :: FamilySnapshot -> (FamilyName, SnapshotGeneration)
familySnapshotKey FamilySnapshot {family, generation} = (family, generation)

groupSnapshotKey :: GroupSnapshot -> (UpdateGroupName, SnapshotGeneration)
groupSnapshotKey GroupSnapshot {group, generation} = (group, generation)

positiveGeneration :: Text -> SnapshotGeneration -> Either Text ()
positiveGeneration context (SnapshotGeneration generation) =
  unless (generation > 0) (Left (context <> " generation must be positive"))

allUnique :: Ord value => [value] -> Bool
allUnique values = Set.size (Set.fromList values) == length values

topologyError :: Text -> Either Text value
topologyError detail = Left ("catalog topology migration required: " <> detail)

familyNameText :: FamilyName -> Text
familyNameText (FamilyName familyName) = familyName

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
nextFamilyGeneration requested snapshots =
  SnapshotGeneration (1 + maximum (0 : [generation | FamilySnapshot {family, generation = SnapshotGeneration generation} <- snapshots, family == requested]))

nextGroupGeneration :: UpdateGroupName -> [GroupSnapshot] -> SnapshotGeneration
nextGroupGeneration requested snapshots =
  SnapshotGeneration (1 + maximum (0 : [generation | GroupSnapshot {group, generation = SnapshotGeneration generation} <- snapshots, group == requested]))
