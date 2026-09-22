module PackageSetTest (tests) where

import Data.ByteString.Lazy qualified as LazyByteString
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Catalog (decodeFamilyCatalog, encodeFamilyCatalog, resolveUpdateGroups)
import HaskellNix.Update.PackageLock
import HaskellNix.Update.Types
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
  testGroup
    "package-set lock"
    [ testCase "version-2 catalog and lock round-trip canonically" testRoundTrip,
      testCase "explicit and singleton update groups resolve deterministically" testResolveGroups,
      testCase "invalid structural and reference cases are rejected" testInvalidCases,
      testCase "strict JSON rejects unknown source fields and support levels" testStrictJson,
      testCase "selection can move OKF while retaining Keiro" testProjection,
      testCase "snapshot policy is independent of current catalog policy" testHistoricalPolicy,
      testCase "catalog topology changes require migration" testTopologyBoundary,
      testCase "legacy migration and historical import are deterministic" testMigration
    ]

testRoundTrip :: Assertion
testRoundTrip = do
  let catalogBytes = LazyByteString.toStrict (encodeFamilyCatalog validCatalog)
      lockBytes = LazyByteString.toStrict (encodePackageSetLock validLock)
  decodeFamilyCatalog catalogBytes @?= Right validCatalog
  decodePackageSetLock validCatalog lockBytes @?= Right validLock
  decoded <- assertRight (decodePackageSetLock validCatalog lockBytes)
  encodePackageSetLock decoded @?= encodePackageSetLock validLock

testResolveGroups :: Assertion
testResolveGroups =
  resolveUpdateGroups validCatalog
    @?= Right
      [ UpdateGroup (UpdateGroupName "baikai-shikumi") [FamilyName "baikai", FamilyName "shikumi"],
        UpdateGroup (UpdateGroupName "keiro") [FamilyName "keiro"],
        UpdateGroup (UpdateGroupName "okf") [FamilyName "okf"]
      ]

testInvalidCases :: Assertion
testInvalidCases =
  mapM_
    (\(label, candidate) -> assertLeft label (validatePackageSetLock validCatalog candidate))
    [ ("unknown group", mapSets (mapSetGroups (map (replaceGroup "okf" "unknown"))) validLock),
      ("missing group", mapSets (mapSetGroups (filter ((/= UpdateGroupName "okf") . selectionGroupName))) validLock),
      ("wrong group membership", mapGroups (mapGroupFamilies "baikai-shikumi" (take 1)) validLock),
      ("missing family generation", mapGroups (mapGroupFamilyGeneration "okf" 99) validLock),
      ("duplicate family snapshot", validLock {familySnapshots = familySnapshots validLock <> take 1 (familySnapshots validLock)}),
      ("non-positive generation", mapFamilies (mapFamilyGeneration "baikai" 0) validLock),
      ("historical default", mapSets (mapSetSupport "default" Historical) validLock),
      ("default set not found", validLock {defaultPackageSet = "missing"}),
      ("duplicate package provider", mapFamilies (mapPackageName "keiro" "baikai") validLock),
      ("snapshot policy mismatch", mapFamilies (mapOptions "okf" 1 "wrong") validLock)
    ]

testStrictJson :: Assertion
testStrictJson = do
  let encoded = Text.decodeUtf8 (LazyByteString.toStrict (encodePackageSetLock validLock))
      unknownSource = Text.replace "\"type\": \"github\"" "\"mutable\": true, \"type\": \"github\"" encoded
      unknownSupport = Text.replace "\"supportLevel\": \"curated\"" "\"supportLevel\": \"unsupported\"" encoded
  assertLeft "unknown locked-source field" (decodePackageSetLock validCatalog (Text.encodeUtf8 unknownSource))
  assertLeft "unknown support level" (decodePackageSetLock validCatalog (Text.encodeUtf8 unknownSupport))

testProjection :: Assertion
testProjection = do
  defaultFamilies <- assertRight (selectPackageSet validCatalog validLock "default")
  historicalFamilies <- assertRight (selectPackageSet validCatalog validLock "historical")
  generationOf "keiro" defaultFamilies @?= SnapshotGeneration 1
  generationOf "keiro" historicalFamilies @?= SnapshotGeneration 1
  generationOf "okf" defaultFamilies @?= SnapshotGeneration 2
  generationOf "okf" historicalFamilies @?= SnapshotGeneration 1

testHistoricalPolicy :: Assertion
testHistoricalPolicy = do
  _ <- assertRight (validatePackageSetLock validCatalog validLock)
  let changedCurrentPolicy = mapCatalogFamily "okf" (withExcludedPackages (Set.singleton (PackageName "retired"))) validCatalog
  _ <- assertRight (validatePackageSetLock changedCurrentPolicy validLock)
  assertLeft "malformed snapshot policy" (validatePackageSetLock validCatalog (mapFamilies (mapOptions "okf" 1 "wrong") validLock))

