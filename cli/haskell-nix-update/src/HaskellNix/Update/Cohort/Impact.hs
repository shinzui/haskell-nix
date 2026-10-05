{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Impact (retainedConstraints, impactReport) where

import Data.Aeson (Value (..))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.List (nub, sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Pretty (prettyShow)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Types

-- Only explicitly requested names are unlocked. A retained runtime projection
-- remains exact unless the caller explicitly requests a runtime update.
retainedConstraints :: Map Text Version -> Map Text Version -> Bool -> [Text] -> Either Text Text
retainedConstraints previous runtime updateRuntime requested
    | null requested = Left "a targeted update requires at least one package"
    | not (null unknown) = Left ("requested packages are not frozen: " <> Text.intercalate ", " unknown)
    | not (null inconsistentRuntime) = Left ("runtime projection differs from the recorded cohort: " <> Text.intercalate ", " inconsistentRuntime)
    | not updateRuntime && not (null runtimeRequests) = Left ("explicit runtime update required: " <> Text.intercalate ", " runtimeRequests)
    | otherwise = Right (Text.unlines ("constraints:" : zipWith render ("  " : repeat "  , ") (Map.toAscList retained)))
  where
    names = Set.fromList requested
    unknown = Set.toAscList (names Set.\\ Map.keysSet previous)
    runtimeRequests = Set.toAscList (names `Set.intersection` Map.keysSet runtime)
    inconsistentRuntime = [name | (name, version) <- Map.toAscList runtime, Map.lookup name previous /= Just version]
    retained = Map.union (if updateRuntime then Map.withoutKeys runtime names else runtime) (Map.withoutKeys previous names)
    render prefix (name, version) = prefix <> "any." <> name <> " ==" <> Text.pack (prettyShow version)

-- Metadata and flag-only changes are real changes even when versions match.
-- Compare identity values as sets so plan unit ordering cannot create churn.
impactReport :: Map Text PlanPackage -> Map Text PlanPackage -> Map Text Value -> Map Text Value -> [Inventory] -> Text
impactReport before after previousPolicy nextPolicy inventories = Text.unlines (concatMap describe changed)
  where
    names = Set.toAscList (Map.keysSet before <> Map.keysSet after <> Map.keysSet previousPolicy <> Map.keysSet nextPolicy)
    changed = [(name, categories name) | name <- names, not (null (categories name))]
    categories name = case (Map.lookup name before, Map.lookup name after) of
        (Nothing, Just _) -> ["added"] <> policyChanges name
        (Just _, Nothing) -> ["removed"] <> policyChanges name
        (Just old, Just new) ->
            ["version" | old.version /= new.version]
                <> ["source" | old.source /= new.source || different ["pkg-src", "pkg-src-sha256"] old new]
                <> ["cabal-metadata" | different ["pkg-cabal-sha256"] old new]
                <> ["flags" | different ["flags"] old new]
                <> ["dependencies" | old.dependencies /= new.dependencies]
                <> policyChanges name
        _ -> policyChanges name
    policyChanges name = ["policy" | Map.lookup name previousPolicy /= Map.lookup name nextPolicy]
    different keys old new = not (sameValues (project keys old) (project keys new))
    project keys package = nub [Object (KeyMap.filterWithKey (\key _ -> key `elem` keys) fields) | Object fields <- package.identities]
    sameValues xs ys = length xs == length ys && all (`elem` ys) xs
    describe (name, changes) =
        [name <> ": " <> Text.intercalate ", " changes]
            <> sort
                ( nub
                    [ "  " <> inv.contributor.mori <> " [" <> inv.contributor.role <> "] " <> Text.pack bound.file <> " [" <> bound.component <> "] -> " <> Text.intercalate " -> " path
                    | inv <- inventories
                    , bound <- inv.bounds
                    , Just path <- [dependencyPath inv.packages bound.package name]
                    ]
                )

-- Breadth-first search returns a deterministic shortest reverse-impact path
-- from an application component's direct dependency to the changed package.
dependencyPath :: Map Text PlanPackage -> Text -> Text -> Maybe [Text]
dependencyPath packages root target = search Set.empty [[root]]
  where
    search _ [] = Nothing
    search visited (path : rest)
        | last path == target = Just path
        | last path `Set.member` visited = search visited rest
        | otherwise = search (Set.insert (last path) visited) (rest <> [path <> [name] | name <- sort (maybe [] (\p -> p.dependencies) (Map.lookup (last path) packages)), name `notElem` path])
