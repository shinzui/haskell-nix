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
import Distribution.Parsec (simpleParsec)
import Distribution.Pretty (prettyShow)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Catalog (encodeFamilyCatalog)
import HaskellNix.Update.Hackage
import HaskellNix.Update.PackageLock (decodePackageLock, encodePackageLock)
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
      testCase "Hackage 404 records an unpublished package" testHackage404,
      testCase "offline check validates the locked Git package" testOfflineCheck,
      testCase "online check detects remote revision drift without writes" testOnlineCheckDrift,
      testCase "excluded packages are kept out of the generated lock" testExcludedPackage,
      testCase "an exclusion matching nothing fails without managed writes" testStaleExclusion
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

excluding :: Text -> FamilyConfig -> FamilyConfig
excluding name config = config {excludedPackages = Set.singleton (PackageName name)}

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

withConfiguredFixture :: [Text] -> (FamilyConfig -> FamilyConfig) -> (Fixture -> IO value) -> IO value
withConfiguredFixture familyNames configure action =
  withSystemTempDirectory "haskell-nix-update-test" $ \root -> do
    createDirectoryIfMissing True (root </> "config")
    createDirectoryIfMissing True (root </> "packages")
    let familyConfigs = map (configure . familyConfig) familyNames
        catalog = FamilyCatalog {schemaVersion = 1, families = familyConfigs}
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
  pure (WorkflowEnvironment {processRunner, httpClient}, commandLog)

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
              <> ":{\"locked\":{\"rev\":"
              <> quoted (Text.unpack (revisionText revision))
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
