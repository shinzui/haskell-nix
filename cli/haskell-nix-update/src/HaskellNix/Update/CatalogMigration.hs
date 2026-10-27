module HaskellNix.Update.CatalogMigration
  ( prepareCatalogAddition,
    planCatalogAddition,
    renderCatalogAddition,
  )
where

import Control.Monad (unless)
import Data.List (sort, sortOn)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import HaskellNix.Update.Catalog (validateFamilyCatalog)
import HaskellNix.Update.PackageLock (validatePackageSetLock)
import HaskellNix.Update.Plan (snapshotFromObservation)
import HaskellNix.Update.Types

-- A request is additions only, not a replacement catalog. Existing identical
-- definitions are accepted for replay without observing their moving upstreams.
prepareCatalogAddition :: FamilyCatalog -> FamilyCatalog -> Either UpdateError (FamilyCatalog, [FamilyConfig])
prepareCatalogAddition current@FamilyCatalog {schemaVersion, families, updateGroups} request = do
  _ <- fromText (validateFamilyCatalog current)
  _ <- fromText (validateFamilyCatalog request)
  unless (schemaVersion == 2 && catalogSchema request == 2) $
    Left (UpdateError "catalog add requires schemaVersion 2")
  unless (null (explicitGroups request)) $
    Left (UpdateError "catalog add accepts singleton additions only; updateGroups must be empty")
  let old = Map.fromList [(name, config) | config@FamilyConfig {name} <- families]
  added <- fmap concat $ traverse (newFamily old) (configuredFamilies request)
  merged <- fromText (validateFamilyCatalog (FamilyCatalog 2 (sortOn familyKey (families <> added)) updateGroups))
  pure (merged, added)
  where
    newFamily old candidate@FamilyConfig {name} = case Map.lookup name old of
      Nothing -> Right [candidate]
      Just previous
        | previous == candidate -> Right []
        | otherwise -> Left (UpdateError "catalog add cannot change an existing family identity or discovery policy")
    familyKey FamilyConfig {name} = name
    catalogSchema FamilyCatalog {schemaVersion = value} = value
    explicitGroups FamilyCatalog {updateGroups = value} = value
    configuredFamilies FamilyCatalog {families = value} = value

planCatalogAddition :: FamilyCatalog -> PackageSetLock -> FamilyCatalog -> [SnapshotObservation] -> Either UpdateError (FamilyCatalog, PackageSetLock)
planCatalogAddition current previous@PackageSetLock {familySnapshots, groupSnapshots, packageSets} request observations = do
  _ <- fromText (validatePackageSetLock current previous)
  (merged, added) <- prepareCatalogAddition current request
  let expected = [name | FamilyConfig {name} <- added]
      actual = [name | SnapshotObservation {config = FamilyConfig {name}} <- observations]
  unless (sort actual == expected) $
    Left (UpdateError "catalog add observations must cover exactly the new families once")
  unless (all (\SnapshotObservation {config} -> config `elem` added) observations) $
    Left (UpdateError "catalog add observed policy differs from the request")
  snapshots <- traverse snapshotFromObservation observations
  let newSelections = [GroupSelection (groupName family) (SnapshotGeneration 1) | family <- expected]
      newGroups =
        [ GroupSnapshot (groupName family) (SnapshotGeneration 1) [FamilySnapshotSelection family (SnapshotGeneration 1)] "default"
        | family <- expected
        ]
      extendSet set@PackageSet {groups} = set {groups = sortOn selectionKey (groups <> newSelections)}
      next =
        previous
          { familySnapshots = sortOn snapshotKey (familySnapshots <> snapshots),
            groupSnapshots = sortOn groupKey (groupSnapshots <> newGroups),
            packageSets = map extendSet packageSets
          }
  validated <- fromText (validatePackageSetLock merged next)
  pure (merged, validated)
  where
    groupName (FamilyName name) = UpdateGroupName name
    selectionKey GroupSelection {group} = group
    snapshotKey FamilySnapshot {family, generation} = (family, generation)
    groupKey GroupSnapshot {group, generation} = (group, generation)

renderCatalogAddition :: [FamilyConfig] -> PackageSetLock -> Text
renderCatalogAddition [] _ = "No catalog changes."
renderCatalogAddition added PackageSetLock {packageSets} =
  Text.unlines
    ( ("Add singleton families/groups: " <> Text.intercalate ", " names)
        : ["Package set " <> name <> ": " <> Text.intercalate ", " [family <> "=1" | family <- names] | PackageSet {name} <- packageSets]
    )
  where
    names = [name | FamilyConfig {name = FamilyName name} <- added]

fromText :: Either Text value -> Either UpdateError value
fromText = either (Left . UpdateError) Right
