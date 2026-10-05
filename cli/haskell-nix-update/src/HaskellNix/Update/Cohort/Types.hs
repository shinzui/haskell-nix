{- | Recorded solver inputs. Versions and ranges use Cabal's textual syntax in
JSON; readers validate them with Cabal before accepting a record.
-}
module HaskellNix.Update.Cohort.Types (
    Contributor (..),
    Exclusion (..),
    Configuration (..),
    PackageSource (..),
    PlanPackage (..),
    DeclaredBound (..),
    Inventory (..),
    NixInventory (..),
) where

import Data.Aeson (FromJSON, ToJSON, Value)
import Data.Map.Strict (Map)
import Data.Text (Text)
import GHC.Generics (Generic)

data Exclusion = Exclusion {package :: !Text, reason :: !Text}
    deriving stock (Eq, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

data Configuration = Configuration {name :: !Text, flags :: !(Map Text Text)}
    deriving stock (Eq, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

data Contributor = Contributor
    { name :: !Text
    , mori :: !Text
    , revision :: !Text
    , role :: !Text
    , ownPackages :: ![Text]
    , excludedDependencies :: ![Exclusion]
    , cabalFiles :: ![FilePath]
    , indexStateOverride :: !(Maybe Text)
    , deployedAttr :: !(Maybe Text)
    , configurations :: ![Configuration]
    }
    deriving stock (Eq, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

data PackageSource = Hackage | SourcePin | Boot
    deriving stock (Eq, Ord, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

data PlanPackage = PlanPackage
    { version :: !Text
    , source :: !PackageSource
    , identities :: ![Value]
    , dependencies :: ![Text]
    }
    deriving stock (Eq, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

data DeclaredBound = DeclaredBound
    { package :: !Text
    , range :: !Text
    , file :: !FilePath
    , component :: !Text
    , condition :: !Text
    , tool :: !(Maybe Text)
    }
    deriving stock (Eq, Ord, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

data Inventory = Inventory
    { contributor :: !Contributor
    , configuration :: !Text
    , indexState :: !(Maybe Text)
    , packages :: !(Map Text PlanPackage)
    , bounds :: ![DeclaredBound]
    , project :: !Text
    }
    deriving stock (Eq, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

data NixInventory = NixInventory
    { channelRevision :: !Text
    , dotfilesRevision :: !Text
    , system :: !Text
    , channel :: !(Map Text (Maybe Text))
    , deployed :: !(Map Text (Map Text Text))
    }
    deriving stock (Eq, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)
