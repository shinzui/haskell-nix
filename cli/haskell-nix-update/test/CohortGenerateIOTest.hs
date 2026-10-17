{-# LANGUAGE OverloadedRecordDot #-}

module CohortGenerateIOTest (tests) where

import Data.Aeson (encode, object, (.=))
import Control.Exception (IOException, try)
import System.Directory (createDirectory)
import Data.ByteString (ByteString)
import Data.ByteString qualified as BS
import HaskellNix.Update.Cohort.Context (decodeGenerationContext)
import HaskellNix.Update.Cohort.Generate (classifyCohort)
import Data.ByteString.Lazy qualified as LBS
import Distribution.Version (Version)
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time (UTCTime, defaultTimeLocale, parseTimeOrError)
import HaskellNix.Update.Cohort.GenerateIO
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.Model (parseVersion)
import HaskellNix.Update.Cohort.Types
import HaskellNix.Update.Hackage
import HaskellNix.Update.Process
import HaskellNix.Update.Types
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

tests :: TestTree
tests = testGroup "live cohort generation"
    [ testCase "policy schema is strict" $ do
        assertLeft (decodeGenerationPolicy "{\"schemaVersion\":2,\"excluded\":{},\"sourcePinned\":{}}")
        assertLeft (decodeGenerationPolicy "{\"schemaVersion\":1,\"excluded\":{},\"sourcePinned\":{},\"ignore\":[]}")
        decodeGenerationPolicy policyBytes @?= Right (GenerationPolicy Map.empty Map.empty)
    , testCase "cached source still resolves new metadata at the exact cutoff" $ do
        calls <- newIORef []
        result <- resolveGeneratedEntries (recording calls) revisions (time "2026-10-16T00:00:00Z") (classified "1" hashB) (Map.singleton "example" (sampleVersion "1", SriHash sri))
        entries <- right result
        (entries Map.! "example").selectedRevision.revisionNumber @?= 1
        readIORef calls >>= (@?= [])
    , testCase "an earlier cutoff does not reuse the later revision" $ do
        calls <- newIORef []
        result <- resolveGeneratedEntries (recording calls) revisions (time "2026-10-14T00:00:00Z") (classified "1" hashA) (Map.singleton "example" (sampleVersion "1", SriHash sri))
        entries <- right result
        (entries Map.! "example").selectedRevision.revisionNumber @?= 0
        readIORef calls >>= (@?= [])
    , testCase "a conflicting metadata hash fails before source prefetch" $ do
        calls <- newIORef []
        result <- resolveGeneratedEntries (recording calls) revisions (time "2026-10-16T00:00:00Z") (classified "1" hashA) Map.empty
        assertLeft result
        readIORef calls >>= (@?= [])
    , testCase "a changed version cannot reuse the old tarball hash" $ do
        calls <- newIORef []
        result <- resolveGeneratedEntries (recording calls) revisions (time "2026-10-16T00:00:00Z") (classified "2" hashB) (Map.singleton "example" (sampleVersion "1", SriHash "wrong-old-hash"))
        entries <- right result
        (entries Map.! "example").unpackedHash @?= SriHash sri
        observed <- readIORef calls
        map (.arguments) observed @?= [["store", "prefetch-file", "--json", "--unpack", "https://hackage.haskell.org/package/example-2/example-2.tar.gz"]]
    , testCase "non-generated records do not contact Hackage" $ do
        calls <- newIORef []
        let blocked = HttpClient (\_ -> assertFailure "unexpected Hackage call" >> pure (Left (UpdateError "unexpected")))
        result <- resolveGeneratedEntries (recording calls) blocked (time "2026-10-16T00:00:00Z") (Map.map (\p -> p{packageClassification = CohortFirstParty}) (classified "1" hashB)) Map.empty
        result @?= Right Map.empty
        readIORef calls >>= (@?= [])
    , testCase "transient transport failures retry without changing the cutoff" $ do
        attempts <- newIORef (0 :: Int)
        calls <- newIORef []
        let client = HttpClient $ \url -> do
                count <- atomicModifyIORef' attempts (\n -> (n + 1, n))
                if count == 0 then pure (Left (UpdateError "temporary transport failure")) else revisions.performGet url
        result <- resolveGeneratedEntries (recording calls) client (time "2026-10-16T00:00:00Z") (classified "1" hashB) (Map.singleton "example" (sampleVersion "1", SriHash sri))
        entries <- right result
        (entries Map.! "example").selectedRevision.revisionNumber @?= 1
        readIORef attempts >>= (@?= 2)
    , testCase "output aliases cannot overwrite a solve input" $ do
        calls <- newIORef []
        result <- runGenerate (recording calls) revisions Map.empty (GenerateOptions "input.freeze" "policy.json" "./input.freeze" "boot.nix" False Nothing ".")
        assertLeft result
        readIORef calls >>= (@?= [])
    , testCase "exported generation context repeats exactly and check never rewrites drift" $
        withSystemTempDirectory "cohort-context-export" $ \root -> do
            let freeze = root </> "cohort.freeze"
                out = root </> "versions.nix"
                boot = root </> "boot.nix"
                contextFile = root </> "context.json"
                policyFile = root </> "policy.json"
                options = GenerateOptions freeze policyFile out boot False (Just contextFile) root
                runner = ProcessRunner $ \spec -> pure $ Right (ProcessResult ExitSuccess (case spec.arguments of
                    "build" : _ -> "/mock/compiler\n"
                    ["list", "--global", "--simple-output"] -> "base-4.21.2.0\n"
                    ["eval", "--json", "--file", _] -> "{\"packages\":{}}"
                    "eval" : _ -> hashA
                    _ -> "unexpected") "")
                blocked = HttpClient (\_ -> assertFailure "unexpected download for first-party ownership" >> pure (Left (UpdateError "unexpected")))
                generate opts = runGenerate runner blocked (Map.singleton "example" (sampleVersion "1")) opts
            BS.writeFile (root </> "flake.lock") lockBytes
            TextIO.writeFile freeze "-- Compiler: ghc-9.12.4\nindex-state: 2026-10-16T00:00:00Z\nconstraints: any.example ==1\n"
            LBS.writeFile (root </> "cohort-sources.json") (encode (Map.map (.selectedPackage) (classified "1" hashB)))
            BS.writeFile policyFile policyBytes
            _ <- generate options >>= right
            first <- traverse BS.readFile [out, boot, contextFile]
            context <- BS.readFile contextFile >>= right . decodeGenerationContext
            classifications <- right (classifyCohort context)
            (classifications Map.! "example").packageClassification @?= CohortFirstParty
            _ <- generate options >>= right
            traverse BS.readFile [out, boot, contextFile] >>= (@?= first)
            _ <- generate options{checkOnly = True} >>= right
            let blockedOutput = root </> "blocked-output"
            createDirectory blockedOutput
            TextIO.writeFile (blockedOutput </> "sentinel") "preserve directory\n"
            failed <- try (generate options{bootOutputPath = blockedOutput})
            case failed of
                Left (_ :: IOException) -> pure ()
                Right result -> assertFailure ("expected publication rename failure: " <> show result)
            traverse BS.readFile [out, boot, contextFile] >>= (@?= first)
            TextIO.readFile (blockedOutput </> "sentinel") >>= (@?= "preserve directory\n")
            originalFreeze <- BS.readFile freeze
            let concurrent = ProcessRunner $ \spec -> do
                    case spec.arguments of
                        "build" : _ -> BS.appendFile freeze "-- concurrent writer\n"
                        _ -> pure ()
                    runner.runProcess spec
            runGenerate concurrent blocked (Map.singleton "example" (sampleVersion "1")) options >>= assertLeft
            traverse BS.readFile [out, boot, contextFile] >>= (@?= first)
            BS.writeFile freeze originalFreeze
            TextIO.writeFile contextFile "stale context\n"
            generate options{checkOnly = True} >>= assertLeft
            TextIO.readFile contextFile >>= (@?= "stale context\n")
            traverse BS.readFile [out, boot] >>= (@?= take 2 first)
    , testCase "failed live metadata lookup preserves both published files" $
        withSystemTempDirectory "cohort-generation" $ \root -> do
            let freeze = root </> "cohort.freeze"
                out = root </> "versions.nix"
                boot = root </> "boot.nix"
                policyFile = root </> "policy.json"
            BS.writeFile (root </> "flake.lock") lockBytes
            TextIO.writeFile freeze "-- Compiler: ghc-9.12.4\nindex-state: 2026-10-16T00:00:00Z\nconstraints: any.example ==1\n"
            LBS.writeFile (root </> "cohort-sources.json") (encode (Map.map (.selectedPackage) (classified "1" hashB)))
            LBS.writeFile policyFile (LBS.fromStrict policyBytes)
            TextIO.writeFile out "{ packages = {}; }\n"
            TextIO.writeFile boot "{ ghc = \"previous\"; }\n"
            let runner = ProcessRunner $ \spec -> pure $ Right (ProcessResult ExitSuccess (case spec.arguments of
                    "build" : _ -> "/mock/compiler\n"
                    ["list", "--global", "--simple-output"] -> "base-4.21.2.0\n"
                    ["eval", "--json", "--file", _] -> "{\"packages\":{}}"
                    _ -> "unexpected") "")
            TextIO.writeFile (root </> "context.json") "previous context\n"
            result <- runGenerate runner (HttpClient (\_ -> pure (Right (HttpResponse 404 "missing")))) Map.empty (GenerateOptions freeze policyFile out boot False (Just (root </> "context.json")) root)
            assertLeft result
            TextIO.readFile (root </> "context.json") >>= (@?= "previous context\n")
            TextIO.readFile out >>= (@?= "{ packages = {}; }\n")
            TextIO.readFile boot >>= (@?= "{ ghc = \"previous\"; }\n")
    ]

policyBytes :: ByteString
policyBytes = "{\"schemaVersion\":1,\"excluded\":{},\"sourcePinned\":{}}"

classified :: Text -> Text -> Map.Map Text ClassifiedPackage
classified number hash = Map.singleton "example" (ClassifiedPackage (PlanPackage number Hackage [object ["pkg-cabal-sha256" .= hash, "pkg-src-sha256" .= hashA, "flags" .= object []]] []) CohortGenerated)

hashA, hashB, sri :: Text
hashA = Text.replicate 64 "a"
hashB = Text.replicate 64 "b"
sri = "sha256-" <> Text.replicate 43 "a" <> "="

revisions :: HttpClient
revisions = HttpClient $ \_ -> pure (Right (HttpResponse 200 (LBS.toStrict (encode
    [ object ["number" .= (0 :: Int), "time" .= ("2026-10-13T00:00:00Z" :: Text), "sha256" .= hashA]
    , object ["number" .= (1 :: Int), "time" .= ("2026-10-15T00:00:00Z" :: Text), "sha256" .= hashB]
    ]))))

recording :: IORef [ProcessSpec] -> ProcessRunner
recording calls = ProcessRunner $ \spec -> do
    modifyIORef' calls (<> [spec])
    pure (Right (ProcessResult ExitSuccess ("{\"hash\":\"" <> sri <> "\"}") ""))

time :: String -> UTCTime
time = parseTimeOrError True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ"

sampleVersion :: Text -> Version
sampleVersion text = either (error . Text.unpack) id (parseVersion text)

right :: (Show e) => Either e a -> IO a
right = either (\err -> assertFailure (show err) >> error "unreachable") pure

assertLeft :: (Show a) => Either e a -> IO ()
assertLeft value = case value of
    Left _ -> pure ()
    Right found -> assertFailure (show found)

lockBytes :: ByteString
lockBytes = "{\"root\":\"root\",\"nodes\":{\"root\":{\"inputs\":{\"nixpkgs\":\"nixpkgs\"}},\"nixpkgs\":{\"locked\":{\"rev\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}}}}"
