{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Cli (CohortCommand (..), cohortParser, runCohort) where

import Control.Exception (IOException, try)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT (..), runExceptT)
import Data.Aeson (FromJSON, ToJSON, Value, eitherDecodeStrict')
import Data.Aeson.Encode.Pretty (encodePretty)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Distribution.Pretty (prettyShow)
import HaskellNix.Update.Catalog (decodeFamilyCatalog)
import HaskellNix.Update.Cohort.Freeze (FreezeHeader (FreezeHeader), normaliseCabalFreeze, parseCohortFreeze, renderCohortFreeze)
import HaskellNix.Update.Cohort.Impact (impactReport, retainedConstraints)
import HaskellNix.Update.Cohort.Inventory
import HaskellNix.Update.Cohort.Model
import HaskellNix.Update.Cohort.Report qualified as Report
import HaskellNix.Update.Cohort.Types
import HaskellNix.Update.PackageLock (decodePackageSetLock, selectPackageSet)
import HaskellNix.Update.Types (UpdateError (..))
import HaskellNix.Update.Types qualified as Lock
import Options.Applicative
import System.Directory (createDirectoryIfMissing, listDirectory)
import System.FilePath (takeDirectory, takeExtension, (</>))

data CohortCommand
    = CohortInventory !FilePath !Text !FilePath !FilePath !Text !FilePath
    | CohortInventoryNix !FilePath !FilePath ![(Text, FilePath)] !Text !Text !Text !FilePath
    | CohortStub !FilePath !FilePath !FilePath !FilePath !FilePath
    | CohortNormaliseFreeze !FilePath !FilePath !FilePath !Text !Text
    | CohortReport !FilePath !FilePath !FilePath !FilePath !FilePath !(Maybe FilePath)
    | CohortCheck !FilePath !FilePath !FilePath
    | CohortUpdateConstraints !FilePath !(Maybe FilePath) !Bool ![Text] !(Maybe Text) !FilePath
    | CohortImpact !FilePath !FilePath !FilePath !(Maybe FilePath) !(Maybe FilePath) !FilePath
    deriving stock (Eq, Show)

cohortParser :: Parser CohortCommand
cohortParser =
    subparser
        ( command "inventory" (info (inventoryParser <**> helper) (fullDesc <> progDesc "Record a contributor's fresh Cabal plan and component bounds"))
            <> command "report" (info (reportParser <**> helper) (fullDesc <> progDesc "Report upgrade-only violations, caps and source identities"))
            <> command "check" (info (checkParser <**> helper) (fullDesc <> progDesc "Compare a resolved plan with the freeze and source manifest"))
            <> command "update-constraints" (info (updateParser <**> helper) (fullDesc <> progDesc "Retain unrelated and runtime versions for an explicit targeted update"))
            <> command "impact" (info (impactParser <**> helper) (fullDesc <> progDesc "Report version, source, metadata, flag and policy changes with consumer paths"))
            <> command "stub" (info (stubParser <**> helper) (fullDesc <> progDesc "Generate the union stub and upgrade-only floors"))
            <> command "normalise-freeze" (info (normaliseParser <**> helper) (fullDesc <> progDesc "Write canonical version constraints and recorded index-state"))
            <> command "inventory-nix" (info (nixParser <**> helper) (fullDesc <> progDesc "Record channel and deployed dependency version maps"))
        )
  where
    updateParser = CohortUpdateConstraints <$> pathOption "freeze" "cabal/cohort.freeze" <*> optionalPath "runtime-freeze" <*> switch (long "update-runtime") <*> some (textOption "package") <*> optional (textOption "index-state") <*> pathOption "out" "cabal/retained.config"
    impactParser = CohortImpact <$> pathOption "before" "cabal/cohort-sources.json" <*> strOption (long "after" <> metavar "FILE") <*> pathOption "inventory" "cabal/inventory" <*> optionalPath "before-policy" <*> optionalPath "after-policy" <*> pathOption "out" "cabal/cohort-impact.txt"
    optionalPath key = optional (strOption (long key <> metavar "FILE"))
    checkParser = CohortCheck <$> pathOption "freeze" "cabal/cohort.freeze" <*> pathOption "sources" "cabal/cohort-sources.json" <*> pathOption "plan" "cabal/dist-newstyle/cache/plan.json"
    reportParser = CohortReport <$> pathOption "freeze" "cabal/cohort.freeze" <*> pathOption "inventory" "cabal/inventory" <*> pathOption "lock" "packages/first-party-lock.json" <*> pathOption "catalog" "config/first-party-families.json" <*> pathOption "policy-floors" "cabal/policy-floors.json" <*> optional (strOption (long "out" <> metavar "FILE"))
    pathOption key defaultPath = strOption (long key <> value defaultPath <> metavar "PATH")
    stubParser = CohortStub <$> pathOption "inventory" "cabal/inventory" <*> pathOption "lock" "packages/first-party-lock.json" <*> pathOption "catalog" "config/first-party-families.json" <*> pathOption "policy-floors" "cabal/policy-floors.json" <*> pathOption "out-dir" "cabal"
    normaliseParser = CohortNormaliseFreeze <$> strOption (long "in" <> metavar "FILE") <*> strOption (long "out" <> metavar "FILE") <*> pathOption "plan" "cabal/dist-newstyle/cache/plan.json" <*> textOption "index-state" <*> textOption "haskell-nix-rev"
    nixParser =
        CohortInventoryNix
            <$> strOption (long "names" <> metavar "FILE")
            <*> strOption (long "channel" <> metavar "FILE")
            <*> many (option (eitherReader deployedPair) (long "deployed" <> metavar "NAME=FILE"))
            <*> textOption "channel-revision"
            <*> textOption "dotfiles-revision"
            <*> textOption "system"
            <*> strOption (long "out" <> metavar "FILE")
    textOption key = Text.pack <$> strOption (long key <> metavar "VALUE")
    deployedPair raw = case break (== '=') raw of
        (key, '=' : path) | not (null key || null path) -> Right (Text.pack key, path)
        _ -> Left "expected NAME=FILE"
    inventoryParser =
        CohortInventory
            <$> strOption (long "contributors" <> value "cabal/contributors.json" <> metavar "FILE")
            <*> (Text.pack <$> strOption (long "contributor" <> metavar "NAME"))
            <*> strOption (long "source" <> metavar "DIR")
            <*> strOption (long "plan" <> metavar "FILE")
            <*> (Text.pack <$> strOption (long "configuration" <> value "default" <> metavar "NAME"))
            <*> strOption (long "out" <> metavar "FILE")

runCohort :: CohortCommand -> IO (Either UpdateError Text)
runCohort commandValue = do
    result <- try (dispatch commandValue)
    pure $ case result of
        Left (err :: IOException) -> Left (UpdateError (Text.pack (show err)))
        Right outcome -> either (Left . UpdateError) Right outcome

readJSON :: (FromJSON a) => FilePath -> IO (Either Text a)
readJSON path = either (Left . Text.pack) Right . eitherDecodeStrict' <$> BS.readFile path

writeJSON :: (ToJSON a) => FilePath -> a -> IO ()
writeJSON path payload = do
    createDirectoryIfMissing True (takeDirectory path)
    LBS.writeFile path (encodePretty payload <> "\n")

dispatch :: CohortCommand -> IO (Either Text Text)
dispatch (CohortInventory contributorsFile wanted root plan config out) = do
    contributors <- readJSON contributorsFile
    case contributors >>= selectContributor of
        Left err -> pure (Left err)
        Right contributor -> do
            versions <- readPlanVersions plan
            bounds <- readDeclaredBounds root contributor.cabalFiles
            constraints <- readProjectConstraints (root </> "cabal.project")
            project <- TextIO.readFile (root </> "cabal.project")
            case Inventory contributor config (contributor.indexStateOverride <|> lookup "index-state" (projectFields project)) <$> versions <*> ((<>) <$> bounds <*> constraints) <*> pure project of
                Left err -> pure (Left err)
                Right inventory -> do
                    writeJSON out inventory
                    pure (Right ("Recorded " <> wanted <> " [" <> config <> "] in " <> Text.pack out))
  where
    selectContributor contributors = case [c | c <- contributors, c.name == wanted] of
        [c]
            | config `elem` map (\x -> x.name) c.configurations -> Right c
            | otherwise -> Left ("unknown contributor configuration: " <> config)
        [] -> Left ("unknown contributor: " <> wanted)
        _ -> Left ("duplicate contributor: " <> wanted)
dispatch (CohortInventoryNix namesFile channelFile deployedFiles channelRev dotfilesRev system out) = do
    names <- readJSON namesFile
    channel <- readJSON channelFile
    deployed <- traverse (\(name, path) -> fmap ((name,) <$>) (readJSON path)) deployedFiles
    case (,,) <$> names <*> channel <*> sequence deployed of
        Left err -> pure (Left err)
        Right (requested :: [Text], channelMap, deployments) ->
            if Map.keys channelMap /= requested || length deployments /= Map.size (Map.fromList deployments)
                then pure (Left "Nix inventory names differ or deployed contributors are duplicated")
                else do
                    writeJSON out (NixInventory channelRev dotfilesRev system channelMap (Map.fromList deployments))
                    pure (Right ("Recorded Nix inventory in " <> Text.pack out))
dispatch (CohortStub directory lockFile catalogFile policyFile out) = runExceptT $ do
    (inventories, nix, firstParty, policy) <- loadInputs directory lockFile catalogFile policyFile
    floors <- ExceptT (pure (floorVersions inventories nix firstParty policy))
    (bounds, _) <- ExceptT (pure (stubBounds floors inventories))
    lift (createDirectoryIfMissing True (out </> "rei-family-cohort"))
    lift (TextIO.writeFile (out </> "rei-family-cohort/rei-family-cohort.cabal") (renderStubCabal bounds))
    lift (TextIO.writeFile (out </> "floors.config") (renderFloors floors))
    pure ("Generated cohort stub and " <> Text.pack (show (Map.size floors)) <> " upgrade-only floors")
dispatch (CohortNormaliseFreeze input out plan indexState channelRev) = runExceptT $ do
    original <- lift (TextIO.readFile input)
    versions <- ExceptT (pure (normaliseCabalFreeze original))
    packages <- ExceptT (readPlanVersions plan)
    let sourcePins = Map.keysSet (Map.filter (\p -> p.source == SourcePin) packages)
        retained = Map.withoutKeys versions sourcePins
    lift (TextIO.writeFile out (renderCohortFreeze (FreezeHeader indexState "ghc-9.12.4" channelRev "haskell-nix-update cohort normalise-freeze") retained))
    lift (writeJSON (takeDirectory out </> "cohort-sources.json") packages)
    pure ("Wrote freeze and source manifest: " <> Text.pack out)
dispatch (CohortReport freeze directory lockFile catalogFile policyFile out) = runExceptT $ do
    (inventories, nix, firstParty, policy) <- loadInputs directory lockFile catalogFile policyFile
    contents <- lift (TextIO.readFile freeze)
    versions <- ExceptT (pure (parseCohortFreeze contents))
    manifest :: Map Text PlanPackage <- ExceptT (readJSON (takeDirectory freeze </> "cohort-sources.json"))
    pinned <- ExceptT (pure (traverse (parseVersion . (\p -> p.version)) (Map.filter (\p -> p.source == SourcePin) manifest)))
    report <- ExceptT (pure (Report.cohortReport (Map.union versions pinned) inventories nix firstParty policy))
    let rendered = Report.renderReport report
    lift (maybe (pure ()) (\path -> TextIO.writeFile path rendered) out)
    if Report.reportFailed report then ExceptT (pure (Left rendered)) else pure rendered
dispatch (CohortCheck freeze sources plan) = runExceptT $ do
    contents <- lift (TextIO.readFile freeze)
    versions <- ExceptT (pure (parseCohortFreeze contents))
    expected <- ExceptT (readJSON sources)
    actual <- ExceptT (readPlanVersions plan)
    selected <- ExceptT (pure (traverse (parseVersion . (\p -> p.version)) (Map.filter (\p -> p.source /= SourcePin) actual)))
    if selected /= versions
        then ExceptT (pure (Left "resolved plan versions differ from the cohort freeze"))
        else
            if actual /= expected
                then ExceptT (pure (Left "resolved plan source, metadata, flags or dependency identities differ from the cohort manifest"))
                else pure "Cohort plan matches the freeze and source manifest"
dispatch (CohortUpdateConstraints freeze runtimeFreeze updateRuntime requested expectedIndex out) = runExceptT $ do
    original <- lift (TextIO.readFile freeze)
    versions <- ExceptT (pure (parseCohortFreeze original))
    runtime <- case runtimeFreeze of
        Nothing -> pure Map.empty
        Just path -> lift (TextIO.readFile path) >>= ExceptT . pure . parseCohortFreeze
    retained <- ExceptT (pure (retainedConstraints versions runtime updateRuntime requested))
    let index = maybe "" id (lookup "index-state" (projectFields original))
    case expectedIndex of
        Just expected | index /= "hackage.haskell.org " <> expected -> ExceptT (pure (Left "recorded index-state differs from the previous freeze; an explicit broad update is required"))
        _ -> pure ()
    lift (TextIO.writeFile out ("-- Targeted update: unrelated versions remain exact.\nindex-state: " <> index <> "\n" <> retained))
    pure ("Retained unrelated versions in " <> Text.pack out)
dispatch (CohortImpact before after directory beforePolicy afterPolicy out) = runExceptT $ do
    previous <- ExceptT (readJSON before)
    candidate <- ExceptT (readJSON after)
    inventories <- readInventories directory
    oldPolicy <- readPolicy beforePolicy
    newPolicy <- readPolicy afterPolicy
    let report = impactReport previous candidate oldPolicy newPolicy inventories
    lift (TextIO.writeFile out report)
    pure report
  where
    readPolicy :: Maybe FilePath -> ExceptT Text IO (Map Text Value)
    readPolicy Nothing = pure Map.empty
    readPolicy (Just path) = ExceptT (readJSON path)

readInventories :: FilePath -> ExceptT Text IO [Inventory]
readInventories directory = do
    files <- lift (sort <$> listDirectory directory)
    traverse (\file -> ExceptT (readJSON (directory </> file))) [f | f <- files, takeExtension f == ".json", f /= "nix.json"]

loadInputs :: FilePath -> FilePath -> FilePath -> FilePath -> ExceptT Text IO ([Inventory], NixInventory, Map Text Text, [PolicyFloor])
loadInputs directory lockFile catalogFile policyFile = do
    inventories <- readInventories directory
    nix <- ExceptT (readJSON (directory </> "nix.json"))
    policy <- ExceptT (readJSON policyFile)
    catalogBytes <- lift (BS.readFile catalogFile)
    catalog <- ExceptT (pure (decodeFamilyCatalog catalogBytes))
    lockBytes <- lift (BS.readFile lockFile)
    lock <- ExceptT (pure (decodePackageSetLock catalog lockBytes))
    selected <- ExceptT (pure (selectPackageSet catalog lock "default"))
    let firstParty = Map.fromList [(name, Text.pack (prettyShow pin.version)) | family <- selected, package <- family.packages, Lock.PackageName name <- [package.name], Just pin <- [package.hackage]]
    pure (inventories, nix, firstParty, policy)
