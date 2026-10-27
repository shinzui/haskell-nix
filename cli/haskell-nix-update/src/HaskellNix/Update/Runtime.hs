{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Runtime (
    module HaskellNix.Update.Runtime.Types,
    RuntimeCommand (..),
    runtimeParser,
    runRuntime,
    renderRuntimeConfiguration,
    renderRuntimeSources,
    renderRuntimeFamilyIdentity,
    publishRuntimeFiles,
) where

import Control.Exception (IOException, onException, try)
import Control.Monad (forM, forM_, unless, when)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT (..), runExceptT)
import Data.Aeson
import Data.Aeson.Encode.Pretty (Config (..), defConfig, encodePretty')
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.List (find, nub, sort)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding (decodeUtf8, encodeUtf8)
import HaskellNix.Update.Catalog (decodeFamilyCatalog)
import HaskellNix.Update.Cohort.Freeze hiding (command)
import HaskellNix.Update.Cohort.Generate (classifyCohort)
import HaskellNix.Update.Cohort.GenerateIO (decodeGenerationPolicy)
import HaskellNix.Update.Cohort.GenerationTypes (GenerationContext (..))
import HaskellNix.Update.Cohort.Impact (validateRetainedIdentities)
import HaskellNix.Update.Cohort.Inventory (decodePlanVersions, projectFields)
import HaskellNix.Update.Cohort.Model qualified as CohortModel
import HaskellNix.Update.Cohort.Render (canonicalJSON, canonicalPackage)
import HaskellNix.Update.Cohort.Types (PackageSource (..), PlanPackage (..))
import HaskellNix.Update.Nix (decodeChannelRevision, decodeLockedSource, managedFilesDirty)
import HaskellNix.Update.PackageLock (decodePackageSetLock)
import HaskellNix.Update.Process
import HaskellNix.Update.Runtime.Types
import HaskellNix.Update.Types qualified as FP
import Options.Applicative (Parser, helper, info, long, metavar, progDesc, strOption, subparser, switch, (<**>))
import Options.Applicative qualified as Options
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory, makeAbsolute, pathIsSymbolicLink, removeFile, renameFile)
import System.FilePath (takeDirectory, (</>))
import System.IO (hClose)
import System.IO.Temp (withSystemTempDirectory, withTempFile)

data RuntimeCommand
    = RuntimeSnapshot !Text !FilePath !Bool
    | RuntimeCheck !Text
    | RuntimeDescribe !Text !Bool
    deriving stock (Eq, Show)

runtimeParser :: Parser RuntimeCommand
runtimeParser =
    subparser
        ( Options.command "snapshot" (info (RuntimeSnapshot <$> named <*> strOption (long "cohort-freeze" <> Options.value "cabal/cohort.freeze" <> metavar "FILE") <*> switch (long "dry-run") <**> helper) (progDesc "Stage and append an immutable runtime generation"))
            <> Options.command "check" (info (RuntimeCheck <$> named <**> helper) (progDesc "Validate retained runtime records and every projection without writes"))
            <> Options.command "describe" (info (RuntimeDescribe <$> named <*> switch (long "json") <**> helper) (progDesc "Describe retained runtime membership and support"))
        )
  where
    named = Text.pack <$> strOption (long "name" <> metavar "RUNTIME")

runRuntime :: RuntimeCommand -> IO (Either FP.UpdateError Text)
runRuntime selected = do
    result <- try (runExceptT (run selected))
    pure $ case result of
        Left (exception :: IOException) -> Left (FP.UpdateError (Text.pack (show exception)))
        Right value -> value
  where
    run command = do
        config <- readFileE "config/runtime-package-sets.json" >>= textResult . decodeRuntimeConfig
        catalog <- readFileE "config/first-party-families.json" >>= textResult . decodeFamilyCatalog
        firstParty <- readFileE "packages/first-party-lock.json" >>= textResult . decodePackageSetLock catalog
        lock <- readFileE runtimeLockPath >>= textResult . decodeRuntimeLock config firstParty
        let name = case command of RuntimeSnapshot n _ _ -> n; RuntimeCheck n -> n; RuntimeDescribe n _ -> n
        definition <- maybe (failure ("unknown runtime: " <> name)) pure (Map.lookup name config.runtimes)
        let records = Map.findWithDefault [] name lock.runtimes
        forM_ (concat (Map.elems lock.runtimes)) checkRecord
        case command of
            RuntimeCheck _ -> pure ("Runtime " <> name <> ": " <> Text.pack (show (length records)) <> " retained generations validated")
            RuntimeDescribe _ json ->
                pure $
                    if json
                        then decodeUtf8 (LBS.toStrict (prettyJSON (object ["name" .= name, "definition" .= definition, "generations" .= records])))
                        else "Runtime " <> name <> ": generations " <> Text.intercalate ", " (map (Text.pack . show . (.generation)) records)
            RuntimeSnapshot _ freeze dryRun -> snapshot config firstParty lock name definition freeze dryRun

