{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Model (
    PolicyFloor (..),
    Floor (..),
    Cap (..),
    parseVersion,
    parseRange,
    floorVersions,
    stubBounds,
    renderStubCabal,
    renderFloors,
) where

import Data.Aeson (FromJSON, ToJSON, Value (..))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (nub, sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Pretty (prettyShow)
import Distribution.Version
import GHC.Generics (Generic)
import HaskellNix.Update.Cohort.Types

data PolicyFloor = PolicyFloor {package :: !Text, floor :: !Text, reason :: !Text}
    deriving stock (Eq, Show, Generic)
    deriving anyclass (FromJSON, ToJSON)

data Floor = Floor {version :: !Version, sources :: ![Text]}
    deriving stock (Eq, Show)

data Cap = Cap {bound :: !DeclaredBound, contributor :: !Text, needed :: !Version}
    deriving stock (Eq, Show)

parseVersion :: Text -> Either Text Version
parseVersion value = maybe (Left ("invalid version: " <> value)) Right (simpleParsec (Text.unpack value))

parseRange :: Text -> Either Text VersionRange
parseRange value = maybe (Left ("invalid range: " <> value)) Right (simpleParsec (Text.unpack value))

floorVersions :: [Inventory] -> NixInventory -> Map Text Text -> [PolicyFloor] -> Either Text (Map Text Floor)
floorVersions inventories nix firstParty policy = do
    entries <- traverse parseEntry (observations <> policyEntries <> firstPartyEntries)
    if any (\p -> Set.member p.package excluded) policy
        then Left "a policy floor cannot target an owned or explicitly excluded dependency"
        else pure (Map.withoutKeys (Map.fromListWith merge entries) excluded)
  where
    excluded = Set.fromList (concatMap (\inventory -> inventory.contributor.ownPackages <> map (\e -> e.package) inventory.contributor.excludedDependencies) inventories)
    hackageVersions = Set.fromList [(name, p.version) | inventory <- inventories, (name, p) <- Map.toList inventory.packages, p.source == Hackage]
    used = Set.fromList [name | inventory <- inventories, (name, p) <- Map.toList inventory.packages, p.source /= Boot]
    observations =
        [ (name, p.version, inventory.contributor.name <> " (cabal " <> inventory.configuration <> ")")
        | inventory <- inventories
        , (name, p) <- Map.toList inventory.packages
        , p.source == Hackage || (p.source == SourcePin && Set.member (name, p.version) hackageVersions)
        ]
            <> [(name, v, "channel") | (name, Just v) <- Map.toList nix.channel, Set.member name used, v /= "<error>"]
            <> [(name, v, application <> " (deployed)") | (application, packages) <- Map.toList nix.deployed, (name, v) <- Map.toList packages, Set.member name used]
    policyEntries = [(p.package, p.floor, "policy: " <> p.reason) | p <- policy]
    firstPartyEntries = [(name, v, "first-party default") | (name, v) <- Map.toList firstParty, Set.member name used]
    parseEntry (name, v, origin) = do
        parsed <- parseVersion v
        pure (name, Floor parsed [origin])
    merge a b = case compare a.version b.version of
        GT -> a
        LT -> b
        EQ -> Floor a.version (sort (nub (a.sources <> b.sources)))

stubBounds :: Map Text Floor -> [Inventory] -> Either Text (Map (Text, Maybe Text) VersionRange, [Cap])
stubBounds floors inventories = do
    selected <- traverse classify entries
    pure (Map.fromListWith intersectVersionRanges (retainedLibraries <> [(key, if cap == Nothing then range else anyVersion) | (key, range, cap) <- selected]), [cap | (_, _, Just cap) <- selected])
  where
    excluded = Set.fromList (concatMap (\inventory -> inventory.contributor.ownPackages <> map (\e -> e.package) inventory.contributor.excludedDependencies) inventories)
    -- Pre-existing non-boot records are registered libraries, including older
    -- transitive libraries whose parents now select a different implementation.
    -- Keep their observed floors represented instead of silently dropping them.
    installedLibraries = Set.fromList [name | inventory <- inventories, (name, package) <- Map.toList inventory.packages, package.source == Hackage, any installed package.identities]
    installed (Object fields) = KeyMap.lookup "type" fields == Just (String "pre-existing")
    installed _ = False
    retainedLibraries = [((name, Nothing), orLaterVersion entry.version) | (name, entry) <- Map.toList floors, Set.member name installedLibraries, not (Set.member name excluded)]
    entries = [(inventory.contributor.mori, bound) | inventory <- inventories, bound <- inventory.bounds, not (Set.member bound.package excluded)]
    classify (owner, bound) = do
        range <- parseRange bound.range
        case Map.lookup bound.package floors of
            Just floorEntry | not (withinRange floorEntry.version range) -> pure ((bound.package, bound.tool), range, Just (Cap bound owner floorEntry.version))
            _ -> pure ((bound.package, bound.tool), range, Nothing)

renderStubCabal :: Map (Text, Maybe Text) VersionRange -> Text
renderStubCabal bounds =
    Text.unlines
        ( ["cabal-version: 3.4", "-- Generated by haskell-nix-update cohort stub. Do not edit.", "name: rei-family-cohort", "version: 0", "build-type: Simple", "library"]
            <> field "build-depends" [name <> " " <> display range | ((name, Nothing), range) <- Map.toAscList bounds]
            <> field "build-tool-depends" [name <> ":" <> tool <> " " <> display range | ((name, Just tool), range) <- Map.toAscList bounds]
        )
  where
    display = Text.pack . prettyShow . simplifyVersionRange
    field _ [] = []
    field name entries = ("  " <> name <> ":") : zipWith (\prefix entry -> prefix <> entry) ("    " : repeat "    , ") entries

renderFloors :: Map Text Floor -> Text
renderFloors floors =
    Text.unlines
        ( "-- Generated by haskell-nix-update cohort stub. Do not edit."
            : "constraints:"
            : zipWith (\prefix (name, floorEntry) -> prefix <> "any." <> name <> " >=" <> Text.pack (prettyShow floorEntry.version)) ("  " : repeat "  , ") (Map.toAscList floors)
        )
