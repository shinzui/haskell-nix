module HaskellNix.Update.Catalog
  ( decodeFamilyCatalog,
    encodeFamilyCatalog,
    validateFamilyCatalog,
    resolveUpdateGroups,
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
import Data.List (sort, sortOn)
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
validateFamilyCatalog catalog@(FamilyCatalog schemaVersion families updateGroups)
  | schemaVersion /= 1 && schemaVersion /= 2 = Left "family config schemaVersion must be 1 or 2"
  | schemaVersion == 1 && not (null updateGroups) = Left "family config schemaVersion 1 cannot define updateGroups"
  | familyNames /= sort familyNames = Left "family config families must be sorted by name"
  | Set.size (Set.fromList familyNames) /= length familyNames = Left "family names must be unique"
  | Set.size (Set.fromList inputNames) /= length inputNames = Left "GitHub input names must be unique"
  | otherwise = do
      traverse_ validateFamily families
      validateExplicitGroups familyNames updateGroups
      Right catalog
  where
    familyNames = [name | FamilyConfig {name} <- families]
    inputNames = [githubInput | FamilyConfig {githubInput} <- families]

resolveUpdateGroups :: FamilyCatalog -> Either Text [UpdateGroup]
resolveUpdateGroups catalog@FamilyCatalog {families, updateGroups} = do
  _ <- validateFamilyCatalog catalog
  let groupedFamilies = Set.fromList [family | UpdateGroup {families = members} <- updateGroups, family <- members]
      singletonGroups =
        [ UpdateGroup {name = UpdateGroupName familyName, families = [family]}
        | FamilyConfig {name = family@(FamilyName familyName)} <- families,
          family `Set.notMember` groupedFamilies
        ]
  pure (sortOn groupNameText (updateGroups <> singletonGroups))
  where
    groupNameText UpdateGroup {name = UpdateGroupName groupName} = groupName

validateExplicitGroups :: [FamilyName] -> [UpdateGroup] -> Either Text ()
validateExplicitGroups familyNames updateGroups
  | groupNames /= sort groupNames = Left "family config updateGroups must be sorted by name"
  | Set.size (Set.fromList groupNames) /= length groupNames = Left "update group names must be unique"
  | any (`Set.member` familyNameSet) groupNamesAsFamilies = Left "update group names must not shadow family names"
  | Set.size (Set.fromList allMembers) /= length allMembers = Left "a family may belong to only one explicit update group"
  | not (Set.fromList allMembers `Set.isSubsetOf` familyNameSet) = Left "update group contains an unknown family"
  | otherwise = traverse_ validateGroup updateGroups
  where
    familyNameSet = Set.fromList familyNames
    groupNames = [name | UpdateGroup {name} <- updateGroups]
    groupNamesAsFamilies = [FamilyName name | UpdateGroupName name <- groupNames]
    allMembers = [family | UpdateGroup {families = members} <- updateGroups, family <- members]
    validateGroup UpdateGroup {name = UpdateGroupName groupName, families = members}
      | Text.null groupName = Left "update group name must not be empty"
      | length members < 2 = Left ("explicit update group " <> groupName <> " must contain at least two families")
      | members /= sort members = Left ("update group " <> groupName <> " families must be sorted")
      | otherwise = Right ()

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
  schemaVersion <- fields .: "schemaVersion"
  case (schemaVersion :: Int) of
    1 -> rejectUnknown "family config" ["schemaVersion", "families"] fields
    2 -> rejectUnknown "family config" ["schemaVersion", "families", "updateGroups"] fields
    _ -> fail "family config schemaVersion must be 1 or 2"
  familyValues <- fields .: "families"
  families <- traverse parseFamilyConfig familyValues
  updateGroups <-
    if schemaVersion == 1
      then pure []
      else fields .: "updateGroups" >>= traverse parseUpdateGroup
  pure FamilyCatalog {schemaVersion, families, updateGroups}

parseUpdateGroup :: Value -> Parser UpdateGroup
parseUpdateGroup = withObject "UpdateGroup" $ \fields -> do
  rejectUnknown "update group" ["name", "families"] fields
  name <- UpdateGroupName <$> fields .: "name"
  families <- map FamilyName <$> fields .: "families"
  pure UpdateGroup {name, families}

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
familyCatalogValue FamilyCatalog {schemaVersion, families, updateGroups} =
  object
    ( [ "schemaVersion" .= schemaVersion,
        "families" .= map familyConfigValue families
      ]
        <> ["updateGroups" .= map updateGroupValue updateGroups | schemaVersion == 2]
    )

updateGroupValue :: UpdateGroup -> Value
updateGroupValue UpdateGroup {name = UpdateGroupName name, families} =
  object
    [ "name" .= name,
      "families" .= [familyName | FamilyName familyName <- families]
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
