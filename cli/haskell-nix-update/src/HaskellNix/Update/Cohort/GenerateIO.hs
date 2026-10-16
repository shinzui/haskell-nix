{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.GenerateIO (
    GenerateOptions (..), runGenerate, decodeGenerationPolicy, decodeRevisions,
    resolveGeneratedEntries,
) where

import Control.Exception (onException)
import Control.Concurrent (threadDelay)
import Control.Monad (unless)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT (..), runExceptT)
import Data.Aeson (FromJSON, Value (..), eitherDecodeStrict', withObject, (.:))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as BS
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding (encodeUtf8)
import Data.Text.IO qualified as TextIO
import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Distribution.Pretty (prettyShow)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Freeze
import HaskellNix.Update.Cohort.Generate (classifyCohort)
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.Model (parseVersion)
import HaskellNix.Update.Cohort.Render (renderBootPackages, renderCohortVersions)
import HaskellNix.Update.Cohort.Revision (selectRevision)
import HaskellNix.Update.Cohort.Types (PlanPackage (..))
import HaskellNix.Update.Hackage (HttpClient (..), HttpResponse (..))
import HaskellNix.Update.Nix (decodeChannelRevision, prefetchHackage)
import HaskellNix.Update.Process
import HaskellNix.Update.Types (GitRevision (..), PackageName (..), SriHash (..), UpdateError (..))
import System.Directory (createDirectoryIfMissing, doesFileExist, makeAbsolute, removeFile, renameFile)
import System.FilePath (normalise, takeDirectory, (</>))
import System.IO (hClose)
import System.IO.Temp (withTempFile)

data GenerateOptions = GenerateOptions
    { freezePath :: !FilePath, policyPath :: !FilePath, outputPath :: !FilePath
    , bootOutputPath :: !FilePath, checkOnly :: !Bool
    } deriving stock (Eq, Show)

decodeGenerationPolicy :: BS.ByteString -> Either Text GenerationPolicy
decodeGenerationPolicy bytes = decodeWith parser bytes
  where
    parser = withObject "cohort policy" $ \o -> do
        schema :: Int <- o .: "schemaVersion"
        unless (schema == 1 && all (`elem` ["schemaVersion", "excluded", "sourcePinned"]) (KeyMap.keys o)) (fail "unsupported cohort policy schema or fields")
        excluded <- o .: "excluded"
        pinned <- o .: "sourcePinned"
        GenerationPolicy <$> traverse owned excluded <*> traverse owned pinned
    owned = withObject "owned policy" $ \o -> do
        unless (all (`elem` ["reason", "owner"]) (KeyMap.keys o)) (fail "unknown ownership policy field")
        OwnedPolicy <$> o .: "reason" <*> o .: "owner"

decodeRevisions :: BS.ByteString -> Either Text [HackageRevision]
decodeRevisions bytes = do
    values :: [Value] <- decodeJSON bytes
    traverse (either (Left . Text.pack) Right . parseEither parser) values
  where
    parser = withObject "Hackage revision" $ \o -> HackageRevision <$> o .: "number" <*> o .: "time" <*> o .: "sha256"

-- Source hashes and metadata have independent lifetimes: even a cached tarball
-- must resolve its metadata at this context's exact cutoff. Runtime generation
-- can call this helper with its own retained context and hash cache.
resolveGeneratedEntries :: ProcessRunner -> HttpClient -> UTCTime -> Map Text ClassifiedPackage -> Map Text (Version, SriHash) -> IO (Either UpdateError (Map Text GeneratedEntry))
resolveGeneratedEntries runner client cutoff classified cached = runExceptT $
    Map.traverseWithKey resolve (Map.filter (\p -> p.packageClassification == CohortGenerated) classified)
  where
    resolve name package = do
        version <- fromText (parseVersion package.selectedPackage.version)
        expected <- fromText (metadataHash name package.selectedPackage)
        response <- ExceptT (request 3 ("https://hackage.haskell.org/package/" <> name <> "-" <> Text.pack (prettyShow version) <> "/revisions/"))
        unless (response.statusCode == 200) (failText ("Hackage revisions HTTP " <> Text.pack (show response.statusCode) <> " for " <> name))
        revisions <- fromText (decodeRevisions response.body)
        revision <- fromText (selectRevision cutoff expected revisions)
        hash <- case Map.lookup name cached of
            Just (old, value) | old == version -> pure value
            _ -> ExceptT (prefetchHackage runner (PackageName name) version)
        pure (GeneratedEntry version hash revision)
    request attempts url = do
        result <- client.performGet url
        if attempts > (1 :: Int) && retryable result
            then threadDelay 250000 >> request (attempts - 1) url
            else pure result
    retryable (Left _) = True
    retryable (Right response) = response.statusCode `elem` [429, 500, 502, 503, 504]
    metadataHash name package = case [hash | Object fields <- package.identities, Just (String hash) <- [KeyMap.lookup "pkg-cabal-sha256" fields]] of
        hash : rest | all (== hash) rest && length (hash : rest) == length package.identities -> Right hash
        _ -> Left ("missing or conflicting Cabal metadata hashes for " <> name)

runGenerate :: ProcessRunner -> HttpClient -> Map Text Version -> GenerateOptions -> IO (Either UpdateError Text)
runGenerate runner client firstParty options = runExceptT $ do
    targets <- lift (traverse (fmap normalise . makeAbsolute) [options.outputPath, options.bootOutputPath])
    protected <- lift (traverse (fmap normalise . makeAbsolute) [options.freezePath, options.policyPath, takeDirectory options.freezePath </> "cohort-sources.json", "flake.lock"])
    unless (head targets /= last targets && all (`notElem` protected) targets) (failText "cohort output paths must differ and cannot overwrite solve inputs")
    contents <- lift (TextIO.readFile options.freezePath)
    document <- fromText (parseFreezeDocument contents)
    sources <- readJSON (takeDirectory options.freezePath </> "cohort-sources.json")
    policy <- lift (BS.readFile options.policyPath) >>= fromText . decodeGenerationPolicy
    cutoff <- fromText (maybe (Left "invalid cohort cutoff") Right (parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" (Text.unpack document.freezeIndexState)))
    compiler <- case [Text.strip value | line <- Text.lines contents, Just value <- [Text.stripPrefix "-- Compiler:" line]] of
        ["ghc-9.12.4"] -> pure "9.12.4"
        _ -> failText "cohort generation currently requires the recorded ghc-9.12.4 compiler"
    compilerRoot <- command "nix" ["build", "--no-link", "--print-out-paths", "--impure", "--expr", "let f = builtins.getFlake (toString ./.); in (import f.inputs.nixpkgs {}).haskell.compiler.ghc9124"]
    shipped <- command (Text.unpack (Text.strip compilerRoot) </> "bin/ghc-pkg") ["list", "--global", "--simple-output"]
    boot <- fromText (Map.fromList <$> traverse bootEntry (Text.words shipped))
    let context = GenerationContext document sources boot firstParty policy Map.empty Map.empty Map.empty
    -- A version-only base probe cannot prove source/metadata/policy equality.
    -- Without that evidence the shared classifier conservatively generates it.
    classified <- fromText (classifyCohort context)
    cached <- readCachedHashes runner options.outputPath
    entries <- ExceptT (resolveGeneratedEntries runner client cutoff classified cached)
    absoluteFreeze <- lift (makeAbsolute options.freezePath)
    hash <- Text.strip <$> command "nix" ["eval", "--impure", "--raw", "--expr", "builtins.hashFile \"sha256\" " <> nixString (Text.pack absoluteFreeze)]
    lock <- lift (BS.readFile "flake.lock")
    GitRevision nixpkgs <- ExceptT (pure (decodeChannelRevision "nixpkgs" lock))
    rendered <- fromText (renderCohortVersions (GenerationMetadata hash document.freezeIndexState compiler nixpkgs) document classified entries)
    let renderedBoot = renderBootPackages compiler boot
    if options.checkOnly
        then do
            current <- lift (readOptional options.outputPath)
            currentBoot <- lift (readOptional options.bootOutputPath)
            unless (current == Just rendered && currentBoot == Just renderedBoot) (failText "generated cohort files are stale; run cohort generate")
        else lift (publishPair options.outputPath rendered options.bootOutputPath renderedBoot)
    pure ("Cohort: " <> Text.pack (show (Map.size classified)) <> " recorded packages, " <> Text.pack (show (Map.size entries)) <> " generated Hackage recipes")
  where
    command executable arguments = (.standardOutput) <$> ExceptT (runChecked runner (ProcessSpec executable arguments Nothing []))
    bootEntry entry = let (name, version) = Text.breakOnEnd "-" entry in do
        unless (not (Text.null name)) (Left ("invalid shipped boot package: " <> entry))
        (Text.dropEnd 1 name,) <$> parseVersion version

readCachedHashes :: ProcessRunner -> FilePath -> ExceptT UpdateError IO (Map Text (Version, SriHash))
readCachedHashes runner path = do
    exists <- lift (doesFileExist path)
    if not exists then pure Map.empty else do
        output <- ExceptT (runChecked runner (ProcessSpec "nix" ["eval", "--json", "--file", path] Nothing []))
        fromText (decodeWith parser (encodeUtf8 output.standardOutput))
  where
    parser = withObject "generated cohort" $ \o -> do
        packages <- o .: "packages"
        traverse (withObject "generated package" $ \p -> do
            version <- p .: "version"
            parsed <- either (fail . Text.unpack) pure (parseVersion version)
            hash <- p .: "sha256"
            pure (parsed, SriHash hash)) packages

-- Stage both files before replacing either, and restore the previous pair if a
-- rename fails. Network/metadata failures occur before this publication step.
publishPair :: FilePath -> Text -> FilePath -> Text -> IO ()
publishPair target contents bootTarget bootContents = do
    old <- readOptional target
    oldBoot <- readOptional bootTarget
    createDirectoryIfMissing True (takeDirectory target)
    createDirectoryIfMissing True (takeDirectory bootTarget)
    withTempFile (takeDirectory target) ".cohort-versions" $ \temporary handle ->
        withTempFile (takeDirectory bootTarget) ".cohort-boot" $ \bootTemporary bootHandle -> do
            TextIO.hPutStr handle contents
            TextIO.hPutStr bootHandle bootContents
            hClose handle
            hClose bootHandle
            (renameFile temporary target >> renameFile bootTemporary bootTarget)
                `onException` (restore target old >> restore bootTarget oldBoot)
  where
    restore path Nothing = do
        exists <- doesFileExist path
        if exists then removeFile path else pure ()
    restore path (Just value) = TextIO.writeFile path value

readOptional :: FilePath -> IO (Maybe Text)
readOptional path = do
    exists <- doesFileExist path
    if exists then Just <$> TextIO.readFile path else pure Nothing

readJSON :: FromJSON a => FilePath -> ExceptT UpdateError IO a
readJSON path = lift (BS.readFile path) >>= fromText . decodeJSON

decodeJSON :: FromJSON a => BS.ByteString -> Either Text a
decodeJSON = either (Left . Text.pack) Right . eitherDecodeStrict'

decodeWith :: (Value -> Parser a) -> BS.ByteString -> Either Text a
decodeWith parser bytes = decodeJSON bytes >>= either (Left . Text.pack) Right . parseEither parser

fromText :: Either Text a -> ExceptT UpdateError IO a
fromText = ExceptT . pure . either (Left . UpdateError) Right

failText :: Text -> ExceptT UpdateError IO a
failText = fromText . Left

nixString :: Text -> String
nixString value = Text.unpack ("\"" <> Text.replace "${" "\\${" (Text.replace "\"" "\\\"" (Text.replace "\\" "\\\\" value)) <> "\"")