testTopologyBoundary :: Assertion
testTopologyBoundary = do
  let FamilyCatalog {families = currentFamilies, updateGroups = currentGroups} = validCatalog
      extraFamily = familyConfig "zeta"
      added = FamilyCatalog {schemaVersion = 2, families = currentFamilies <> [extraFamily], updateGroups = currentGroups}
      regrouped = validCatalog {updateGroups = [UpdateGroup (UpdateGroupName "all-ai") [FamilyName "baikai", FamilyName "shikumi"]]}
  assertMigrationRequired (validatePackageSetLock added validLock)
  assertMigrationRequired (validatePackageSetLock regrouped validLock)

testMigration :: Assertion
testMigration = do
  migrated <- assertRight (migrateLegacyPackageLock validCatalog legacySources legacyLock legacyCatalog "default")
  projected <- assertRight (selectPackageSet validCatalog migrated "default")
  let PackageLock {families = legacyFamilies} = legacyLock
  map familyRevision projected @?= map lockedRevision legacyFamilies
  let changedLock = mapLegacyFamily "okf" changeHackage legacyLock
  imported <- assertRight (importLegacyPackageLock validCatalog legacySources changedLock legacyCatalog "historical" migrated)
  importedAgain <- assertRight (importLegacyPackageLock validCatalog legacySources changedLock legacyCatalog "historical" imported)
  encodePackageSetLock importedAgain @?= encodePackageSetLock imported
  generationOf "okf" (familySnapshots imported) @?= SnapshotGeneration 2
  generationOf "keiro" (familySnapshots imported) @?= SnapshotGeneration 1
  let mismatchedSources = Map.adjust (\source -> source {rev = GitRevision revisionB}) (FamilyName "okf") legacySources
  assertLeft "source revision mismatch" (migrateLegacyPackageLock validCatalog mismatchedSources legacyLock legacyCatalog "default")
  where
    changeHackage LockedFamily {name, githubInput, githubRev, packages} =
      LockedFamily {name, githubInput, githubRev, packages = map changePackage packages}
    changePackage LockedPackage {name, path, version, cabal2nixOptions, hackage = Just HackagePin {hash}} =
      LockedPackage {name, path, version, cabal2nixOptions, hackage = Just HackagePin {version = testVersion "2.0", hash}}
    changePackage package = package

validCatalog :: FamilyCatalog
validCatalog =
  FamilyCatalog
    { schemaVersion = 2,
      families = map familyConfig ["baikai", "keiro", "okf", "shikumi"],
      updateGroups = [UpdateGroup (UpdateGroupName "baikai-shikumi") [FamilyName "baikai", FamilyName "shikumi"]]
    }

legacyCatalog :: FamilyCatalog
legacyCatalog = validCatalog {schemaVersion = 1, updateGroups = []}

familyConfig :: Text -> FamilyConfig
familyConfig familyName =
  FamilyConfig
    { name = FamilyName familyName,
      moriProject = "shinzui/" <> familyName,
      github = "shinzui/" <> familyName,
      githubInput = familyName <> "-src",
      packageOverrides = Map.empty,
      excludedPackages = Set.empty
    }

validLock :: PackageSetLock
validLock =
  PackageSetLock
    { schemaVersion = 2,
      familySnapshots =
        [ mkSnapshot "baikai" 1 "" revisionA,
          mkSnapshot "keiro" 1 "" revisionA,
          mkSnapshot "okf" 1 "-flegacy" revisionA,
          mkSnapshot "okf" 2 "" revisionB,
          mkSnapshot "shikumi" 1 "" revisionA
        ],
      groupSnapshots =
        [ groupSnapshot "baikai-shikumi" 1 [("baikai", 1), ("shikumi", 1)],
          groupSnapshot "keiro" 1 [("keiro", 1)],
          groupSnapshot "okf" 1 [("okf", 1)],
          groupSnapshot "okf" 2 [("okf", 2)]
        ],
      packageSets =
        [ packageSet "default" Curated [("baikai-shikumi", 1), ("keiro", 1), ("okf", 2)],
          packageSet "historical" Historical [("baikai-shikumi", 1), ("keiro", 1), ("okf", 1)]
        ],
      defaultPackageSet = "default"
    }

