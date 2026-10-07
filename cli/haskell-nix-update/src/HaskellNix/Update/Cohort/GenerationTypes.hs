module HaskellNix.Update.Cohort.GenerationTypes (
    OwnedPolicy (..),
    GenerationPolicy (..),
    GenerationContext (..),
    Classification (..),
    ClassifiedPackage (..),
    HackageRevision (..),
    GeneratedEntry (..),
    GenerationMetadata (..),
) where

import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Time (UTCTime)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Freeze (FreezeDocument)
import HaskellNix.Update.Cohort.Types (PlanPackage)
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