runtimeLockPath :: FilePath
runtimeLockPath = "packages/runtime-lock.json"

type RuntimeIO = ExceptT FP.UpdateError IO

snapshot :: RuntimeConfig -> FP.PackageSetLock -> RuntimeLock -> Text -> RuntimeDefinition -> FilePath -> Bool -> RuntimeIO Text
snapshot config firstParty lock name definition freezePath dryRun = do
    inputs <- captureInputs
    originalLock <- readFileE runtimeLockPath
    channelRevision <- Text.strip <$> runCommand "git" ["rev-parse", "HEAD"]
    freezeBytes <- readFileE freezePath
    document <- textResult (parseFreezeDocument (decodeUtf8 freezeBytes))
    sources <- readJSON (takeDirectory freezePath </> "cohort-sources.json")
    closure <- textResult (runtimeClosure (Map.keys definition.roots) sources)
    let owned = Map.map canonicalPackage closure
    let records = Map.findWithDefault [] name lock.runtimes
    defaultSet <- maybe (failure "missing default first-party set") pure (find (\set -> set.name == firstParty.defaultPackageSet) firstParty.packageSets)
    let complete = Map.fromList [(group, value) | selection <- defaultSet.groups, let FP.UpdateGroupName group = selection.group, let FP.SnapshotGeneration value = selection.generation]
        selected = Map.restrictKeys complete (Map.keysSet (Map.fromList [(group, ()) | group <- definition.groups]))
        configurations = [RuntimeConfiguration system "ghc9124" channel True True | system <- ["aarch64-darwin", "x86_64-linux"], channel <- ["github", "hackage"]]
    lockBytes <- readFileE "flake.lock"
    FP.GitRevision nixpkgs <- textResultError (decodeChannelRevision "nixpkgs" lockBytes)
    FP.GitRevision toolchain <- textResultError (decodeChannelRevision "haskell-nix-dev" lockBytes)
    validateCohort document sources firstParty complete "generated/ghc-boot-packages.nix" "config/cohort-policy.json"
    toolchainInputs <- resolvedToolchainInputs lockBytes
    generated :: Value <- decodeJSON =<< runCommand "nix" ["eval", "--json", "--file", "generated/cohort-versions.nix"]
    generatedSources :: Map Text PlanPackage <- jsonField "sourceManifest" generated
    generatedFreeze :: Text <- jsonField "freezeSha256" generated
    currentFreeze <- hashFiles (Map.singleton "freeze" freezePath)
    ensure (Map.lookup "freeze" currentFreeze == Just generatedFreeze && Map.map canonicalPackage generatedSources == Map.map canonicalPackage sources) "generated cohort is stale"
    ensure (Map.restrictKeys (Map.map canonicalPackage generatedSources) (Map.keysSet owned) == Map.map canonicalPackage owned) "generated cohort source context is stale"
    policyHashes <- hashFiles (Map.fromList [(path, path) | path <- Map.keys inputs, policyInput path])
    componentMap <- captureComponents definition firstParty owned
    let identityPayload = runtimeIdentity definition owned componentMap selected configurations firstParty policyHashes nixpkgs toolchain toolchainInputs
    identity <-
        lift
            ( withSystemTempDirectory "runtime-identity-" $ \temporary -> do
                let file = temporary </> "identity.json"
                BS.writeFile file (encodeUtf8 (canonicalJSON identityPayload))
                runExceptT (hashFiles (Map.singleton "identity" file))
            )
            >>= textResultError
    fingerprint <- maybe (failure "missing runtime fingerprint") pure (Map.lookup "identity" identity)
    case find (\record -> record.fingerprint == fingerprint) records of
        Just record -> pure ("Runtime " <> name <> " generation " <> tshow record.generation <> ": unchanged")
        Nothing -> do
            dirty <- textResultError =<< lift (managedFilesDirty streamingProcessRunner "." [runtimeLockPath, "cabal/runtimes/" <> Text.unpack name, "generated/runtimes/" <> Text.unpack name, "packages/runtimes/" <> Text.unpack name])
            ensure (not dirty) "runtime managed files are dirty; commit or restore them before appending a generation"
            let next = 1 + maximum (0 : map (.generation) records)
                cabalDirectory = "cabal/runtimes/" <> Text.unpack name <> "/" <> show next
                recipeDirectory = "packages/runtimes/" <> Text.unpack name <> "/" <> show next <> "/recipes"
                freezeFile = cabalDirectory </> "cohort.freeze"
                sourceFile = cabalDirectory </> "cohort-sources.json"
                versionFile = "generated/runtimes/" <> Text.unpack name <> "/" <> show next <> ".nix"
                policyFile = recipeDirectory </> "cabal/cohort-nix-policy.json"
                generationPaths = [cabalDirectory, takeDirectory recipeDirectory, versionFile]
            forM_ generationPaths $ \path -> do
                exists <- lift ((||) <$> doesFileExist path <*> doesDirectoryExist path)
                ensure (not exists) ("runtime generation path already exists: " <> Text.pack path)
            outcome <- lift $ withSystemTempDirectory "runtime-snapshot-" $ \temporary -> runExceptT $ do
                let runtimeFreeze = renderCohortFreeze (FreezeHeader document.freezeIndexState "ghc-9.12.4" channelRevision "haskell-nix-update runtime snapshot") (Map.restrictKeys document.freezeVersions (Map.keysSet owned))
                    metadata = object ["definition" .= definition, "selections" .= selected, "configurations" .= configurations, "nixpkgsRevision" .= nixpkgs, "toolchainRevision" .= toolchain, "indexState" .= document.freezeIndexState]
                    captured = Map.fromList [(recipeDirectory </> path, content) | (path, content) <- Map.toList inputs]
                    projections =
                        captured
                            <> Map.fromList
                                [(freezeFile, encodeUtf8 runtimeFreeze), (sourceFile, LBS.toStrict (prettyJSON owned)), (cabalDirectory </> "components.json", LBS.toStrict (prettyJSON componentMap)), (cabalDirectory </> "context.json", LBS.toStrict (prettyJSON metadata)), (cabalDirectory </> "identity.json", encodeUtf8 (canonicalJSON identityPayload))]
                forM_ (Map.toList projections) $ \(path, content) -> lift (writeBytes (temporary </> path) content)
                freezeHash <- hashFiles (Map.singleton freezeFile (temporary </> freezeFile))
                let versionProjection = renderVersionProjection name next (Map.keys owned) (freezeHash Map.! freezeFile)
                lift (writeBytes (temporary </> versionFile) (encodeUtf8 versionProjection))
                _ <- runCommand "nix" ["run", "--inputs-from", ".", "nixpkgs#nixpkgs-fmt", "--", temporary </> versionFile]
                let paths = Map.keys projections <> [versionFile]
                hashes <- hashFiles (Map.fromList [(path, temporary </> path) | path <- paths])
                fullFreeze <- maybe (failure "cohort freeze is not a captured input") pure (Map.lookup (recipeDirectory </> "cabal/cohort.freeze") hashes)
                let roles = runtimeRoles definition owned
                    record = RuntimeGeneration definition next document.freezeIndexState fullFreeze nixpkgs toolchain toolchainInputs selected configurations (Map.keys definition.roots) (Map.map canonicalPackage owned) roles componentMap hashes fingerprint recipeDirectory freezeFile sourceFile versionFile policyFile
                common <- readFileE "cabal/common.config"
                githubSources <- textResult (renderRuntimeSources "github" firstParty selected owned)
                hackageSources <- textResult (renderRuntimeSources "hackage" firstParty selected owned)
                let configuration = renderRuntimeConfiguration (Map.keys owned) (decodeUtf8 common) owned
                    projectFiles = [(cabalDirectory </> "github.project", "import: cohort.freeze\nimport: configuration.project\n" <> githubSources), (cabalDirectory </> "hackage.project", "import: cohort.freeze\nimport: configuration.project\n" <> hackageSources), (cabalDirectory </> "configuration.project", configuration)]
                forM_ projectFiles $ \(path, content) -> lift (writeBytes (temporary </> path) (encodeUtf8 content))
                profileFiles <- forM ["github", "hackage"] $ \channel -> do
                    profile <- captureSourceProfile temporary cabalDirectory channel definition owned firstParty selected document.freezeIndexState freezePath
                    let file = cabalDirectory </> Text.unpack channel <> "-sources.json"
                    lift (writeBytes (temporary </> file) (LBS.toStrict (prettyJSON profile)))
                    pure file
                projectHashes <- hashFiles (Map.fromList [(path, temporary </> path) | (path, _) <- projectFiles])
                profileHashes <- hashFiles (Map.fromList [(path, temporary </> path) | path <- profileFiles])
                let finalRecord = record{projections = hashes <> projectHashes <> profileHashes}
                    finalLock = RuntimeLock lock.schemaVersion (Map.insert name (records <> [finalRecord]) lock.runtimes)
                _ <- textResult (validateRuntimeLock config firstParty finalLock)
                after <- captureInputs
                ensure (after == inputs) "runtime inputs changed while staging; no managed files published"
                currentLock <- readFileE runtimeLockPath
                ensure (currentLock == originalLock) "runtime lock changed while staging; no managed files published"
                unless dryRun $ do
                    files <- forM (Map.keys finalRecord.projections) $ \path -> (path,) <$> readFileE (temporary </> path)
                    lift (publishRuntimeFiles (Map.insert runtimeLockPath (LBS.toStrict (prettyJSON finalLock)) (Map.fromList files)))
                pure ("Runtime " <> name <> " generation " <> tshow next <> (if dryRun then ": dry-run; no managed files changed" else ": captured immutable projections"))
            textResultError outcome

