module PlannerTest (tests) where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Plan
import HaskellNix.Update.Types
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
  testGroup
    "refresh planner"
    [ testCase "reports every change category deterministically" testChangeCategories,
      testCase "allows GitHub and Hackage versions to differ" testLegitimateVersionDifference,
      testCase "package-set refresh appends one atomic group and isolates other sets" testPackageSetRefresh,
      testCase "package-set refresh reuses identical snapshots" testPackageSetNoOp,
      testCase "package-set operations preserve complete mappings" testPackageSetOperations
    ]

testChangeCategories :: IO ()
testChangeCategories = do
  RefreshPlan {familyChanges, nextPackageLock = PackageLock {families}} <-
    assertRight (planRefresh catalog previousLock [observation])
  assertContains familyChanges (GitHubRevisionChanged family oldRevision newRevision)
  assertContains familyChanges (PackageAdded family (PackageName "added"))
  assertContains familyChanges (PackageRemoved family (PackageName "removed"))
  assertContains familyChanges (GitHubVersionChanged family (PackageName "changed") (testVersion "1.0") (testVersion "2.0"))
  assertContains familyChanges (HackagePublished family (PackageName "published") (testVersion "1.0"))
  assertContains familyChanges (HackageUnpublished family (PackageName "unpublished") (testVersion "1.0"))
  assertContains familyChanges (HackageVersionChanged family (PackageName "changed") (testVersion "1.0") (testVersion "2.1"))
  assertContains familyChanges (HackageHashChanged family (PackageName "changed") hashA hashB)
  assertContains familyChanges (HackageFallbackUsed family (PackageName "fallback") (testVersion "0.9"))
  map (\LockedFamily {name} -> name) families @?= [family]
  where
    family = FamilyName "example"
    oldRevision = GitRevision "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    newRevision = GitRevision "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    hashA = SriHash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    hashB = SriHash "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
    familyConfig =
      FamilyConfig
        { name = family,
          moriProject = "example/example",
          github = "example/example",
          githubInput = "example-src",
          packageOverrides = Map.empty,
          excludedPackages = Set.empty
        }
    catalog = FamilyCatalog {schemaVersion = 1, families = [familyConfig], updateGroups = []}
    previousLock =
      PackageLock
        { schemaVersion = 1,
          families =
            [ LockedFamily
                { name = family,
                  githubInput = "example-src",
                  githubRev = oldRevision,
                  packages =
                    [ locked "changed" "1.0" (Just (pin "1.0" hashA)),
                      locked "published" "1.0" Nothing,
                      locked "removed" "1.0" Nothing,
                      locked "unpublished" "1.0" (Just (pin "1.0" hashA))
                    ]
                }
            ]
        }
    observation =
      ObservedFamily
        { config = familyConfig,
          githubRev = newRevision,
          packages =
            [ observed "added" "1.0" Nothing False,
              observed "changed" "2.0" (Just (pin "2.1" hashB)) False,
              observed "fallback" "1.0" (Just (pin "0.9" hashA)) True,
              observed "published" "1.0" (Just (pin "1.0" hashA)) False,
              observed "unpublished" "1.0" Nothing False
            ]
        }

testLegitimateVersionDifference :: IO ()
testLegitimateVersionDifference = do
  RefreshPlan {nextPackageLock} <- assertRight (planRefresh catalog previousLock [observation])
  case nextPackageLock of
    PackageLock {families = [LockedFamily {packages = [LockedPackage {version = githubVersion, hackage = Just HackagePin {version = hackageVersion}}]}]} -> do
      githubVersion @?= testVersion "3.0"
      hackageVersion @?= testVersion "2.5"
    other -> assertFailure ("unexpected planned lock: " <> show other)
  where
    family = FamilyName "example"
    packageName = PackageName "example-package"
    revision = GitRevision "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    hash = SriHash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    config =
      FamilyConfig family "example/example" "example/example" "example-src" Map.empty Set.empty
    catalog = FamilyCatalog 1 [config] []
    previousLock = PackageLock 1 [LockedFamily family "example-src" revision [locked "example-package" "2.0" (Just (pin "2.0" hash))]]
    observation = ObservedFamily config revision [observedPackage packageName "3.0" (Just (pin "2.5" hash)) False]

