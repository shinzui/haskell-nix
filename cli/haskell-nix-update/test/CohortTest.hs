{-# LANGUAGE OverloadedRecordDot #-}

module CohortTest (tests) where

import Data.Aeson (encode, object, (.=))
import Data.ByteString.Lazy qualified as LBS
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import HaskellNix.Update.Cohort.Impact (validateRetainedIdentities)
import HaskellNix.Update.Cohort.Inventory
import HaskellNix.Update.Cohort.Types
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

tests :: TestTree
tests =
    testGroup
        "cohort inventory"
        [ testCase "validates actual compiler provenance" $ do
            validatePlanCompiler "ghc-9.12.4" "{\"compiler-id\":\"ghc-9.12.4\"}" @?= Right ()
            assertLeft (validatePlanCompiler "ghc-9.12.4" "{\"compiler-id\":\"ghc-9.14.1\"}")
        , testCase "canonicalizes component identities independent of row order" $ do
            let row component = object ["id" .= component, "type" .= ("configured" :: Text.Text), "pkg-name" .= ("example" :: Text.Text), "pkg-version" .= ("1" :: Text.Text), "component-name" .= component, "pkg-src" .= object ["type" .= ("repo-tar" :: Text.Text)]]
                plan rows = LBS.toStrict (encode (object ["install-plan" .= rows]))
                a = row ("lib" :: Text.Text)
                b = row ("test:unit" :: Text.Text)
            first <- right (decodePlanVersions Set.empty (plan [a, b, a]))
            second <- right (decodePlanVersions Set.empty (plan [b, a]))
            first @?= second
            length (first Map.! "example").identities @?= 2
        , testCase "targeted updates reject unrelated metadata and flags" $ do
            let package flags = PlanPackage "1" Hackage [object ["flags" .= flags]] []
                old = Map.singleton "example" (package False)
                new = Map.singleton "example" (package True)
            assertLeft (validateRetainedIdentities old new ["other"])
            assertLeft (validateRetainedIdentities old Map.empty ["other"])
            validateRetainedIdentities old new ["example"] @?= Right ()
        , testCase "classifies sources and retains transitive edges" $ do
            let bytes =
                    LBS.toStrict $
                        encode $
                            object
                                [ "install-plan"
                                    .= [ object ["id" .= ("base-id" :: Text.Text), "type" .= ("pre-existing" :: Text.Text), "pkg-name" .= ("base" :: Text.Text), "pkg-version" .= ("4.21.2.0" :: Text.Text)]
                                       , object ["id" .= ("library-id" :: Text.Text), "type" .= ("configured" :: Text.Text), "pkg-name" .= ("library" :: Text.Text), "pkg-version" .= ("1.0" :: Text.Text), "pkg-src" .= object ["type" .= ("repo-tar" :: Text.Text)], "depends" .= ["base-id" :: Text.Text]]
                                       , object ["id" .= ("fork-id" :: Text.Text), "type" .= ("configured" :: Text.Text), "pkg-name" .= ("fork" :: Text.Text), "pkg-version" .= ("2.0" :: Text.Text), "pkg-src" .= object ["type" .= ("source-repo" :: Text.Text)]]
                                       , object ["id" .= ("app-id" :: Text.Text), "type" .= ("configured" :: Text.Text), "pkg-name" .= ("app" :: Text.Text), "pkg-version" .= ("0.1" :: Text.Text), "pkg-src" .= object ["type" .= ("local" :: Text.Text)]]
                                       , object ["id" .= ("installed-id" :: Text.Text), "type" .= ("pre-existing" :: Text.Text), "pkg-name" .= ("aeson" :: Text.Text), "pkg-version" .= ("2.2.5.1" :: Text.Text)]
                                       ]
                                ]
            result <- right (decodePlanVersions (Set.singleton "base") bytes)
            Map.keys result @?= ["aeson", "base", "fork", "library"]
            (result Map.! "base").source @?= Boot
            (result Map.! "aeson").source @?= Hackage
            (result Map.! "fork").source @?= SourcePin
            (result Map.! "library").dependencies @?= ["base"]
        , testCase "rejects unknown sources and unresolved dependency edges" $ do
            assertLeft (decodePlanVersions Set.empty "{\"install-plan\":[{\"id\":\"x\",\"type\":\"configured\",\"pkg-name\":\"x\",\"pkg-version\":\"1\",\"pkg-src\":{\"type\":\"unknown\"}}]}")
            assertLeft (decodePlanVersions Set.empty "{\"install-plan\":[{\"id\":\"x\",\"type\":\"configured\",\"pkg-name\":\"x\",\"pkg-version\":\"1\",\"depends\":[\"missing\"],\"pkg-src\":{\"type\":\"repo-tar\"}}]}")
        , testCase "conditional tests, benchmarks and executable tools are inventoried" $
            withSystemTempDirectory "cohort-test" $ \root -> do
                TextIO.writeFile (root </> "example.cabal") $
                    Text.unlines
                        [ "cabal-version: 3.4"
                        , "name: example"
                        , "version: 1"
                        , "build-type: Simple"
                        , "flag alternative"
                        , "  default: False"
                        , "library"
                        , "  build-depends: base >=4"
                        , "  if flag(alternative)"
                        , "    build-depends: text >=2"
                        , "  else"
                        , "    build-depends: bytestring >=0.12"
                        , "test-suite unit"
                        , "  type: exitcode-stdio-1.0"
                        , "  main-is: Main.hs"
                        , "  build-depends: tasty >=1.5"
                        , "benchmark performance"
                        , "  type: exitcode-stdio-1.0"
                        , "  main-is: Main.hs"
                        , "  build-depends: criterion >=1"
                        , "  build-tool-depends: happy:happy >=1.20"
                        ]
                bounds <- readDeclaredBounds root ["example.cabal"] >>= right
                assertBool "both conditional alternatives" (all (\n -> any (\b -> b.package == n && b.condition /= "always") bounds) ["text", "bytestring"])
                assertBool "test dependency" (any (\b -> b.package == "tasty" && b.component == "test:unit") bounds)
                assertBool "benchmark tool" (any (\b -> b.package == "happy" && b.tool == Just "happy" && b.component == "benchmark:performance") bounds)
        , testCase "project constraints retain versions, ignore flags and nested fields" $
            withSystemTempDirectory "cohort-project" $ \root -> do
                TextIO.writeFile (root </> "cabal.project") "constraints:\n  crypton >=1.1,\n  dhall -use-http-client-tls\npackage example\n  constraints: fake <1\n"
                bounds <- readProjectConstraints (root </> "cabal.project") >>= right
                map (\b -> b.package) bounds @?= ["crypton"]
        ]

right :: (Show e) => Either e a -> IO a
right = either (assertFailure . show) pure

assertLeft :: (Show a) => Either e a -> Assertion
assertLeft (Left _) = pure ()
assertLeft (Right result) = assertFailure ("expected failure: " <> show result)
