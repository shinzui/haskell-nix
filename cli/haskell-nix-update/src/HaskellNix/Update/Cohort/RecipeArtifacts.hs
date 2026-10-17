{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.RecipeArtifacts (
    ArtifactOptions (..),
    runArtifacts,
) where

import Control.Exception (onException)
import Control.Monad (unless, forM)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT (..), runExceptT)
import Data.Aeson (Value (..), eitherDecodeStrict', object, withObject, (.:), (.=))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (parseEither)
import Data.ByteString qualified as BS
import Data.Char (isAlphaNum, isAscii, chr)
import Numeric (showHex)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding (encodeUtf8)
import Data.Text.IO qualified as TextIO
import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Distribution.Pretty (prettyShow)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Context
import HaskellNix.Update.Cohort.Freeze (FreezeDocument (..))
import HaskellNix.Update.Cohort.Generate (classifyCohort)
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.Model (parseVersion)
import HaskellNix.Update.Cohort.Recipes
import HaskellNix.Update.Cohort.Render (canonicalJSON, validHash, validSriHash)
import HaskellNix.Update.Cohort.Types (PlanPackage (..))
import HaskellNix.Update.Process
import HaskellNix.Update.Types (UpdateError (..))
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory, makeAbsolute, pathIsSymbolicLink, renameDirectory)
import System.FilePath ((</>), takeDirectory, isAbsolute, splitDirectories, normalise)
import System.IO.Temp (withTempDirectory, withSystemTempDirectory)

data ArtifactOptions = ArtifactOptions
    { contextPath :: !FilePath, outputDirectory :: !FilePath, checkOnly :: !Bool }
    deriving stock (Eq, Show)

data Configuration = Configuration
    { compilerKey :: !Text, compilerVersion :: !Version, system :: !Text
    , channel :: !Text, nixpkgsRevision :: !Text, policyIdentity :: !Text
    , converterDerivation :: !Text, converterOutput :: !Text, converterVersion :: !Text
    } deriving stock (Eq, Show)

data PackageInput = PackageInput
    { metadataPath :: !FilePath, archivePath :: !FilePath, unpackedHash :: !Text
    , revisionNumber :: !Int, revisionSha256 :: !Text, revisionTime :: !UTCTime
    , nativeArguments :: !(Map Text Text)
    } deriving stock (Eq, Show)

data Context = Context
    { generation :: !GenerationContext, configuration :: !Configuration
    , packages :: !(Map Text PackageInput)
    } deriving stock (Eq, Show)