locked :: String -> String -> Maybe HackagePin -> LockedPackage
locked packageName packageVersion hackage =
  LockedPackage
    { name = PackageName (fromString packageName),
      path = packageName,
      version = testVersion packageVersion,
      cabal2nixOptions = "",
      hackage
    }

observed :: String -> String -> Maybe HackagePin -> Bool -> ObservedPackage
observed packageName packageVersion = observedPackage (PackageName (fromString packageName)) packageVersion

observedPackage :: PackageName -> String -> Maybe HackagePin -> Bool -> ObservedPackage
observedPackage name@(PackageName packageName) packageVersion hackage usedHackageFallback =
  ObservedPackage
    { discovered =
        DiscoveredPackage
          { name,
            path = Text.unpack packageName,
            version = testVersion packageVersion
          },
      hackage,
      usedHackageFallback
    }

pin :: String -> SriHash -> HackagePin
pin packageVersion hash = HackagePin {version = testVersion packageVersion, hash}

testVersion :: String -> Version
testVersion value = maybe (error ("invalid test version: " <> value)) id (simpleParsec value)

fromString :: String -> Text.Text
fromString = Text.pack

assertContains :: [FamilyChange] -> FamilyChange -> IO ()
assertContains changes expected =
  assertBool ("missing change: " <> show expected <> " in " <> show changes) (expected `elem` changes)

assertRight :: Show error => Either error value -> IO value
assertRight = either (assertFailure . show) pure

testPackageSetRefresh :: IO ()
testPackageSetRefresh = do
  PackageSetRefreshPlan {nextPackageSetLock, selectedFamilySnapshots, selectedGroupSnapshots} <-
    assertRight
      ( planPackageSetRefresh
          snapshotCatalog
          snapshotLock
          "default"
          [(pairGroup, "default", changedSnapshotObservations)]
      )
  length (familySnapshots nextPackageSetLock) @?= 4
  length (groupSnapshots nextPackageSetLock) @?= 2
  selectedFamilySnapshots
    @?= [
          FamilySnapshotSelection (FamilyName "alpha") (SnapshotGeneration 2),
          FamilySnapshotSelection (FamilyName "beta") (SnapshotGeneration 2)
        ]
  selectedGroupSnapshots @?= [GroupSelection (UpdateGroupName "pair") (SnapshotGeneration 2)]
  selectedGeneration "default" nextPackageSetLock @?= SnapshotGeneration 2
  selectedGeneration "historical" nextPackageSetLock @?= SnapshotGeneration 1
  assertLeft (planPackageSetRefresh snapshotCatalog snapshotLock "historical" [(pairGroup, "default", changedSnapshotObservations)])
  assertLeft (planPackageSetRefresh snapshotCatalog snapshotLock "default" [(pairGroup, "default", take 1 changedSnapshotObservations)])

testPackageSetNoOp :: IO ()
testPackageSetNoOp = do
  PackageSetRefreshPlan {nextPackageSetLock} <-
    assertRight (planPackageSetRefresh snapshotCatalog snapshotLock "default" [(pairGroup, "default", originalSnapshotObservations)])
  nextPackageSetLock @?= snapshotLock

testPackageSetOperations :: IO ()
testPackageSetOperations = do
  cloned <- assertRight (clonePackageSet "default" "candidate" snapshotLock)
  let candidate = lookupSet "candidate" cloned
  supportLevel candidate @?= Historical
  groups candidate @?= groups (lookupSet "default" cloned)
  selected <- assertRight (selectGroupFromPackageSet "candidate" (UpdateGroupName "pair") "historical" cloned)
  selectedGeneration "candidate" selected @?= SnapshotGeneration 1
  reprofiled <- assertRight (selectGroupCompatibilityProfile "candidate" (UpdateGroupName "pair") "legacy" selected)
  length (groupSnapshots reprofiled) @?= 2
  selectedGeneration "candidate" reprofiled @?= SnapshotGeneration 2
  promoted <- assertRight (setPackageSetSupportLevel "candidate" Curated reprofiled)
  supportLevel (lookupSet "candidate" promoted) @?= Curated
  assertLeft (setPackageSetSupportLevel "default" Historical promoted)