checkRecord :: RuntimeGeneration -> RuntimeIO ()
checkRecord record = do
    hashes <- hashFiles (Map.fromList [(path, path) | path <- Map.keys record.projections])
    textResult (validateProjectionHashes record hashes)
    actual <- concat <$> traverse ownedFiles [record.recipeDirectory, takeDirectory record.freezeFile]
    ensure (sort (record.versionFile : actual) == Map.keys record.projections) "runtime recipe/projection membership drift"
    versions :: Value <- decodeJSON =<< runCommand "nix" ["eval", "--json", "--file", record.versionFile]
    versionSources :: Map Text PlanPackage <- jsonField "sourceManifest" versions
    ensure (versionSources == record.ownership) "runtime generated recipes disagree with source ownership"
    identity :: Value <- readJSON (takeDirectory record.freezeFile </> "identity.json")
    catalog <- readFileE (record.recipeDirectory </> "config/first-party-families.json") >>= textResult . decodeFamilyCatalog
    firstParty <- readFileE (record.recipeDirectory </> "packages/first-party-lock.json") >>= textResult . decodePackageSetLock catalog
    capturedToolchain <- readFileE (record.recipeDirectory </> "flake.lock") >>= resolvedToolchainInputs
    ensure (capturedToolchain == record.toolchainInputs) "runtime toolchain descriptors disagree with retained lock"
    let policyHashes = Map.fromList [(relative, hash) | (path, hash) <- Map.toList hashes, Just relative <- [Text.stripPrefix (Text.pack record.recipeDirectory <> "/") (Text.pack path)], policyInput (Text.unpack relative)]
        expectedIdentity = runtimeIdentity record.definition record.ownership record.components record.selections record.configurations firstParty (Map.mapKeys Text.unpack policyHashes) record.nixpkgsRevision record.toolchainRevision record.toolchainInputs
    ensure (identity == expectedIdentity && Map.lookup (takeDirectory record.freezeFile </> "identity.json") hashes == Just record.fingerprint) "runtime fingerprint disagrees with captured source/policy inputs"
    sources <- readJSON record.sourceFile
    ensure (sources == record.ownership) "runtime ownership disagrees with retained source projection"
    components :: Map Text Value <- readJSON (takeDirectory record.freezeFile </> "components.json")
    ensure (components == record.components && record.roles == runtimeRoles record.definition record.ownership) "runtime components/roles disagree with retained source records"
    forM_ (nub (map (.channel) record.configurations)) $ \channel -> do
        profile <- readJSON (takeDirectory record.freezeFile </> Text.unpack channel <> "-sources.json")
        textResult (validateSourceProfile channel firstParty record.selections record.ownership profile)
    document <- readFileE record.freezeFile >>= textResult . parseFreezeDocument . decodeUtf8
    ensure (document.freezeIndexState == record.indexState) "runtime freeze disagrees with retained index-state"
    validateCohort
        document
        record.ownership
        firstParty
        record.selections
        (record.recipeDirectory </> "generated/ghc-boot-packages.nix")
        (record.recipeDirectory </> "config/cohort-policy.json")

