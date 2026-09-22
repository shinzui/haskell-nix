module WorkflowTest (tests) where

import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Char8 qualified as ByteStringChar8
import Data.ByteString.Lazy qualified as LazyByteString
import Data.IORef
import Data.List (find)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Distribution.Parsec (simpleParsec)
import Distribution.Pretty (prettyShow)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Catalog (encodeFamilyCatalog)
import HaskellNix.Update.Hackage
import HaskellNix.Update.PackageLock (decodePackageLock, decodePackageSetLock, encodePackageLock, encodePackageSetLock)
import HaskellNix.Update.Process
import HaskellNix.Update.Types
import HaskellNix.Update.Workflow
import System.Directory (createDirectoryIfMissing)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

tests :: TestTree
tests =
  testGroup
    "refresh workflow"
    [ testCase "bootstrap refresh adds newly configured families" testBootstrapRefresh,
      testCase "successful refresh updates both generated views" testSuccessfulRefresh,
      testCase "no-change refresh leaves both lock files byte-for-byte unchanged" testNoChange,
      testCase "partial refresh preserves unselected families" testPartialRefresh,
      testCase "dry-run performs discovery without managed writes" testDryRun,
      testCase "dirty managed files are refused before remote work" testDirtyRefusal,
      testCase "missing Git object fails without managed writes" testMissingObject,
      testCase "prefetch failure rolls back byte-for-byte" testPrefetchRollback,
      testCase "post-update validation failure rolls back byte-for-byte" testValidationRollback,
      testCase "validation warms the first-party checks before running them" testValidationWarmsChecks,
      testCase "Hackage 404 records an unpublished package" testHackage404,
      testCase "offline check validates the locked Git package" testOfflineCheck,
      testCase "online check detects remote revision drift without writes" testOnlineCheckDrift,
      testCase "excluded packages are kept out of the generated lock" testExcludedPackage,
      testCase "an exclusion matching nothing fails without managed writes" testStaleExclusion,
      testCase "grouped package-set refresh is atomic and isolated" testPackageSetRefresh,
      testCase "package-set no-op and dry-run preserve exact bytes" testPackageSetNoOpAndDryRun,
      testCase "Hackage-only package-set refresh appends a generation" testPackageSetHackageOnly,
      testCase "grouped package-set failure rolls back both managed files" testPackageSetRollback,
      testCase "historical offline check ignores tracking inputs" testHistoricalPackageSetCheck,
      testCase "package-set mutation commands preserve a valid graph" testPackageSetCommands,
      testCase "migration creates the current set and imports history" testMigrateLock
    ]

testBootstrapRefresh :: IO ()
testBootstrapRefresh = withFixture ["alpha"] $ \fixture -> do
  let emptyPackageLock = LazyByteString.toStrict (encodePackageLock (PackageLock 1 []))
      bootstrapFixture = fixture {originalPackageLock = emptyPackageLock}
  ByteString.writeFile (fixtureRoot fixture </> "packages/first-party-lock.json") emptyPackageLock
  (environment, _) <- fakeEnvironment bootstrapFixture (defaultSettings ["alpha"])
  _ <- runRefreshWorkflow environment (fixturePaths fixture) [] False >>= assertRight
  packageBytes <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
  packageLock <- assertRight (decodePackageLock (fixtureCatalog fixture) packageBytes)
  familyRevision packageLock (FamilyName "alpha") @?= GitRevision revisionA

testSuccessfulRefresh :: IO ()
testSuccessfulRefresh = withFixture ["alpha"] $ \fixture -> do
  (environment, _) <- fakeEnvironment fixture (changedSettings ["alpha"])
  result <- runRefreshWorkflow environment (fixturePaths fixture) [] False
  _ <- assertRight result
  newFlake <- ByteString.readFile (fixtureRoot fixture </> "flake.lock")
  newPackageLock <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
  assertBool "flake.lock should change" (newFlake /= originalFlake fixture)
  assertBool "package lock should change" (newPackageLock /= originalPackageLock fixture)
  packageLock <- assertRight (decodePackageLock (fixtureCatalog fixture) newPackageLock)
  familyRevision packageLock (FamilyName "alpha") @?= GitRevision revisionB

testNoChange :: IO ()
testNoChange = withFixture ["alpha"] $ \fixture -> do
  (environment, _) <- fakeEnvironment fixture (defaultSettings ["alpha"])
  _ <- runRefreshWorkflow environment (fixturePaths fixture) [] False >>= assertRight
  assertOriginalBytes fixture