snapshotCatalog :: FamilyCatalog
snapshotCatalog =
  FamilyCatalog
    { schemaVersion = 2,
      families = [snapshotConfig "alpha", snapshotConfig "beta"],
      updateGroups = [pairGroup]
    }

pairGroup :: UpdateGroup
pairGroup = UpdateGroup (UpdateGroupName "pair") [FamilyName "alpha", FamilyName "beta"]

snapshotConfig :: Text.Text -> FamilyConfig
snapshotConfig familyName =
  FamilyConfig
    { name = FamilyName familyName,
      moriProject = "example/" <> familyName,
      github = "example/" <> familyName,
      githubInput = familyName <> "-src",
      packageOverrides = Map.empty,
      excludedPackages = Set.empty
    }

snapshotLock :: PackageSetLock
snapshotLock =
  PackageSetLock
    { schemaVersion = 2,
      familySnapshots = [snapshot "alpha" 1 revisionA, snapshot "beta" 1 revisionA],
      groupSnapshots = [GroupSnapshot (UpdateGroupName "pair") (SnapshotGeneration 1) [FamilySnapshotSelection (FamilyName "alpha") (SnapshotGeneration 1), FamilySnapshotSelection (FamilyName "beta") (SnapshotGeneration 1)] "default"],
      packageSets =
        [ PackageSet "default" Curated [GroupSelection (UpdateGroupName "pair") (SnapshotGeneration 1)],
          PackageSet "historical" Historical [GroupSelection (UpdateGroupName "pair") (SnapshotGeneration 1)]
        ],
      defaultPackageSet = "default"
    }

snapshot :: Text.Text -> Int -> Text.Text -> FamilySnapshot
snapshot familyName generation revision =
  FamilySnapshot
    { family = FamilyName familyName,
      generation = SnapshotGeneration generation,
      discoveryPolicy = DiscoveryPolicy Map.empty Set.empty,
      source = sourceFor familyName revision,
      packages = [locked (Text.unpack familyName <> "-package") "1.0" (Just (pin "1.0" hashA))]
    }

sourceFor :: Text.Text -> Text.Text -> LockedSource
sourceFor familyName revision =
  LockedSource "github" "example" familyName (GitRevision revision) hashA

originalSnapshotObservations :: [SnapshotObservation]
originalSnapshotObservations = map (snapshotObservation revisionA "1.0" hashA) ["alpha", "beta"]

changedSnapshotObservations :: [SnapshotObservation]
changedSnapshotObservations =
  [ snapshotObservation revisionB "1.0" hashA "alpha",
    snapshotObservation revisionA "2.0" hashB "beta"
  ]

snapshotObservation :: Text.Text -> String -> SriHash -> Text.Text -> SnapshotObservation
snapshotObservation revision hackageVersion hackageHash familyName =
  SnapshotObservation
    { config = snapshotConfig familyName,
      sourceDescriptor = sourceFor familyName revision,
      packages = [observed (Text.unpack familyName <> "-package") "1.0" (Just (pin hackageVersion hackageHash)) False]
    }

selectedGeneration :: Text.Text -> PackageSetLock -> SnapshotGeneration
selectedGeneration setName lock =
  case groups (lookupSet setName lock) of
    [GroupSelection {generation}] -> generation
    other -> error ("unexpected selections: " <> show other)

lookupSet :: Text.Text -> PackageSetLock -> PackageSet
lookupSet setName PackageSetLock {packageSets} =
  case filter (\PackageSet {name} -> name == setName) packageSets of
    [packageSet] -> packageSet
    other -> error ("unexpected package sets: " <> show other)

revisionA :: Text.Text
revisionA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

revisionB :: Text.Text
revisionB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

hashA :: SriHash
hashA = SriHash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

hashB :: SriHash
hashB = SriHash "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="

assertLeft :: Show value => Either error value -> IO ()
assertLeft result =
  case result of
    Left _ -> pure ()
    Right value -> assertFailure ("expected failure, got " <> show value)
