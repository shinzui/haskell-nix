module HaskellNix.Update.Nix
  ( decodeLockedSource,
    readLockedSource,
    decodeLockedRevision,
    readLockedRevision,
    updateInput,
    prefetchHackage,
    validatePackageSetSelection,
    validateFlake,
    managedFilesDirty,
  )
where

import Control.Exception (IOException, try)
import Data.Aeson (Object, Value (..), eitherDecodeStrict', encode, withObject, (.:))
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as ByteString
import Data.Char (isAlphaNum, isHexDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Distribution.Types.Version (Version)
import HaskellNix.Update.Hackage (packageArchiveUrl)
import HaskellNix.Update.Process
import HaskellNix.Update.Types

decodeLockedSource :: Text -> ByteString.ByteString -> Either UpdateError LockedSource
decodeLockedSource inputName bytes = do
  value <- firstError "invalid flake.lock JSON" (eitherDecodeStrict' bytes)
  lockedSource <- firstError "invalid flake.lock input" (parseEither (parseInputSource inputName) value)
  validateLockedSource inputName lockedSource

readLockedSource :: FilePath -> Text -> IO (Either UpdateError LockedSource)
readLockedSource flakeLockPath inputName = do
  attempted <- try (ByteString.readFile flakeLockPath) :: IO (Either IOException ByteString.ByteString)
  pure $ case attempted of
    Left exception -> Left (UpdateError ("could not read " <> Text.pack flakeLockPath <> ": " <> Text.pack (show exception)))
    Right bytes -> decodeLockedSource inputName bytes

decodeLockedRevision :: Text -> ByteString.ByteString -> Either UpdateError GitRevision
decodeLockedRevision inputName bytes = rev <$> decodeLockedSource inputName bytes

readLockedRevision :: FilePath -> Text -> IO (Either UpdateError GitRevision)
readLockedRevision flakeLockPath inputName = do
  attempted <- try (ByteString.readFile flakeLockPath) :: IO (Either IOException ByteString.ByteString)
  pure $ case attempted of
    Left exception -> Left (UpdateError ("could not read " <> Text.pack flakeLockPath <> ": " <> Text.pack (show exception)))
    Right bytes -> decodeLockedRevision inputName bytes

updateInput :: ProcessRunner -> FilePath -> Text -> IO (Either UpdateError ())
updateInput runner repositoryRoot inputName = do
  result <-
    runChecked
      runner
      ProcessSpec
        { executable = "nix",
          arguments = ["flake", "update", Text.unpack inputName],
          workingDirectory = Just repositoryRoot,
          environmentAdditions = []
        }
  pure (() <$ result)

prefetchHackage :: ProcessRunner -> PackageName -> Version -> IO (Either UpdateError SriHash)
prefetchHackage runner packageName version = do
  let url = packageArchiveUrl packageName version
  result <-
    runChecked
      runner
      ProcessSpec
        { executable = "nix",
          arguments = ["store", "prefetch-file", "--json", "--unpack", Text.unpack url],
          workingDirectory = Nothing,
          environmentAdditions = []
        }
  pure $ do
    ProcessResult {standardOutput} <- result
    value <- firstError ("invalid prefetch JSON for " <> url) (eitherDecodeStrict' (TextEncoding.encodeUtf8 standardOutput))
    hash <- firstError ("invalid prefetch result for " <> url) (parseEither parsePrefetch value)
    Right (SriHash hash)

validatePackageSetSelection :: ProcessRunner -> FilePath -> Text -> IO (Either UpdateError ())
validatePackageSetSelection runner repositoryRoot packageSetName = do
  result <-
    runChecked
      runner
      ProcessSpec
        { executable = "nix",
          arguments =
            [ "eval",
              "--impure",
              "--no-eval-cache",
              "--json",
              "--expr",
              Text.unpack validatePackageSetExpression,
              "--apply",
              "validate: validate " <> Text.unpack (nixString packageSetName)
            ],
          workingDirectory = Just repositoryRoot,
          environmentAdditions = []
        }
  pure (() <$ result)

validatePackageSetExpression :: Text
validatePackageSetExpression =
  -- getFlake receives the working-tree path so validation covers the just-written
  -- lock rather than the last commit; Nix requires --impure for that local path.
  "packageSet: let flake = builtins.getFlake (toString ./.); constructor = flake.lib.mkFirstPartyPackageSet; validate = channel: let selected = constructor { inherit packageSet channel; }; in builtins.deepSeq selected.selections (builtins.deepSeq selected.selectedFamilies (builtins.attrNames selected.registry)); in map validate [\"github\" \"hackage\"]"

nixString :: Text -> Text
nixString = TextEncoding.decodeUtf8 . LazyByteString.toStrict . encode

validateFlake :: ProcessRunner -> FilePath -> IO (Either UpdateError ())
validateFlake runner repositoryRoot = do
  -- Realise the import-from-derivation builds before the check needs them.
  -- Deliberately best-effort: if this cannot run, `nix flake check` below is
  -- still the authoritative verdict and reports the real failure, so a warm
  -- that fails must not mask it.
  _ <- warmChecks runner repositoryRoot
  result <-
    runChecked
      runner
      ProcessSpec
        { executable = "nix",
          -- --no-eval-cache keeps validation deterministic: the first-party
          -- checks force cabal2nix import-from-derivation builds, and a
          -- transient IFD or substitution failure would otherwise be cached as
          -- a failed attribute, wedging every later refresh with "cached failed
          -- attribute ... unexpectedly succeeded" until the eval cache is
          -- cleared by hand.
          arguments = ["flake", "check", "--no-build", "--no-eval-cache"],
          workingDirectory = Just repositoryRoot,
          environmentAdditions = []
        }
  pure (() <$ result)

-- | Force the cabal2nix import-from-derivation builds that every flake check
-- performs, so that @nix flake check@ finds them already in the store.
--
-- @nix flake check@ computes those derivations during evaluation but does not
-- realise them, so the import fails with @path '/nix/store/...-cabal2nix-<pkg>.drv'
-- is not valid@ on any refresh that locks a revision whose packages have never
-- been evaluated. Evaluating each check's own @drvPath@ performs the same imports
-- through a path that builds them.
--
-- It warms /every/ check for the system, not only @first-party-versions@: the
-- registry fixture and build-setting checks import cabal2nix derivations too,
-- and a nixpkgs bump invalidates all of them at once, so warming one check
-- still left validation failing on the others. Each check is wrapped in
-- @tryEval@ so one that genuinely fails its assertions does not stop the rest
-- from being warmed; @nix flake check@ still reports that failure.
--
-- It must be this expression, evaluated purely against the flake reference. A
-- hand-written @nix eval --impure@ over @callCabal2nix@ computes a /different/
-- derivation for the same package and warms something the check never asks for,
-- which is why doing this by hand is unreliable.
warmChecks :: ProcessRunner -> FilePath -> IO (Either UpdateError ())
warmChecks runner repositoryRoot = do
  attempted <- currentSystem runner
  case attempted of
    Left updateError -> pure (Left updateError)
    Right system -> do
      let attribute = ".#checks." <> Text.unpack system
      result <-
        runChecked
          runner
          ProcessSpec
            { executable = "nix",
              arguments = ["eval", "--no-eval-cache", "--json", attribute, "--apply", Text.unpack warmChecksExpression],
              workingDirectory = Just repositoryRoot,
              environmentAdditions = []
            }
      pure (() <$ result)

-- | Maps each check to whether its derivation path evaluated.
warmChecksExpression :: Text
warmChecksExpression = "checks: builtins.mapAttrs (_: check: (builtins.tryEval check.drvPath).success) checks"

-- | The Nix system double this machine builds for.
--
-- @--impure@ is required to read @builtins.currentSystem@ and is safe here
-- precisely because the expression is a bare string: it instantiates no package
-- set, so it cannot pick up the impurities that make an impure evaluation
-- disagree with the pure one.
currentSystem :: ProcessRunner -> IO (Either UpdateError Text)
currentSystem runner = do
  result <-
    runChecked
      runner
      ProcessSpec
        { executable = "nix",
          arguments = ["eval", "--impure", "--raw", "--expr", "builtins.currentSystem"],
          workingDirectory = Nothing,
          environmentAdditions = []
        }
  pure $ do
    ProcessResult {standardOutput} <- result
    Right (Text.strip standardOutput)

managedFilesDirty :: ProcessRunner -> FilePath -> [FilePath] -> IO (Either UpdateError Bool)
managedFilesDirty runner repositoryRoot managedPaths = do
  result <-
    runChecked
      runner
      ProcessSpec
        { executable = "git",
          arguments = ["status", "--porcelain", "--"] <> managedPaths,
          workingDirectory = Just repositoryRoot,
          environmentAdditions = []
        }
  pure $ do
    ProcessResult {standardOutput} <- result
    Right (not (Text.null (Text.strip standardOutput)))

parseInputSource :: Text -> Value -> Parser LockedSource
parseInputSource inputName = withObject "flake lock" $ \fields -> do
  rootName <- fields .: "root"
  nodesValue <- fields .: "nodes"
  withObject "flake nodes" (parseRootNode rootName) nodesValue
  where
    parseRootNode rootName nodes = do
      rootValue <- lookupValue "root node" rootName nodes
      withObject "flake root node" (parseRootInputs nodes) rootValue
    parseRootInputs nodes rootFields = do
      inputsValue <- rootFields .: "inputs"
      withObject "flake root inputs" (parseInputNode nodes) inputsValue
    parseInputNode nodes inputs = do
      inputValue <- lookupValue "flake input" inputName inputs
      nodeName <- case inputValue of
        String name -> pure name
        _ -> fail ("flake input " <> Text.unpack inputName <> " is not a direct node reference")
      nodeValue <- lookupValue "input node" nodeName nodes
      withObject "flake input node" parseLocked nodeValue
    parseLocked nodeFields = do
      lockedValue <- nodeFields .: "locked"
      withObject "flake locked input" parseDescriptor lockedValue
    parseDescriptor lockedFields = do
      sourceType <- lockedFields .: "type"
      owner <- lockedFields .: "owner"
      repo <- lockedFields .: "repo"
      revision <- lockedFields .: "rev"
      narHash <- lockedFields .: "narHash"
      pure
        LockedSource
          { sourceType,
            owner,
            repo,
            rev = GitRevision revision,
            narHash = SriHash narHash
          }

lookupValue :: String -> Text -> Object -> Parser Value
lookupValue context key fields =
  maybe
    (fail (context <> " " <> Text.unpack key <> " is missing"))
    pure
    (KeyMap.lookup (Key.fromText key) fields)

parsePrefetch :: Value -> Parser Text
parsePrefetch = withObject "prefetch result" (.: "hash")

validRevision :: Text -> Bool
validRevision value = Text.length value == 40 && Text.all isHexDigit value

validSriHash :: Text -> Bool
validSriHash value =
  Text.length value == 51
    && "sha256-" `Text.isPrefixOf` value
    && Text.all validBase64Character (Text.drop 7 value)
  where
    validBase64Character character = isAlphaNum character || character `elem` ['+', '/', '=']

validateLockedSource :: Text -> LockedSource -> Either UpdateError LockedSource
validateLockedSource inputName lockedSource@LockedSource {sourceType, owner, repo, rev = GitRevision revision, narHash = SriHash hash}
  | sourceType /= "github" = Left (UpdateError ("flake input " <> inputName <> " is not a GitHub source"))
  | Text.null owner || Text.null repo = Left (UpdateError ("flake input " <> inputName <> " has an empty owner or repository"))
  | not (validRevision revision) = Left (UpdateError ("flake input " <> inputName <> " does not contain a 40-character Git revision"))
  | not (validSriHash hash) = Left (UpdateError ("flake input " <> inputName <> " does not contain a valid sha256 NAR hash"))
  | otherwise = Right lockedSource

firstError :: Text -> Either String value -> Either UpdateError value
firstError context = either (Left . UpdateError . ((context <> ": ") <>) . Text.pack) Right