testPartialRefresh :: IO ()
testPartialRefresh = withFixture ["alpha", "beta"] $ \fixture -> do
  (environment, commandLog) <- fakeEnvironment fixture (changedSettings ["alpha", "beta"])
  _ <- runRefreshWorkflow environment (fixturePaths fixture) ["alpha"] False >>= assertRight
  packageBytes <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
  packageLock <- assertRight (decodePackageLock (fixtureCatalog fixture) packageBytes)
  familyRevision packageLock (FamilyName "alpha") @?= GitRevision revisionB
  familyRevision packageLock (FamilyName "beta") @?= GitRevision revisionA
  commands <- readIORef commandLog
  assertBool "unselected beta must not be queried" (not (any (commandMentions "owner/beta") commands))

testDryRun :: IO ()
testDryRun = withFixture ["alpha"] $ \fixture -> do
  (environment, commandLog) <- fakeEnvironment fixture (changedSettings ["alpha"])
  result <- runRefreshWorkflow environment (fixturePaths fixture) [] True
  summary <- assertRight result
  assertBool "summary should identify dry-run" ("Dry run" `Text.isInfixOf` summary)
  assertOriginalBytes fixture
  commands <- readIORef commandLog
  assertBool "dry-run must not update flake inputs" (not (any isFlakeUpdate commands))

testDirtyRefusal :: IO ()
testDirtyRefusal = withFixture ["alpha"] $ \fixture -> do
  let settings = (changedSettings ["alpha"]) {dirtyManagedFiles = True}
  (environment, commandLog) <- fakeEnvironment fixture settings
  result <- runRefreshWorkflow environment (fixturePaths fixture) [] False
  assertLeft result
  assertOriginalBytes fixture
  commands <- readIORef commandLog
  length commands @?= 1

testMissingObject :: IO ()
testMissingObject = withFixture ["alpha"] $ \fixture -> do
  let settings = (changedSettings ["alpha"]) {gitObjectMissing = True}
  (environment, _) <- fakeEnvironment fixture settings
  runRefreshWorkflow environment (fixturePaths fixture) [] True >>= assertLeft
  assertOriginalBytes fixture

testPrefetchRollback :: IO ()
testPrefetchRollback = withFixture ["alpha"] $ \fixture -> do
  let settings = (changedSettings ["alpha"]) {prefetchFails = True}
  (environment, _) <- fakeEnvironment fixture settings
  runRefreshWorkflow environment (fixturePaths fixture) [] False >>= assertLeft
  assertOriginalBytes fixture

testValidationRollback :: IO ()
testValidationRollback = withFixture ["alpha"] $ \fixture -> do
  let settings = (changedSettings ["alpha"]) {validationFails = True}
  (environment, _) <- fakeEnvironment fixture settings
  runRefreshWorkflow environment (fixturePaths fixture) [] False >>= assertLeft
  assertOriginalBytes fixture

-- The first-party checks perform cabal2nix import-from-derivation builds that
-- `nix flake check` computes but does not realise, so validation must force them
-- first or a refresh that locks an unseen revision fails on
-- "path '/nix/store/...-cabal2nix-<package>.drv' is not valid".
--
-- The warm has to be this expression, evaluated purely against the flake: an
-- impure sweep over callCabal2nix computes different derivations and warms
-- something the check never imports, so asserting the shape here is the point.
testValidationWarmsChecks :: IO ()
testValidationWarmsChecks = withFixture ["alpha"] $ \fixture -> do
  (environment, commandLog) <- fakeEnvironment fixture (changedSettings ["alpha"])
  _ <- runRefreshWorkflow environment (fixturePaths fixture) [] False >>= assertRight
  commands <- readIORef commandLog
  assertBool
    "validation must warm every check before checking"
    (any isChecksWarm commands)
  let ordered = filter (\command -> isChecksWarm command || isFlakeCheck command) commands
  case ordered of
    (warm : check : _) ->
      assertBool
        "the warm must run before the check"
        (isChecksWarm warm && isFlakeCheck check)
    _ -> assertFailure ("expected a warm followed by a check, saw " <> show ordered)

testHackage404 :: IO ()
testHackage404 = withFixture ["alpha"] $ \fixture -> do
  let settings =
        (defaultSettings ["alpha"])
          { hackageVersions = Map.singleton "alpha-package" Nothing
          }
  (environment, _) <- fakeEnvironment fixture settings
  _ <- runRefreshWorkflow environment (fixturePaths fixture) [] False >>= assertRight
  packageBytes <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
  packageLock <- assertRight (decodePackageLock (fixtureCatalog fixture) packageBytes)
  packageHackage packageLock (FamilyName "alpha") @?= Nothing

testOfflineCheck :: IO ()
testOfflineCheck = withFixture ["alpha"] $ \fixture -> do
  (environment, _) <- fakeEnvironment fixture (defaultSettings ["alpha"])
  summary <- runCheckWorkflow environment (fixturePaths fixture) [] False >>= assertRight
  assertBool "offline check summary" ("no drift" `Text.isInfixOf` summary)
  assertOriginalBytes fixture