resolvedToolchainInputs :: BS.ByteString -> RuntimeIO (Map Text (Map Text Text))
resolvedToolchainInputs bytes =
    Map.fromList
        <$> forM
            ["nixpkgs", "haskell-nix-dev"]
            ( \name -> do
                source <- textResultError (decodeLockedSource name bytes)
                let FP.GitRevision revision = source.rev
                    FP.SriHash hash = source.narHash
                pure (name, Map.fromList [("type", source.sourceType), ("owner", source.owner), ("repo", source.repo), ("rev", revision), ("narHash", hash)])
            )

captureComponents :: RuntimeDefinition -> FP.PackageSetLock -> Map Text PlanPackage -> RuntimeIO (Map Text Value)
captureComponents definition firstParty owned = do
    let firstPartyNames = [name | family <- firstParty.familySnapshots, package <- family.packages, let FP.PackageName name = package.name]
        extraRoots = Map.withoutKeys definition.roots (Map.keysSet (Map.fromList [(name, ()) | name <- firstPartyNames]))
        pins = Map.filter (\package -> package.source == SourcePin) owned
        names = sort (nub (Map.keys extraRoots <> Map.keys pins))
    recipes :: Map Text Value <- readJSON "config/runtime-kafka-sources.json"
    nativeSources <- capturePinnedSources (Map.keys pins)
    Map.fromList
        <$> forM
            names
            ( \name -> do
                project <-
                    maybe
                        (failure ("declare the canonical runtime source project: " <> name))
                        pure
                        (case Map.lookup name definition.roots of Just root -> Just root.project; Nothing -> Map.lookup name definition.sourceProjects)
                pure
                    ( name
                    , object
                        ( ["project" .= project, "package" .= name, "source" .= (owned Map.! name)]
                            <> maybe [] (\value -> ["recipe" .= value]) (Map.lookup name recipes)
                            <> maybe [] (\value -> ["nativeSource" .= value]) (Map.lookup name nativeSources)
                        )
                    )
            )

