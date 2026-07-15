module HaskellNix.Update.Plan
  ( planRefresh,
    renderChanges,
  )
where

import Data.List (sort, sortOn)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Pretty (prettyShow)
import Distribution.Types.Version (Version)
import HaskellNix.Update.PackageLock (validatePackageLock)
import HaskellNix.Update.Types

planRefresh :: FamilyCatalog -> PackageLock -> [ObservedFamily] -> Either UpdateError RefreshPlan
planRefresh catalog previousLock observations = do
  rejectDuplicateObservations observations
  replacements <- traverse (buildReplacement previousByName) observations
  let replacementMap = Map.fromList [(name, pair) | pair@(LockedFamily {name}, _) <- replacements]
      unknownNames = Map.keysSet replacementMap `Set.difference` Map.keysSet configuredByName
  if Set.null unknownNames
    then pure ()
    else Left (UpdateError ("observed unknown families: " <> renderFamilyNames (Set.toAscList unknownNames)))
  let nextFamilies =
        sortOn familyKey
          ( [ maybe oldFamily fst (Map.lookup name replacementMap)
              | oldFamily@LockedFamily {name} <- previousFamilies
            ]
              <> [ family
                   | (name, (family, _)) <- Map.toAscList replacementMap,
                     name `Map.notMember` previousByName
                 ]
          )
  let nextPackageLock = PackageLock {schemaVersion = 1, families = nextFamilies}
      familyChanges = concatMap snd replacements
  _ <- firstUpdateError (validatePackageLock catalog nextPackageLock)
  pure RefreshPlan {familyChanges, nextPackageLock}
  where
    FamilyCatalog _ configuredFamilies = catalog
    PackageLock _ previousFamilies = previousLock
    configuredByName = Map.fromList [(name, family) | family@FamilyConfig {name} <- configuredFamilies]
    previousByName = Map.fromList [(name, family) | family@LockedFamily {name} <- previousFamilies]
    familyKey LockedFamily {name} = name

buildReplacement :: Map FamilyName LockedFamily -> ObservedFamily -> Either UpdateError (LockedFamily, [FamilyChange])
buildReplacement previousByName ObservedFamily {config, githubRev, packages = observedPackages} = do
  let FamilyConfig {name = familyName, githubInput, packageOverrides} = config
      packageNames = [name | ObservedPackage {discovered = DiscoveredPackage {name}} <- observedPackages]
  if Set.size (Set.fromList packageNames) == length packageNames
    then pure ()
    else Left (UpdateError ("family " <> familyNameText familyName <> " discovered duplicate package names"))
  let lockedPackages = sortOn packageKey (map (lockPackage packageOverrides) observedPackages)
      nextFamily = LockedFamily {name = familyName, githubInput, githubRev, packages = lockedPackages}
      changes =
        maybe
          (concatMap (newPackageChanges familyName) observedPackages)
          (compareFamily familyName githubRev observedPackages)
          (Map.lookup familyName previousByName)
  pure (nextFamily, changes)
  where
    packageKey LockedPackage {name} = name

lockPackage :: Map PackageName PackageOverride -> ObservedPackage -> LockedPackage
lockPackage overrides ObservedPackage {discovered = DiscoveredPackage {name, path, version}, hackage} =
  LockedPackage
    { name,
      path,
      version,
      cabal2nixOptions = maybe "" overrideOptions (Map.lookup name overrides),
      hackage
    }
  where
    overrideOptions PackageOverride {cabal2nixOptions} = cabal2nixOptions

compareFamily :: FamilyName -> GitRevision -> [ObservedPackage] -> LockedFamily -> [FamilyChange]
compareFamily familyName nextRevision observedPackages LockedFamily {githubRev = previousRevision, packages = previousPackages} =
  revisionChanges <> packageChanges <> removedChanges
  where
    previousByName = Map.fromList [(name, package) | package@LockedPackage {name} <- previousPackages]
    nextNames = Set.fromList [name | ObservedPackage {discovered = DiscoveredPackage {name}} <- observedPackages]
    revisionChanges =
      [GitHubRevisionChanged familyName previousRevision nextRevision | previousRevision /= nextRevision]
    packageChanges = concatMap compareObserved observedPackages
    compareObserved observed@ObservedPackage {discovered = DiscoveredPackage {name}} =
      case Map.lookup name previousByName of
        Nothing -> newPackageChanges familyName observed
        Just previousPackage -> comparePackage familyName observed previousPackage
    removedChanges =
      [ PackageRemoved familyName name
        | LockedPackage {name} <- previousPackages,
          name `Set.notMember` nextNames
      ]