testOnlineCheckDrift :: IO ()
testOnlineCheckDrift = withFixture ["alpha"] $ \fixture -> do
  (environment, _) <- fakeEnvironment fixture (changedSettings ["alpha"])
  runCheckWorkflow environment (fixturePaths fixture) [] True >>= assertLeft
  assertOriginalBytes fixture

-- A family repository may carry an example package whose name collides with
-- another family. Excluding it keeps discovery honest without locking it.
testExcludedPackage :: IO ()
testExcludedPackage =
  withConfiguredFixture ["alpha"] (excluding "shared-example") $ \fixture -> do
    let settings =
          (defaultSettings ["alpha"])
            { extraPackages = ["shared-example"],
              githubVersions =
                Map.fromList
                  [("alpha-package", testVersion "1.0"), ("shared-example", testVersion "1.0")]
            }
    (environment, commandLog) <- fakeEnvironment fixture settings
    _ <- runRefreshWorkflow environment (fixturePaths fixture) [] False >>= assertRight
    packageBytes <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
    packageLock <- assertRight (decodePackageLock (fixtureCatalog fixture) packageBytes)
    lockedPackageNames packageLock (FamilyName "alpha") @?= [PackageName "alpha-package"]
    -- Discovery parses every Cabal file before exclusions apply, so the Git
    -- read is expected; only the Hackage prefetch must never happen.
    commands <- readIORef commandLog
    assertBool
      "an excluded package must never be prefetched from Hackage"
      (not (any (\command -> isPrefetch command && commandMentions "shared-example" command) commands))

testStaleExclusion :: IO ()
testStaleExclusion =
  withConfiguredFixture ["alpha"] (excluding "absent-example") $ \fixture -> do
    (environment, _) <- fakeEnvironment fixture (defaultSettings ["alpha"])
    runRefreshWorkflow environment (fixturePaths fixture) [] False >>= assertLeft
    assertOriginalBytes fixture

testPackageSetRefresh :: IO ()
testPackageSetRefresh = withPackageSetFixture $ \fixture -> do
  (environment, _) <- fakeEnvironment fixture (changedSettings ["alpha", "beta"])
  _ <-
    runRefreshCommand
      environment
      (fixturePaths fixture)
      Nothing
      [TargetFamily (FamilyName "alpha")]
      Nothing
      False
      >>= assertRight
  lockBytes <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
  lock <- assertRight (decodePackageSetLock (fixtureCatalog fixture) lockBytes)
  length (familySnapshots lock) @?= 4
  length (groupSnapshots lock) @?= 2
  packageSetGeneration "default" lock @?= SnapshotGeneration 2
  packageSetGeneration "retained" lock @?= SnapshotGeneration 1

testPackageSetNoOpAndDryRun :: IO ()
testPackageSetNoOpAndDryRun = withPackageSetFixture $ \fixture -> do
  (noChangeEnvironment, _) <- fakeEnvironment fixture (defaultSettings ["alpha", "beta"])
  _ <- runRefreshCommand noChangeEnvironment (fixturePaths fixture) Nothing [] Nothing False >>= assertRight
  assertOriginalBytes fixture
  (dryRunEnvironment, _) <- fakeEnvironment fixture (changedSettings ["alpha", "beta"])
  _ <- runRefreshCommand dryRunEnvironment (fixturePaths fixture) Nothing [] Nothing True >>= assertRight
  assertOriginalBytes fixture

testPackageSetHackageOnly :: IO ()
testPackageSetHackageOnly = withPackageSetFixture $ \fixture -> do
  let settings =
        (defaultSettings ["alpha", "beta"])
          { hackageVersions = Map.fromList [("alpha-package", Just (testVersion "2.0")), ("beta-package", Just (testVersion "2.0"))],
            prefetchedHash = hashB
          }
  (environment, _) <- fakeEnvironment fixture settings
  _ <- runRefreshCommand environment (fixturePaths fixture) Nothing [] Nothing False >>= assertRight
  lockBytes <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
  lock <- assertRight (decodePackageSetLock (fixtureCatalog fixture) lockBytes)
  length (familySnapshots lock) @?= 4
  packageSetGeneration "default" lock @?= SnapshotGeneration 2
  assertBool "Hackage-only refresh must retain Git revisions" (all ((== GitRevision revisionA) . rev . source) (familySnapshots lock))

