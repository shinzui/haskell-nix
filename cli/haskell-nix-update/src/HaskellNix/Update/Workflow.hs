module HaskellNix.Update.Workflow
  ( WorkflowPaths (..),
    WorkflowEnvironment (..),
    defaultWorkflowPaths,
    defaultWorkflowEnvironment,
    runRefreshWorkflow,
    runCheckWorkflow,
    atomicWriteFile,
  )
where

import Control.Exception (IOException, catch, onException, try)
import Control.Monad (unless, when)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT (..), runExceptT, throwE)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Foldable (traverse_)
import Data.List (sortOn)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Pretty (prettyShow)
import HaskellNix.Update.Catalog (decodeFamilyCatalog)
import HaskellNix.Update.Git (discoverPackages, ensureRevision, remoteHead, requireRevision)
import HaskellNix.Update.Hackage (HttpClient, defaultHttpClient, queryHackage)
import HaskellNix.Update.Mori (MoriProject (..), locateMoriProject)
import HaskellNix.Update.Nix
import HaskellNix.Update.PackageLock (decodePackageLock, decodePackageLockForRefresh, encodePackageLock)
import HaskellNix.Update.Plan (planRefresh, renderChanges)
import Data.Text.IO qualified as TextIO
import HaskellNix.Update.Process (ProcessRunner, defaultProcessRunner, streamingProcessRunner)
import HaskellNix.Update.Types
import System.Directory (removeFile, renameFile)
import System.FilePath (takeDirectory, (</>))
import System.IO (hClose, hFlush, hIsTerminalDevice, openBinaryTempFile, stderr)

data WorkflowPaths = WorkflowPaths
  { repositoryRoot :: !FilePath,
    catalogPath :: !FilePath,
    packageLockPath :: !FilePath,
    flakeLockPath :: !FilePath
  }
  deriving stock (Eq, Show)

data WorkflowEnvironment = WorkflowEnvironment
  { processRunner :: !ProcessRunner,
    httpClient :: !HttpClient,
    -- | Reports each step as it starts. Refreshes spend most of their time in
    -- silent network and `nix` work, so this is what shows one is progressing.
    progress :: !(Text -> IO ())
  }

defaultWorkflowPaths :: FilePath -> WorkflowPaths
defaultWorkflowPaths repositoryRoot =
  WorkflowPaths
    { repositoryRoot,
      catalogPath = "config/first-party-families.json",
      packageLockPath = "packages/first-party-lock.json",
      flakeLockPath = "flake.lock"
    }

-- | Streams step progress and subprocess stderr when stderr is a terminal, and
-- stays quiet otherwise so a caller collecting stderr (such as `just status`,
-- which reports its first line) sees only the final error.
defaultWorkflowEnvironment :: IO WorkflowEnvironment
defaultWorkflowEnvironment = do
  httpClient <- defaultHttpClient
  interactive <- hIsTerminalDevice stderr
  pure
    WorkflowEnvironment
      { processRunner = if interactive then streamingProcessRunner else defaultProcessRunner,
        httpClient,
        progress = if interactive then reportProgress else const (pure ())
      }

reportProgress :: Text -> IO ()
reportProgress step = TextIO.hPutStrLn stderr ("==> " <> step) >> hFlush stderr

runRefreshWorkflow :: WorkflowEnvironment -> WorkflowPaths -> [Text] -> Bool -> IO (Either UpdateError Text)
runRefreshWorkflow environment paths requestedFamilies dryRun = do
  loaded <- loadManagedState decodePackageLockForRefresh paths
  case loaded of
    Left updateError -> pure (Left updateError)
    Right state@ManagedState {catalog, packageLock} ->
      case selectFamilies catalog requestedFamilies of
        Left updateError -> pure (Left updateError)
        Right selectedFamilies
          | dryRun -> runExceptT (previewRefresh environment paths catalog packageLock selectedFamilies)
          | otherwise -> guardedRefresh environment paths state selectedFamilies

