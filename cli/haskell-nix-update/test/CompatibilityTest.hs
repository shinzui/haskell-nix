{-# LANGUAGE OverloadedRecordDot #-}

module CompatibilityTest (tests) where

import Data.Aeson hiding (Success)
import Data.Aeson qualified as Aeson
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.Text (Text)
import Data.Text.Encoding (encodeUtf8)
import HaskellNix.Update.Compatibility.Types
import HaskellNix.Update.Compatibility.Report
import HaskellNix.Update.Compatibility.Cli
import HaskellNix.Update.Cli (Command (..), parserInfo)
import Options.Applicative (ParserResult (..), defaultPrefs, execParserPure, renderFailure)
import Paths_haskell_nix_update (getDataFileName)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit
import System.Exit (ExitCode (..))

tests :: TestTree
tests = testGroup "compatibility declaration report"
    [ testCase "Nix export is accepted without claiming native success" $ do
        context <- fixture >>= right . decodeCompatibilityContext
        checkCompatibilityReport context @?= Right "Compatibility declarations valid; native evidence remains unverified"
        assertBool "source entries exported" (not (null context.entries))
        assertBool "no declaration is verified" (all (\e -> e.status `elem` ["selected-unverified", "inactive-row", "inactive-scope"]) context.entries)
    , testCase "JSON output preserves complete Nix facts" $ do
        bytes <- fixture
        context <- right (decodeCompatibilityContext bytes)
        eitherDecodeStrict' (encodeUtf8 (renderCompatibilityReport True context)) @?= Right context.document
    , testCase "forged evidence and guard results are rejected" $ do
        mapM_ (\(field, value) -> mutateEntry field value >>= invalid)
            [("evidenceStatus", String "passed"), ("sourceGuard", String "passed"), ("status", String "passed")]
    , testCase "captured inputs must agree with their construction boundary" $ do
        value <- fixtureValue >>= mapRows withCapture
        _ <- right (decodeCompatibilityContext (LBS.toStrict (encode value)))
        wrong <- mapRows (set "inputs" (object ["version" .= ("0.0.1" :: Text), "sourceIdentity" .= ("wrong-source" :: Text), "metadataIdentity" .= ("wrong-metadata" :: Text), "derivation" .= ("wrong.drv" :: Text)])) value
        invalid wrong
    , testCase "captured source constructors cannot claim stock pre-repair facts" $ do
        value <- fixtureValue >>= mapRows withCapture
        wrong <- mapRows (\row -> case row of
            Object fields -> case KM.lookup "construction" fields of
                Just observation -> set "construction" (set "stage" (String "source-constructor") observation) row
                _ -> row
            _ -> row) value
        invalid wrong
    , testCase "captured enabled tests cannot hide behind a suppression declaration" $ do
        value <- fixtureValue >>= mapRows withCapture
        wrong <- mapRows (\row -> case row of
            Object fields -> case KM.lookup "construction" fields of
                Just (Object observation) -> case KM.lookup "after" observation of
                    Just after -> let changed = set "effective" (object ["testsEnabled" .= True, "boundsRelaxed" .= True, "configureFlags" .= ([] :: [Text])]) after
                        in set "construction" (Object (KM.insert "after" changed observation)) row
                    _ -> row
                _ -> row
            _ -> row) value
        invalid wrong
    , testCase "required evidence cannot disappear from diagnostics" $ do
        value <- fixtureValue
        invalid (set "requiredEvidence" (toJSON (["legacy-kioku-core-v1"] :: [Text])) value)
    , testCase "a missing selected instance cannot satisfy required evidence" $ do
        value <- fixtureValue
        let changed = set "entries" (toJSON ([] :: [Value]))
                    $ set "requiredEvidence" (toJSON (["legacy-kioku-core-v1"] :: [Text]))
                    $ set "problems" (toJSON (["required entry has no selected instance: legacy-kioku-core-v1"] :: [Text])) value
        context <- right (decodeCompatibilityContext (LBS.toStrict (encode changed)))
        case checkCompatibilityReport context of Left _ -> pure (); Right _ -> assertFailure "missing evidence passed"
    , testCase "wrong schema, duplicate entries and missing input identities fail" $ do
        value <- fixtureValue
        invalid (set "schemaVersion" (Number 2) value)
        invalid (set "inputIdentity" (String "not-a-hash") value)
        case value of
            Object fields -> case KM.lookup "entries" fields of
                Just entries -> do
                    rows <- right (fromJSONList entries)
                    invalid (set "entries" (toJSON (rows ++ rows)) value)
                _ -> assertFailure "fixture missing entries"
            _ -> assertFailure "fixture is not an object"
        mutateEntry "inputs" (object ["version" .= ("0.8.0.2" :: Text)]) >>= invalid
    , testCase "report and check parsers require explicit context" $ do
        case execParserPure defaultPrefs parserInfo ["compatibility", "report", "--context", "selected.json", "--json"] of
            Success (Compatibility (CompatibilityReport "selected.json" True)) -> pure ()
            other -> assertFailure (show other)
        case execParserPure defaultPrefs parserInfo ["compatibility", "check"] of
            Failure failure -> snd (renderFailure failure "haskell-nix-update") @?= ExitFailure 2
            other -> assertFailure (show other)
    ]
  where
    fixture = getDataFileName "test/fixtures/valid/compatibility-report.json" >>= BS.readFile
    fixtureValue = fixture >>= right . eitherDecodeStrict'
    set key value (Object fields) = Object (KM.insert key value fields)
    set _ _ value = value
    withCapture row@(Object fields) = case KM.lookup "inputs" fields of
        Just inputs -> let snapshot = set "effective" (object ["testsEnabled" .= False, "boundsRelaxed" .= True, "configureFlags" .= ([] :: [Text])]) inputs
            in set "construction" (object ["stage" .= ("compatibility-row" :: Text), "before" .= snapshot, "after" .= snapshot]) row
        _ -> row
    withCapture value = value
    mapRows f document = case document of
        Object fields -> case KM.lookup "entries" fields of
            Just encoded -> do
                rows <- right (fromJSONList encoded)
                pure (set "entries" (toJSON (map f rows)) document)
            _ -> assertFailure "fixture has no entries"
        _ -> assertFailure "fixture is not an object"
    mutateEntry field value = do
        document <- fixtureValue
        case document of
            Object fields -> case KM.lookup "entries" fields of
                Just encoded -> do
                    rows <- right (fromJSONList encoded)
                    pure (set "entries" (toJSON (map (set field value) rows)) document)
                _ -> assertFailure "missing fixture entries"
            _ -> assertFailure "invalid fixture"
    invalid value = case decodeCompatibilityContext (LBS.toStrict (encode value)) of
        Left _ -> pure ()
        Right context -> assertFailure (show context)
    fromJSONList value = case fromJSON value of
        Error err -> Left err
        Aeson.Success rows -> Right (rows :: [Value])
    right :: Show err => Either err value -> IO value
    right = either (assertFailure . show) pure
