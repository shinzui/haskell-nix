module HaskellNix.Update.Nix
  ( decodeLockedRevision,
    readLockedRevision,
    updateInput,
    prefetchHackage,
    validateFlake,
    managedFilesDirty,
  )
where

import Control.Exception (IOException, try)
import Data.Aeson (Object, Value (..), eitherDecodeStrict', withObject, (.:))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as ByteString
import Data.Char (isHexDigit)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Distribution.Types.Version (Version)
import HaskellNix.Update.Hackage (packageArchiveUrl)
import HaskellNix.Update.Process
import HaskellNix.Update.Types

decodeLockedRevision :: Text -> ByteString.ByteString -> Either UpdateError GitRevision
decodeLockedRevision inputName bytes = do
  value <- firstError "invalid flake.lock JSON" (eitherDecodeStrict' bytes)
  revision <- firstError "invalid flake.lock input" (parseEither (parseInputRevision inputName) value)
  if validRevision revision
    then Right (GitRevision revision)
    else Left (UpdateError ("flake input " <> inputName <> " does not contain a 40-character Git revision"))

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

validateFlake :: ProcessRunner -> FilePath -> IO (Either UpdateError ())
validateFlake runner repositoryRoot = do
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

parseInputRevision :: Text -> Value -> Parser Text
parseInputRevision inputName = withObject "flake lock" $ \fields -> do
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
      withObject "flake locked input" (.: "rev") lockedValue

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

firstError :: Text -> Either String value -> Either UpdateError value
firstError context = either (Left . UpdateError . ((context <> ": ") <>) . Text.pack) Right