runCheckWorkflow :: WorkflowEnvironment -> WorkflowPaths -> [Text] -> Bool -> IO (Either UpdateError Text)
runCheckWorkflow environment paths requestedFamilies online = do
  loaded <- loadManagedState decodePackageLock paths
  case loaded of
    Left updateError -> pure (Left updateError)
    Right ManagedState {catalog, packageLock} ->
      case selectFamilies catalog requestedFamilies of
        Left updateError -> pure (Left updateError)
        Right selectedFamilies -> runExceptT $ do
          traverse_ (checkFamily environment paths packageLock online) selectedFamilies
          pure
            ( "Checked "
                <> Text.pack (show (length selectedFamilies))
                <> " family/families; no drift found"
                <> if online then " (online)." else " (offline)."
            )

data ManagedState = ManagedState
  { catalog :: !FamilyCatalog,
    packageLock :: !PackageLock,
    originalFlakeLock :: !ByteString,
    originalPackageLock :: !ByteString
  }

loadManagedState :: (FamilyCatalog -> ByteString -> Either Text PackageLock) -> WorkflowPaths -> IO (Either UpdateError ManagedState)
loadManagedState decodeLock paths = runExceptT $ do
  catalogBytes <- readFileE (resolvePath paths (catalogPath paths))
  catalog <- liftEitherText "family catalog" (decodeFamilyCatalog catalogBytes)
  originalPackageLock <- readFileE (resolvePath paths (packageLockPath paths))
  packageLock <- liftEitherText "package lock" (decodeLock catalog originalPackageLock)
  originalFlakeLock <- readFileE (resolvePath paths (flakeLockPath paths))
  pure ManagedState {catalog, packageLock, originalFlakeLock, originalPackageLock}

previewRefresh :: WorkflowEnvironment -> WorkflowPaths -> FamilyCatalog -> PackageLock -> [FamilyConfig] -> ExceptT UpdateError IO Text
previewRefresh environment paths catalog packageLock selectedFamilies = do
  observations <- traverse (observeRemoteFamily environment paths) selectedFamilies
  RefreshPlan {familyChanges} <- liftEitherE (planRefresh catalog packageLock observations)
  pure ("Dry run; managed lock files were not changed.\n" <> renderChanges familyChanges)

guardedRefresh :: WorkflowEnvironment -> WorkflowPaths -> ManagedState -> [FamilyConfig] -> IO (Either UpdateError Text)
guardedRefresh environment@WorkflowEnvironment {processRunner, progress} paths state@ManagedState {catalog, packageLock, originalPackageLock} selectedFamilies = do
  progress "checking that flake.lock and packages/first-party-lock.json are committed"
  dirty <-
    managedFilesDirty
      processRunner
      (repositoryRoot paths)
      [flakeLockPath paths, packageLockPath paths]
  case dirty of
    Left updateError -> pure (Left updateError)
    Right True ->
      pure
        ( Left
            (UpdateError "refusing to refresh because flake.lock or packages/first-party-lock.json has uncommitted changes")
        )
    Right False -> do
      attempted <-
        try (runExceptT (applyRefresh environment paths catalog packageLock originalPackageLock selectedFamilies))
          :: IO (Either IOException (Either UpdateError Text))
      case attempted of
        Right (Right summary) -> pure (Right summary)
        Right (Left updateError) -> progress rollbackStep >> rollbackAfterFailure paths state updateError
        Left exception ->
          progress rollbackStep
            >> rollbackAfterFailure paths state (UpdateError ("refresh failed: " <> Text.pack (show exception)))
  where
    rollbackStep = "refresh failed; restoring flake.lock and packages/first-party-lock.json"

