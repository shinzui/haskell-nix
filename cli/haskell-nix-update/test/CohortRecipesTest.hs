{-# LANGUAGE OverloadedRecordDot #-}

module CohortRecipesTest (tests) where

import Data.Aeson (Value, object, (.=))
import Data.IORef
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.Recipes
import HaskellNix.Update.Cohort.Types
import HaskellNix.Update.Process
import Distribution.Version (mkVersion)
import System.Exit (ExitCode (..))
import Test.Tasty
import Test.Tasty.HUnit

tests :: TestTree
tests = testGroup "complete recipe conversion"
    [ testCase "flags are deterministic and source binding is portable" $ do
        arguments <- right (recipeArguments request)
        arguments @?=
            [ "--compiler=ghc-9.12.4", "--system=aarch64-darwin", "--sha256=", "--no-hpack"
            , "--src-expression=src", "--extra-arguments=src", "--flag=alpha", "--flag=-beta", "/tmp/selected.cabal"
            ]
    , testCase "compiler-provided and undeclared systems cannot enter generated coverage" $ do
        left (recipeArguments request {classifiedPackage = selected {packageClassification = CohortBoot}})
        left (recipeArguments request {system = "x86_64-darwin"})
    , testCase "conflicting component flags are rejected" $ do
        let package = selected.selectedPackage
        left (selectedPackageFlags "example" package {identities = package.identities <> [identity False]})
    , testCase "metadata drift fails before invoking the converter" $ do
        calls <- newIORef []
        result <- convertRecipe (runner calls "wrong" recipe) converter request
        left result
        observed <- readIORef calls
        map (.executable) observed @?= ["nix"]
    , testCase "metadata is checked again after conversion" $ do
        calls <- newIORef []
        hashes <- newIORef [hash, "changed"]
        result <- convertRecipe (changingRunner calls hashes recipe) converter request
        left result
        observed <- readIORef calls
        map (.executable) observed @?= ["nix", converter, "nix"]
    , testCase "scratch paths cannot leak into portable recipe output" $ do
        calls <- newIORef []
        result <- convertRecipe (runner calls hash "src = /tmp/selected.cabal;") converter request
        left result
    , testCase "a scratch directory cannot leak without the metadata filename" $ do
        calls <- newIORef []
        result <- convertRecipe (runner calls hash "src = /tmp/work/source;") converter request {metadataPath = "/tmp/work/selected.cabal"}
        left result
    , testCase "verified conversion returns stable newline-terminated bytes" $ do
        calls <- newIORef []
        result <- convertRecipe (runner calls hash recipe) converter request
        result @?= Right (recipe <> "\n")
        observed <- readIORef calls
        length observed @?= 3
    , testCase "a converter failure cannot produce an artifact" $ do
        let failing = ProcessRunner $ \spec -> pure $ Right $
                if spec.executable == "nix" then ProcessResult ExitSuccess hash ""
                else ProcessResult (ExitFailure 1) "" "unsupported Cabal format"
        result <- convertRecipe failing converter request
        left result
    ]

hash :: Text
hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

identity :: Bool -> Value
identity enabled = object
    [ "pkg-cabal-sha256" .= hash
    , "flags" .= Map.fromList [("alpha" :: Text, enabled), ("beta", False)]
    ]

selected :: ClassifiedPackage
selected = ClassifiedPackage (PlanPackage "1.0" Hackage [identity True] ["base"]) CohortGenerated

request :: RecipeConversion
request = RecipeConversion "example" selected (mkVersion [9,12,4]) "aarch64-darwin" "/tmp/selected.cabal"

converter :: FilePath
converter = "/fixed-pinned-tool/bin/cabal2nix"

recipe :: Text
recipe = "{ mkDerivation, src }: mkDerivation { inherit src; }"

runner :: IORef [ProcessSpec] -> Text -> Text -> ProcessRunner
runner calls selectedHash output = ProcessRunner $ \spec -> do
    modifyIORef' calls (<> [spec])
    pure (Right (ProcessResult ExitSuccess (if spec.executable == "nix" then selectedHash else output) ""))

changingRunner :: IORef [ProcessSpec] -> IORef [Text] -> Text -> ProcessRunner
changingRunner calls hashes output = ProcessRunner $ \spec -> do
    modifyIORef' calls (<> [spec])
    value <- if spec.executable == "nix" then atomicModifyIORef' hashes (\values -> case values of
        first:rest -> (rest, first)
        [] -> ([], "unexpected extra hash request")) else pure output
    pure (Right (ProcessResult ExitSuccess value ""))

right :: Show e => Either e a -> IO a
right = either (assertFailure . show) pure

left :: Show a => Either e a -> IO ()
left = either (const (pure ())) (assertFailure . ("expected failure: " <>) . show)
