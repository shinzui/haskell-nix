module HaskellNix.Update.Types
  ( FamilyName (..),
    UpdateGroupName (..),
    SnapshotGeneration (..),
    PackageName (..),
    GitRevision (..),
    SriHash (..),
    PackageOverride (..),
    FamilyConfig (..),
    UpdateGroup (..),
    FamilyCatalog (..),
    DiscoveryPolicy (..),
    HackagePin (..),
    LockedPackage (..),
    LockedFamily (..),
    PackageLock (..),
    LegacyPackageLock,
    LockedSource (..),
    FamilySnapshot (..),
    FamilySnapshotSelection (..),
    GroupSnapshot (..),
    GroupSelection (..),
    PackageSetSupportLevel (..),
    PackageSet (..),
    PackageSetLock (..),
    DiscoveredPackage (..),
    HackageRelease (..),
    ObservedPackage (..),
    ObservedFamily (..),
    FamilyChange (..),
    RefreshPlan (..),
    UpdateError (..),
  )
where

import Data.Map.Strict (Map)
import Data.Set (Set)
import Data.Text (Text)
import Distribution.Types.Version (Version)

newtype FamilyName = FamilyName Text
  deriving stock (Eq, Ord, Show)

newtype UpdateGroupName = UpdateGroupName Text
  deriving stock (Eq, Ord, Show)

newtype SnapshotGeneration = SnapshotGeneration Int
  deriving stock (Eq, Ord, Show)

newtype PackageName = PackageName Text
  deriving stock (Eq, Ord, Show)

newtype GitRevision = GitRevision Text
  deriving stock (Eq, Ord, Show)

newtype SriHash = SriHash Text
  deriving stock (Eq, Ord, Show)

data PackageOverride = PackageOverride
  { cabal2nixOptions :: !Text
  }
  deriving stock (Eq, Show)

data FamilyConfig = FamilyConfig
  { name :: !FamilyName,
    moriProject :: !Text,
    github :: !Text,
    githubInput :: !Text,
    packageOverrides :: !(Map PackageName PackageOverride),
    -- Discovered Cabal packages that never become family packages. A repository
    -- may carry an example or fixture package whose name collides with another
    -- family; excluding it keeps package names globally unique.
    excludedPackages :: !(Set PackageName)
  }
  deriving stock (Eq, Show)

data UpdateGroup = UpdateGroup
  { name :: !UpdateGroupName,
    families :: ![FamilyName]
  }
  deriving stock (Eq, Show)

data FamilyCatalog = FamilyCatalog
  { schemaVersion :: !Int,
    families :: ![FamilyConfig],
    updateGroups :: ![UpdateGroup]
  }
  deriving stock (Eq, Show)

data DiscoveryPolicy = DiscoveryPolicy
  { packageOverrides :: !(Map PackageName PackageOverride),
    excludedPackages :: !(Set PackageName)
  }
  deriving stock (Eq, Show)

data HackagePin = HackagePin
  { version :: !Version,
    hash :: !SriHash
  }
  deriving stock (Eq, Show)

data LockedPackage = LockedPackage
  { name :: !PackageName,
    path :: !FilePath,
    version :: !Version,
    cabal2nixOptions :: !Text,
    hackage :: !(Maybe HackagePin)
  }
  deriving stock (Eq, Show)

data LockedFamily = LockedFamily
  { name :: !FamilyName,
    githubInput :: !Text,
    githubRev :: !GitRevision,
    packages :: ![LockedPackage]
  }
  deriving stock (Eq, Show)

data PackageLock = PackageLock
  { schemaVersion :: !Int,
    families :: ![LockedFamily]
  }
  deriving stock (Eq, Show)

-- The production updater continues to use the version-1 flat lock while the
-- version-2 snapshot graph is introduced alongside it.
type LegacyPackageLock = PackageLock

data LockedSource = LockedSource
  { sourceType :: !Text,
    owner :: !Text,
    repo :: !Text,
    rev :: !GitRevision,
    narHash :: !SriHash
  }
  deriving stock (Eq, Show)

data FamilySnapshot = FamilySnapshot
  { family :: !FamilyName,
    generation :: !SnapshotGeneration,
    discoveryPolicy :: !DiscoveryPolicy,
    source :: !LockedSource,
    packages :: ![LockedPackage]
  }
  deriving stock (Eq, Show)

data FamilySnapshotSelection = FamilySnapshotSelection
  { family :: !FamilyName,
    generation :: !SnapshotGeneration
  }
  deriving stock (Eq, Ord, Show)

data GroupSnapshot = GroupSnapshot
  { group :: !UpdateGroupName,
    generation :: !SnapshotGeneration,
    families :: ![FamilySnapshotSelection],
    compatibilityProfile :: !Text
  }
  deriving stock (Eq, Show)

data GroupSelection = GroupSelection
  { group :: !UpdateGroupName,
    generation :: !SnapshotGeneration
  }
  deriving stock (Eq, Ord, Show)

data PackageSetSupportLevel = Curated | Historical
  deriving stock (Eq, Ord, Show)

data PackageSet = PackageSet
  { name :: !Text,
    supportLevel :: !PackageSetSupportLevel,
    groups :: ![GroupSelection]
  }
  deriving stock (Eq, Show)

data PackageSetLock = PackageSetLock
  { schemaVersion :: !Int,
    familySnapshots :: ![FamilySnapshot],
    groupSnapshots :: ![GroupSnapshot],
    packageSets :: ![PackageSet],
    defaultPackageSet :: !Text
  }
  deriving stock (Eq, Show)

data DiscoveredPackage = DiscoveredPackage
  { name :: !PackageName,
    path :: !FilePath,
    version :: !Version
  }
  deriving stock (Eq, Show)

data HackageRelease = HackageRelease
  { version :: !Version,
    usedFallback :: !Bool
  }
  deriving stock (Eq, Show)

data ObservedPackage = ObservedPackage
  { discovered :: !DiscoveredPackage,
    hackage :: !(Maybe HackagePin),
    usedHackageFallback :: !Bool
  }
  deriving stock (Eq, Show)

data ObservedFamily = ObservedFamily
  { config :: !FamilyConfig,
    githubRev :: !GitRevision,
    packages :: ![ObservedPackage]
  }
  deriving stock (Eq, Show)

data FamilyChange
  = GitHubRevisionChanged !FamilyName !GitRevision !GitRevision
  | PackageAdded !FamilyName !PackageName
  | PackageRemoved !FamilyName !PackageName
  | GitHubVersionChanged !FamilyName !PackageName !Version !Version
  | HackagePublished !FamilyName !PackageName !Version
  | HackageUnpublished !FamilyName !PackageName !Version
  | HackageVersionChanged !FamilyName !PackageName !Version !Version
  | HackageHashChanged !FamilyName !PackageName !SriHash !SriHash
  | HackageFallbackUsed !FamilyName !PackageName !Version
  deriving stock (Eq, Show)

data RefreshPlan = RefreshPlan
  { familyChanges :: ![FamilyChange],
    nextPackageLock :: !PackageLock
  }
  deriving stock (Eq, Show)

newtype UpdateError = UpdateError {message :: Text}
  deriving stock (Eq, Show)