testPackageSetRollback :: IO ()
testPackageSetRollback = withPackageSetFixture $ \fixture -> do
  let settings = (changedSettings ["alpha", "beta"]) {prefetchFails = True}
  (environment, _) <- fakeEnvironment fixture settings
  runRefreshCommand environment (fixturePaths fixture) Nothing [TargetGroup (UpdateGroupName "pair")] Nothing False >>= assertLeft
  assertOriginalBytes fixture

testHistoricalPackageSetCheck :: IO ()
testHistoricalPackageSetCheck = withPackageSetFixture $ \fixture -> do
  writeIORef (currentRevisions fixture) (Map.fromList [("alpha", GitRevision revisionB), ("beta", GitRevision revisionB)])
  ByteString.writeFile
    (fixtureRoot fixture </> "flake.lock")
    (flakeLockBytes (Map.fromList [("alpha", GitRevision revisionB), ("beta", GitRevision revisionB)]))
  (environment, _) <- fakeEnvironment fixture (defaultSettings ["alpha", "beta"])
  _ <- runCheckCommand environment (fixturePaths fixture) (Just "retained") [] False >>= assertRight
  pure ()

testPackageSetCommands :: IO ()
testPackageSetCommands = withPackageSetFixture $ \fixture -> do
  (environment, _) <- fakeEnvironment fixture (defaultSettings ["alpha", "beta"])
  _ <- runPackageSetCommand environment (fixturePaths fixture) (ProfilePackageSetGroup "default" (UpdateGroupName "pair") "legacy" False) >>= assertRight
  _ <- runPackageSetCommand environment (fixturePaths fixture) (ClonePackageSet "default" "candidate" Historical False) >>= assertRight
  _ <- runPackageSetCommand environment (fixturePaths fixture) (SelectPackageSetGroup "candidate" (UpdateGroupName "pair") (Right "retained") False) >>= assertRight
  _ <- runPackageSetCommand environment (fixturePaths fixture) (SetPackageSetSupport "candidate" Curated False) >>= assertRight
  lockBytes <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
  lock <- assertRight (decodePackageSetLock (fixtureCatalog fixture) lockBytes)
  packageSetGeneration "default" lock @?= SnapshotGeneration 2
  packageSetGeneration "candidate" lock @?= SnapshotGeneration 1
  supportFor "candidate" lock @?= Curated
  runPackageSetCommand environment (fixturePaths fixture) (SetPackageSetSupport "default" Historical False) >>= assertLeft

testMigrateLock :: IO ()
testMigrateLock = withMigrationFixture $ \fixture -> do
  (environment, _) <- fakeEnvironment fixture (defaultSettings ["alpha", "beta"])
  _ <- runMigrateLockWorkflow environment (fixturePaths fixture) "stable" [("old", "history")] True >>= assertRight
  assertOriginalBytes fixture
  _ <- runMigrateLockWorkflow environment (fixturePaths fixture) "stable" [("old", "history")] False >>= assertRight
  lockBytes <- ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json")
  lock <- assertRight (decodePackageSetLock (fixtureCatalog fixture) lockBytes)
  defaultPackageSet lock @?= "stable"
  map (\PackageSet {name} -> name) (packageSets lock) @?= ["old", "stable"]
  supportFor "old" lock @?= Historical

excluding :: Text -> FamilyConfig -> FamilyConfig
excluding excludedName FamilyConfig {name, moriProject, github, githubInput, packageOverrides} =
  FamilyConfig
    { name,
      moriProject,
      github,
      githubInput,
      packageOverrides,
      excludedPackages = Set.singleton (PackageName excludedName)
    }

data Fixture = Fixture
  { fixtureRoot :: !FilePath,
    fixturePaths :: !WorkflowPaths,
    fixtureCatalog :: !FamilyCatalog,
    originalFlake :: !ByteString,
    originalPackageLock :: !ByteString,
    currentRevisions :: !(IORef (Map Text GitRevision))
  }

withFixture :: [Text] -> (Fixture -> IO value) -> IO value
withFixture familyNames = withConfiguredFixture familyNames id

withPackageSetFixture :: (Fixture -> IO value) -> IO value
withPackageSetFixture action =
  withFixture ["alpha", "beta"] $ \fixture -> do
    let catalog =
          FamilyCatalog
            { schemaVersion = 2,
              families = [familyConfig "alpha", familyConfig "beta"],
              updateGroups = [UpdateGroup (UpdateGroupName "pair") [FamilyName "alpha", FamilyName "beta"]]
            }
        lock = packageSetFixtureLock
        catalogBytes = LazyByteString.toStrict (encodeFamilyCatalog catalog)
        lockBytes = LazyByteString.toStrict (encodePackageSetLock lock)
        packageSetFixture =
          fixture
            { fixtureCatalog = catalog,
              originalPackageLock = lockBytes
            }
    ByteString.writeFile (fixtureRoot fixture </> "config/first-party-families.json") catalogBytes
    ByteString.writeFile (fixtureRoot fixture </> "packages/first-party-lock.json") lockBytes
    action packageSetFixture

