module HaskellNix.Update.Cohort.GenerationTypes (
    OwnedPolicy (..),
    GenerationPolicy (..),
    GenerationContext (..),
    Classification (..),
    ClassifiedPackage (..),
    HackageRevision (..),
    GeneratedEntry (..),
    GenerationMetadata (..),
    selectedMetadataHash,
    selectedPackageFlags,
) where

import Data.Map.Strict (Map)
import Data.Aeson (Value (..), fromJSON, Result (..))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Text (Text)
import Data.Time (UTCTime)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Freeze (FreezeDocument)
import HaskellNix.Update.Cohort.Types (PlanPackage (..))
import HaskellNix.Update.Types (SriHash)

data OwnedPolicy = OwnedPolicy {policyReason :: !Text, policyOwner :: !Text}
    deriving stock (Eq, Show)

data GenerationPolicy = GenerationPolicy
    {excludedPackages :: !(Map Text OwnedPolicy), pinnedPackages :: !(Map Text OwnedPolicy)}
    deriving stock (Eq, Show)

-- All context is explicit: retained runtime projections can use this same
-- classifier without reading or changing the live default cohort.
data GenerationContext = GenerationContext
    { document :: !FreezeDocument
    , sources :: !(Map Text PlanPackage)
    , shippedBoot :: !(Map Text Version)
    , firstParty :: !(Map Text Version)
    , policy :: !GenerationPolicy
    , basePackages :: !(Map Text PlanPackage)
    , selectedPolicyIdentities :: !(Map Text Text)
    , basePolicyIdentities :: !(Map Text Text)
    }
    deriving stock (Eq, Show)

data Classification
    = CohortBoot
    | CohortFirstParty
    | CohortExcluded !OwnedPolicy
    | CohortSourcePinned !OwnedPolicy
    | CohortSameAsBase
    | CohortGenerated
    deriving stock (Eq, Show)

data ClassifiedPackage = ClassifiedPackage
    {selectedPackage :: !PlanPackage, packageClassification :: !Classification}
    deriving stock (Eq, Show)

data HackageRevision = HackageRevision
    {revisionNumber :: !Int, revisionTime :: !UTCTime, revisionSha256 :: !Text}
    deriving stock (Eq, Show)

data GeneratedEntry = GeneratedEntry
    {generatedVersion :: !Version, unpackedHash :: !SriHash, selectedRevision :: !HackageRevision}
    deriving stock (Eq, Show)

data GenerationMetadata = GenerationMetadata
    { freezeSha256 :: !Text
    , generationIndexState :: !Text
    , generationCompiler :: !Text
    , generationNixpkgsRevision :: !Text
    }
    deriving stock (Eq, Show)

-- Exact metadata and flags come from the existing solved identities. Conversion
-- and revision resolution share these facts rather than keeping another lock.
selectedMetadataHash :: Text -> PlanPackage -> Either Text Text
selectedMetadataHash name package = case [hash | Object fields <- identities package, Just (String hash) <- [KeyMap.lookup "pkg-cabal-sha256" fields]] of
    hash : rest | all (== hash) rest && length (hash : rest) == length (identities package) -> Right hash
    _ -> Left ("missing or conflicting Cabal metadata hashes for " <> name)

selectedPackageFlags :: Text -> PlanPackage -> Either Text (Map Text Bool)
selectedPackageFlags name package = do
    assignments <- traverse flags (identities package)
    case assignments of
        first : rest | all (== first) rest -> Right first
        _ -> Left ("missing or conflicting component flags for " <> name)
  where
    flags (Object fields) = case KeyMap.lookup "flags" fields of
        Just value -> case fromJSON value of
            Success parsed -> Right parsed
            Error _ -> Left ("invalid component flags for " <> name)
        Nothing -> Left ("missing component flags for " <> name)
    flags _ = Left ("invalid component identity for " <> name)
