{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Cli (CohortCommand (..), cohortParser, runCohort) where

import Control.Exception (IOException, try)
import Data.Aeson (FromJSON, ToJSON, eitherDecodeStrict')
import Data.Aeson.Encode.Pretty (encodePretty)
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import HaskellNix.Update.Cohort.Inventory
import HaskellNix.Update.Cohort.Types
import HaskellNix.Update.Types (UpdateError (..))
import Options.Applicative
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory, (</>))

data CohortCommand
    = CohortInventory !FilePath !Text !FilePath !FilePath !Text !FilePath
    | CohortInventoryNix !FilePath !FilePath ![(Text, FilePath)] !Text !Text !Text !FilePath
    deriving stock (Eq, Show)

cohortParser :: Parser CohortCommand
cohortParser =
    subparser
        ( command "inventory" (info (inventoryParser <**> helper) (fullDesc <> progDesc "Record a contributor's fresh Cabal plan and component bounds"))
            <> command "inventory-nix" (info (nixParser <**> helper) (fullDesc <> progDesc "Record channel and deployed dependency version maps"))
        )
  where
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