withMigrationFixture :: (Fixture -> IO value) -> IO value
withMigrationFixture action =
  withFixture ["alpha", "beta"] $ \fixture -> do
    let catalog =
          FamilyCatalog
            { schemaVersion = 2,
              families = [familyConfig "alpha", familyConfig "beta"],
              updateGroups = [UpdateGroup (UpdateGroupName "pair") [FamilyName "alpha", FamilyName "beta"]]
            }
        catalogBytes = LazyByteString.toStrict (encodeFamilyCatalog catalog)
        migrationFixture = fixture {fixtureCatalog = catalog}
    ByteString.writeFile (fixtureRoot fixture </> "config/first-party-families.json") catalogBytes
    action migrationFixture

packageSetFixtureLock :: PackageSetLock
packageSetFixtureLock =
  PackageSetLock
    { schemaVersion = 2,
      familySnapshots = map initialSnapshot ["alpha", "beta"],
      groupSnapshots =
        [ GroupSnapshot
            { group = UpdateGroupName "pair",
              generation = SnapshotGeneration 1,
              families =
                [ FamilySnapshotSelection (FamilyName "alpha") (SnapshotGeneration 1),
                  FamilySnapshotSelection (FamilyName "beta") (SnapshotGeneration 1)
                ],
              compatibilityProfile = "default"
            }
        ],
      packageSets =
        [ PackageSet "default" Curated [GroupSelection (UpdateGroupName "pair") (SnapshotGeneration 1)],
          PackageSet "retained" Historical [GroupSelection (UpdateGroupName "pair") (SnapshotGeneration 1)]
        ],
      defaultPackageSet = "default"
    }
  where
    initialSnapshot familyName =
      let LockedFamily {packages = familyPackages} = lockedFamily familyName
       in FamilySnapshot
            { family = FamilyName familyName,
              generation = SnapshotGeneration 1,
              discoveryPolicy = DiscoveryPolicy Map.empty Set.empty,
              source = LockedSource "github" "owner" familyName (GitRevision revisionA) hashA,
              packages = familyPackages
            }

withConfiguredFixture :: [Text] -> (FamilyConfig -> FamilyConfig) -> (Fixture -> IO value) -> IO value
withConfiguredFixture familyNames configure action =
  withSystemTempDirectory "haskell-nix-update-test" $ \root -> do
    createDirectoryIfMissing True (root </> "config")
    createDirectoryIfMissing True (root </> "packages")
    let familyConfigs = map (configure . familyConfig) familyNames
        catalog = FamilyCatalog {schemaVersion = 1, families = familyConfigs, updateGroups = []}
        initialRevisions = Map.fromList [(familyName, GitRevision revisionA) | familyName <- familyNames]
        packageLock = PackageLock 1 (map lockedFamily familyNames)
        catalogBytes = LazyByteString.toStrict (encodeFamilyCatalog catalog)
        packageBytes = LazyByteString.toStrict (encodePackageLock packageLock)
        flakeBytes = flakeLockBytes initialRevisions
    ByteString.writeFile (root </> "config/first-party-families.json") catalogBytes
    ByteString.writeFile (root </> "packages/first-party-lock.json") packageBytes
    ByteString.writeFile (root </> "flake.lock") flakeBytes
    currentRevisions <- newIORef initialRevisions
    action
      Fixture
        { fixtureRoot = root,
          fixturePaths = defaultWorkflowPaths root,
          fixtureCatalog = catalog,
          originalFlake = flakeBytes,
          originalPackageLock = packageBytes,
          currentRevisions
        }

data FakeSettings = FakeSettings
  { remoteRevisions :: !(Map Text GitRevision),
    githubVersions :: !(Map Text Version),
    hackageVersions :: !(Map Text (Maybe Version)),
    prefetchedHash :: !SriHash,
    dirtyManagedFiles :: !Bool,
    gitObjectMissing :: !Bool,
    prefetchFails :: !Bool,
    validationFails :: !Bool,
    -- Additional packages every family repository discovers alongside its own
    -- package, used to exercise configured exclusions.
    extraPackages :: ![Text]
  }

defaultSettings :: [Text] -> FakeSettings
defaultSettings familyNames =
  FakeSettings
    { remoteRevisions = Map.fromList [(familyName, GitRevision revisionA) | familyName <- familyNames],
      githubVersions = Map.fromList [(packageName familyName, testVersion "1.0") | familyName <- familyNames],
      hackageVersions = Map.fromList [(packageName familyName, Just (testVersion "1.0")) | familyName <- familyNames],
      prefetchedHash = hashA,
      dirtyManagedFiles = False,
      gitObjectMissing = False,
      prefetchFails = False,
      validationFails = False,
      extraPackages = []
    }