applyRefresh :: WorkflowEnvironment -> WorkflowPaths -> FamilyCatalog -> PackageLock -> ByteString -> [FamilyConfig] -> ExceptT UpdateError IO Text
applyRefresh environment@WorkflowEnvironment {processRunner, progress} paths catalog previousLock originalPackageLock selectedFamilies = do
  familiesWithRemoteHeads <- traverse addRemoteHead selectedFamilies
  traverse_ updateWhenChanged familiesWithRemoteHeads
  traverse_ verifyLockedHead familiesWithRemoteHeads
  observations <- traverse (observeLockedFamily environment paths) selectedFamilies
  RefreshPlan {familyChanges, nextPackageLock} <- liftEitherE (planRefresh catalog previousLock observations)
  let nextBytes = LazyByteString.toStrict (encodePackageLock nextPackageLock)
  when (originalPackageLock /= nextBytes) $ do
    lift (progress ("writing " <> Text.pack (packageLockPath paths)))
    writeFileE (resolvePath paths (packageLockPath paths)) nextBytes
  lift (progress "validating: warming flake checks, then nix flake check (this is the slow step)")
  liftEitherIO (validateFlake processRunner (repositoryRoot paths))
  pure (renderChanges familyChanges)
  where
    addRemoteHead family@FamilyConfig {name = FamilyName familyName, github} = do
      lift (progress (familyName <> ": querying GitHub HEAD"))
      revision <- liftEitherIO (remoteHead processRunner github)
      pure (family, revision)
    updateWhenChanged (FamilyConfig {name = FamilyName familyName, githubInput}, remoteRevision) = do
      currentRevision <- liftEitherIO (readLockedRevision (resolvePath paths (flakeLockPath paths)) githubInput)
      if currentRevision /= remoteRevision
        then do
          lift (progress (familyName <> ": locking " <> githubInput <> " at " <> shortRevision remoteRevision))
          liftEitherIO (updateInput processRunner (repositoryRoot paths) githubInput)
        else lift (progress (familyName <> ": " <> githubInput <> " already at GitHub HEAD"))
    verifyLockedHead (FamilyConfig {name = FamilyName familyName, githubInput}, remoteRevision) = do
      lockedRevision <- liftEitherIO (readLockedRevision (resolvePath paths (flakeLockPath paths)) githubInput)
      unless (lockedRevision == remoteRevision) $
        throwE
          ( UpdateError
              ( "family "
                  <> familyName
                  <> ": nix flake update did not lock the queried remote HEAD"
              )
          )

observeRemoteFamily :: WorkflowEnvironment -> WorkflowPaths -> FamilyConfig -> ExceptT UpdateError IO ObservedFamily
observeRemoteFamily environment@WorkflowEnvironment {processRunner} paths family@FamilyConfig {github} = do
  revision <- liftEitherIO (remoteHead processRunner github)
  observeFamily environment paths True family revision

observeLockedFamily :: WorkflowEnvironment -> WorkflowPaths -> FamilyConfig -> ExceptT UpdateError IO ObservedFamily
observeLockedFamily environment paths family@FamilyConfig {githubInput} = do
  revision <- liftEitherIO (readLockedRevision (resolvePath paths (flakeLockPath paths)) githubInput)
  observeFamily environment paths True family revision

observeFamily :: WorkflowEnvironment -> WorkflowPaths -> Bool -> FamilyConfig -> GitRevision -> ExceptT UpdateError IO ObservedFamily
observeFamily WorkflowEnvironment {processRunner, httpClient, progress} _paths fetchMissing family@FamilyConfig {name = FamilyName familyName} revision = do
  lift (progress (familyName <> ": discovering packages at " <> shortRevision revision))
  MoriProject {path} <- liftEitherIO (locateMoriProject processRunner family)
  if fetchMissing
    then liftEitherIO (ensureRevision processRunner path revision)
    else liftEitherIO (requireRevision processRunner path revision)
  discoveredPackages <- liftEitherIO (discoverPackages processRunner path revision)
  includedPackages <- liftEitherE (applyExclusions family discoveredPackages)
  packages <- traverse (observePackage processRunner httpClient progress) includedPackages
  pure ObservedFamily {config = family, githubRev = revision, packages}

shortRevision :: GitRevision -> Text
shortRevision (GitRevision revision) = Text.take 7 revision

-- Drop configured exclusions from discovery. An exclusion that matches nothing
-- is stale configuration, so it fails rather than silently doing nothing.
applyExclusions :: FamilyConfig -> [DiscoveredPackage] -> Either UpdateError [DiscoveredPackage]
applyExclusions FamilyConfig {name = familyName, excludedPackages} discoveredPackages
  | not (null unmatched) =
      Left
        ( UpdateError
            ( "family "
                <> familyNameText familyName
                <> ": excluded packages were not discovered: "
                <> Text.intercalate ", " unmatched
            )
        )
  | otherwise = Right (filter included discoveredPackages)
  where
    discoveredNames = Set.fromList [name | DiscoveredPackage {name} <- discoveredPackages]
    unmatched =
      [ packageName
      | PackageName packageName <- Set.toAscList (Set.difference excludedPackages discoveredNames)
      ]
    included DiscoveredPackage {name} = not (Set.member name excludedPackages)