runtimeRoles :: RuntimeDefinition -> Map Text PlanPackage -> Map Text [Text]
runtimeRoles definition =
    Map.mapWithKey
        ( \package value ->
            nub
                ( [if value.source == Boot then "compiler" else "library"]
                    <> maybe [] (\root -> [root.role]) (Map.lookup package definition.roots)
                    <> ["build-tool" | package `elem` ["alex", "happy", "hsc2hs", "c2hs"]]
                )
        )

capturePinnedSources :: [Text] -> RuntimeIO (Map Text Value)
capturePinnedSources names = do
    let expression = "let f = builtins.getFlake (toString ./.); pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; overlays = [ f.overlays.github ]; }; hs = pkgs.haskell.packages.ghc9124; facts = import ./lib/cohortSource.nix { lib = pkgs.lib; }; names = (" <> nixJSON names <> "); in builtins.listToAttrs (map (name: let origin = hs.${name}.cohortSourceOrigin; in { inherit name; value = (facts.record origin.source) // { inherit (origin) subdirectory; }; }) names)"
    values <- decodeJSON =<< runCommand "nix" ["eval", "--impure", "--json", "--expr", Text.unpack expression]
    forM_ (Map.toList values) $ \(name, value) -> do
        hash :: Maybe Text <- jsonField "hash" value
        mode :: Maybe Text <- jsonField "hashMode" value
        ensure (maybe False (Text.isPrefixOf "sha256-") hash && mode == Just "recursive") ("runtime source lacks actual NAR identity: " <> name)
    pure values

-- Both source configurations replay the same bounded cohort. No version is
-- unlocked, and the shared parser/retention checker owns identity comparison.
captureSourceProfile :: FilePath -> FilePath -> Text -> RuntimeDefinition -> Map Text PlanPackage -> FP.PackageSetLock -> Map Text Int -> Text -> FilePath -> RuntimeIO (Map Text PlanPackage)
captureSourceProfile temporary directory channel definition owned firstParty selections cutoff freeze = do
    compiler <- Text.strip <$> runCommand "nix" ["build", "--no-link", "--print-out-paths", "--impure", "--expr", "let f = builtins.getFlake (toString ./.); in (import f.inputs.nixpkgs {}).haskell.compiler.ghc9124"]
    absoluteFreeze <- lift (makeAbsolute freeze)
    let stage = temporary </> Text.unpack channel <> "-proof"
        cabalFile = stage </> "rei-family-cohort/rei-family-cohort.cabal"
        projectFile = stage </> "cohort.project"
        buildDirectory = stage </> "dist-newstyle"
    bounds <- textResult (traverse CohortModel.parseRange (Map.fromList [((name, Nothing), "==" <> (owned Map.! name).version) | name <- Map.keys definition.roots]))
    lift (writeBytes cabalFile (encodeUtf8 (CohortModel.renderStubCabal bounds)))
    lift (writeBytes projectFile (encodeUtf8 ("packages: rei-family-cohort\nimport: " <> Text.pack absoluteFreeze <> "\nimport: " <> Text.pack (temporary </> directory </> Text.unpack channel <> ".project") <> "\n")))
    _ <- runCommand "nix" ["develop", ".#cohort-inventory", "--max-jobs", "2", "--cores", "2", "-c", "env", "-u", "GHC_PACKAGE_PATH", "-u", "GHC_ENVIRONMENT", "cabal", "build", "lib:rei-family-cohort", "--dry-run", "--project-file=" <> projectFile, "--builddir=" <> buildDirectory, "--with-compiler=" <> Text.unpack compiler <> "/bin/ghc", "--with-hc-pkg=" <> Text.unpack compiler <> "/bin/ghc-pkg", "--index-state=" <> Text.unpack cutoff]
    plan <- readFileE (buildDirectory </> "cache/plan.json")
    parsed <- textResult (decodePlanVersions (Map.keysSet (Map.filter (\value -> value.source == Boot) owned)) plan)
    ensure (Map.keys parsed == Map.keys owned && Map.map (.version) parsed == Map.map (.version) owned) ("runtime " <> channel <> " source configuration changes the recorded ownership/version closure; explicit cohort update required")
    let sourceChanges = if channel == "github" then [name | family <- selectedFamilyRows firstParty selections, package <- family.packages, let FP.PackageName name = package.name] else []
    textResult (validateRetainedIdentities owned parsed sourceChanges)
    textResult (validateSourceProfile channel firstParty selections owned parsed)
    pure (Map.map canonicalPackage parsed)