changedSettings :: [Text] -> FakeSettings
changedSettings familyNames =
  (defaultSettings familyNames)
    { remoteRevisions = Map.fromList [(familyName, GitRevision revisionB) | familyName <- familyNames],
      githubVersions = Map.fromList [(packageName familyName, testVersion "2.0") | familyName <- familyNames],
      hackageVersions = Map.fromList [(packageName familyName, Just (testVersion "2.1")) | familyName <- familyNames],
      prefetchedHash = hashB
    }

fakeEnvironment :: Fixture -> FakeSettings -> IO (WorkflowEnvironment, IORef [ProcessSpec])
fakeEnvironment fixture settings = do
  commandLog <- newIORef []
  let processRunner = ProcessRunner (runFakeProcess fixture settings commandLog)
      httpClient = HttpClient (runFakeHttp settings)
  pure
    ( WorkflowEnvironment
        { processRunner,
          httpClient,
          progress = const (pure ()),
          validateSelectedPackageSet = \_ _ -> pure (Right ())
        },
      commandLog
    )

runFakeProcess :: Fixture -> FakeSettings -> IORef [ProcessSpec] -> ProcessSpec -> IO (Either UpdateError ProcessResult)
runFakeProcess fixture settings commandLog spec@ProcessSpec {executable, arguments} = do
  modifyIORef' commandLog (<> [spec])
  case (executable, arguments) of
    ("git", ["status", "--porcelain", "--", _, _]) ->
      pure (success (if dirtyManagedFiles settings then " M flake.lock\n" else ""))
    ("git", ["ls-remote", url, "HEAD"]) ->
      pure $ do
        familyName <- familyFromUrl settings (Text.pack url)
        revision <- lookupSetting "remote revision" familyName (remoteRevisions settings)
        success (revisionText revision <> "\tHEAD\n")
    ("mori", ["registry", "show", project, "--json", "--full"]) ->
      let familyName = Text.pack (dropProjectNamespace project)
       in pure
            ( success
                ( "{\"path\":\"/fake/"
                    <> familyName
                    <> "\",\"repositories\":[{\"github\":\"owner/"
                    <> familyName
                    <> "\"}]}"
                )
            )
    ("git", ["-C", _, "cat-file", "-e", _]) ->
      pure
        ( if gitObjectMissing settings
            then failure 1 "missing object"
            else success ""
        )
    ("git", ["-C", _, "fetch", "origin", _]) -> pure (success "")
    ("git", ["-C", _, "rev-parse", "--verify", "history^{commit}"]) ->
      pure (success (revisionA <> "\n"))
    ("git", ["-C", _, "show", target])
      | target == Text.unpack revisionA <> ":config/first-party-families.json" ->
          let FamilyCatalog {families} = fixtureCatalog fixture
              historicalCatalog = FamilyCatalog 1 families []
           in pure (success (TextEncoding.decodeUtf8 (LazyByteString.toStrict (encodeFamilyCatalog historicalCatalog))))
      | target == Text.unpack revisionA <> ":packages/first-party-lock.json" ->
          pure (success (TextEncoding.decodeUtf8 (originalPackageLock fixture)))
      | target == Text.unpack revisionA <> ":flake.lock" ->
          pure (success (TextEncoding.decodeUtf8 (originalFlake fixture)))
    ("git", ["-C", repository, "ls-tree", "-r", "--name-only", _]) ->
      let familyName = familyFromRepository repository
          names = packageName familyName : extraPackages settings
       in pure (success (Text.concat [name <> "/" <> name <> ".cabal\n" | name <- names]))
    ("git", ["-C", _, "show", target]) ->
      let name = packageFromShowTarget (Text.pack target)
       in pure $ do
            packageVersion <- lookupSetting "GitHub version" name (githubVersions settings)
            success
              ( "cabal-version: 3.0\nname: "
                  <> name
                  <> "\nversion: "
                  <> Text.pack (prettyShow packageVersion)
                  <> "\nbuild-type: Simple\n"
              )
    ("nix", ["flake", "update", inputName]) -> do
      let familyName = Text.dropEnd 4 (Text.pack inputName)
      case Map.lookup familyName (remoteRevisions settings) of
        Nothing -> pure (Left (UpdateError ("missing remote revision for " <> familyName)))
        Just revision -> do
          modifyIORef' (currentRevisions fixture) (Map.insert familyName revision)
          revisions <- readIORef (currentRevisions fixture)
          ByteString.writeFile (fixtureRoot fixture </> "flake.lock") (flakeLockBytes revisions)
          pure (success "")
    ("nix", ["store", "prefetch-file", "--json", "--unpack", _]) ->
      pure
        ( if prefetchFails settings
            then failure 1 "prefetch failed"
            else success ("{\"hash\":\"" <> hashText (prefetchedHash settings) <> "\"}\n")
        )
    ("nix", ["eval", "--impure", "--raw", "--expr", "builtins.currentSystem"]) ->
      pure (success "aarch64-darwin")
    -- The import-from-derivation warm that runs before validation. It is
    -- best-effort in production, so the fake answers it plainly and the
    -- validation verdict below stays the only thing that decides the refresh.
    ("nix", ["eval", "--no-eval-cache", "--json", attribute, "--apply", _])
      | ".#checks.aarch64-darwin" == attribute ->
          pure (success "{\"first-party-versions\":true}\n")
    ("nix", ["flake", "check", "--no-build", "--no-eval-cache"]) ->
      pure
        ( if validationFails settings
            then failure 1 "validation failed"
            else success ""
        )
    _ -> pure (Left (UpdateError ("unexpected fake command: " <> Text.pack (show (executable, arguments)))))

