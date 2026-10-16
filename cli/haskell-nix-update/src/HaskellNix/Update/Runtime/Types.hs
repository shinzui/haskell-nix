{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Runtime.Types
    ( RuntimeConfig (..), RuntimeDefinition (..), RuntimeRoot (..)
    , RuntimeLock (..), RuntimeGeneration (..), RuntimeConfiguration (..)
    , decodeRuntimeConfig, decodeRuntimeLock, validateRuntimeConfig, validateRuntimeLock
    , runtimeClosure, composeRuntimeSelections, validateProjectionHashes
    ) where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.Char (isHexDigit)
import Data.Foldable (traverse_)
import Data.List (sort)
import Data.Maybe (isJust)
import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import GHC.Generics (Generic)
import HaskellNix.Update.Cohort.Model (parseVersion)
import HaskellNix.Update.Cohort.Types (PlanPackage (..))
import HaskellNix.Update.Types qualified as FirstParty
import System.FilePath (isAbsolute, splitDirectories)

data RuntimeConfig = RuntimeConfig {schemaVersion :: !Int, runtimes :: !(Map Text RuntimeDefinition)}
    deriving stock (Eq, Show, Generic)
    deriving anyclass (ToJSON)
instance FromJSON RuntimeConfig where parseJSON = genericParseJSON defaultOptions {rejectUnknownFields = True}

data RuntimeDefinition = RuntimeDefinition
    {projects :: ![Text], groups :: ![Text], roots :: !(Map Text RuntimeRoot)}
    deriving stock (Eq, Show, Generic)
    deriving anyclass (ToJSON)
instance FromJSON RuntimeDefinition where parseJSON = genericParseJSON defaultOptions {rejectUnknownFields = True}

data RuntimeRoot = RuntimeRoot {project :: !Text, capability :: !Text, role :: !Text}
    deriving stock (Eq, Show, Generic)
    deriving anyclass (ToJSON)
instance FromJSON RuntimeRoot where parseJSON = genericParseJSON defaultOptions {rejectUnknownFields = True}

data RuntimeLock = RuntimeLock {schemaVersion :: !Int, runtimes :: !(Map Text [RuntimeGeneration])}
    deriving stock (Eq, Show, Generic)
    deriving anyclass (ToJSON)
instance FromJSON RuntimeLock where parseJSON = genericParseJSON defaultOptions {rejectUnknownFields = True}

data RuntimeConfiguration = RuntimeConfiguration
    {system :: !Text, compiler :: !Text, channel :: !Text, disableProfiling :: !Bool, disableHaddock :: !Bool}
    deriving stock (Eq, Ord, Show, Generic)
    deriving anyclass (ToJSON)
instance FromJSON RuntimeConfiguration where parseJSON = genericParseJSON defaultOptions {rejectUnknownFields = True}

-- Every projection and the retained recipe tree is content addressed. The
-- ownership graph includes transitive libraries, boot packages and build tools.
-- Support is declared per configuration and accepted only by the plan's evidence.
data RuntimeGeneration = RuntimeGeneration
    { definition :: !RuntimeDefinition
    , generation :: !Int
    , indexState :: !Text
    , cohortFreezeSha256 :: !Text
    , nixpkgsRevision :: !Text
    , toolchainRevision :: !Text
    , selections :: !(Map Text Int)
    , configurations :: ![RuntimeConfiguration]
    , roots :: ![Text]
    , ownership :: !(Map Text PlanPackage)
    , roles :: !(Map Text [Text])
    , components :: !(Map Text Value)
    , projections :: !(Map FilePath Text)
    , fingerprint :: !Text
    , recipeDirectory :: !FilePath
    , freezeFile :: !FilePath
    , sourceFile :: !FilePath
    , versionFile :: !FilePath
    , policyFile :: !FilePath
    } deriving stock (Eq, Show, Generic)
      deriving anyclass (ToJSON)
instance FromJSON RuntimeGeneration where parseJSON = genericParseJSON defaultOptions {rejectUnknownFields = True}

decodeRuntimeConfig :: ByteString -> Either Text RuntimeConfig
decodeRuntimeConfig bytes = either (Left . Text.pack) validateRuntimeConfig (eitherDecodeStrict' bytes)

decodeRuntimeLock :: RuntimeConfig -> FirstParty.PackageSetLock -> ByteString -> Either Text RuntimeLock
decodeRuntimeLock config firstParty bytes = either (Left . Text.pack) (validateRuntimeLock config firstParty) (eitherDecodeStrict' bytes)

validateRuntimeConfig :: RuntimeConfig -> Either Text RuntimeConfig
validateRuntimeConfig config = do
    require (config.schemaVersion == 1 && not (Map.null config.runtimes)) "runtime config schemaVersion must be 1 with named definitions"
    traverse_ validateDefinition (Map.toList config.runtimes)
    pure config
  where
    validateDefinition (name, definition) = do
        require (safeName name && unique definition.projects && unique definition.groups && not (null definition.groups)) "invalid runtime name, duplicate projects or groups"
        require (all canonicalProject definition.projects && not (Map.null definition.roots)) "runtime requires canonical projects and root components"
        require (all (`elem` map (.project) (Map.elems definition.roots)) definition.projects) "runtime project has no root component"
        traverse_ (\(package, root) -> do
            require (safeName package && canonicalProject root.project) ("invalid runtime root: " <> package)
            require (root.role `elem` ["library", "test", "build-tool"] && root.capability `elem` ["core", "pgmq", "kafka"]) ("invalid runtime role/capability: " <> package)) (Map.toList definition.roots)
        if name == "keiro-runtime" then do
            require (all (`elem` definition.projects) requiredProjects) "keiro-runtime omits a required project"
            require (all (`Map.member` definition.roots) ["keiki", "keiki-codec-json", "keiro", "kiroku-store", "shibuya-core", "pgmq-core", "settei", "pg-migrate", "hw-kafka-client", "shibuya-pgmq-adapter", "shibuya-kiroku-adapter", "shibuya-kafka-adapter", "kafka-effectful", "hw-kafka-streamly"]) "keiro-runtime omits a required root/codec/adapter"
            require (all (`elem` definition.groups) ["keiki", "keiro", "kiroku", "shibuya", "pgmq-hs", "settei", "pg-migrate"]) "keiro-runtime omits a required first-party group"
        else pure ()
    requiredProjects = map ("mori://shinzui/" <>) ["keiki", "keiro", "kiroku", "shibuya", "pgmq-hs", "settei", "pg-migrate", "hw-kafka-client"]

validateRuntimeLock :: RuntimeConfig -> FirstParty.PackageSetLock -> RuntimeLock -> Either Text RuntimeLock
validateRuntimeLock config firstParty lock = do
    _ <- validateRuntimeConfig config
    require (lock.schemaVersion == 1 && Map.keys lock.runtimes == Map.keys config.runtimes) "runtime lock names/schema disagree with configuration"
    traverse_ validateNamed (Map.toList lock.runtimes)
    pure lock
  where
    knownGroups = Map.fromListWith (<>) [(name, [value]) | snapshot <- firstParty.groupSnapshots, let FirstParty.UpdateGroupName name = snapshot.group, let FirstParty.SnapshotGeneration value = snapshot.generation]
    validateNamed (name, records) = do
        let definition = config.runtimes Map.! name
        require (unique (map (.generation) records) && map (.generation) records == sort (map (.generation) records)) "runtime generations must be unique and ordered"
        require (all (`Map.member` knownGroups) definition.groups) "runtime definition contains an unknown group"
        traverse_ (\record -> do
            _ <- validateRuntimeConfig (RuntimeConfig 1 (Map.singleton name record.definition))
            validateRecord record.definition record) records
    validateRecord definition record = do
        require (record.generation > 0 && validHash record.fingerprint && validHash record.cohortFreezeSha256) "invalid runtime generation/fingerprint"
        require (validRevision record.nixpkgsRevision && validRevision record.toolchainRevision && validTimestamp record.indexState) "invalid runtime toolchain/index-state identity"
        require (Map.keys record.selections == sort definition.groups) "runtime group selections are incomplete"
        traverse_ (\(group, value) -> require (value `elem` Map.findWithDefault [] group knownGroups) ("unknown runtime group generation: " <> group)) (Map.toList record.selections)
        require (not (null record.configurations) && unique record.configurations) "runtime configurations must be nonempty and unique"
        traverse_ (\c -> require (c.system `elem` ["aarch64-darwin", "x86_64-linux"] && c.compiler == "ghc9124" && c.channel `elem` ["github", "hackage"] && c.disableProfiling && c.disableHaddock) "undeclared runtime support configuration") record.configurations
        require (record.roots == Map.keys definition.roots) "runtime record omits or adds a declared root"
        closure <- runtimeClosure record.roots record.ownership
        require (Map.keys closure == Map.keys record.ownership) "runtime ownership includes unreachable dependencies"
        require (Map.keys record.roles == Map.keys record.ownership) "runtime dependency roles are incomplete"
        traverse_ (\rs -> require (not (null rs) && unique rs && all (`elem` ["library", "test", "build-tool", "compiler"]) rs) "invalid runtime dependency role") (Map.elems record.roles)
        traverse_ (\(name, package) -> do
            _ <- parseVersion package.version
            require (not (null package.identities)) ("runtime source identity is missing: " <> name)
            traverse_ (validateIdentity name package.version) package.identities
            let identities = [map (`KeyMap.lookup` fields) ["pkg-src", "pkg-src-sha256", "pkg-cabal-sha256", "flags"] | Object fields <- package.identities]
            case identities of
                first : rest -> require (all (== first) rest) ("conflicting runtime source/metadata/flags: " <> name)
                [] -> Left ("runtime source identity is missing: " <> name)) (Map.toList record.ownership)
        require (all (`Map.member` record.ownership) (Map.keys record.components)) "runtime source component has no ownership record"
        require (not (Map.null record.projections) && all validHash (Map.elems record.projections) && all safePath (Map.keys record.projections)) "invalid runtime projection paths/hashes"
        require (Map.lookup (record.recipeDirectory <> "/cabal/cohort.freeze") record.projections == Just record.cohortFreezeSha256) "runtime cohort projection identity mismatch"
        require (safePath record.recipeDirectory && all (`Map.member` record.projections) [record.freezeFile, record.sourceFile, record.versionFile, record.policyFile]) "missing runtime projection ownership"
        require (any (Text.isPrefixOf (Text.pack record.recipeDirectory <> "/") . Text.pack) (Map.keys record.projections)) "runtime recipes are not captured"

validateIdentity :: Text -> Text -> Value -> Either Text ()
validateIdentity name version (Object fields) = require
    (KeyMap.lookup "pkg-name" fields == Just (String name) && KeyMap.lookup "pkg-version" fields == Just (String version))
    ("runtime identity disagrees with package name/version: " <> name)
validateIdentity name _ _ = Left ("invalid runtime source identity: " <> name)

-- Hashing is performed through the shared Nix process adapter; this pure
-- comparison is also used by check/snapshot before publishing any managed file.
validateProjectionHashes :: RuntimeGeneration -> Map FilePath Text -> Either Text ()
validateProjectionHashes record observed = require (record.projections == observed)
    "runtime projection source/metadata/policy hash drift"

runtimeClosure :: [Text] -> Map Text PlanPackage -> Either Text (Map Text PlanPackage)
runtimeClosure names packages = go Set.empty names
  where
    go visited [] = Right (Map.restrictKeys packages visited)
    go visited (name : rest)
        | Set.member name visited = go visited rest
        | otherwise = case Map.lookup name packages of
            Nothing -> Left ("runtime dependency has no source/ownership record: " <> name)
            Just package -> go (Set.insert name visited) (package.dependencies <> rest)

composeRuntimeSelections :: [Text] -> Map Text Int -> Map Text Int -> Either Text (Map Text Int)
composeRuntimeSelections allGroups runtime application = do
    traverse_ (\(name, value) -> require (maybe True (== value) (Map.lookup name application)) ("application conflicts with runtime group: " <> name)) (Map.toList runtime)
    let selected = Map.union runtime application
    require (Map.keys selected == sort allGroups && all (> 0) (Map.elems selected)) "missing or unknown complementary application groups"
    pure selected

require :: Bool -> Text -> Either Text ()
require condition message = unless condition (Left message)

unique :: Ord a => [a] -> Bool
unique values = Set.size (Set.fromList values) == length values

validHash :: Text -> Bool
validHash value = Text.length value == 64 && Text.all isHexDigit value

safeName :: Text -> Bool
safeName value = not (Text.null value) && Text.all (\c -> c `elem` ['a'..'z'] <> ['0'..'9'] <> ['-']) value

canonicalProject :: Text -> Bool
canonicalProject value = case Text.splitOn "/" value of
    ["mori:", "", namespace, project] -> not (Text.null namespace) && not (Text.null project)
    _ -> False

safePath :: FilePath -> Bool
safePath path = not (null path || isAbsolute path) && all (`notElem` [".", "..", ""]) (splitDirectories path)

validRevision :: Text -> Bool
validRevision value = Text.length value == 40 && Text.all isHexDigit value

validTimestamp :: Text -> Bool
validTimestamp value = isJust (parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" (Text.unpack value) :: Maybe UTCTime)
