module HaskellNix.Update.PackageLock
  ( decodePackageLock,
    encodePackageLock,
    validatePackageLock,
  )
where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Encode.Pretty (Config (..), defConfig, encodePretty')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Char (isAlphaNum, isHexDigit)
import Data.Foldable (traverse_)
import Data.List (sort)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Pretty (prettyShow)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Types
import System.FilePath (isAbsolute, splitDirectories)

decodePackageLock :: FamilyCatalog -> ByteString -> Either Text PackageLock
decodePackageLock catalog bytes = do
  value <- firstText (eitherDecodeStrict' bytes)
  packageLock <- firstText (parseEither parsePackageLock value)
  validatePackageLock catalog packageLock

encodePackageLock :: PackageLock -> LazyByteString.ByteString
encodePackageLock = (<> "\n") . encodePretty' prettyConfig . packageLockValue

validatePackageLock :: FamilyCatalog -> PackageLock -> Either Text PackageLock
validatePackageLock catalog packageLock@(PackageLock schemaVersion lockedFamilies)
  | schemaVersion /= 1 = Left "package lock schemaVersion must be 1"
  | lockedNames /= sort lockedNames = Left "package-lock families must be sorted by name"
  | Set.size (Set.fromList lockedNames) /= length lockedNames = Left "package-lock family names must be unique"
  | Set.size (Set.fromList packageNames) /= length packageNames = Left "package names must be globally unique"
  | configuredNames /= lockedNames = Left "family config and package lock family names do not match"
  | otherwise = traverse_ validateCross lockedFamilies >> Right packageLock
  where
    FamilyCatalog _ configuredFamilies = catalog
    configuredNames = [name | FamilyConfig {name} <- configuredFamilies]
    lockedNames = [name | LockedFamily {name} <- lockedFamilies]
    packageNames = [name | LockedFamily {packages} <- lockedFamilies, LockedPackage {name} <- packages]
    configuredByName = Map.fromList [(name, family) | family@FamilyConfig {name} <- configuredFamilies]

    validateCross lockedFamily@LockedFamily {name} = do
      validateLockedFamily lockedFamily
      configuredFamily <- maybe (Left "package-lock family is not configured") Right (Map.lookup name configuredByName)
      validateFamilyAgreement configuredFamily lockedFamily

validateLockedFamily :: LockedFamily -> Either Text ()
validateLockedFamily LockedFamily {name = FamilyName familyName, githubInput, githubRev = GitRevision githubRev, packages}
  | Text.null familyName = Left "locked family name must not be empty"
  | Text.null githubInput = Left ("family " <> familyName <> " has an empty GitHub input")
  | not (validRevision githubRev) = Left ("family " <> familyName <> " has a malformed Git revision")
  | names /= sort names = Left ("family " <> familyName <> " packages must be sorted by name")
  | Set.size (Set.fromList names) /= length names = Left ("family " <> familyName <> " package names must be unique")
  | otherwise = traverse_ (validateLockedPackage familyName) packages
  where
    names = [name | LockedPackage {name} <- packages]

validateLockedPackage :: Text -> LockedPackage -> Either Text ()
validateLockedPackage familyName LockedPackage {name = PackageName packageName, path, hackage}
  | Text.null packageName = Left ("family " <> familyName <> " contains an empty package name")
  | not (validRelativePath path) = Left ("package " <> packageName <> " has an invalid relative path")
  | maybe False (not . validHackagePin) hackage = Left ("package " <> packageName <> " has an invalid Hackage pin")
  | otherwise = Right ()

validateFamilyAgreement :: FamilyConfig -> LockedFamily -> Either Text ()
validateFamilyAgreement
  FamilyConfig {name = FamilyName familyName, githubInput = configuredInput, packageOverrides}
  LockedFamily {githubInput = lockedInput, packages}
    | configuredInput /= lockedInput = Left ("family " <> familyName <> " GitHub input does not match the config")
    | any (`Set.notMember` packageNameSet) (Map.keysSet packageOverrides) = Left ("family " <> familyName <> " overrides an unknown package")
    | otherwise = traverse_ validateOptions packages
    where
      packageNameSet = Set.fromList [name | LockedPackage {name} <- packages]
      validateOptions LockedPackage {name, cabal2nixOptions}
        | cabal2nixOptions == expectedOptions name = Right ()
        | otherwise = Left ("package " <> packageNameText name <> " Cabal2nix options do not match the config")
      expectedOptions packageName =
        case Map.lookup packageName packageOverrides of
          Nothing -> ""
          Just PackageOverride {cabal2nixOptions} -> cabal2nixOptions

parsePackageLock :: Value -> Parser PackageLock
parsePackageLock = withObject "PackageLock" $ \fields -> do
  rejectUnknown "package lock" ["schemaVersion", "families"] fields
  schemaVersion <- fields .: "schemaVersion"
  familyValues <- fields .: "families"
  families <- traverse parseLockedFamily familyValues
  pure PackageLock {schemaVersion, families}

parseLockedFamily :: Value -> Parser LockedFamily
parseLockedFamily = withObject "LockedFamily" $ \fields -> do
  rejectUnknown "locked family" ["name", "githubInput", "githubRev", "packages"] fields
  name <- FamilyName <$> fields .: "name"
  githubInput <- fields .: "githubInput"
  githubRev <- GitRevision <$> fields .: "githubRev"
  packageValues <- fields .: "packages"
  packages <- traverse parseLockedPackage packageValues
  pure LockedFamily {name, githubInput, githubRev, packages}

parseLockedPackage :: Value -> Parser LockedPackage
parseLockedPackage = withObject "LockedPackage" $ \fields -> do
  rejectUnknown "locked package" ["name", "path", "version", "cabal2nixOptions", "hackage"] fields
  name <- PackageName <$> fields .: "name"
  path <- fields .: "path"
  versionText <- fields .: "version"
  version <- parseVersion versionText
  cabal2nixOptions <- fields .: "cabal2nixOptions"
  hackageValue <- fields .: "hackage"
  hackage <- traverse parseHackagePin hackageValue
  pure LockedPackage {name, path, version, cabal2nixOptions, hackage}

parseHackagePin :: Value -> Parser HackagePin
parseHackagePin = withObject "HackagePin" $ \fields -> do
  rejectUnknown "Hackage pin" ["version", "hash"] fields
  versionText <- fields .: "version"
  version <- parseVersion versionText
  hash <- SriHash <$> fields .: "hash"
  pure HackagePin {version, hash}

parseVersion :: Text -> Parser Version
parseVersion value =
  maybe (fail ("invalid dot-separated version: " <> Text.unpack value)) pure (simpleParsec (Text.unpack value))

packageLockValue :: PackageLock -> Value
packageLockValue PackageLock {schemaVersion, families} =
  object
    [ "schemaVersion" .= schemaVersion,
      "families" .= map lockedFamilyValue families
    ]

lockedFamilyValue :: LockedFamily -> Value
lockedFamilyValue LockedFamily {name = FamilyName name, githubInput, githubRev = GitRevision githubRev, packages} =
  object
    [ "name" .= name,
      "githubInput" .= githubInput,
      "githubRev" .= githubRev,
      "packages" .= map lockedPackageValue packages
    ]

lockedPackageValue :: LockedPackage -> Value
lockedPackageValue LockedPackage {name = PackageName name, path, version, cabal2nixOptions, hackage} =
  object
    [ "name" .= name,
      "path" .= path,
      "version" .= renderVersion version,
      "cabal2nixOptions" .= cabal2nixOptions,
      "hackage" .= fmap hackagePinValue hackage
    ]

hackagePinValue :: HackagePin -> Value
hackagePinValue HackagePin {version, hash = SriHash hash} =
  object
    [ "version" .= renderVersion version,
      "hash" .= hash
    ]

renderVersion :: Version -> Text
renderVersion = Text.pack . prettyShow

validRevision :: Text -> Bool
validRevision value = Text.length value == 40 && Text.all isHexDigit value

validRelativePath :: FilePath -> Bool
validRelativePath path =
  not (null path)
    && not (isAbsolute path)
    && all validSegment (splitDirectories path)
  where
    validSegment segment = not (null segment) && segment /= "." && segment /= ".."

validHackagePin :: HackagePin -> Bool
validHackagePin HackagePin {hash = SriHash hash} = validSriHash hash

validSriHash :: Text -> Bool
validSriHash value =
  case Text.stripPrefix "sha256-" value of
    Nothing -> False
    Just encoded ->
      Text.length encoded == 44
        && Text.last encoded == '='
        && Text.all validBase64Character (Text.init encoded)
  where
    validBase64Character character = isAlphaNum character || character == '+' || character == '/'

packageNameText :: PackageName -> Text
packageNameText (PackageName name) = name

rejectUnknown :: String -> [Text] -> Object -> Parser ()
rejectUnknown context allowed fields = do
  let allowedKeys = Set.fromList (map Key.fromText allowed)
      unknown = filter (`Set.notMember` allowedKeys) (KeyMap.keys fields)
  unless (null unknown) $ fail (context <> " contains unknown fields: " <> show (map Key.toText unknown))

prettyConfig :: Config
prettyConfig = defConfig {confCompare = compare}

firstText :: Either String value -> Either Text value
firstText = either (Left . Text.pack) Right