runFakeHttp :: FakeSettings -> Text -> IO (Either UpdateError HttpResponse)
runFakeHttp settings url =
  pure $ case find (\package -> package `Text.isInfixOf` url) (Map.keys (hackageVersions settings)) of
    Nothing -> Left (UpdateError ("unexpected Hackage URL: " <> url))
    Just name -> case Map.lookup name (hackageVersions settings) of
      Nothing -> Left (UpdateError ("missing Hackage setting for " <> name))
      Just Nothing -> Right HttpResponse {statusCode = 404, body = ""}
      Just (Just packageVersion) ->
        Right
          HttpResponse
            { statusCode = 200,
              body =
                ByteStringChar8.pack
                  ( "{\""
                      <> prettyShow packageVersion
                      <> "\":\"normal\"}"
                  )
            }

familyConfig :: Text -> FamilyConfig
familyConfig familyName =
  FamilyConfig
    { name = FamilyName familyName,
      moriProject = "tests/" <> familyName,
      github = "owner/" <> familyName,
      githubInput = familyName <> "-src",
      packageOverrides = Map.empty,
      excludedPackages = Set.empty
    }

lockedFamily :: Text -> LockedFamily
lockedFamily familyName =
  LockedFamily
    { name = FamilyName familyName,
      githubInput = familyName <> "-src",
      githubRev = GitRevision revisionA,
      packages =
        [ LockedPackage
            { name = PackageName (packageName familyName),
              path = Text.unpack (packageName familyName),
              version = testVersion "1.0",
              cabal2nixOptions = "",
              hackage = Just HackagePin {version = testVersion "1.0", hash = hashA}
            }
        ]
    }

flakeLockBytes :: Map Text GitRevision -> ByteString
flakeLockBytes revisions =
  ByteStringChar8.pack
    ( "{\"root\":\"root\",\"nodes\":{\"root\":{\"inputs\":{"
        <> commaSeparated
          [ quoted (Text.unpack familyName <> "-src") <> ":" <> quoted (Text.unpack familyName <> "-src")
            | familyName <- Map.keys revisions
          ]
        <> "}},"
        <> commaSeparated
          [ quoted (Text.unpack familyName <> "-src")
              <> ":{\"locked\":{\"type\":\"github\",\"owner\":\"owner\",\"repo\":"
              <> quoted (Text.unpack familyName)
              <> ",\"rev\":"
              <> quoted (Text.unpack (revisionText revision))
              <> ",\"narHash\":"
              <> quoted (Text.unpack (hashText hashA))
              <> "}}"
            | (familyName, revision) <- Map.toAscList revisions
          ]
        <> "}}\n"
    )

familyRevision :: PackageLock -> FamilyName -> GitRevision
familyRevision PackageLock {families} requestedName =
  case find (\LockedFamily {name} -> name == requestedName) families of
    Just LockedFamily {githubRev} -> githubRev
    Nothing -> error ("missing test family " <> show requestedName)

packageSetGeneration :: Text -> PackageSetLock -> SnapshotGeneration
packageSetGeneration requestedName PackageSetLock {packageSets} =
  case find (\PackageSet {name} -> name == requestedName) packageSets of
    Just PackageSet {groups = [GroupSelection {generation}]} -> generation
    other -> error ("unexpected test package set: " <> show other)

supportFor :: Text -> PackageSetLock -> PackageSetSupportLevel
supportFor requestedName PackageSetLock {packageSets} =
  case find (\PackageSet {name} -> name == requestedName) packageSets of
    Just PackageSet {supportLevel} -> supportLevel
    Nothing -> error ("missing test package set " <> Text.unpack requestedName)

