{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Report (Report (..), cohortReport, renderReport, reportFailed) where

import Data.List (nub, sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Maybe (mapMaybe)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Pretty (prettyShow)
import Distribution.Version (Version, withinRange)
import HaskellNix.Update.Cohort.Model
import HaskellNix.Update.Cohort.Types

data Report = Report
    { packages :: !Int
    , downgrades :: ![Text]
    , targets :: ![Text]
    , firstPartyAgreement :: ![Text]
    , caps :: ![Text]
    , upgrades :: ![Text]
    , nixUpgrades :: ![Text]
    , sourcePins :: ![Text]
    , excluded :: ![Text]
    , boot :: ![Text]
    }
    deriving stock (Eq, Show)

cohortReport :: Map Text Version -> [Inventory] -> NixInventory -> Map Text Text -> [PolicyFloor] -> Either Text Report
cohortReport frozen inventories nix firstParty policy = do
    floors <- floorVersions inventories nix firstParty policy
    capped <- traverse classifyBound [(inv, b) | inv <- inventories, b <- inv.bounds, not (b.package `Set.member` excludedNames)]
    let violations =
            [ name <> " " <> selected name <> " < floor " <> display entry.version <> " from " <> Text.intercalate ", " entry.sources
            | (name, entry) <- Map.toAscList floors
            , maybe True (< entry.version) (Map.lookup name frozen)
            , not (Set.member name own)
            ]
        targetLines = [p.package <> " " <> selected p.package <> " (target >=" <> p.floor <> ": " <> p.reason <> ")" | p <- policy]
    agreement <- traverse firstPartyLine (Map.toAscList firstParty)
    upgrades <- fmap concat $ traverse inventoryUpgrades inventories
    nixChanges <- traverse nixUpgrade [(name, v) | (name, Just v) <- Map.toAscList nix.channel, v /= "<error>"]
    pure
        ( Report
            (Map.size frozen)
            (sorted violations)
            (sorted targetLines)
            agreement
            (sorted (mapMaybe id capped))
            (sorted upgrades)
            (sorted (mapMaybe id nixChanges))
            ( sorted
                [ inv.contributor.mori <> " " <> name <> " " <> p.version <> " -> " <> selected name <> if name `elem` ["streamly", "streamly-core"] && inv.contributor.name == "mina" then " (retired by plan 13)" else ""
                | inv <- inventories
                , (name, p) <- Map.toList inv.packages
                , p.source == SourcePin
                ]
            )
            (sorted [inv.contributor.mori <> " " <> exclusion.package <> ": " <> exclusion.reason | inv <- inventories, exclusion <- inv.contributor.excludedDependencies])
            (sorted [name <> " " <> p.version | inv <- inventories, (name, p) <- Map.toList inv.packages, p.source == Boot])
        )
  where
    display = Text.pack . prettyShow
    selected name = maybe "(not frozen)" display (Map.lookup name frozen)
    sorted = sort . nub
    own = Set.fromList (concatMap (\i -> i.contributor.ownPackages) inventories)
    excludedNames = own <> Set.fromList [e.package | i <- inventories, e <- i.contributor.excludedDependencies]
    classifyBound (inv, bound) = do
        range <- parseRange bound.range
        pure $ case Map.lookup bound.package frozen of
            Just version | not (withinRange version range) -> Just (bound.package <> " " <> display version <> ": " <> inv.contributor.mori <> " " <> Text.pack bound.file <> " [" <> bound.component <> "; " <> bound.condition <> "] " <> bound.range)
            _ -> Nothing
    firstPartyLine (name, recorded) = do
        version <- parseVersion recorded
        pure
            ( name <> " snapshot=" <> recorded <> " frozen=" <> selected name <> case Map.lookup name frozen of
                Nothing -> " (not used by the cohort)"
                Just actual
                    | actual > version -> " (first-party lag)"
                    | actual < version -> " (snapshot above freeze)"
                    | otherwise -> " (equal)"
            )
    inventoryUpgrades inv = do
        comparisons <-
            traverse
                ( \(name, p) -> do
                    old <- parseVersion p.version
                    pure $ case Map.lookup name frozen of
                        Just new | new > old && p.source == Hackage -> Just (inv.contributor.mori <> " " <> name <> " " <> p.version <> " -> " <> display new)
                        _ -> Nothing
                )
                (Map.toAscList inv.packages)
        pure (mapMaybe id comparisons)
    nixUpgrade (name, raw) = do
        old <- parseVersion raw
        pure $ case Map.lookup name frozen of
            Just new | new > old -> Just (name <> " " <> raw <> " -> " <> display new)
            _ -> Nothing

reportFailed :: Report -> Bool
reportFailed report = not (null report.downgrades)

renderReport :: Report -> Text
renderReport report =
    Text.unlines
        ( section "DOWNGRADES" report.downgrades
            <> section "TARGETS" report.targets
            <> section "FIRST-PARTY AGREEMENT" report.firstPartyAgreement
            <> section "CAPS" report.caps
            <> section "UPGRADES PER APPLICATION" report.upgrades
            <> section "NIX UPGRADES" report.nixUpgrades
            <> section "SOURCE PINS" report.sourcePins
            <> section "EXCLUDED" report.excluded
            <> section "BOOT PACKAGES" report.boot
            <> [ "packages: "
                    <> count report.packages
                    <> "  downgrades: "
                    <> count (length report.downgrades)
                    <> "  caps: "
                    <> count (length report.caps)
                    <> "  source pins: "
                    <> count (length report.sourcePins)
               ]
        )
  where
    count = Text.pack . show
    section name entries = [name] <> (if null entries then ["(none)"] else entries) <> [""]