observePackage :: ProcessRunner -> HttpClient -> (Text -> IO ()) -> DiscoveredPackage -> ExceptT UpdateError IO ObservedPackage
observePackage processRunner httpClient progress discovered@DiscoveredPackage {name} = do
  lift (progress (packageNameText name <> ": querying Hackage"))
  hackageRelease <- liftEitherIO (queryHackage httpClient name)
  case hackageRelease of
    Nothing -> pure ObservedPackage {discovered, hackage = Nothing, usedHackageFallback = False}
    Just HackageRelease {version, usedFallback} -> do
      lift (progress (packageNameText name <> ": prefetching " <> Text.pack (prettyShow version)))
      hash <- liftEitherIO (prefetchHackage processRunner name version)
      pure
        ObservedPackage
          { discovered,
            hackage = Just HackagePin {version, hash},
            usedHackageFallback = usedFallback
          }

checkFamily :: WorkflowEnvironment -> WorkflowPaths -> PackageLock -> Bool -> FamilyConfig -> ExceptT UpdateError IO ()
checkFamily WorkflowEnvironment {processRunner, httpClient} paths packageLock online family@FamilyConfig {name = familyName, github, githubInput} = do
  lockedFamily <- liftEitherE (findLockedFamily packageLock familyName)
  flakeRevision <- liftEitherIO (readLockedRevision (resolvePath paths (flakeLockPath paths)) githubInput)
  let LockedFamily {githubRev, packages = lockedPackages} = lockedFamily
  unless (flakeRevision == githubRev) $
    throwE
      ( UpdateError
          ( "family "
              <> familyNameText familyName
              <> ": package lock revision does not match flake.lock"
          )
      )
  MoriProject {path} <- liftEitherIO (locateMoriProject processRunner family)
  liftEitherIO (requireRevision processRunner path githubRev)
  discoveredPackages <- liftEitherIO (discoverPackages processRunner path githubRev)
  includedPackages <- liftEitherE (applyExclusions family discoveredPackages)
  liftEitherE (verifyDiscovered familyName lockedPackages includedPackages)
  when online $ do
    remoteRevision <- liftEitherIO (remoteHead processRunner github)
    unless (remoteRevision == githubRev) $
      throwE (UpdateError ("family " <> familyNameText familyName <> ": remote GitHub HEAD differs from the lock"))
    traverse_ (checkHackage httpClient familyName) lockedPackages

checkHackage :: HttpClient -> FamilyName -> LockedPackage -> ExceptT UpdateError IO ()
checkHackage httpClient familyName LockedPackage {name, hackage} = do
  release <- liftEitherIO (queryHackage httpClient name)
  let expectedVersion = fmap (\HackagePin {version} -> version) hackage
      actualVersion = fmap (\HackageRelease {version} -> version) release
  unless (expectedVersion == actualVersion) $
    throwE
      ( UpdateError
          ( familyNameText familyName
              <> "/"
              <> packageNameText name
              <> ": Hackage latest version differs from the lock"
          )
      )

verifyDiscovered :: FamilyName -> [LockedPackage] -> [DiscoveredPackage] -> Either UpdateError ()
verifyDiscovered familyName lockedPackages discoveredPackages =
  let locked = sortOn packageNameKey [(name, path, version) | LockedPackage {name, path, version} <- lockedPackages]
      discovered = sortOn packageNameKey [(name, path, version) | DiscoveredPackage {name, path, version} <- discoveredPackages]
   in unlessEither
        (locked == discovered)
        ( UpdateError
            ( "family "
                <> familyNameText familyName
                <> ": packages parsed from the locked Git object differ from the package lock"
            )
        )
  where
    packageNameKey (name, _, _) = name