validateSourceProfile :: Text -> FP.PackageSetLock -> Map Text Int -> Map Text PlanPackage -> Map Text PlanPackage -> Either Text ()
validateSourceProfile channel firstParty selections baseline profile = do
    unless (Map.keys baseline == Map.keys profile && Map.map (.version) baseline == Map.map (.version) profile) (Left "runtime source profile changes the recorded ownership/version inventory")
    let firstPartyPackages = [(family, package) | family <- selectedFamilyRows firstParty selections, package <- family.packages, let FP.PackageName name = package.name, Map.member name baseline]
        switched = if channel == "github" then [name | (_, package) <- firstPartyPackages, let FP.PackageName name = package.name] else []
    validateRetainedIdentities baseline profile switched
    when (channel == "github") $ forM_ firstPartyPackages $ \(family, package) -> do
        let FP.PackageName name = package.name
            FP.GitRevision revision = family.source.rev
            selected = profile Map.! name
            origin (Object fields) = do
                Object source <- KeyMap.lookup "pkg-src" fields
                Object repository <- KeyMap.lookup "source-repo" source
                pure
                    ( KeyMap.lookup "location" repository == Just (String ("https://github.com/" <> family.source.owner <> "/" <> family.source.repo))
                        && KeyMap.lookup "tag" repository == Just (String revision)
                        && maybe (String ".") id (KeyMap.lookup "subdir" repository) == String (Text.pack package.path)
                    )
            origin _ = Nothing
        unless (selected.source == SourcePin && not (null selected.identities) && all ((== Just True) . origin) selected.identities) (Left ("runtime Git source profile disagrees with retained family snapshot: " <> name))

validateCohort :: FreezeDocument -> Map Text PlanPackage -> FP.PackageSetLock -> Map Text Int -> FilePath -> FilePath -> RuntimeIO ()
validateCohort document sources firstParty selections bootPath policyPath = do
    boot :: Value <- decodeJSON =<< runCommand "nix" ["eval", "--json", "--file", bootPath]
    bootVersions :: Map Text Text <- jsonField "packages" boot
    shipped <- textResult (traverse CohortModel.parseVersion bootVersions)
    policy <- readFileE policyPath >>= textResult . decodeGenerationPolicy
    let firstPartyVersions = Map.fromList [(name, package.version) | family <- selectedFamilyRows firstParty selections, package <- family.packages, let FP.PackageName name = package.name]
    _ <- textResult (classifyCohort (GenerationContext document sources shipped firstPartyVersions policy Map.empty Map.empty Map.empty))
    pure ()

selectedGroupRows :: FP.PackageSetLock -> Map Text Int -> [FP.GroupSnapshot]
selectedGroupRows firstParty selections = [row | row <- firstParty.groupSnapshots, let FP.UpdateGroupName group = row.group, let FP.SnapshotGeneration value = row.generation, Map.lookup group selections == Just value]

selectedFamilyRows :: FP.PackageSetLock -> Map Text Int -> [FP.FamilySnapshot]
selectedFamilyRows firstParty selections =
    [row | row <- firstParty.familySnapshots, any (\reference -> reference.family == row.family && reference.generation == row.generation) references]
  where
    references = concatMap (.families) (selectedGroupRows firstParty selections)

runtimeIdentity :: RuntimeDefinition -> Map Text PlanPackage -> Map Text Value -> Map Text Int -> [RuntimeConfiguration] -> FP.PackageSetLock -> Map FilePath Text -> Text -> Text -> Map Text (Map Text Text) -> Value
runtimeIdentity definition owned components selected configurations firstParty policyHashes nixpkgs toolchain toolchainInputs =
    object
        [ "definition" .= definition
        , "ownership" .= Map.map canonicalPackage owned
        , "components" .= components
        , "roles" .= runtimeRoles definition owned
        , "selections" .= selected
        , "families" .= map (String . renderRuntimeFamilyIdentity) familyRows
        , "groups" .= map (String . tshow) sourceRows
        , "policies" .= policyHashes
        , "nixpkgs" .= nixpkgs
        , "toolchain" .= toolchain
        , "toolchainInputs" .= toolchainInputs
        , "configurations" .= configurations
        ]
  where
    sourceRows = [row | row <- firstParty.groupSnapshots, let FP.UpdateGroupName group = row.group, let FP.SnapshotGeneration value = row.generation, Map.lookup group selected == Just value]
    familyReferences = concatMap (.families) sourceRows
    familyRows = [row | row <- firstParty.familySnapshots, any (\reference -> reference.family == row.family && reference.generation == row.generation) familyReferences]

-- These strings are part of immutable fingerprints from before nested discovery.
-- Keep the original field encoding when the optional path list is empty, while
-- binding nonempty lists into new identities. Derived Show added the empty field
-- to historical records when DiscoveryPolicy grew, invalidating their hashes.
renderRuntimeFamilyIdentity :: FP.FamilySnapshot -> Text
renderRuntimeFamilyIdentity row =
    "FamilySnapshot {family = " <> tshow row.family
        <> ", generation = " <> tshow row.generation
        <> ", discoveryPolicy = DiscoveryPolicy {packageOverrides = " <> tshow row.discoveryPolicy.packageOverrides
        <> ", excludedPackages = " <> tshow row.discoveryPolicy.excludedPackages
        <> (if null row.discoveryPolicy.additionalPackagePaths then "" else ", additionalPackagePaths = " <> tshow row.discoveryPolicy.additionalPackagePaths)
        <> "}, source = " <> tshow row.source
        <> ", packages = " <> tshow row.packages <> "}"