mkSnapshot :: Text -> Int -> Text -> Text -> FamilySnapshot
mkSnapshot familyName generation options revision =
  FamilySnapshot
    { family = FamilyName familyName,
      generation = SnapshotGeneration generation,
      discoveryPolicy =
        DiscoveryPolicy
          { packageOverrides =
              if Text.null options
                then Map.empty
                else Map.singleton (PackageName familyName) (PackageOverride options),
            excludedPackages = Set.empty
          },
      source = lockedSource familyName revision,
      packages = [lockedPackage familyName options]
    }

lockedSource :: Text -> Text -> LockedSource
lockedSource familyName revision =
  LockedSource
    { sourceType = "github",
      owner = "shinzui",
      repo = familyName,
      rev = GitRevision revision,
      narHash = hashA
    }

groupSnapshot :: Text -> Int -> [(Text, Int)] -> GroupSnapshot
groupSnapshot snapshotGroupName generation selectedFamilies =
  GroupSnapshot
    { group = UpdateGroupName snapshotGroupName,
      generation = SnapshotGeneration generation,
      families = [FamilySnapshotSelection (FamilyName familyName) (SnapshotGeneration selectedGeneration) | (familyName, selectedGeneration) <- selectedFamilies],
      compatibilityProfile = "default"
    }

packageSet :: Text -> PackageSetSupportLevel -> [(Text, Int)] -> PackageSet
packageSet setName supportLevel selectedGroups =
  PackageSet
    { name = setName,
      supportLevel,
      groups = [GroupSelection (UpdateGroupName selectedGroupName) (SnapshotGeneration generation) | (selectedGroupName, generation) <- selectedGroups]
    }

legacyLock :: PackageLock
legacyLock =
  PackageLock
    1
    [ legacyFamily familyName
    | familyName <- ["baikai", "keiro", "okf", "shikumi"]
    ]

legacyFamily :: Text -> LockedFamily
legacyFamily familyName =
  LockedFamily
    { name = FamilyName familyName,
      githubInput = familyName <> "-src",
      githubRev = GitRevision revisionA,
      packages = [lockedPackage familyName ""]
    }

lockedPackage :: Text -> Text -> LockedPackage
lockedPackage packageName options =
  LockedPackage
    { name = PackageName packageName,
      path = ".",
      version = testVersion "1.0",
      cabal2nixOptions = options,
      hackage = Just HackagePin {version = testVersion "1.0", hash = hashA}
    }

legacySources :: Map FamilyName LockedSource
legacySources = Map.fromList [(FamilyName familyName, lockedSource familyName revisionA) | familyName <- ["baikai", "keiro", "okf", "shikumi"]]

mapFamilies :: (FamilySnapshot -> FamilySnapshot) -> PackageSetLock -> PackageSetLock
mapFamilies f lock@PackageSetLock {familySnapshots} = lock {familySnapshots = map f familySnapshots}

mapGroups :: (GroupSnapshot -> GroupSnapshot) -> PackageSetLock -> PackageSetLock
mapGroups f lock@PackageSetLock {groupSnapshots} = lock {groupSnapshots = map f groupSnapshots}

mapSets :: (PackageSet -> PackageSet) -> PackageSetLock -> PackageSetLock
mapSets f lock@PackageSetLock {packageSets} = lock {packageSets = map f packageSets}

mapSetGroups :: ([GroupSelection] -> [GroupSelection]) -> PackageSet -> PackageSet
mapSetGroups f set@PackageSet {groups} = set {groups = f groups}

replaceGroup :: Text -> Text -> GroupSelection -> GroupSelection
replaceGroup old new GroupSelection {group = UpdateGroupName currentGroupName, generation}
  | currentGroupName == old = GroupSelection {group = UpdateGroupName new, generation}
  | otherwise = GroupSelection {group = UpdateGroupName currentGroupName, generation}

selectionGroupName :: GroupSelection -> UpdateGroupName
selectionGroupName GroupSelection {group} = group

mapGroupFamilies :: Text -> ([FamilySnapshotSelection] -> [FamilySnapshotSelection]) -> GroupSnapshot -> GroupSnapshot
mapGroupFamilies requested f candidate@GroupSnapshot {group = UpdateGroupName currentGroupName, families}
  | currentGroupName == requested = withGroupFamilies (f families) candidate
  | otherwise = candidate

mapGroupFamilyGeneration :: Text -> Int -> GroupSnapshot -> GroupSnapshot
mapGroupFamilyGeneration requested newGeneration candidate@GroupSnapshot {group = UpdateGroupName currentGroupName, families}
  | currentGroupName == requested = withGroupFamilies (map change families) candidate
  | otherwise = candidate
  where
    change FamilySnapshotSelection {family} = FamilySnapshotSelection {family, generation = SnapshotGeneration newGeneration}

