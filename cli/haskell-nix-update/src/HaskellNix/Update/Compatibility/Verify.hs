{-# LANGUAGE OverloadedRecordDot #-}

-- A receipt is an observation, not authority. Verification rechecks Nix's
-- metadata and native logs for the exact caller-selected construction context.
module HaskellNix.Update.Compatibility.Verify
    ( ProbeContext (..), ProbePhase (..), decodeProbeContext
    , validateProbeReceipt, runProbe, verifyProbeReceipt ) where

import Control.Exception (IOException, try)
import Control.Monad (unless, forM)
import Data.Aeson
import Data.Aeson.Types (Parser, parseEither)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.List (nub, sort)
import Data.Char (isAlphaNum)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time (getCurrentTime)
import HaskellNix.Update.Process
import HaskellNix.Update.Types (UpdateError (..))
import System.Directory (createDirectory, doesPathExist)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))

data ProbePhase = ProbePhase
    { name :: !Text, package :: !Text, checks :: ![(Text, Text)] }
    deriving stock (Eq, Show)
data ProbeContext = ProbeContext
    { document :: !Value, entryId :: !Text, system :: !Text
    , suites :: ![Text], phases :: ![ProbePhase] }
    deriving stock (Eq, Show)

decodeProbeContext :: BS.ByteString -> Either Text ProbeContext
decodeProbeContext bytes = do
    value <- either (Left . T.pack) Right (eitherDecodeStrict' bytes)
    either (Left . T.pack) Right (parseEither parseProbe value)

parseProbe :: Value -> Parser ProbeContext
parseProbe document = withObject "native probe context" (\o -> do
    schema <- o .: "schemaVersion" :: Parser Int
    kind <- o .: "kind" :: Parser Text
    unless (schema == 1 && kind == "native-compatibility-probe") (fail "unsupported native probe schema/kind")
    channel <- o .: "channel" :: Parser Text
    unless (channel `elem` ["github", "hackage"]) (fail "invalid probe channel")
    o .: "policyIdentity" >>= digest
    suites <- o .: "requiredSuites"
    uniqueNonempty "required suites" suites
    validation <- o .: "validation"
    (entryId, system, compiler, baseline, candidate, services) <- withObject "strict validation" (\v -> do
        v .: "inputIdentity" >>= digest
        status <- v .: "status" :: Parser Text
        profile <- v .: "policyProfile" :: Parser Text
        tests <- v .: "tests" :: Parser Text
        bounds <- v .: "bounds" :: Parser Text
        missing <- v .: "missingServices" :: Parser [Text]
        unless (status == "unverified" && profile == "strict-v1" && tests == "run" && bounds == "enforce" && null missing)
            (fail "probe requires unblocked strict tests and enforced bounds")
        entryId <- v .: "entryId" >>= nonempty
        system <- v .: "system" >>= nonempty
        compiler <- v .: "compiler" >>= drv
        required <- v .: "requiredServices"
        unless (nub required == required) (fail "duplicate required service")
        provided <- v .: "providedServiceProbes" :: Parser Object
        unless (sort required == sort (map Key.toText (KM.keys provided))) (fail "service coverage differs")
        services <- forM required (\key -> do path <- provided .: Key.fromText key >>= drv; pure ("service:" <> key, path))
        baseline <- v .: "baseline"
        candidate <- v .: "candidate"
        mapM_ strict [baseline, candidate]
        before <- inputs baseline
        after <- inputs candidate
        unless (before == after) (fail "removal changed source, metadata, version or dependency instances")
        pure (entryId, system, compiler, baseline, candidate, services)
        ) validation
    phaseValues <- o .: "phases" :: Parser Object
    unless (sort (KM.keys phaseValues) == ["baseline", "candidate"]) (fail "probe needs exactly baseline and candidate")
    phases <- forM [("baseline", baseline), ("candidate", candidate)] $ \(name, snapshot) -> do
        package <- withObject "package snapshot" (\s -> s .: "derivation" >>= drv) snapshot
        phase <- phaseValues .: Key.fromText name
        withObject "probe phase" (\p -> do
            graph <- p .: "graph"
            graphDrv <- withObject "cohort graph" (\g -> do
                graphDrv <- g .: "derivation" >>= drv
                declaration <- g .: "declaration"
                validateGraph package compiler system snapshot declaration
                pure graphDrv) graph
            behaviors <- p .: "behaviorProbes" :: Parser Object
            unless (not (KM.null behaviors)) (fail "native behavior checks missing")
            behaviorChecks <- forM (KM.toList behaviors) $ \(key, value) -> do
                _ <- nonempty (Key.toText key)
                path <- parseJSON value >>= drv
                pure ("behavior:" <> Key.toText key, path)
            pure ProbePhase { name, package, checks = ("graph", graphDrv) : behaviorChecks ++ services }
            ) phase
    pure ProbeContext { document, entryId, system, suites, phases }
    ) document
  where
    inputs = withObject "selected package inputs" $ \s -> do
        values <- traverse (s .:) ["sourceIdentity", "metadataIdentity", "version"] :: Parser [Value]
        effective <- s .: "effective"
        deps <- withObject "effective dependencies" (.: "dependencies") effective :: Parser Value
        pure (values, deps)
    strict = withObject "strict package snapshot" $ \s -> do
        mapM_ (\key -> s .: key >>= nonempty) ["sourceIdentity", "metadataIdentity", "version"]
        effective <- s .: "effective"
        withObject "effective strict policy" (\e -> do
            tests <- e .: "testsEnabled" :: Parser Bool
            relaxed <- e .: "boundsRelaxed" :: Parser Bool
            inventory <- e .: "testDependencyInventory" :: Parser Text
            configureFlags <- e .: "configureFlags" :: Parser [Text]
            unless (not (any (\flag -> any (`T.isPrefixOf` flag)
                ["--allow-newer", "--allow-older", "--disable-tests", "--enable-tests=false"]) configureFlags))
                (fail "configure flags disable tests or relax declared bounds")
            execution <- e .: "testExecution"
            withObject "standard Cabal test execution" (\x -> do
                custom <- x .: "customCheckPhase" :: Parser Bool
                targets <- x .: "targets" :: Parser [Text]
                flags <- x .: "flags" :: Parser [Text]
                unless (tests && not relaxed && inventory == "declared" && not custom && targets == [""] && null flags)
                    (fail "disabled, relaxed, custom, filtered or incomplete tests cannot pass")
                ) execution
            ) effective

-- The producer reconstructs every package and checks the actual derivation
-- graph when built. Validate its declaration before trusting its check output.
validateGraph :: Text -> Text -> Text -> Value -> Value -> Parser ()
validateGraph package compiler system snapshot = withObject "cohort graph declaration" $ \g -> do
    selectedSystem <- g .: "system"
    unless (selectedSystem == system) (fail "graph system differs")
    ghc <- g .: "compiler" >>= withObject "graph compiler" (.: "drvPath")
    unless (ghc == compiler) (fail "graph compiler differs")
    root <- g .: "root" >>= withObject "graph root" (.: "drvPath")
    unless (root == package) (fail "graph root differs")
    packages <- g .: "packages" :: Parser [Value]
    nodes <- forM packages $ withObject "graph node" $ \n -> do
        path <- n .: "drvPath" >>= drv
        name <- n .: "name" >>= nonempty
        dependencies <- n .: "dependencies" :: Parser [Text]
        pure (path, name, dependencies)
    let paths = [path | (path, _, _) <- nodes]
        names = [name | (_, name, _) <- nodes]
    unless (package `elem` paths && nub paths == paths && nub names == names)
        (fail "missing root or duplicate dependency instances")
    unless (all (\(_, _, deps) -> all (`elem` paths) deps) nodes)
        (fail "omitted transitive dependency in graph")
    native <- g .: "nativePackages" :: Parser [Value]
    nativePaths <- traverse (withObject "native graph node" (\n -> n .: "drvPath" >>= drv)) native
    declared <- withObject "snapshot" (\s -> s .: "effective" >>= withObject "effective" (.: "dependencies")) snapshot :: Parser Object
    mapM_ (\value -> do
        deps <- parseJSON value :: Parser [Value]
        mapM_ (withObject "dependency instance" (\d -> case KM.lookup "derivation" d of
            Just path -> do
                selected <- parseJSON path
                unless (selected `elem` (compiler : paths ++ nativePaths)) (fail "declared dependency missing from graph")
            Nothing -> do
                -- Compiler boot dependencies are represented as unresolved null
                -- arguments by callPackage; the cohort producer checks them.
                kind <- d .: "kind" :: Parser Text
                unless (kind == "null") (fail "unverifiable dependency instance"))) deps
        ) (KM.elems declared)

validateProbeReceipt :: ProbeContext -> Value -> Either Text ()
validateProbeReceipt context receipt = either (Left . T.pack) Right (parseEither parse receipt)
  where
    parse = withObject "probe receipt" $ \r -> do
        schema <- r .: "schemaVersion" :: Parser Int
        selected <- r .: "context"
        status <- r .: "status" :: Parser Text
        unless (schema == 1 && selected == context.document) (fail "receipt belongs to another input, policy or probe context")
        unless (status == "passed") (fail "failed, blocked, waived or unverified receipt cannot pass")
        waivers <- r .: "remainingWaivers" :: Parser [Text]
        unless (null waivers) (fail "waiver-qualified evidence cannot claim strict validation")
        results <- r .: "results"
        unless (results == expectedResults context) (fail "receipt omitted or changed required tests, graph, behavior or services")

expectedResults :: ProbeContext -> Value
expectedResults context = toJSON [phaseResult phase True True [(key, path, True) | (key, path) <- phase.checks] | phase <- context.phases]

phaseResult :: ProbePhase -> Bool -> Bool -> [(Text, Text, Bool)] -> Value
phaseResult phase packagePassed suitesPassed checks = object
    [ "phase" .= phase.name, "package" .= phase.package, "packagePassed" .= packagePassed
    , "suitesPassed" .= suitesPassed
    , "checks" .= [object ["id" .= key, "derivation" .= path, "passed" .= passed] | (key, path, passed) <- checks] ]

runProbe :: ProcessRunner -> ProbeContext -> Text -> FilePath -> IO (Either UpdateError Text)
runProbe runner context selectedEntry destination
    | selectedEntry /= context.entryId = pure (Left (UpdateError "requested entry does not match the constructed removal candidate"))
    | otherwise = ioErrors $ do
        exists <- doesPathExist destination
        if exists then pure (Left (UpdateError "probe output already exists; select a fresh staging directory")) else do
            native <- nativeSystem runner context
            case native of
                Left err -> pure (Left err)
                Right () -> do
                    createDirectory destination
                    results <- observe runner True (Just destination) context
                    now <- getCurrentTime
                    let passed = results == expectedResults context
                        receipt = object ["schemaVersion" .= (1 :: Int), "context" .= context.document
                            , "status" .= (if passed then "passed" else "failed" :: Text)
                            , "observedAt" .= show now, "remainingWaivers" .= ([] :: [Text]), "results" .= results]
                    LBS.writeFile (destination </> "receipt.json") (encode receipt)
                    pure $ if passed then Right ("Native removal probe passed; receipt: " <> T.pack (destination </> "receipt.json"))
                        else Left (UpdateError ("Native removal probe incomplete or failed; inspect " <> T.pack (destination </> "receipt.json")))

verifyProbeReceipt :: ProcessRunner -> ProbeContext -> Value -> IO (Either UpdateError Text)
verifyProbeReceipt runner context receipt = case validateProbeReceipt context receipt of
    Left err -> pure (Left (UpdateError err))
    Right () -> do
        native <- nativeSystem runner context
        case native of
            Left err -> pure (Left err)
            Right () -> do
                current <- observe runner False Nothing context
                pure $ if current == expectedResults context
                    then Right "Native receipt verified against exact inputs, Nix metadata and complete suite logs"
                    else Left (UpdateError "receipt evidence is missing or disagrees with current native Nix metadata/logs")

nativeSystem :: ProcessRunner -> ProbeContext -> IO (Either UpdateError ())
nativeSystem runner context = do
    result <- runChecked runner (spec ["eval", "--impure", "--raw", "--expr", "builtins.currentSystem"])
    pure $ do
        value <- result
        unless (T.strip value.standardOutput == context.system) (Left (UpdateError "probe must run on its declared native system"))

observe :: ProcessRunner -> Bool -> Maybe FilePath -> ProbeContext -> IO Value
observe runner build destination context = toJSON <$> forM context.phases (\phase -> do
    packagePassed <- checkOutput (phase.name <> "-package") phase.package
    logResult <- runner.runProcess (spec ["log", T.unpack phase.package])
    let suitesPassed = case logResult of
            Right result | result.exitCode == ExitSuccess ->
                let logLines = map T.strip (T.lines result.standardOutput)
                    passed = [T.dropEnd 6 (T.drop 11 line) | line <- logLines, "Test suite " `T.isPrefixOf` line, ": PASS" `T.isSuffixOf` line]
                in "Running phase: checkPhase" `elem` logLines && sort passed == sort context.suites
                    && not (any (T.isSuffixOf ": FAIL") logLines)
            _ -> False
    save (phase.name <> "-suite.log") logResult
    checks <- forM phase.checks $ \(key, path) -> do
        passed <- if packagePassed && suitesPassed then checkOutput (phase.name <> "-" <> T.replace ":" "-" key) path else pure False
        pure (key, path, passed)
    pure (phaseResult phase packagePassed suitesPassed checks))
  where
    checkOutput label path = do
        result <- runner.runProcess (spec (if build
            then ["build", "--no-link", "--json", "--print-build-logs", "--timeout", "900", T.unpack path <> "^*"]
            else ["path-info", "--json", T.unpack path <> "^*"]))
        save (label <> ".log") result
        pure $ case result of
            Right value -> value.exitCode == ExitSuccess
            Left _ -> False
    save label result = case destination of
        Nothing -> pure ()
        Just directory -> BS.writeFile (directory </> T.unpack (T.map (\c -> if isAlphaNum c || c `elem` (".-_" :: String) then c else '_') label)) (encodeUtf8 (T.takeEnd 131072 (case result of
            Left err -> T.pack (show err)
            Right value -> value.standardOutput <> value.standardError)))

spec :: [String] -> ProcessSpec
spec arguments = ProcessSpec { executable = "nix", arguments, workingDirectory = Nothing, environmentAdditions = [] }

nonempty :: Text -> Parser Text
nonempty value = if T.null (T.strip value) then fail "empty probe identity" else pure value

drv :: Text -> Parser Text
drv value = do
    unless ("/nix/store/" `T.isPrefixOf` value && ".drv" `T.isSuffixOf` value
        && not (T.any (`elem` ['\n', '\r', '^', ' ']) value)) (fail "invalid derivation identity")
    pure value

digest :: Text -> Parser ()
digest value = unless (T.length value == 64 && T.all (`elem` ("0123456789abcdef" :: String)) value) (fail "invalid SHA256 identity")

uniqueNonempty :: String -> [Text] -> Parser ()
uniqueNonempty label values = do
    unless (not (null values) && nub values == values) (fail ("empty or duplicate " <> label))
    mapM_ nonempty values

ioErrors :: IO (Either UpdateError Text) -> IO (Either UpdateError Text)
ioErrors action = do
    result <- try action
    pure $ case result of
        Left (err :: IOException) -> Left (UpdateError (T.pack (show err)))
        Right value -> value
