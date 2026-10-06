{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Inventory (
    readPlanVersions,
    decodePlanVersions,
    validatePlanCompiler,
    readDeclaredBounds,
    readProjectConstraints,
    projectFields,
) where

import Control.Monad (forM)
import Data.Aeson
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as BS
import Data.List (nub, sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (maybeToList)
import Data.Set (Set)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Distribution.PackageDescription
import Distribution.PackageDescription.Parsec
import Distribution.Parsec (simpleParsec)
import Distribution.Pretty (Pretty, prettyShow)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Types
import System.Environment (lookupEnv)
import System.FilePath ((</>))
import System.Process (readProcess)

-- Retain component identities, flags, source hashes, and dependency edges for
-- impact reporting. Multiple instances of one version merge; different versions
-- of one name fail rather than silently selecting one.
readPlanVersions :: FilePath -> IO (Either Text (Map Text PlanPackage))
readPlanVersions path = do
    executable <- maybe "ghc-pkg" id <$> lookupEnv "COHORT_GHC_PKG"
    installed <- Text.words . Text.pack <$> readProcess executable ["list", "--global", "--simple-output"] ""
    let bootNames = Set.fromList [Text.intercalate "-" (init (Text.splitOn "-" entry)) | entry <- installed]
    decodePlanVersions bootNames <$> BS.readFile path

decodePlanVersions :: Set Text -> BS.ByteString -> Either Text (Map Text PlanPackage)
decodePlanVersions bootNames bytes = do
    value <- either (Left . Text.pack) Right (eitherDecodeStrict' bytes)
    rows <- either (Left . Text.pack) Right (parseEither (withObject "plan" (.: "install-plan")) value :: Either String [Value])
    parsed <- traverse (either (Left . Text.pack) Right . parseEither parseRow) rows
    let ids = Map.fromList [(unitId, pkgName) | (unitId, pkgName, _, _, _) <- parsed]
        resolve dep = maybe (Left ("unresolved plan dependency: " <> dep)) Right (Map.lookup dep ids)
    entries <- forM parsed $ \(_, pkgName, pkgVersion, pkgSource, raw) -> case pkgSource of
        Nothing -> pure Nothing
        Just src -> do
            deps <- either (Left . Text.pack) Right (parseEither parseDependencies raw)
            names <- traverse resolve deps
            pure (Just (pkgName, PlanPackage pkgVersion src [identity raw] (sort (nub names))))
    foldl insertEntry (Right Map.empty) [entry | Just entry <- entries]
  where
    insertEntry acc (pkgName, entry) = do
        current <- acc
        case Map.lookup pkgName current of
            Nothing -> pure (Map.insert pkgName entry current)
            Just old
                | old.version == entry.version && old.source == entry.source ->
                    pure (Map.insert pkgName (old{identities = canonicalIdentities (old.identities <> entry.identities), dependencies = sort (nub (old.dependencies <> entry.dependencies))}) current)
                | otherwise -> Left ("multiple versions/sources for " <> pkgName)
    canonicalIdentities = sortOn encode . nub
    identity (Object fields) = Object (KeyMap.filterWithKey (\key _ -> key `elem` ["pkg-name", "pkg-version", "pkg-src", "pkg-src-sha256", "pkg-cabal-sha256", "flags", "type", "component-name"]) fields)
    identity other = other
    parseRow = withObject "plan entry" $ \o -> do
        unitId <- o .: "id"
        pkgName <- o .: "pkg-name"
        pkgVersion <- o .: "pkg-version"
        case simpleParsec (Text.unpack pkgVersion) :: Maybe Version of
            Nothing -> fail "invalid package version"
            Just _ -> pure ()
        kind <- o .: "type" :: Parser Text
        src <-
            if kind == "pre-existing"
                then pure (Just (if Set.member pkgName bootNames then Boot else Hackage))
                else do
                    pkgSrc <- o .: "pkg-src"
                    sourceType <- withObject "pkg-src" (.: "type") pkgSrc :: Parser Text
                    case sourceType of
                        "repo-tar" -> pure (Just Hackage)
                        "source-repo" -> pure (Just SourcePin)
                        "local" -> pure Nothing
                        other -> fail ("unsupported plan source: " <> Text.unpack other)
        pure (unitId, pkgName, pkgVersion, src, Object o)
    parseDependencies = withObject "plan entry" $ \o -> do
        top <- o .:? "depends" .!= []
        executableDeps <- o .:? "exe-depends" .!= []
        components <- o .:? "components" .!= Object mempty
        nested <- withObject "components" (fmap concat . traverse (withObject "component" (\c -> (<>) <$> (c .:? "depends" .!= []) <*> (c .:? "exe-depends" .!= []))) . KeyMap.elems) components
        pure (nub (top <> executableDeps <> nested))

-- Compiler provenance must describe the actual solver plan.
validatePlanCompiler :: Text -> BS.ByteString -> Either Text ()
validatePlanCompiler expected bytes = do
    value <- either (Left . Text.pack) Right (eitherDecodeStrict' bytes)
    actual <- either (Left . Text.pack) Right (parseEither (withObject "plan" (.: "compiler-id")) value)
    if actual == expected then Right () else Left ("resolved compiler differs from recorded input: " <> actual <> " /= " <> expected)

readDeclaredBounds :: FilePath -> [FilePath] -> IO (Either Text [DeclaredBound])
readDeclaredBounds root files = fmap (fmap (sort . nub . concat) . sequence) $ forM files $ \file -> do
    bytes <- BS.readFile (root </> file)
    pure $ case snd (runParseResult (parseGenericPackageDescription bytes)) of
        Left errors -> Left (Text.pack file <> ": " <> Text.pack (show errors))
        Right gpd ->
            Right $
                concatMap (walk file "library" libBuildInfo "always") (maybeToList (condLibrary gpd))
                    <> concatMap (\(n, t) -> walk file ("library:" <> display n) libBuildInfo "always" t) (condSubLibraries gpd)
                    <> concatMap (\(n, t) -> walk file ("executable:" <> display n) buildInfo "always" t) (condExecutables gpd)
                    <> concatMap (\(n, t) -> walk file ("test:" <> display n) testBuildInfo "always" t) (condTestSuites gpd)
                    <> concatMap (\(n, t) -> walk file ("benchmark:" <> display n) benchmarkBuildInfo "always" t) (condBenchmarks gpd)
                    <> concatMap (\(n, t) -> walk file ("foreign-library:" <> display n) foreignLibBuildInfo "always" t) (condForeignLibs gpd)
                    <> [dependencyBound file "custom-setup" "always" d | setup <- maybeToList (setupBuildInfo (packageDescription gpd)), d <- setupDepends setup]
  where
    display :: (Pretty a) => a -> Text
    display = Text.pack . prettyShow
    dependencyBound file component condition dep = DeclaredBound (display (depPkgName dep)) (display (depVerRange dep)) file component condition Nothing
    walk :: FilePath -> Text -> (a -> BuildInfo) -> Text -> CondTree ConfVar [Dependency] a -> [DeclaredBound]
    walk file component getInfo condition (CondNode node deps branches) =
        map (dependencyBound file component condition) deps
            <> [DeclaredBound (display pn) (display vr) file component condition (Just (display exe)) | ExeDependency pn exe vr <- buildToolDepends (getInfo node)]
            <> concatMap (branch file component getInfo condition) branches
    branch :: FilePath -> Text -> (a -> BuildInfo) -> Text -> CondBranch ConfVar [Dependency] a -> [DeclaredBound]
    branch file component getInfo parent (CondBranch cond yes no) =
        walk file component getInfo (parent <> " && " <> Text.pack (show cond)) yes
            <> concatMap (walk file component getInfo (parent <> " && not(" <> Text.pack (show cond) <> ")")) (maybeToList no)

-- Top-level project fields retain continuation lines and discard comments.
-- Nested package stanzas are intentionally excluded from global constraints.
projectFields :: Text -> [(Text, Text)]
projectFields = reverse . foldl step [] . Text.lines
  where
    step acc original
        | Text.null stripped = acc
        | Text.head original == ' ' || Text.head original == '\t' = case acc of
            (key, val) : rest -> (key, val <> " " <> stripped) : rest
            [] -> []
        | otherwise = case Text.breakOn ":" stripped of
            (key, val) | not (Text.null val) -> (key, Text.strip (Text.drop 1 val)) : acc
            _ -> ("", "") : acc
      where
        stripped = Text.strip (fst (Text.breakOn "--" original))

readProjectConstraints :: FilePath -> IO (Either Text [DeclaredBound])
readProjectConstraints path = do
    contents <- TextIO.readFile path
    pure $ fmap concat $ traverse parseConstraint [Text.strip part | ("constraints", value) <- projectFields contents, part <- Text.splitOn "," value, not (Text.null (Text.strip part))]
  where
    parseConstraint text = case simpleParsec (Text.unpack text) of
        Just dep -> Right [DeclaredBound (Text.pack (prettyShow (depPkgName dep))) (Text.pack (prettyShow (depVerRange dep))) "cabal.project" "cabal.project constraints" "always" Nothing]
        Nothing | any (\word -> Text.isPrefixOf "+" word || Text.isPrefixOf "-" word) (drop 1 (Text.words text)) -> Right []
        Nothing -> Left ("invalid project constraint: " <> text)