policyInput :: FilePath -> Bool
policyInput path = any (`Text.isPrefixOf` Text.pack path) ["lib/", "patches/", "overlays/", "config/"] || path `elem` ["cabal/common.config", "cabal/cohort-nix-policy.json"]

ownedFiles :: FilePath -> RuntimeIO [FilePath]
ownedFiles directory = do
    symbolic <- lift (pathIsSymbolicLink directory)
    ensure (not symbolic) ("runtime projection directory is a symlink: " <> Text.pack directory)
    names <- lift (listDirectory directory)
    concat
        <$> forM
            names
            ( \name -> do
                let path = directory </> name
                symbolic <- lift (pathIsSymbolicLink path)
                ensure (not symbolic) ("runtime projection contains a symlink: " <> Text.pack path)
                nested <- lift (doesDirectoryExist path)
                if nested then ownedFiles path else pure [path]
            )

captureInputs :: RuntimeIO (Map FilePath BS.ByteString)
captureInputs = do
    names <- runCommand "git" ["ls-files", "--", "lib", "overlays", "patches", "config", "generated/cohort-versions.nix", "generated/ghc-boot-packages.nix", "packages/first-party-lock.json", "cabal/common.config", "cabal/cohort.freeze", "cabal/cohort-sources.json", "cabal/cohort-nix-policy.json", "flake.lock"]
    Map.fromList
        <$> forM
            (map Text.unpack (Text.lines names))
            ( \path -> do
                symbolic <- lift (pathIsSymbolicLink path)
                ensure (not symbolic) ("runtime recipe input must be a regular tracked file: " <> Text.pack path)
                (path,) <$> readFileE path
            )

hashFiles :: Map FilePath FilePath -> RuntimeIO (Map FilePath Text)
hashFiles paths = do
    absolute <- lift (traverse makeAbsolute paths)
    decodeJSON =<< runCommand "nix" ["eval", "--impure", "--json", "--expr", Text.unpack ("builtins.mapAttrs (_: path: builtins.hashFile \"sha256\" path) (" <> nixJSON absolute <> ")")]

renderVersionProjection :: Text -> Int -> [Text] -> Text -> Text
renderVersionProjection name generation names hash =
    Text.unlines
        [ "# Generated deterministic projection of the accepted cohort; do not edit."
        , "let"
        , "  selected = import ../../../packages/runtimes/" <> name <> "/" <> tshow generation <> "/recipes/generated/cohort-versions.nix;"
        , "  names = " <> nixJSON names <> ";"
        , "  keep = values: builtins.intersectAttrs (builtins.listToAttrs (map (name: { inherit name; value = null; }) names)) values;"
        , "  keepNames = values: builtins.filter (name: builtins.elem name names) values;"
        , "in selected // {"
        , "  freezeSha256 = \"" <> hash <> "\";"
        , "  packages = keep selected.packages; policy = keep selected.policy;"
        , "  sourceManifest = keep selected.sourceManifest; flags = keep selected.flags;"
        , "  boot = keepNames selected.boot; firstParty = keepNames selected.firstParty; sameAsBase = keepNames selected.sameAsBase;"
        , "}"
        ]

-- Extract configuration from the shared solve; exact resolved flags include
-- automatic defaults. Keep owned package option blocks, but source stanzas are
-- reconstructed from the captured source identities below.
renderRuntimeConfiguration :: [Text] -> Text -> Map Text PlanPackage -> Text
renderRuntimeConfiguration names common packages =
    Text.unlines
        ( ["-- Retained runtime configuration from the shared cohort."]
            <> ["with-compiler: ghc-9.12.4", "tests: False", "benchmarks: False"]
            <> field "allow-newer" [value | ("allow-newer", text) <- projectFields common, value <- map Text.strip (Text.splitOn "," text), Text.takeWhile (/= ':') value `elem` names]
            <> field "constraints" ["any." <> name <> " " <> Text.unwords [(if enabled then "+" else "-") <> flag | (key, Bool enabled) <- KeyMap.toList flags, let flag = Key.toText key] | (name, package) <- Map.toAscList packages, Object identity : _ <- [package.identities], Just (Object flags) <- [KeyMap.lookup "flags" identity], not (KeyMap.null flags)]
            <> ownedBlocks (Text.lines common)
        )
  where
    field _ [] = []
    field key entries = (key <> ":") : zipWith (<>) ("  " : repeat "  , ") entries
    ownedBlocks [] = []
    ownedBlocks (line : rest)
        | Just package <- Text.stripPrefix "package " line =
            let (body, remaining) = span (\value -> Text.null (Text.strip value) || Text.isPrefixOf " " value || Text.isPrefixOf "--" value) rest
             in (if Text.strip package `elem` names then line : body else []) <> ownedBlocks remaining
        | otherwise = ownedBlocks rest

