module HaskellNix.Update.Types
  ( FamilyName (..),
    PackageName (..),
    GitRevision (..),
    SriHash (..),
    PackageOverride (..),
    FamilyConfig (..),
    FamilyCatalog (..),
    HackagePin (..),
    LockedPackage (..),
    LockedFamily (..),
    PackageLock (..),
  )
where

import Data.Map.Strict (Map)
import Data.Text (Text)
import Distribution.Types.Version (Version)

newtype FamilyName = FamilyName Text
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
    packageOverrides :: !(Map PackageName PackageOverride)
  }
  deriving stock (Eq, Show)

data FamilyCatalog = FamilyCatalog
  { schemaVersion :: !Int,
    families :: ![FamilyConfig]
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