newPackageChanges :: FamilyName -> ObservedPackage -> [FamilyChange]
newPackageChanges familyName ObservedPackage {discovered = DiscoveredPackage {name}, hackage, usedHackageFallback} =
  PackageAdded familyName name : fallbackChange familyName name hackage usedHackageFallback

comparePackage :: FamilyName -> ObservedPackage -> LockedPackage -> [FamilyChange]
comparePackage
  familyName
  ObservedPackage
    { discovered = DiscoveredPackage {name, version = nextVersion},
      hackage = nextHackage,
      usedHackageFallback
    }
  LockedPackage {version = previousVersion, hackage = previousHackage} =
    githubChanges
      <> hackageChanges familyName name previousHackage nextHackage
      <> fallbackChange familyName name nextHackage usedHackageFallback
    where
      githubChanges =
        [GitHubVersionChanged familyName name previousVersion nextVersion | previousVersion /= nextVersion]

hackageChanges :: FamilyName -> PackageName -> Maybe HackagePin -> Maybe HackagePin -> [FamilyChange]
hackageChanges familyName packageName previousPin nextPin =
  case (previousPin, nextPin) of
    (Nothing, Nothing) -> []
    (Nothing, Just HackagePin {version}) -> [HackagePublished familyName packageName version]
    (Just HackagePin {version}, Nothing) -> [HackageUnpublished familyName packageName version]
    (Just HackagePin {version = previousVersion, hash = previousHash}, Just HackagePin {version = nextVersion, hash = nextHash}) ->
      [HackageVersionChanged familyName packageName previousVersion nextVersion | previousVersion /= nextVersion]
        <> [HackageHashChanged familyName packageName previousHash nextHash | previousHash /= nextHash]

fallbackChange :: FamilyName -> PackageName -> Maybe HackagePin -> Bool -> [FamilyChange]
fallbackChange familyName packageName hackagePin usedFallback =
  case (usedFallback, hackagePin) of
    (True, Just HackagePin {version}) -> [HackageFallbackUsed familyName packageName version]
    _ -> []

renderChanges :: [FamilyChange] -> Text
renderChanges [] = "No changes."
renderChanges changes = Text.unlines (map (("- " <>) . renderChange) changes)

renderChange :: FamilyChange -> Text
renderChange = \case
  GitHubRevisionChanged familyName previous next ->
    familyNameText familyName <> ": GitHub revision " <> revisionText previous <> " -> " <> revisionText next
  PackageAdded familyName packageName -> familyPackage familyName packageName <> ": added"
  PackageRemoved familyName packageName -> familyPackage familyName packageName <> ": removed"
  GitHubVersionChanged familyName packageName previous next ->
    familyPackage familyName packageName <> ": GitHub version " <> versionText previous <> " -> " <> versionText next
  HackagePublished familyName packageName version ->
    familyPackage familyName packageName <> ": published on Hackage at " <> versionText version
  HackageUnpublished familyName packageName version ->
    familyPackage familyName packageName <> ": no longer published on Hackage (was " <> versionText version <> ")"
  HackageVersionChanged familyName packageName previous next ->
    familyPackage familyName packageName <> ": Hackage version " <> versionText previous <> " -> " <> versionText next
  HackageHashChanged familyName packageName previous next ->
    familyPackage familyName packageName <> ": Hackage hash " <> hashText previous <> " -> " <> hashText next
  HackageFallbackUsed familyName packageName version ->
    familyPackage familyName packageName <> ": Hackage has no normal release; using " <> versionText version

rejectDuplicateObservations :: [ObservedFamily] -> Either UpdateError ()
rejectDuplicateObservations observations =
  let names = [name | ObservedFamily {config = FamilyConfig {name}} <- observations]
   in if sort names == Set.toAscList (Set.fromList names)
        then Right ()
        else Left (UpdateError "observed family names must be unique")

familyPackage :: FamilyName -> PackageName -> Text
familyPackage familyName packageName = familyNameText familyName <> "/" <> packageNameText packageName

familyNameText :: FamilyName -> Text
familyNameText (FamilyName name) = name

packageNameText :: PackageName -> Text
packageNameText (PackageName name) = name

revisionText :: GitRevision -> Text
revisionText (GitRevision revision) = revision

hashText :: SriHash -> Text
hashText (SriHash hash) = hash

versionText :: Version -> Text
versionText = Text.pack . prettyShow

renderFamilyNames :: [FamilyName] -> Text
renderFamilyNames = Text.intercalate ", " . map familyNameText

firstUpdateError :: Either Text value -> Either UpdateError value
firstUpdateError = either (Left . UpdateError) Right
