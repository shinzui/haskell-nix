{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Generate (classifyCohort) where

import Control.Monad (unless)
import Data.Aeson (Value (..), encode)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Char (isHexDigit)
import Data.List (nub, sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import HaskellNix.Update.Cohort.Freeze (FreezeDocument (..))
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.Model (parseVersion)
import HaskellNix.Update.Cohort.Types (PackageSource (..), PlanPackage (..))

classifyCohort :: GenerationContext -> Either Text (Map Text ClassifiedPackage)
classifyCohort context = do
    let frozen = Map.keysSet context.document.freezeVersions
        recorded = Map.keysSet context.sources
        pins = Map.keysSet (Map.filter (\p -> p.source == SourcePin) context.sources)
    unless (frozen `Set.isSubsetOf` recorded) (Left "freeze contains packages missing from source manifest")
    unless (Map.keysSet context.document.freezeFlags `Set.isSubsetOf` recorded) (Left "freeze flags refer to packages missing from source manifest")
    unless ((recorded Set.\\ frozen) `Set.isSubsetOf` pins) (Left "source manifest contains unfrozen non-source-pinned packages")
    unless (Set.null (Map.keysSet context.policy.excludedPackages `Set.intersection` Map.keysSet context.policy.pinnedPackages)) (Left "conflicting excluded/source-pinned ownership")
    mapM_ validatePolicy (Map.elems context.policy.excludedPackages <> Map.elems context.policy.pinnedPackages)
    Map.traverseWithKey classify context.sources
  where
    validatePolicy entry = do
        unless (not (Text.null (Text.strip entry.policyReason))) (Left "generation policy requires a reason")
        unless (validOwner entry.policyOwner) (Left "generation policy requires a canonical Mori owner")
    validOwner owner = case Text.stripPrefix "mori://" owner of
        Just path -> case Text.splitOn "/" path of
            namespace : project : suffix -> all validPart (namespace : project : suffix)
            _ -> False
        Nothing -> False
    validPart part = not (Text.null part) && not (Text.any (\c -> c <= ' ' || c `elem` ['?', '#', '\\']) part)
    classify name package = do
        version <- parseVersion package.version
        case Map.lookup name context.document.freezeVersions of
            Just expected -> unless (version == expected) (Left ("freeze/source version mismatch for " <> name))
            Nothing -> pure ()
        unless (not (null package.identities)) (Left ("missing source identities for " <> name))
        case Map.lookup name context.document.freezeFlags of
            Just flags -> unless (all (matchesFlags flags) package.identities) (Left ("freeze/source flags mismatch for " <> name))
            Nothing -> pure ()
        classification <- case package.source of
            Boot -> do
                unless (Map.lookup name context.shippedBoot == Just version) (Left ("non-shipped boot version for " <> name))
                pure CohortBoot
            SourcePin -> do
                owner <- maybe (Left ("source-pinned package requires declared ownership: " <> name)) Right (Map.lookup name context.policy.pinnedPackages)
                unless (all validPin package.identities) (Left ("incomplete pinned source identity for " <> name))
                case Map.lookup name context.firstParty of
                    Just expected -> unless (expected == version) (Left ("first-party/source-pin version mismatch for " <> name))
                    Nothing -> pure ()
                pure (CohortSourcePinned owner)
            Hackage -> do
                unless (all validHackage package.identities) (Left ("incomplete Hackage source/metadata identity for " <> name))
                unless (not (Map.member name context.shippedBoot)) (Left ("cannot replace a shipped boot package: " <> name))
                unless (not (Map.member name context.policy.pinnedPackages)) (Left ("Hackage/source-pinned policy conflict for " <> name))
                case (Map.lookup name context.firstParty, Map.lookup name context.policy.excludedPackages) of
                    (Just _, Just _) -> Left ("first-party/excluded ownership conflict for " <> name)
                    (Just expected, _) -> do
                        unless (expected == version) (Left ("first-party version mismatch for " <> name))
                        pure CohortFirstParty
                    (_, Just owner) -> pure (CohortExcluded owner)
                    _ -> pure (if sameAsBase name package then CohortSameAsBase else CohortGenerated)
        pure (ClassifiedPackage package classification)
    sameAsBase name package = case (Map.lookup name context.basePackages, Map.lookup name context.selectedPolicyIdentities, Map.lookup name context.basePolicyIdentities) of
        (Just base, Just selectedPolicy, Just basePolicy) ->
            not (Text.null selectedPolicy) && selectedPolicy == basePolicy && canonical package == canonical base
        _ -> False
    canonical package = package{identities = sortOn encode (nub package.identities), dependencies = sort (nub package.dependencies)}
    hash key (Object fields) = case KeyMap.lookup key fields of
        Just (String value) -> Text.length value == 64 && Text.all isHexDigit value
        _ -> False
    hash _ _ = False
    matchesFlags flags (Object fields) = case KeyMap.lookup "flags" fields of
        Just (Object actual) -> all (\(name, enabled) -> KeyMap.lookup (Key.fromText name) actual == Just (Bool enabled)) (Map.toList flags)
        _ -> Map.null flags
    matchesFlags _ _ = False
    validHackage identity = hash "pkg-cabal-sha256" identity && hash "pkg-src-sha256" identity
    validPin identity@(Object fields) =
        hash "pkg-src-sha256" identity && case KeyMap.lookup "pkg-src" fields of
            Just (Object src) | KeyMap.lookup "type" src == Just (String "source-repo") -> case KeyMap.lookup "source-repo" src of
                Just (Object repository) | KeyMap.lookup "type" repository == Just (String "git") -> case (KeyMap.lookup "tag" repository, KeyMap.lookup "location" repository) of
                    (Just (String tag), Just (String location)) -> Text.length tag == 40 && Text.all isHexDigit tag && not (Text.null location)
                    _ -> False
                _ -> False
            _ -> False
    validPin _ = False
