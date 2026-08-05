module PlannerTest (tests) where

import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Plan (planRefresh)
import HaskellNix.Update.Types
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
  testGroup
    "refresh planner"
    [ testCase "reports every change category deterministically" testChangeCategories,
      testCase "allows GitHub and Hackage versions to differ" testLegitimateVersionDifference
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
    catalog = FamilyCatalog {schemaVersion = 1, families = [familyConfig]}
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
    catalog = FamilyCatalog 1 [config]
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