-- This bounded artifact format converts the existing classifier's generated
-- Hackage selections. Every other classification is retained explicitly in the
-- manifest. Shared source-pin construction stays with its existing owner.
decodeContext :: BS.ByteString -> Either Text Context
decodeContext bytes = do
    value <- either (Left . Text.pack) Right (eitherDecodeStrict' bytes)
    context <- either (Left . Text.pack) Right (parseEither parser value)
    classified <- classifyCohort context.generation
    let expected = Map.keysSet (Map.filter ((== CohortGenerated) . (.packageClassification)) classified)
        cfg = context.configuration
    unless (Map.keysSet context.packages == expected && not (Map.null context.packages))
        (Left "recipe context must cover every generated Hackage selection exactly once")
    unless (cfg.system `elem` ["aarch64-darwin", "x86_64-linux"]
        && prettyShow cfg.compilerVersion `elem` ["9.12.4", "9.14.1"]
        && cfg.compilerKey == "ghc" <> Text.replace "." "" (Text.pack (prettyShow cfg.compilerVersion))
        && cfg.channel `elem` ["github", "hackage"])
        (Left "unsupported explicit recipe compiler/system/channel configuration")
    unless (Text.length cfg.nixpkgsRevision == 40 && Text.all hex cfg.nixpkgsRevision
        && validHash cfg.policyIdentity && not (Text.null cfg.converterVersion)
        && Text.isPrefixOf "/nix/store/" cfg.converterDerivation && Text.isSuffixOf ".drv" cfg.converterDerivation
        && Text.isPrefixOf "/nix/store/" cfg.converterOutput)
        (Left "recipe context requires exact nixpkgs, policy and converter identities")
    cutoff <- maybe (Left "invalid recipe metadata cutoff") Right
        (parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" (Text.unpack context.generation.document.freezeIndexState) :: Maybe UTCTime)
    unless (all ((<= cutoff) . (.revisionTime)) (Map.elems context.packages))
        (Left "recipe metadata revision is newer than the frozen index-state")
    mapM_ (validatePackage classified) (Map.toAscList context.packages)
    pure context
  where
    parser = withObject "recipe context" $ \o -> do
        exact ["schemaVersion", "generationContext", "configuration", "packages"] o
        schema :: Int <- o .: "schemaVersion"
        unless (schema == 1) (fail "unsupported recipe context schema")
        raw <- o .: "generationContext"
        generation <- either (fail . Text.unpack) pure (decodeGenerationContext (encodeUtf8 (canonicalJSON raw)))
        Context generation <$> (o .: "configuration" >>= parseConfiguration) <*> (o .: "packages" >>= traverse parsePackage)
    parseConfiguration = withObject "recipe configuration" $ \o -> do
        exact ["compilerKey", "compilerVersion", "system", "channel", "nixpkgsRevision", "policyIdentity", "converter"] o
        compiler <- o .: "compilerVersion" >>= either (fail . Text.unpack) pure . parseVersion
        (drv, output, version) <- o .: "converter" >>= withObject "recipe converter" (\c -> do
            exact ["derivation", "output", "version"] c
            (,,) <$> c .: "derivation" <*> c .: "output" <*> c .: "version")
        Configuration <$> o .: "compilerKey" <*> pure compiler <*> o .: "system" <*> o .: "channel"
            <*> o .: "nixpkgsRevision" <*> o .: "policyIdentity" <*> pure drv <*> pure output <*> pure version
    parsePackage = withObject "recipe package input" $ \o -> do
        exact ["metadataPath", "archivePath", "unpackedHash", "revision", "nativeArguments"] o
        (number, hash, timestamp) <- o .: "revision" >>= withObject "selected metadata revision" (\r -> do
            exact ["number", "sha256", "time"] r
            (,,) <$> r .: "number" <*> r .: "sha256" <*> r .: "time")
        PackageInput <$> o .: "metadataPath" <*> o .: "archivePath" <*> o .: "unpackedHash" <*> pure number <*> pure hash <*> pure timestamp <*> o .: "nativeArguments"
    exact keys fields = unless (length keys == KeyMap.size fields && all (`KeyMap.member` fields) keys)
        (fail "missing or unknown recipe context fields")
    hex c = c `elem` ("0123456789abcdefABCDEF" :: String)
    identifier text = not (Text.null text) && Text.all (\c -> isAscii c && (isAlphaNum c || c `elem` ['-', '_'])) text
    validatePackage classified (name, input) = do
        unless (identifier name && all (\path -> not (null path) && not (isAbsolute path)
            && all (`notElem` ["..", ".", ""]) (splitDirectories path)) [input.metadataPath, input.archivePath]
            && validSriHash input.unpackedHash && input.revisionNumber >= 0
            && all identifier (Map.keys input.nativeArguments)
            && all (`notElem` ["src", "mkDerivation", "lib"]) (Map.keys input.nativeArguments)
            && all (all identifier . Text.splitOn ".") (Map.elems input.nativeArguments))
            (Left ("invalid portable recipe package inputs: " <> name))
        package <- maybe (Left "missing classified recipe package") Right (Map.lookup name classified)
        expected <- selectedMetadataHash name package.selectedPackage
        _ <- selectedPackageFlags name package.selectedPackage
        _ <- selectedArchiveHash package.selectedPackage
        unless (input.revisionSha256 == expected) (Left ("selected revision metadata differs from solved identity: " <> name))

runArtifacts :: ProcessRunner -> ArtifactOptions -> IO (Either UpdateError Text)
runArtifacts runner options = runExceptT $ do
    contextFile <- lift (normalise <$> makeAbsolute options.contextPath)
    target <- lift (normalise <$> makeAbsolute options.outputDirectory)
    unless (target /= "/" && contextFile /= target && not (Text.pack (target <> "/") `Text.isPrefixOf` Text.pack contextFile))
        (failText "recipe output cannot contain its context input")
    captured <- lift (BS.readFile contextFile)
    context <- fromText (decodeContext captured)
    let cfg = context.configuration
        executable = Text.unpack cfg.converterOutput </> "bin/cabal2nix"
    proof <- command "nix" ["--offline", "derivation", "show", Text.unpack cfg.converterDerivation]
    outputs <- fromText (converterOutputs proof)
    unless (cfg.converterOutput `elem` outputs) (failText "converter output is not an output of the declared derivation")
    version <- Text.strip <$> command executable ["--version"]
    unless (version == cfg.converterVersion) (failText "converter version differs from the explicit context")
    classified <- fromText (classifyCohort context.generation)
    inputs <- forM (Map.toAscList context.packages) $ \(name, input) -> do
        snapshots <- forM [input.metadataPath, input.archivePath] $ \relative -> do
            let path = takeDirectory contextFile </> relative
            links <- lift (traverse pathIsSymbolicLink
                (scanl (</>) (takeDirectory contextFile) (splitDirectories relative)))
            unless (not (or links)) (failText "selected recipe inputs cannot contain symbolic links")
            unless (normalise path /= target && not (Text.pack (target <> "/") `Text.isPrefixOf` Text.pack (normalise path)))
                (failText "recipe output cannot contain selected metadata or archive inputs")
            bytes <- lift (BS.readFile path)
            pure (path, bytes)
        pure (name, snapshots)
    if options.checkOnly
        then lift (doesDirectoryExist target) >>= \exists -> unless exists (failText "recipe artifacts are missing")
        else lift (createDirectoryIfMissing True (takeDirectory target))
    let staging action = if options.checkOnly
            then withSystemTempDirectory ".recipe-artifacts-check" action
            else withTempDirectory (takeDirectory target) ".recipe-artifacts" action
    ExceptT $ staging $ \temporary -> runExceptT $ do
        let stage = temporary </> "artifacts"
        lift (createDirectoryIfMissing True (stage </> "packages"))
        recipes <- forM inputs $ \(name, snapshots) -> do
            package <- maybe (failText "missing selected package") pure (Map.lookup name classified)
            input <- maybe (failText "missing package input") pure (Map.lookup name context.packages)
            let metadata = takeDirectory contextFile </> input.metadataPath
                archive = takeDirectory contextFile </> input.archivePath
            expected <- fromText (selectedArchiveHash package.selectedPackage)
            rawHash <- Text.strip <$> command "nix" ["hash", "file", "--type", "sha256", "--base16", archive]
            unless (rawHash == expected) (failText ("selected source archive hash changed: " <> name))
            unpacked <- command "nix" ["--offline", "store", "prefetch-file", "--json", "--unpack", "--expected-hash", Text.unpack input.unpackedHash, fileUrl archive]
            actual <- fromText (decodeUnpackedHash unpacked)
            unless (actual == input.unpackedHash) (failText ("unpacked source hash changed: " <> name))
            stable <- lift (and <$> traverse (\(path, bytes) -> (== bytes) <$> BS.readFile path) snapshots)
            unless stable (failText "recipe inputs changed during source verification")
            recipe <- ExceptT (convertRecipe runner executable (RecipeConversion name package cfg.compilerVersion cfg.system metadata))
            let output = stage </> "packages" </> Text.unpack name <> ".nix"
            lift (TextIO.writeFile output recipe)
            hash <- Text.strip <$> command "nix" ["hash", "file", "--type", "sha256", "--base16", output]
            unless (validHash hash) (failText "invalid generated recipe content hash")
            pure (name, hash)
        value <- fromText (generationContextValue context.generation)
        let manifest = renderManifest context value classified (Map.fromList recipes)
        lift (TextIO.writeFile (stage </> ".recipe-artifacts") "haskell-nix-update cohort recipes v1\n")
        lift (TextIO.writeFile (stage </> "manifest.json") (canonicalJSON manifest <> "\n"))
        lift (TextIO.writeFile (stage </> "extension.nix") (renderExtension context))
        unchanged <- lift (and <$> traverse (\(path, bytes) -> (== bytes) <$> BS.readFile path) (concatMap snd inputs))
        sameContext <- lift ((== captured) <$> BS.readFile contextFile)
        unless (unchanged && sameContext) (failText "recipe context or metadata changed concurrently; no artifacts promoted")
        if options.checkOnly
            then do
                equal <- lift (sameArtifacts stage target (Map.keys context.packages))
                unless equal (failText "recipe artifacts are stale or unverified; regenerate from the explicit context")
            else lift (promote stage target temporary)
        pure ("Recipes: " <> Text.pack (show (Map.size context.packages)) <> if options.checkOnly then " verified" else " generated")
  where
    command executable arguments = (.standardOutput) <$> ExceptT (runChecked runner (ProcessSpec executable arguments Nothing []))


selectedArchiveHash :: PlanPackage -> Either Text Text
selectedArchiveHash package = case
    [hash | Object fields <- package.identities, Just (String hash) <- [KeyMap.lookup "pkg-src-sha256" fields]] of
    first : rest | validHash first && all (== first) rest && length (first : rest) == length package.identities -> Right first
    _ -> Left "missing or conflicting selected source archive hashes"

decodeUnpackedHash :: Text -> Either Text Text
decodeUnpackedHash bytes = do
    value <- either (Left . Text.pack) Right (eitherDecodeStrict' (encodeUtf8 bytes))
    either (Left . Text.pack) Right (parseEither (withObject "verified unpacked source" (.: "hash")) value)

fileUrl :: FilePath -> String
fileUrl path = "file://" <> concatMap encodeByte (BS.unpack (encodeUtf8 (Text.pack path)))
  where
    encodeByte byte
        | byte < 128 && (isAlphaNum (chr (fromIntegral byte)) || chr (fromIntegral byte) `elem` ("/._-~" :: String)) = [chr (fromIntegral byte)]
        | otherwise = let digits = showHex byte "" in '%' : (if length digits == 1 then '0' : digits else digits)

converterOutputs :: Text -> Either Text [Text]
converterOutputs bytes = do
    value <- either (Left . Text.pack) Right (eitherDecodeStrict' (encodeUtf8 bytes))
    either (Left . Text.pack) Right (parseEither parser value)
  where
    parser = withObject "converter derivation export" $ \o -> do
        let exported = maybe (Object o) id (KeyMap.lookup "derivations" o)
        withObject "converter derivations" (fmap concat . traverse derivation . KeyMap.elems) exported
    derivation = withObject "converter derivation" $ \o -> do
        outputs <- o .: "outputs"
        withObject "converter outputs" (traverse output . KeyMap.elems) outputs
    output = withObject "converter output" $ \o -> do
        path <- o .: "path"
        pure (if Text.isPrefixOf "/" path then path else "/nix/store/" <> path)

renderManifest :: Context -> Value -> Map Text ClassifiedPackage -> Map Text Text -> Value
renderManifest context generation classified hashes = object
    [ "schemaVersion" .= (1 :: Int), "generationContext" .= generation
    , "configuration" .= configurationValue context.configuration
    , "classifications" .= Map.map (classificationValue . (.packageClassification)) classified
    , "packages" .= Map.mapWithKey entry context.packages
    ]
  where
    entry name input = object
        [ "recipeSha256" .= (hashes Map.! name), "unpackedHash" .= input.unpackedHash
        , "revision" .= object ["number" .= input.revisionNumber, "sha256" .= input.revisionSha256, "time" .= input.revisionTime]
        , "nativeArguments" .= input.nativeArguments
        ]


classificationValue :: Classification -> Value
classificationValue classification = case classification of
    CohortBoot -> entry "boot" Nothing
    CohortFirstParty -> entry "first-party" Nothing
    CohortSameAsBase -> entry "same-as-base" Nothing
    CohortGenerated -> entry "generated" Nothing
    CohortExcluded owner -> entry "excluded" (Just owner)
    CohortSourcePinned owner -> entry "source-pinned" (Just owner)
  where
    entry :: Text -> Maybe OwnedPolicy -> Value
    entry kind ownership = object
        (["kind" .= kind] <> ["ownership" .= object ["reason" .= owner.policyReason, "owner" .= owner.policyOwner] | owner <- maybe [] pure ownership])

configurationValue :: Configuration -> Value
configurationValue cfg = object
    [ "compilerKey" .= cfg.compilerKey, "compilerVersion" .= Text.pack (prettyShow cfg.compilerVersion)
    , "system" .= cfg.system, "channel" .= cfg.channel, "nixpkgsRevision" .= cfg.nixpkgsRevision
    , "policyIdentity" .= cfg.policyIdentity
    , "converter" .= object ["derivation" .= cfg.converterDerivation, "output" .= cfg.converterOutput, "version" .= cfg.converterVersion]
    ]

renderExtension :: Context -> Text
renderExtension context = Text.unlines $
    [ "# Generated raw recipe layer; compose the reviewed policy exactly once."
    , "{ pkgs, haskellLib, policyExtension }:"
    , "assert pkgs.stdenv.hostPlatform.system == " <> quote cfg.system <> ";"
    , "pkgs.lib.composeExtensions (final: _previous:"
    , "{"
    ] <> map render (Map.toAscList context.packages) <> ["}) policyExtension"]
  where
    cfg = context.configuration
    render (name, input) =
        let version = (context.generation.sources Map.! name).version
            packageVersion = name <> "-" <> version
            arguments = Text.concat [" " <> quote key <> " = pkgs." <> value <> ";" | (key, value) <- Map.toAscList input.nativeArguments]
            revision = if input.revisionNumber == 0 then "" else
                "revision = " <> quote (Text.pack (show input.revisionNumber)) <> "; editedCabalFile = " <> quote input.revisionSha256 <> ";"
        in "  " <> quote name <> " = assert final.ghc.version == " <> quote (Text.pack (prettyShow cfg.compilerVersion)) <> "; haskellLib.overrideCabal (_: { " <> revision <> " }) (final.callPackage ./packages/" <> name <> ".nix { src = pkgs.fetchzip { url = "
            <> quote ("mirror://hackage/" <> packageVersion <> "/" <> packageVersion <> ".tar.gz")
            <> "; sha256 = " <> quote input.unpackedHash <> "; };" <> arguments <> " });"
    quote = Text.replace "${" "\\${" . canonicalJSON . String

sameArtifacts :: FilePath -> FilePath -> [Text] -> IO Bool
sameArtifacts stage target names = do
    exists <- doesDirectoryExist target
    if not exists then pure False else do
        owned <- ownedOutput target
        if not owned then pure False else do
            actual <- listDirectory (target </> "packages")
            let expected = map ((<> ".nix") . Text.unpack) names
                paths = ["manifest.json", "extension.nix", ".recipe-artifacts"] <> map ("packages" </>) expected
            if length actual /= length expected || any (`notElem` expected) actual
                then pure False else and <$> traverse same paths
  where
    same relative = do
        exists <- doesFileExist (target </> relative)
        if not exists then pure False else do
            symbolic <- pathIsSymbolicLink (target </> relative)
            if symbolic then pure False else do
                a <- BS.readFile (stage </> relative)
                b <- BS.readFile (target </> relative)
                pure (a == b)

promote :: FilePath -> FilePath -> FilePath -> IO ()
promote stage target temporary = do
    exists <- doesDirectoryExist target
    if not exists then renameDirectory stage target else do
        owned <- ownedOutput target
        unless owned (ioError (userError "refusing to replace an unowned recipe output directory"))
        let backup = temporary </> "previous"
        renameDirectory target backup
        renameDirectory stage target `onException` renameDirectory backup target


-- Replacement is allowed only for a directory already owned by this generator.
-- In particular --out . must never rename and discard an unrelated repository.
ownedOutput :: FilePath -> IO Bool
ownedOutput target = do
    symbolic <- pathIsSymbolicLink target
    markerExists <- doesFileExist (target </> ".recipe-artifacts")
    if symbolic || not markerExists then pure False else do
        markerLink <- pathIsSymbolicLink (target </> ".recipe-artifacts")
        if markerLink then pure False else do
            marker <- BS.readFile (target </> ".recipe-artifacts")
            top <- listDirectory target
            rootFiles <- and <$> traverse (\name -> do
                let path = target </> name
                file <- doesFileExist path
                link <- pathIsSymbolicLink path
                pure (file && not link)) ["manifest.json", "extension.nix"]
            packageExists <- doesDirectoryExist (target </> "packages")
            if marker /= "haskell-nix-update cohort recipes v1\n" || not rootFiles || not packageExists
                || length top /= 4 || any (`notElem` ["manifest.json", "extension.nix", "packages", ".recipe-artifacts"]) top
                then pure False else do
                    packageLink <- pathIsSymbolicLink (target </> "packages")
                    if packageLink then pure False else do
                        names <- listDirectory (target </> "packages")
                        regular <- and <$> traverse (\name -> do
                            let path = target </> "packages" </> name
                            file <- doesFileExist path
                            link <- pathIsSymbolicLink path
                            pure (file && not link && Text.isSuffixOf ".nix" (Text.pack name))) names
                        pure regular

fromText :: Either Text a -> ExceptT UpdateError IO a
fromText = ExceptT . pure . either (Left . UpdateError) Right

failText :: Text -> ExceptT UpdateError IO a
failText = fromText . Left
