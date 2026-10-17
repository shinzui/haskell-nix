{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Compare (comparePlan, verifyCohortImport, comparisonContext) where

import Control.Monad (unless)
import Data.Aeson (Value (..), eitherDecodeStrict', object, withObject, (.:), (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (parseEither)
import Data.ByteString (ByteString)
import Data.Char (isHexDigit)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Pretty (prettyShow)
import HaskellNix.Update.Cohort.Freeze (FreezeDocument (..), parseFreezeDocument)
import HaskellNix.Update.Cohort.Inventory (decodePlanVersions, projectFields, validatePlanCompiler)
import HaskellNix.Update.Cohort.Types (PackageSource (..), PlanPackage (..))
import HaskellNix.Update.Cohort.Render (canonicalPackage)

-- Nix graph/source comparison consumes this normalized context. The public
-- comparator never implements a second freeze parser or ownership model.
comparisonContext :: Set.Set Text -> Text -> Map Text PlanPackage -> Either Text Value
comparisonContext owned freeze sources = do
    (document, compiler) <- validateExpected owned freeze sources
    pure (object
        [ "compiler" .= compiler
        , "indexState" .= document.freezeIndexState
        , "versions" .= Map.map (Text.pack . prettyShow) document.freezeVersions
        , "flags" .= document.freezeFlags
        , "sources" .= Map.map canonicalPackage sources
        , "localPackages" .= Set.toAscList owned
        ])

validateExpected :: Set.Set Text -> Text -> Map Text PlanPackage -> Either Text (FreezeDocument, Text)
validateExpected owned freeze sources = do
    document <- parseFreezeDocument freeze
    compiler <- case [Text.strip value | line <- Text.lines freeze, Just value <- [Text.stripPrefix "-- Compiler:" line]] of
        [value] | not (Text.null value) -> Right value
        _ -> Left "freeze must record exactly one compiler header"
    unless (Map.keysSet document.freezeVersions `Set.isSubsetOf` Map.keysSet sources) (Left "freeze packages missing from source manifest")
    mapM_ (validateOwned document) (Set.toAscList (owned `Set.intersection` Map.keysSet sources))
    mapM_ (validateFrozen document) (Map.toAscList sources)
    pure (document, compiler)
  where
    -- Application libraries may be consumed as immutable source packages by a
    -- sibling. They remain outside the shared freeze, but their explicitly
    -- supplied source policy must still be checked for every plan instance.
    validateOwned document name = do
        let package = sources Map.! name
        unless (package.source == SourcePin && Map.notMember name document.freezeVersions)
            (Left "local ownership overlaps the cohort source manifest")
        unless (not (null package.identities) && all immutableRepository package.identities)
            (Left ("contributor source requires immutable Git identity: " <> name))
    immutableRepository (Object identity) = case KeyMap.lookup "pkg-src" identity of
        Just (Object source) -> case KeyMap.lookup "source-repo" source of
            Just (Object repository) -> case (KeyMap.lookup "type" repository, KeyMap.lookup "location" repository, KeyMap.lookup "tag" repository) of
                (Just (String "git"), Just (String location), Just (String revision)) ->
                    Text.isPrefixOf "https://" location && Text.length revision == 40 && Text.all isHexDigit revision
                _ -> False
            _ -> False
        _ -> False
    immutableRepository _ = False
    validateFrozen document (name, package) = do
        case Map.lookup name document.freezeVersions of
            Just version -> unless (package.version == Text.pack (prettyShow version)) (Left ("freeze/source version mismatch: " <> name))
            Nothing -> unless (package.source == SourcePin) (Left ("unfrozen source manifest package: " <> name))
        case Map.lookup name document.freezeFlags of
            Nothing -> pure ()
            Just flags -> unless (not (null package.identities) && all (hasFlags flags) package.identities) (Left ("freeze/source flags mismatch: " <> name))
    hasFlags flags (Object identity) = case KeyMap.lookup "flags" identity of
        Just (Object actual) -> all (\(name, enabled) -> KeyMap.lookup (Key.fromText name) actual == Just (Bool enabled)) (Map.toList flags)
        _ -> False
    hasFlags _ _ = False

-- The caller resolves the revision from this application's own lock, including
-- follows paths. Accept only a full immutable revision and one canonical import.
verifyCohortImport :: Text -> Text -> Either Text Text
verifyCohortImport revision project = do
    unless (Text.length revision == 40 && Text.all isHexDigit revision)
        (Left "cohort import requires a full locked Git revision")
    let expected = "https://raw.githubusercontent.com/shinzui/haskell-nix/" <> revision <> "/cabal/cohort.freeze"
        imports = concat [Text.words (Text.replace "," " " value) | ("import", value) <- projectFields project]
        cohortImports = filter (Text.isInfixOf "cohort.freeze") imports
    unless (cohortImports == [expected])
        (Left ("stale or missing cohort import: expected exactly " <> expected))
    pure ("Cohort import matches locked channel " <> revision)

-- A consumer uses a subset of the union. Check every retained instance, rather
-- than requiring that each application depend on the entire cohort. The shared
-- inventory decoder rejects mixed versions before merging component records.
comparePlan :: Set.Set Text -> Text -> Map Text PlanPackage -> ByteString -> Either Text Text
comparePlan owned freeze sources bytes = do
    (_, compiler) <- validateExpected owned freeze sources
    validatePlanCompiler compiler bytes
    value <- either (Left . Text.pack) Right (eitherDecodeStrict' bytes)
    rows <- either (Left . Text.pack) Right (parseEither (withObject "plan" (.: "install-plan")) value)
    locals <- either (Left . Text.pack) Right (traverse (parseEither localName) rows)
    let undeclared = Set.fromList [name | Just name <- locals] Set.\\ owned
    unless (Set.null undeclared) (Left ("undeclared local packages: " <> Text.intercalate ", " (Set.toAscList undeclared)))
    actual <- decodePlanVersions (Map.keysSet (Map.filter (\p -> p.source == Boot) sources)) bytes
    unless (not (Map.null actual)) (Left "plan contains no verifiable non-local dependencies")
    results <- traverse check (Map.toAscList actual)
    let failures = [message | Left message <- results]
    unless (null failures) (Left (Text.unlines failures))
    pure (Text.unlines [message | Right message <- results])
  where
    localName = withObject "plan row" $ \row -> case KeyMap.lookup "pkg-src" row of
        Just (Object src) | KeyMap.lookup "type" src == Just (String "local") -> Just <$> row .: "pkg-name"
        _ -> pure Nothing
    check (name, package) = pure $ case Map.lookup name sources of
        Nothing -> Left ("missing " <> name <> " from cohort source manifest")
        Just expected
            | package.version /= expected.version -> Left ("mismatch " <> name <> " expected=" <> expected.version <> " actual=" <> package.version)
            | package.source /= expected.source -> Left ("source mismatch " <> name)
            | null package.identities || null expected.identities -> Left ("missing source evidence " <> name)
            | not (all (matchesAny expected) package.identities) -> Left ("source/metadata/flags mismatch or missing evidence " <> name)
            | otherwise -> Right ("ok " <> name <> " " <> package.version)
    matchesAny expected actual = any (matches expected.source actual) expected.identities
    matches Boot (Object actual) (Object expected) =
        KeyMap.lookup "type" actual == Just (String "pre-existing")
            && KeyMap.lookup "type" expected == Just (String "pre-existing")
    matches Hackage (Object actual) (Object expected) =
        -- An installed non-boot package has no trustworthy source hashes in
        -- plan.json. Ask for a fresh plan rather than treating it as evidence.
        all (validHash actual) ["pkg-src-sha256", "pkg-cabal-sha256"]
            && all (equalPresent actual expected) ["pkg-src-sha256", "pkg-cabal-sha256", "flags"]
    matches SourcePin (Object actual) (Object expected) =
        validHash actual "pkg-src-sha256"
            && all (equalPresent actual expected) ["pkg-src", "pkg-src-sha256", "flags"]
    matches _ _ _ = False
    equalPresent actual expected key = case (KeyMap.lookup key actual, KeyMap.lookup key expected) of
        (Just value, Just other) -> value == other && value /= Null
        _ -> False
    validHash fields key = case KeyMap.lookup key fields of
        Just (String value) -> Text.length value == 64 && Text.all isHexDigit value
        _ -> False