findLockedFamily :: PackageLock -> FamilyName -> Either UpdateError LockedFamily
findLockedFamily PackageLock {families} familyName =
  maybe
    (Left (UpdateError ("package lock is missing family " <> familyNameText familyName)))
    Right
    (Map.lookup familyName (Map.fromList [(name, family) | family@LockedFamily {name} <- families]))

selectFamilies :: FamilyCatalog -> [Text] -> Either UpdateError [FamilyConfig]
selectFamilies FamilyCatalog {families} requested
  | null requested = Right families
  | length requested /= Set.size requestedSet = Left (UpdateError "--family values must not be repeated")
  | otherwise = do
      let byName = Map.fromList [(familyNameText name, family) | family@FamilyConfig {name} <- families]
          unknown = requestedSet `Set.difference` Map.keysSet byName
      unlessEither
        (Set.null unknown)
        (UpdateError ("unknown family/families: " <> Text.intercalate ", " (Set.toAscList unknown)))
      traverse (maybe (Left (UpdateError "internal family selection error")) Right . (`Map.lookup` byName)) requested
  where
    requestedSet = Set.fromList requested

rollbackAfterFailure :: WorkflowPaths -> ManagedState -> UpdateError -> IO (Either UpdateError Text)
rollbackAfterFailure paths ManagedState {originalFlakeLock, originalPackageLock} originalError = do
  rollbackResult <-
    try $ do
      atomicWriteFile (resolvePath paths (flakeLockPath paths)) originalFlakeLock
      atomicWriteFile (resolvePath paths (packageLockPath paths)) originalPackageLock
    :: IO (Either IOException ())
  pure $ case rollbackResult of
    Right () -> Left originalError
    Left rollbackError ->
      Left
        ( UpdateError
            ( message originalError
                <> "; rollback also failed: "
                <> Text.pack (show rollbackError)
            )
        )

atomicWriteFile :: FilePath -> ByteString -> IO ()
atomicWriteFile destination bytes = do
  let directory = takeDirectory destination
  (temporaryPath, handle) <- openBinaryTempFile directory ".haskell-nix-update.tmp"
  let cleanup = do
        ignoreIOException (hClose handle)
        ignoreIOException (removeFile temporaryPath)
  (ByteString.hPut handle bytes >> hClose handle >> renameFile temporaryPath destination)
    `onException` cleanup

readFileE :: FilePath -> ExceptT UpdateError IO ByteString
readFileE path = ExceptT $ do
  attempted <- try (ByteString.readFile path) :: IO (Either IOException ByteString)
  pure (either (Left . fileError "read" path) Right attempted)

writeFileE :: FilePath -> ByteString -> ExceptT UpdateError IO ()
writeFileE path bytes = ExceptT $ do
  attempted <- try (atomicWriteFile path bytes) :: IO (Either IOException ())
  pure (either (Left . fileError "write" path) Right attempted)

fileError :: Text -> FilePath -> IOException -> UpdateError
fileError action path exception =
  UpdateError ("could not " <> action <> " " <> Text.pack path <> ": " <> Text.pack (show exception))

liftEitherIO :: IO (Either UpdateError value) -> ExceptT UpdateError IO value
liftEitherIO = ExceptT

liftEitherE :: Either UpdateError value -> ExceptT UpdateError IO value
liftEitherE = ExceptT . pure

liftEitherText :: Text -> Either Text value -> ExceptT UpdateError IO value
liftEitherText context = liftEitherE . either (Left . UpdateError . ((context <> ": ") <>)) Right

unlessEither :: Bool -> UpdateError -> Either UpdateError ()
unlessEither condition updateError = if condition then Right () else Left updateError

resolvePath :: WorkflowPaths -> FilePath -> FilePath
resolvePath WorkflowPaths {repositoryRoot} path = repositoryRoot </> path

familyNameText :: FamilyName -> Text
familyNameText (FamilyName name) = name

packageNameText :: PackageName -> Text
packageNameText (PackageName name) = name

ignoreIOException :: IO () -> IO ()
ignoreIOException action = action `catch` ignore
  where
    ignore :: IOException -> IO ()
    ignore _ = pure ()