renderRuntimeSources :: Text -> FP.PackageSetLock -> Map Text Int -> Map Text PlanPackage -> Either Text Text
renderRuntimeSources channel firstParty selections packages = do
    pins <- traverse sourcePin [(name, package) | (name, package) <- Map.toAscList packages, package.source == SourcePin]
    let selectedGroups = [row | row <- firstParty.groupSnapshots, let FP.UpdateGroupName group = row.group, let FP.SnapshotGeneration value = row.generation, Map.lookup group selections == Just value]
        references = concatMap (.families) selectedGroups
        families = [row | row <- firstParty.familySnapshots, any (\ref -> ref.family == row.family && ref.generation == row.generation) references]
        github = [stanza ("https://github.com/" <> family.source.owner <> "/" <> family.source.repo) (let FP.GitRevision rev = family.source.rev in rev) (nub [Text.pack package.path | package <- family.packages, let FP.PackageName name = package.name, Map.member name packages]) | family <- families]
    pure (Text.concat pins <> if channel == "github" then Text.concat github else "")
  where
    sourcePin (name, package) = case package.identities of
        Object fields : _ -> case KeyMap.lookup "pkg-src" fields of
            Just (Object source) -> case KeyMap.lookup "source-repo" source of
                Just (Object repository) -> case (KeyMap.lookup "location" repository, KeyMap.lookup "tag" repository) of
                    (Just (String location), Just (String tag)) -> Right (stanza location tag (case KeyMap.lookup "subdir" repository of Just (String directory) -> [directory]; _ -> []))
                    _ -> Left ("missing retained source revision: " <> name)
                _ -> Left ("missing retained source repository: " <> name)
            _ -> Left ("missing retained source identity: " <> name)
        _ -> Left ("missing retained source identity: " <> name)
    stanza location revision subdirectories = Text.unlines (["", "source-repository-package", "  type: git", "  location: " <> location, "  tag: " <> revision] <> ["  subdir: " <> Text.unwords subdirectories | not (null subdirectories) && subdirectories /= ["."]])

publishRuntimeFiles :: Map FilePath BS.ByteString -> IO ()
publishRuntimeFiles files = do
    originals <- traverse (\path -> do exists <- doesFileExist path; if exists then Just <$> BS.readFile path else pure Nothing) (Map.fromList [(path, path) | path <- Map.keys files])
    let restore = forM_ (Map.toList originals) $ \(path, content) -> case content of
            Just bytes -> writeAtomic path bytes
            Nothing -> do exists <- doesFileExist path; when exists (removeFile path)
    forM_ (Map.toList files) (uncurry writeAtomic) `onException` restore

writeAtomic :: FilePath -> BS.ByteString -> IO ()
writeAtomic path bytes = do
    createDirectoryIfMissing True (takeDirectory path)
    withTempFile (takeDirectory path) ".runtime-stage-" $ \temporary handle -> do
        BS.hPut handle bytes
        hClose handle
        renameFile temporary path

writeBytes :: FilePath -> BS.ByteString -> IO ()
writeBytes path bytes = createDirectoryIfMissing True (takeDirectory path) >> BS.writeFile path bytes

readFileE :: FilePath -> RuntimeIO BS.ByteString
readFileE = lift . BS.readFile

readJSON :: (FromJSON a) => FilePath -> RuntimeIO a
readJSON path = readFileE path >>= textResult . either (Left . Text.pack) Right . eitherDecodeStrict'

decodeJSON :: (FromJSON a) => Text -> RuntimeIO a
decodeJSON = textResult . either (Left . Text.pack) Right . eitherDecodeStrict' . encodeUtf8

jsonField :: (FromJSON a) => Text -> Value -> RuntimeIO a
jsonField key (Object fields) = case KeyMap.lookup (Key.fromText key) fields of
    Just value -> case fromJSON value of Error problem -> failure (Text.pack problem); Success result -> pure result
    Nothing -> failure ("missing JSON field: " <> key)
jsonField key _ = failure ("expected object for JSON field: " <> key)

runCommand :: FilePath -> [String] -> RuntimeIO Text
runCommand executable arguments = (.standardOutput) <$> ExceptT (runChecked streamingProcessRunner (ProcessSpec executable arguments Nothing []))

ensure :: Bool -> Text -> RuntimeIO ()
ensure condition message = unless condition (failure message)

failure :: Text -> RuntimeIO a
failure = ExceptT . pure . Left . FP.UpdateError

textResult :: Either Text a -> RuntimeIO a
textResult = either failure pure

textResultError :: Either FP.UpdateError a -> RuntimeIO a
textResultError = ExceptT . pure

prettyJSON :: (ToJSON a) => a -> LBS.ByteString
prettyJSON value = encodePretty' defConfig{confCompare = compare} value <> "\n"

nixJSON :: (ToJSON a) => a -> Text
nixJSON value = "builtins.fromJSON " <> Text.replace "${" "\\${" (canonicalJSON (String (canonicalJSON (toJSON value))))

tshow :: (Show a) => a -> Text
tshow = Text.pack . show