packageHackage :: PackageLock -> FamilyName -> Maybe HackagePin
packageHackage PackageLock {families} requestedName =
  case find (\LockedFamily {name} -> name == requestedName) families of
    Just LockedFamily {packages = [LockedPackage {hackage}]} -> hackage
    other -> error ("unexpected test family packages: " <> show other)

lockedPackageNames :: PackageLock -> FamilyName -> [PackageName]
lockedPackageNames PackageLock {families} requestedName =
  case find (\LockedFamily {name} -> name == requestedName) families of
    Just LockedFamily {packages} -> [name | LockedPackage {name} <- packages]
    Nothing -> error ("missing test family " <> show requestedName)

assertOriginalBytes :: Fixture -> IO ()
assertOriginalBytes fixture = do
  ByteString.readFile (fixtureRoot fixture </> "flake.lock") >>= (@?= originalFlake fixture)
  ByteString.readFile (fixtureRoot fixture </> "packages/first-party-lock.json") >>= (@?= originalPackageLock fixture)

familyFromUrl :: FakeSettings -> Text -> Either UpdateError Text
familyFromUrl settings url =
  maybe
    (Left (UpdateError ("unknown GitHub URL: " <> url)))
    (Right . fst)
    (find (\(familyName, _) -> ("owner/" <> familyName) `Text.isInfixOf` url) (Map.toAscList (remoteRevisions settings)))

familyFromRepository :: FilePath -> Text
familyFromRepository = Text.pack . reverse . takeWhile (/= '/') . reverse

dropProjectNamespace :: String -> String
dropProjectNamespace = reverse . takeWhile (/= '/') . reverse

packageName :: Text -> Text
packageName familyName = familyName <> "-package"

-- "<revision>:<package>/<package>.cabal" identifies which discovered package
-- the fake repository is being asked for.
packageFromShowTarget :: Text -> Text
packageFromShowTarget target =
  Text.takeWhile (/= '/') (Text.drop 1 (Text.dropWhile (/= ':') target))

lookupSetting :: Ord key => Text -> key -> Map key value -> Either UpdateError value
lookupSetting context key values =
  maybe (Left (UpdateError (context <> " is missing"))) Right (Map.lookup key values)

success :: Text -> Either UpdateError ProcessResult
success standardOutput =
  Right ProcessResult {exitCode = ExitSuccess, standardOutput, standardError = ""}

failure :: Int -> Text -> Either UpdateError ProcessResult
failure status standardError =
  Right ProcessResult {exitCode = ExitFailure status, standardOutput = "", standardError}

-- The warm must cover every check for the system, not one named check: the
-- registry fixture and build-setting checks import cabal2nix derivations too.
isChecksWarm :: ProcessSpec -> Bool
isChecksWarm ProcessSpec {executable = "nix", arguments = ["eval", "--no-eval-cache", "--json", attribute, "--apply", expression]} =
  attribute == ".#checks.aarch64-darwin" && "drvPath" `Text.isInfixOf` Text.pack expression
isChecksWarm _ = False

isFlakeCheck :: ProcessSpec -> Bool
isFlakeCheck ProcessSpec {executable = "nix", arguments = "flake" : "check" : _} = True
isFlakeCheck _ = False

isFlakeUpdate :: ProcessSpec -> Bool
isFlakeUpdate ProcessSpec {executable = "nix", arguments = "flake" : "update" : _} = True
isFlakeUpdate _ = False

isPrefetch :: ProcessSpec -> Bool
isPrefetch ProcessSpec {executable = "nix", arguments = "store" : "prefetch-file" : _} = True
isPrefetch _ = False

commandMentions :: Text -> ProcessSpec -> Bool
commandMentions needle ProcessSpec {arguments} = needle `Text.isInfixOf` Text.pack (show arguments)

revisionText :: GitRevision -> Text
revisionText (GitRevision revision) = revision

hashText :: SriHash -> Text
hashText (SriHash hash) = hash

testVersion :: String -> Version
testVersion value = maybe (error ("invalid test version: " <> value)) id (simpleParsec value)

commaSeparated :: [String] -> String
commaSeparated = Text.unpack . Text.intercalate "," . map Text.pack

quoted :: String -> String
quoted value = "\"" <> value <> "\""

revisionA :: Text
revisionA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

revisionB :: Text
revisionB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

hashA :: SriHash
hashA = SriHash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

hashB :: SriHash
hashB = SriHash "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="

assertRight :: Show error => Either error value -> IO value
assertRight = either (assertFailure . show) pure

assertLeft :: Show value => Either UpdateError value -> IO ()
assertLeft result = case result of
  Left _ -> pure ()
  Right value -> assertFailure ("expected failure, got: " <> show value)
