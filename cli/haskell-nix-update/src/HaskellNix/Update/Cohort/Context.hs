{-# LANGUAGE OverloadedRecordDot #-}

-- | Portable snapshots of the existing generation inputs. This is a wire
-- representation of GenerationContext, not a second inventory or classifier.
module HaskellNix.Update.Cohort.Context (
    generationContextValue,
    decodeGenerationContext,
) where

import Control.Monad (unless)
import Data.Aeson (Value, eitherDecodeStrict', object, withObject, (.:), (.=))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString qualified as BS
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Pretty (prettyShow)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Freeze (FreezeDocument (..), parseFreezeDocument)
import HaskellNix.Update.Cohort.Generate (classifyCohort)
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.Model (parseVersion)

-- Deliberately exclude timestamps, paths and generation labels. Preserve every
-- source/component identity and base-policy fact used by classifyCohort.
generationContextValue :: GenerationContext -> Either Text Value
generationContextValue context = do
    validateContext context
    pure $ object
        [ "schemaVersion" .= (1 :: Int)
        , "freeze" .= object
            [ "versions" .= versions context.document.freezeVersions
            , "flags" .= context.document.freezeFlags
            , "indexState" .= context.document.freezeIndexState
            ]
        , "sources" .= context.sources
        , "shippedBoot" .= versions context.shippedBoot
        , "firstParty" .= versions context.firstParty
        , "policy" .= object
            [ "excluded" .= fmap owned context.policy.excludedPackages
            , "sourcePinned" .= fmap owned context.policy.pinnedPackages
            ]
        , "basePackages" .= context.basePackages
        , "selectedPolicyIdentities" .= context.selectedPolicyIdentities
        , "basePolicyIdentities" .= context.basePolicyIdentities
        ]
  where
    versions = fmap (Text.pack . prettyShow)
    owned entry = object ["reason" .= entry.policyReason, "owner" .= entry.policyOwner]

decodeGenerationContext :: BS.ByteString -> Either Text GenerationContext
decodeGenerationContext bytes = do
    value <- either (Left . Text.pack) Right (eitherDecodeStrict' bytes)
    context <- either (Left . Text.pack) Right (parseEither parser value)
    validateContext context
    pure context
  where
    parser = withObject "generation context" $ \o -> do
        exact ["schemaVersion", "freeze", "sources", "shippedBoot", "firstParty", "policy", "basePackages", "selectedPolicyIdentities", "basePolicyIdentities"] o
        schema :: Int <- o .: "schemaVersion"
        unless (schema == 1) (fail "unsupported generation context schema")
        document <- o .: "freeze" >>= withObject "generation freeze" (\f -> do
            exact ["versions", "flags", "indexState"] f
            FreezeDocument <$> (f .: "versions" >>= parseVersions) <*> f .: "flags" <*> f .: "indexState")
        policy <- o .: "policy" >>= withObject "generation policy" (\p -> do
            exact ["excluded", "sourcePinned"] p
            GenerationPolicy <$> (p .: "excluded" >>= traverse parseOwned) <*> (p .: "sourcePinned" >>= traverse parseOwned))
        GenerationContext document <$> o .: "sources"
            <*> (o .: "shippedBoot" >>= parseVersions)
            <*> (o .: "firstParty" >>= parseVersions)
            <*> pure policy <*> o .: "basePackages"
            <*> o .: "selectedPolicyIdentities" <*> o .: "basePolicyIdentities"
    parseVersions :: Map Text Text -> Parser (Map Text Version)
    parseVersions = traverse (either (fail . Text.unpack) pure . parseVersion)
    parseOwned = withObject "owned generation policy" $ \o -> do
        exact ["reason", "owner"] o
        OwnedPolicy <$> o .: "reason" <*> o .: "owner"
    exact keys fields = unless (length keys == KeyMap.size fields && all (`KeyMap.member` fields) keys)
        (fail "missing or unknown generation context fields")

validateContext :: GenerationContext -> Either Text ()
validateContext context = do
    -- Reuse the freeze parser for cutoff, package/flag names and versions, then
    -- the accepted classifier for coverage, source ownership and base parity.
    parsed <- parseFreezeDocument $ Text.unlines
        [ "index-state: " <> context.document.freezeIndexState
        , "constraints: " <> Text.intercalate ", "
            (["any." <> name <> " ==" <> Text.pack (prettyShow version) | (name, version) <- Map.toAscList context.document.freezeVersions]
            <> ["any." <> name <> " " <> Text.unwords [ (if enabled then "+" else "-") <> flag | (flag, enabled) <- Map.toAscList flags]
               | (name, flags) <- Map.toAscList context.document.freezeFlags])
        ]
    unless (parsed == context.document) (Left "generation context freeze does not round-trip")
    _ <- classifyCohort context
    pure ()