mapFamilyGeneration :: Text -> Int -> FamilySnapshot -> FamilySnapshot
mapFamilyGeneration requested newGeneration candidate@FamilySnapshot {family = FamilyName familyName}
  | familyName == requested = withFamilyGeneration (SnapshotGeneration newGeneration) candidate
  | otherwise = candidate

mapPackageName :: Text -> Text -> FamilySnapshot -> FamilySnapshot
mapPackageName requested newName candidate@FamilySnapshot {family = FamilyName familyName, packages}
  | familyName == requested = withSnapshotPackages (map rename packages) candidate
  | otherwise = candidate
  where
    rename LockedPackage {path, version, cabal2nixOptions, hackage} =
      LockedPackage {name = PackageName newName, path, version, cabal2nixOptions, hackage}

mapOptions :: Text -> Int -> Text -> FamilySnapshot -> FamilySnapshot
mapOptions requested requestedGeneration options candidate@FamilySnapshot {family = FamilyName familyName, generation = SnapshotGeneration currentGeneration, packages}
  | familyName == requested && currentGeneration == requestedGeneration = withSnapshotPackages (map changeOptions packages) candidate
  | otherwise = candidate
  where
    changeOptions LockedPackage {name, path, version, hackage} =
      LockedPackage {name, path, version, cabal2nixOptions = options, hackage}

withSnapshotPackages :: [LockedPackage] -> FamilySnapshot -> FamilySnapshot
withSnapshotPackages packages FamilySnapshot {family, generation, discoveryPolicy, source} =
  FamilySnapshot {family, generation, discoveryPolicy, source, packages}

withFamilyGeneration :: SnapshotGeneration -> FamilySnapshot -> FamilySnapshot
withFamilyGeneration generation FamilySnapshot {family, discoveryPolicy, source, packages} =
  FamilySnapshot {family, generation, discoveryPolicy, source, packages}

withGroupFamilies :: [FamilySnapshotSelection] -> GroupSnapshot -> GroupSnapshot
withGroupFamilies families GroupSnapshot {group, generation, compatibilityProfile} =
  GroupSnapshot {group, generation, families, compatibilityProfile}

withExcludedPackages :: Set.Set PackageName -> FamilyConfig -> FamilyConfig
withExcludedPackages excludedPackages FamilyConfig {name, moriProject, github, githubInput, packageOverrides} =
  FamilyConfig {name, moriProject, github, githubInput, packageOverrides, excludedPackages}

mapSetSupport :: Text -> PackageSetSupportLevel -> PackageSet -> PackageSet
mapSetSupport requested level set@PackageSet {name}
  | name == requested = set {supportLevel = level}
  | otherwise = set

mapCatalogFamily :: Text -> (FamilyConfig -> FamilyConfig) -> FamilyCatalog -> FamilyCatalog
mapCatalogFamily requested f FamilyCatalog {schemaVersion, families, updateGroups} =
  FamilyCatalog
    { schemaVersion,
      families = map (\family@FamilyConfig {name = FamilyName familyName} -> if familyName == requested then f family else family) families,
      updateGroups
    }

mapLegacyFamily :: Text -> (LockedFamily -> LockedFamily) -> PackageLock -> PackageLock
mapLegacyFamily requested f PackageLock {schemaVersion, families} =
  PackageLock
    { schemaVersion,
      families = map (\family@LockedFamily {name = FamilyName familyName} -> if familyName == requested then f family else family) families
    }

generationOf :: Text -> [FamilySnapshot] -> SnapshotGeneration
generationOf requested snapshots =
  case [generation | FamilySnapshot {family = FamilyName familyName, generation} <- snapshots, familyName == requested] of
    generations -> maximum generations

familyRevision :: FamilySnapshot -> GitRevision
familyRevision FamilySnapshot {source = LockedSource {rev}} = rev

lockedRevision :: LockedFamily -> GitRevision
lockedRevision LockedFamily {githubRev} = githubRev

assertLeft :: Show value => String -> Either Text value -> Assertion
assertLeft _ (Left _) = pure ()
assertLeft label (Right value) = assertFailure (label <> ": expected failure, got " <> show value)

assertMigrationRequired :: Show value => Either Text value -> Assertion
assertMigrationRequired (Left message) = assertBool (Text.unpack message) ("catalog topology migration required" `Text.isPrefixOf` message)
assertMigrationRequired (Right value) = assertFailure ("expected topology migration failure, got " <> show value)

assertRight :: Show error => Either error value -> IO value
assertRight = either (assertFailure . show) pure

testVersion :: String -> Version
testVersion value = maybe (error ("invalid test version: " <> value)) id (simpleParsec value)

revisionA, revisionB :: Text
revisionA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
revisionB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

hashA :: SriHash
hashA = SriHash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
