module HaskellNix.Update.Catalog
  ( decodeFamilyCatalog,
    encodeFamilyCatalog,
    validateFamilyCatalog,
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
import Data.Foldable (traverse_)
import Data.List (sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import HaskellNix.Update.Types

decodeFamilyCatalog :: ByteString -> Either Text FamilyCatalog
decodeFamilyCatalog bytes = do
  value <- firstText (eitherDecodeStrict' bytes)
  catalog <- firstText (parseEither parseFamilyCatalog value)
  validateFamilyCatalog catalog

encodeFamilyCatalog :: FamilyCatalog -> LazyByteString.ByteString
encodeFamilyCatalog = (<> "\n") . encodePretty' prettyConfig . familyCatalogValue

validateFamilyCatalog :: FamilyCatalog -> Either Text FamilyCatalog
validateFamilyCatalog catalog@(FamilyCatalog schemaVersion families)
  | schemaVersion /= 1 = Left "family config schemaVersion must be 1"
  | familyNames /= sort familyNames = Left "family config families must be sorted by name"
  | Set.size (Set.fromList familyNames) /= length familyNames = Left "family names must be unique"
  | Set.size (Set.fromList inputNames) /= length inputNames = Left "GitHub input names must be unique"
  | otherwise = traverse_ validateFamily families >> Right catalog
  where
    familyNames = [name | FamilyConfig {name} <- families]
    inputNames = [githubInput | FamilyConfig {githubInput} <- families]

validateFamily :: FamilyConfig -> Either Text ()
validateFamily FamilyConfig {name = FamilyName name, moriProject, github, githubInput, packageOverrides, excludedPackages}
  | Text.null name = Left "family name must not be empty"
  | Text.null moriProject = Left ("family " <> name <> " has an empty Mori project")
  | not (validGitHub github) = Left ("family " <> name <> " GitHub must be owner/repository")
  | githubInput /= name <> "-src" = Left ("family " <> name <> " input must be named " <> name <> "-src")
  | any Text.null excludedNames = Left ("family " <> name <> " excluded package names must not be empty")
  | not (null overriddenAndExcluded) =
      Left
        ( "family "
            <> name
            <> " cannot both override and exclude: "
            <> Text.intercalate ", " overriddenAndExcluded
        )
  | otherwise = Right ()
  where
    excludedNames = [packageName | PackageName packageName <- Set.toAscList excludedPackages]
    overriddenAndExcluded =
      [ packageName
      | PackageName packageName <- Set.toAscList (Set.intersection excludedPackages (Map.keysSet packageOverrides))
      ]

parseFamilyCatalog :: Value -> Parser FamilyCatalog
parseFamilyCatalog = withObject "FamilyCatalog" $ \fields -> do
  rejectUnknown "family config" ["schemaVersion", "families"] fields
  schemaVersion <- fields .: "schemaVersion"
  familyValues <- fields .: "families"
  families <- traverse parseFamilyConfig familyValues
  pure FamilyCatalog {schemaVersion, families}

parseFamilyConfig :: Value -> Parser FamilyConfig
parseFamilyConfig = withObject "FamilyConfig" $ \fields -> do
  rejectUnknown
    "family"
    ["name", "moriProject", "github", "githubInput", "packageOverrides", "excludedPackages"]
    fields
  name <- FamilyName <$> fields .: "name"
  moriProject <- fields .: "moriProject"
  github <- fields .: "github"
  githubInput <- fields .: "githubInput"
  overrideValue <- fields .:? "packageOverrides" .!= Object KeyMap.empty
  packageOverrides <- parsePackageOverrides overrideValue
  excludedNames <- fields .:? "excludedPackages" .!= []
  let excludedPackages = Set.fromList (map PackageName excludedNames)
  pure FamilyConfig {name, moriProject, github, githubInput, packageOverrides, excludedPackages}

parsePackageOverrides :: Value -> Parser (Map PackageName PackageOverride)
parsePackageOverrides = withObject "packageOverrides" $ \fields ->
  Map.fromList <$> traverse parseEntry (KeyMap.toList fields)
  where
    parseEntry (key, value) = do
      packageOverride <- parsePackageOverride value
      pure (PackageName (Key.toText key), packageOverride)

parsePackageOverride :: Value -> Parser PackageOverride
parsePackageOverride = withObject "PackageOverride" $ \fields -> do
  rejectUnknown "package override" ["cabal2nixOptions"] fields
  cabal2nixOptions <- fields .:? "cabal2nixOptions" .!= ""
  pure PackageOverride {cabal2nixOptions}

familyCatalogValue :: FamilyCatalog -> Value
familyCatalogValue FamilyCatalog {schemaVersion, families} =
  object
    [ "schemaVersion" .= schemaVersion,
      "families" .= map familyConfigValue families
    ]

familyConfigValue :: FamilyConfig -> Value
familyConfigValue FamilyConfig {name = FamilyName name, moriProject, github, githubInput, packageOverrides, excludedPackages} =
  object
    [ "name" .= name,
      "moriProject" .= moriProject,
      "github" .= github,
      "githubInput" .= githubInput,
      "packageOverrides" .= Object (KeyMap.fromList (map overrideEntry (Map.toAscList packageOverrides))),
      "excludedPackages" .= [packageName | PackageName packageName <- Set.toAscList excludedPackages]
    ]
  where
    overrideEntry (PackageName packageName, PackageOverride {cabal2nixOptions}) =
      ( Key.fromText packageName,
        object ["cabal2nixOptions" .= cabal2nixOptions]
      )

validGitHub :: Text -> Bool
validGitHub value =
  case Text.splitOn "/" value of
    [owner, repository] -> not (Text.null owner) && not (Text.null repository)
    _ -> False

rejectUnknown :: String -> [Text] -> Object -> Parser ()
rejectUnknown context allowed fields = do
  let allowedKeys = Set.fromList (map Key.fromText allowed)
      unknown = filter (`Set.notMember` allowedKeys) (KeyMap.keys fields)
  unless (null unknown) $ fail (context <> " contains unknown fields: " <> show (map Key.toText unknown))

prettyConfig :: Config
prettyConfig = defConfig {confCompare = compare}

firstText :: Either String value -> Either Text value
firstText = either (Left . Text.pack) Right
