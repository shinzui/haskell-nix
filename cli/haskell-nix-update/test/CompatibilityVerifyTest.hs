{-# LANGUAGE OverloadedRecordDot #-}

module CompatibilityVerifyTest (tests) where

import Data.Aeson hiding (Success)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.IORef
import Data.Text (Text)
import Data.Text qualified as T
import HaskellNix.Update.Compatibility.Verify
import HaskellNix.Update.Compatibility.Cli
import HaskellNix.Update.Cli (Command (..), parserInfo)
import HaskellNix.Update.Process
import Options.Applicative (ParserResult (..), defaultPrefs, execParserPure)
import Paths_haskell_nix_update (getDataFileName)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests = testGroup "native compatibility receipt"
    [ testCase "Nix-produced strict probe context is accepted" $ fixture >>= right . decodeProbeContext >> pure ()
    , testCase "exact successful receipt is accepted structurally" $ do
        context <- fixture >>= right . decodeProbeContext
        validateProbeReceipt context (receipt context) @?= Right ()
    , testCase "disabled, relaxed, custom, filtered or omitted tests cannot pass" $ do
        value <- fixtureValue
        mapM_ (\(path, changed) -> invalid (setAt (["validation", "candidate", "effective"] ++ path) changed value))
            [(["testsEnabled"], Bool False), (["boundsRelaxed"], Bool True)
            , (["testDependencyInventory"], String "not-evaluated")
            , (["testExecution", "customCheckPhase"], Bool True)
            , (["testExecution", "targets"], toJSON ([] :: [Text]))
            , (["testExecution", "targets"], toJSON (["some-suite"] :: [Text]))
            , (["testExecution", "flags"], toJSON (["--test-options=skip"] :: [Text]))]
    , testCase "configure flags cannot bypass tests or declared bounds" $ do
        value <- fixtureValue
        mapM_ (\flag -> invalid (setAt ["validation", "candidate", "effective", "configureFlags"] (toJSON ([flag] :: [Text])) value))
            ["--disable-tests", "--enable-tests=false", "--allow-newer=base", "--allow-older"]
    , testCase "changed source or metadata cannot masquerade as removal" $ do
        value <- fixtureValue
        mapM_ (\key -> invalid (setAt ["validation", "candidate", key] (String "changed") value)) ["sourceIdentity", "metadataIdentity", "version"]
    , testCase "wrong compiler and system graph are rejected" $ do
        value <- fixtureValue
        invalid (setAt ["validation", "compiler"] (String "/nix/store/wrong-ghc.drv") value)
        invalid (setAt ["validation", "system"] (String "x86_64-linux") value)
    , testCase "wrong and omitted direct/test dependency instances are rejected" $ do
        value <- fixtureValue
        let dep = object ["derivation" .= ("/nix/store/wrong-dependency.drv" :: Text), "output" .= ("out" :: Text)]
        invalid (setAt ["validation", "candidate", "effective", "dependencies", "testHaskellDepends"] (toJSON [dep]) value)
        let both = setAt ["validation", "baseline", "effective", "dependencies", "testHaskellDepends"] (toJSON [dep])
                 $ setAt ["validation", "candidate", "effective", "dependencies", "testHaskellDepends"] (toJSON [dep]) value
        invalid both
    , testCase "omitted transitive dependency is rejected" $ do
        value <- fixtureValue
        context <- fixture >>= right . decodeProbeContext
        let node = object ["drvPath" .= ((last context.phases).package), "name" .= ("root" :: Text)
                , "dependencies" .= (["/nix/store/missing-test-dep.drv"] :: [Text])]
            changed = setAt ["phases", "candidate", "graph", "declaration", "packages"] (toJSON [node]) value
        rejectsWith "omitted transitive" changed
    , testCase "correct and wrong instances together cannot satisfy graph coverage" $ do
        value <- fixtureValue
        context <- fixture >>= right . decodeProbeContext
        let root = object ["drvPath" .= ((last context.phases).package), "name" .= ("root" :: Text), "dependencies" .= ([] :: [Text])]
            node path = object ["drvPath" .= (path :: Text), "name" .= ("same-dependency" :: Text), "dependencies" .= ([] :: [Text])]
            changed = setAt ["phases", "candidate", "graph", "declaration", "packages"]
                (toJSON [root, node "/nix/store/right-instance.drv", node "/nix/store/wrong-instance.drv"]) value
        rejectsWith "duplicate dependency instances" changed
    , testCase "services cannot disappear or pass merely by being declared" $ do
        value <- fixtureValue
        invalid (setAt ["validation", "requiredServices"] (toJSON (["database"] :: [Text])) value)
        invalid (setAt ["validation", "missingServices"] (toJSON (["database"] :: [Text])) value)
    , testCase "empty suite and behavior inventories are rejected" $ do
        value <- fixtureValue
        invalid (setAt ["requiredSuites"] (toJSON ([] :: [Text])) value)
        invalid (setAt ["phases", "candidate", "behaviorProbes"] (object []) value)
    , testCase "stale compiler/source/policy and omitted receipt checks fail" $ do
        context <- fixture >>= right . decodeProbeContext
        let valid = receipt context
        mapM_ (\path -> invalidReceipt context (setAt ("context" : path) (String "changed") valid))
            [["policyIdentity"], ["validation", "compiler"], ["validation", "candidate", "sourceIdentity"]]
        invalidReceipt context (setAt ["results"] (toJSON ([] :: [Value])) valid)
    , testCase "failed, blocked, waived and unverified receipts fail" $ do
        context <- fixture >>= right . decodeProbeContext
        mapM_ (\status -> invalidReceipt context (setAt ["status"] (String status) (receipt context))) ["failed", "blocked", "waived", "unverified"]
        invalidReceipt context (setAt ["remainingWaivers"] (toJSON (["test-waiver"] :: [Text])) (receipt context))
    , testCase "successful labels require fresh native metadata and logs" $ do
        context <- fixture >>= right . decodeProbeContext
        calls <- newIORef []
        let runner = fakeRunner calls context.system goodLog ExitSuccess
        verified <- verifyProbeReceipt runner context (receipt context)
        assertRight verified
        specs <- readIORef calls
        assertBool "read only; no build on receipt recheck" (all (\spec -> take 1 spec.arguments /= ["build"]) specs)
        assertBool "metadata rechecked" (any (\spec -> take 1 spec.arguments == ["path-info"]) specs)
        assertBool "native logs rechecked" (any (\spec -> take 1 spec.arguments == ["log"]) specs)
        missing <- verifyProbeReceipt (fakeRunner calls context.system goodLog (ExitFailure 1)) context (receipt context)
        assertLeft missing
    , testCase "skipped, extra, missing or failed suites fail even with valid outputs" $ do
        context <- fixture >>= right . decodeProbeContext
        calls <- newIORef []
        mapM_ (\suiteLog -> verifyProbeReceipt (fakeRunner calls context.system suiteLog ExitSuccess) context (receipt context) >>= assertLeft)
            ["", "Test suite fixture-tests: PASS\n", "Running phase: checkPhase\nTest suite other: PASS\n"
            , goodLog <> "Test suite ignored-tests: PASS\n", goodLog <> "Test suite hidden: FAIL\n"]
    , testCase "receipt cannot be rechecked on another architecture" $ do
        context <- fixture >>= right . decodeProbeContext
        calls <- newIORef []
        verifyProbeReceipt (fakeRunner calls "wrong-system" goodLog ExitSuccess) context (receipt context) >>= assertLeft
    , testCase "provided service probes are observed for both candidates" $ do
        value <- fixtureValue
        let serviceContext = setAt ["validation", "requiredServices"] (toJSON (["fixture-service"] :: [Text]))
                           $ setAt ["validation", "providedServiceProbes"] (object ["fixture-service" .= ("/nix/store/service-probe.drv" :: Text)]) value
        context <- right (decodeProbeContext (LBS.toStrict (encode serviceContext)))
        calls <- newIORef []
        verifyProbeReceipt (fakeRunner calls context.system goodLog ExitSuccess) context (receipt context) >>= assertRight
        specs <- readIORef calls
        length (filter (elem "/nix/store/service-probe.drv^*" . (.arguments)) specs) @?= 2
        let runner = ProcessRunner $ \spec -> if "/nix/store/service-probe.drv^*" `elem` spec.arguments
                then pure (Right (ProcessResult (ExitFailure 1) "" "service unavailable"))
                else (fakeRunner calls context.system goodLog ExitSuccess).runProcess spec
        verifyProbeReceipt runner context (receipt context) >>= assertLeft
    , testCase "verify stages receipt, refuses stale directories and mismatched entry" $ withSystemTempDirectory "compatibility-verify" $ \directory -> do
        context <- fixture >>= right . decodeProbeContext
        calls <- newIORef []
        let runner = fakeRunner calls context.system goodLog ExitSuccess
            destination = directory </> "probe"
        runProbe runner context "wrong-entry" destination >>= assertLeft
        runProbe runner context context.entryId destination >>= assertRight
        bytes <- BS.readFile (destination </> "receipt.json")
        saved <- right (eitherDecodeStrict' bytes)
        validateProbeReceipt context saved @?= Right ()
        runProbe runner context context.entryId destination >>= assertLeft
    , testCase "CLI requires entry/context/staging or receipt arguments" $ do
        case execParserPure defaultPrefs parserInfo ["compatibility", "verify", "--context", "context.json", "--entry", "entry", "--out", "probe"] of
            Success (Compatibility (CompatibilityVerify "context.json" "entry" "probe")) -> pure ()
            other -> assertFailure (show other)
        case execParserPure defaultPrefs parserInfo ["compatibility", "verify-receipt", "--context", "context.json", "--receipt", "receipt.json"] of
            Success (Compatibility (CompatibilityVerifyReceipt "context.json" "receipt.json")) -> pure ()
            other -> assertFailure (show other)
    ]
  where
    fixture = getDataFileName "test/fixtures/valid/compatibility-probe.json" >>= BS.readFile
    fixtureValue = fixture >>= right . eitherDecodeStrict'
    invalid value = assertLeft (decodeProbeContext (LBS.toStrict (encode value)))
    invalidReceipt context value = assertLeft (validateProbeReceipt context value)
    rejectsWith message value = case decodeProbeContext (LBS.toStrict (encode value)) of
        Left problem -> assertBool (T.unpack problem) (message `T.isInfixOf` problem)
        Right _ -> assertFailure "invalid graph passed"

receipt :: ProbeContext -> Value
receipt context = object ["schemaVersion" .= (1 :: Int), "context" .= context.document, "status" .= ("passed" :: Text)
    , "remainingWaivers" .= ([] :: [Text])
    , "results" .= [object ["phase" .= p.name, "package" .= p.package, "packagePassed" .= True, "suitesPassed" .= True
        , "checks" .= [object ["id" .= key, "derivation" .= path, "passed" .= True] | (key, path) <- p.checks]] | p <- context.phases]]

setAt :: [Text] -> Value -> Value -> Value
setAt [] value _ = value
setAt (key : keys) value (Object o) = Object (KM.insert (Key.fromText key) (setAt keys value (maybe Null id (KM.lookup (Key.fromText key) o))) o)
setAt _ _ value = value

goodLog :: Text
goodLog = "Running phase: checkPhase\nTest suite fixture-tests: PASS\n"

fakeRunner :: IORef [ProcessSpec] -> Text -> Text -> ExitCode -> ProcessRunner
fakeRunner calls system suiteLog status = ProcessRunner $ \spec -> do
    modifyIORef' calls (spec :)
    pure (Right (if take 1 spec.arguments == ["eval"] then ProcessResult ExitSuccess system ""
        else if take 1 spec.arguments == ["log"] then ProcessResult ExitSuccess suiteLog ""
        else ProcessResult status "[]" ""))

right :: Show err => Either err value -> IO value
right = either (assertFailure . show) pure

assertLeft :: Show a => Either e a -> Assertion
assertLeft = either (const (pure ())) (assertFailure . ("unexpected pass: " <>) . show)

assertRight :: Show e => Either e a -> Assertion
assertRight = either (assertFailure . show) (const (pure ()))
