{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Render (renderCohortVersions, renderBootPackages) where

import Control.Monad (unless)
import Data.Aeson (Value (..), encode, toJSON)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString.Lazy qualified as LBS
import Data.Char (isHexDigit)
import Data.Foldable (toList)
import Data.List (nub, sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding (decodeUtf8)
import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Distribution.Pretty (prettyShow)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Freeze (FreezeDocument (..))
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.Model (parseVersion)
import HaskellNix.Update.Cohort.Types (PlanPackage (..))
import HaskellNix.Update.Types (SriHash (..))

-- Rendering has no network or filesystem effects. The caller must supply all
-- revision and unpacked-source proofs before any generated output is accepted.
renderCohortVersions :: GenerationMetadata -> FreezeDocument -> Map Text ClassifiedPackage -> Map Text GeneratedEntry -> Either Text Text
renderCohortVersions metadata document classified entries = do
    unless (validHash metadata.freezeSha256) (Left "invalid freeze SHA256")
    unless (metadata.generationIndexState == document.freezeIndexState) (Left "generation/freeze index-state mismatch")
    cutoff <- maybe (Left "invalid generation index-state") Right (parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" (Text.unpack metadata.generationIndexState) :: Maybe UTCTime)
    let generated = Map.filter (\p -> p.packageClassification == CohortGenerated) classified
    unless (Map.keysSet generated == Map.keysSet entries) (Left "generated entry coverage differs from classification")
    mapM_ (validateEntry cutoff) (Map.toAscList entries)
    pure $
        Text.unlines
            [ "# Generated cohort selection; do not edit by hand."
            , "{"
            , "  schemaVersion = 1;"
            , "  freezeSha256 = " <> quote metadata.freezeSha256 <> ";"
            , "  indexState = " <> quote metadata.generationIndexState <> ";"
            , "  ghc = " <> quote metadata.generationCompiler <> ";"
            , "  nixpkgsBase = " <> quote metadata.generationNixpkgsRevision <> ";"
            , "  packages = {"
            , Text.intercalate "\n" (map renderEntry (Map.toAscList entries))
            , "  };"
            , "  sameAsBase = " <> names CohortSameAsBase <> ";"
            , "  boot = " <> names CohortBoot <> ";"
            , "  firstParty = " <> names CohortFirstParty <> ";"
            , "  flags = builtins.fromJSON " <> quote (canonicalJSON (toJSON document.freezeFlags)) <> ";"
            , "  sourceManifest = builtins.fromJSON " <> quote (canonicalJSON (toJSON (Map.map (canonicalPackage . (.selectedPackage)) classified))) <> ";"
            , "  policy = {"
            , Text.intercalate "\n" ["    " <> quote name <> " = { reason = " <> quote owner.policyReason <> "; owner = " <> quote owner.policyOwner <> "; sourcePinned = " <> (if pinned then "true" else "false") <> "; };" | (name, p) <- Map.toAscList classified, (owner, pinned) <- owned p.packageClassification]
            , "  };"
            , "}"
            ]
  where
    names category = "[ " <> Text.unwords [quote name | (name, p) <- Map.toAscList classified, p.packageClassification == category] <> " ]"
    owned (CohortExcluded owner) = [(owner, False)]
    owned (CohortSourcePinned owner) = [(owner, True)]
    owned _ = []
    validateEntry cutoff (name, entry) = do
        selected <- maybe (Left "missing classified generated package") Right (Map.lookup name classified)
        version <- parseVersion selected.selectedPackage.version
        unless (entry.generatedVersion == version) (Left ("generated version mismatch: " <> name))
        let revision = entry.selectedRevision
            SriHash sourceHash = entry.unpackedHash
        unless (validSriHash sourceHash) (Left ("invalid unpacked SRI hash: " <> name))
        unless (revision.revisionNumber >= 0 && revision.revisionTime <= cutoff && validHash revision.revisionSha256) (Left ("invalid selected revision: " <> name))
        unless (not (null selected.selectedPackage.identities) && all (matches revision.revisionSha256) selected.selectedPackage.identities) (Left ("revision hash differs from source manifest: " <> name))
    matches expected (Object fields) = KeyMap.lookup "pkg-cabal-sha256" fields == Just (String expected)
    matches _ _ = False
    renderEntry (name, entry) =
        let SriHash hash = entry.unpackedHash
            revision = entry.selectedRevision
            revised = if revision.revisionNumber == 0 then "null" else "{ number = " <> quote (Text.pack (show revision.revisionNumber)) <> "; sha256 = " <> quote revision.revisionSha256 <> "; }"
         in "    " <> quote name <> " = { version = " <> quote (Text.pack (prettyShow entry.generatedVersion)) <> "; sha256 = " <> quote hash <> "; revision = " <> revised <> "; };"

canonicalPackage :: PlanPackage -> PlanPackage
canonicalPackage package = package{identities = sortOn canonicalJSON (nub package.identities), dependencies = sort (nub package.dependencies)}

renderBootPackages :: Text -> Map Text Version -> Text
renderBootPackages compiler packages = Text.unlines (["# Generated shipped boot package versions.", "{", "  ghc = " <> quote compiler <> ";", "  packages = {"] <> ["    " <> quote name <> " = " <> quote (Text.pack (prettyShow version)) <> ";" | (name, version) <- Map.toAscList packages] <> ["  };", "}"])

validHash :: Text -> Bool
validHash value = Text.length value == 64 && Text.all isHexDigit value

validSriHash :: Text -> Bool
validSriHash value = case Text.stripPrefix "sha256-" value of
    Just digest -> Text.length digest == 44 && Text.last digest == '=' && Text.all (\c -> c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c `elem` ['+', '/']) (Text.init digest)
    Nothing -> False

quote :: Text -> Text
quote value = "\"" <> Text.replace "${" "\\${" (Text.concatMap escape value) <> "\""
  where
    escape '\\' = "\\\\"
    escape '"' = "\\\""
    escape '\n' = "\\n"
    escape '\r' = "\\r"
    escape '\t' = "\\t"
    escape c = Text.singleton c

-- Aeson object ordering is not an input identity: sort recursively before
-- rendering JSON so provenance is deterministic across decoder backends.
canonicalJSON :: Value -> Text
canonicalJSON (Object fields) = "{" <> Text.intercalate "," [canonicalJSON (String (Key.toText key)) <> ":" <> canonicalJSON value | (key, value) <- sortOn (Key.toText . fst) (KeyMap.toList fields)] <> "}"
canonicalJSON (Array values) = "[" <> Text.intercalate "," (map canonicalJSON (toList values)) <> "]"
canonicalJSON value = decodeUtf8 (LBS.toStrict (encode value))
