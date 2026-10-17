{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Compatibility.Types
    ( CompatibilityContext (..), CompatibilityEntry (..), decodeCompatibilityContext ) where

import Control.Monad (unless)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.List (nub)
import Data.Text (Text)
import Data.Text qualified as Text

-- Keep the full Nix-produced document for rendering. Haskell validates the
-- interchange contract; it does not implement another version/guard selector.
data CompatibilityContext = CompatibilityContext
    { document :: !Value
    , entries :: ![CompatibilityEntry]
    , requiredEvidence :: ![Text]
    , problems :: ![Text]
    } deriving stock (Eq, Show)

data CompatibilityEntry = CompatibilityEntry
    { entryId :: !Text
    , package :: !Text
    , status :: !Text
    , required :: !Bool
    , constructionProblems :: ![Text]
    } deriving stock (Eq, Show)

decodeCompatibilityContext :: ByteString -> Either Text CompatibilityContext
decodeCompatibilityContext bytes = do
    value <- either (Left . Text.pack) Right (eitherDecodeStrict' bytes)
    either (Left . Text.pack) Right (parseEither parseContext value)

parseContext :: Value -> Parser CompatibilityContext
parseContext document = withObject "compatibility declaration context" (\o -> do
    schema <- o .: "schemaVersion" :: Parser Int
    kind <- o .: "reportKind"
    unless (schema == 1 && kind == ("declaration-only" :: Text)) (fail "unsupported compatibility report schema/kind")
    configuration <- o .: "configuration"
    withObject "configuration" (\c -> do
        mapM_ (\key -> c .: key >>= nonempty) ["packageSet", "system"]
        channel <- c .: "channel"
        unless (channel `elem` (["github", "hackage"] :: [Text])) (fail "invalid channel")
        compiler <- c .: "ghc"
        withObject "ghc" (\g -> mapM_ (\key -> g .: key >>= nonempty) ["version", "derivation"]) compiler
        ) configuration
    mapM_ (\key -> o .: key >>= digest) ["inputIdentity", "policyIdentity"]
    entries <- o .: "entries" >>= traverse parseEntry
    requiredEvidence <- o .: "requiredEvidence"
    mapM_ nonempty requiredEvidence
    unless (nub requiredEvidence == requiredEvidence) (fail "duplicate required evidence ID")
    unless (nub [(e.entryId, e.package) | e <- entries] == [(e.entryId, e.package) | e <- entries]) (fail "duplicate report entry instance")
    mapM_ (\e -> unless (e.required == (e.entryId `elem` requiredEvidence && e.status == "selected-unverified")) (fail "inconsistent required evidence flag")) entries
    problems <- o .: "problems"
    let expected = ["required entry has no selected instance: " <> i | i <- requiredEvidence, not (any (\e -> e.entryId == i && e.status == "selected-unverified") entries)]
                ++ ["required evidence is unverified: " <> e.entryId <> "/" <> e.package | e <- entries, e.required]
                ++ concatMap (.constructionProblems) entries
    unless (problems == expected) (fail "inconsistent evidence diagnostics")
    pure CompatibilityContext { document, entries, requiredEvidence, problems }
    ) document

parseEntry :: Value -> Parser CompatibilityEntry
parseEntry = withObject "compatibility entry" $ \o -> do
    entryId <- o .: "id"
    package <- o .: "package"
    mapM_ nonempty [entryId, package]
    status <- o .: "status"
    unless (status `elem` (["selected-unverified", "inactive-row", "inactive-scope"] :: [Text])) (fail "invalid declaration status")
    evidence <- o .: "evidenceStatus"
    unless (evidence == ("unverified" :: Text)) (fail "a declaration report cannot claim verified evidence")
    guard <- o .: "sourceGuard"
    unless (guard `elem` (["not-required", "unverified"] :: [Text])) (fail "source guard has no verified receipt")
    effects <- o .: "effects"
    unless (not (null (effects :: [Text]))) (fail "entry has no declared effects")
    mapM_ nonempty effects
    inputs <- o .: "inputs"
    withObject "pre-repair inputs" (\i -> mapM_ (\key -> i .: key >>= nonempty) ["version", "sourceIdentity", "metadataIdentity", "derivation"]) inputs
    construction <- o .:? "construction"
    mapM_ (validateConstruction inputs) construction
    constructionProblems <- o .:? "constructionProblems" .!= []
    expectedProblems <- case construction of
        Nothing -> pure []
        Just observation -> withObject "construction policy" (\c -> do
            after <- c .: "after"
            withObject "after construction" (\a -> do
                effective <- a .: "effective"
                withObject "effective policy" (\e -> do
                    tests <- e .: "testsEnabled" :: Parser (Maybe Bool)
                    bounds <- e .: "boundsRelaxed" :: Parser (Maybe Bool)
                    pure $
                        ["declared test suppression not visible: " <> entryId <> "/" <> package | status == "selected-unverified", "test-suppression" `elem` effects, tests /= Just False]
                        ++ ["declared bounds relaxation not visible: " <> entryId <> "/" <> package | status == "selected-unverified", "bound-relaxation" `elem` effects, bounds /= Just True]
                    ) effective
                ) after
            ) observation
    unless (constructionProblems == expectedProblems) (fail "inconsistent captured policy diagnostics")
    required <- o .: "required"
    pure CompatibilityEntry { entryId, package, status, required, constructionProblems }

-- Selection remains Nix-owned. This checks only that the captured boundary and
-- the report's input identity agree, without relabelling an observation as a test.
validateConstruction :: Value -> Value -> Parser ()
validateConstruction inputs = withObject "construction observation" $ \o -> do
    stage <- o .: "stage"
    before <- o .: "before"
    after <- o .: "after"
    case stage :: Text of
        "source-constructor" -> do
            unless (before == Null) (fail "source constructor cannot claim a stock pre-repair input")
            agree inputs after
        "compatibility-row" -> do
            unless (before /= Null) (fail "compatibility repair lacks its actual pre-repair input")
            agree inputs before
            snapshot after
        _ -> fail "invalid construction observation stage"
  where
    identity = withObject "captured input" $ \o -> do
        mapM_ (\key -> o .: key >>= nonempty) ["version", "sourceIdentity", "metadataIdentity", "derivation"]
        pure (Object (KeyMap.filterWithKey (\key _ -> key `elem` ["version", "sourceIdentity", "metadataIdentity", "derivation"]) o))
    agree expected actual = do
        expectedIdentity <- identity expected
        actualIdentity <- identity actual
        unless (expectedIdentity == actualIdentity) (fail "report inputs disagree with captured construction boundary")
        snapshot actual
    snapshot = withObject "captured snapshot" $ \o -> do
        _ <- identity (Object o)
        effective <- o .: "effective"
        withObject "effective Cabal arguments" (\e -> do
            _ <- e .: "testsEnabled" :: Parser (Maybe Bool)
            _ <- e .: "boundsRelaxed" :: Parser (Maybe Bool)
            _ <- e .: "configureFlags" :: Parser [Text]
            pure ()
            ) effective

nonempty :: Text -> Parser ()
nonempty value = unless (not (Text.null (Text.strip value))) (fail "empty compatibility identity")

digest :: Text -> Parser ()
digest value = unless (Text.length value == 64 && Text.all (`elem` ("0123456789abcdef" :: String)) value) (fail "invalid SHA256 report identity")
