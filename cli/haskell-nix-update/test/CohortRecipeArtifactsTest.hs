{-# LANGUAGE OverloadedRecordDot #-}

module CohortRecipeArtifactsTest (tests) where

import Control.Exception (IOException, try)
import Control.Monad (forM_)
import Data.Aeson (Value (..), encode, object, (.=))
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString qualified as BS
import Data.ByteString.Lazy qualified as LBS
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Distribution.Version (mkVersion)
import HaskellNix.Update.Cohort.Context
import HaskellNix.Update.Cohort.Freeze
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.RecipeArtifacts
import HaskellNix.Update.Cohort.Types (PlanPackage (..), PackageSource (..))
import HaskellNix.Update.Process
import HaskellNix.Update.Types (UpdateError (..))
import System.Directory (createDirectory)
import System.Exit (ExitCode (..))
import System.FilePath ((</>))
import System.IO.Temp (withSystemTempDirectory)
import Test.Tasty
import Test.Tasty.HUnit

tests :: TestTree
tests = testGroup "staged complete recipe artifacts"
    [ testCase "repeat conversion and offline check preserve exact publication" $
        fixture $ \root options -> do
            _ <- runArtifacts runner options >>= right
            first <- artifacts root
            _ <- runArtifacts runner options >>= right
            artifacts root >>= (@?= first)
            _ <- runArtifacts runner options{checkOnly = True} >>= right
            artifacts root >>= (@?= first)
            TextIO.appendFile (root </> "out/extension.nix") "# drift\n"
            drift <- artifacts root
            runArtifacts runner options{checkOnly = True} >>= left
            artifacts root >>= (@?= drift)
    , testCase "unknown schema, missing coverage and unsupported system never promote" $
        fixture $ \root options -> do
            _ <- runArtifacts runner options >>= right
            first <- artifacts root
            generation <- right (generationContextValue generationContext)
            let invalid =
                    [ object ["schemaVersion" .= (2 :: Int), "generationContext" .= generation, "configuration" .= configuration "aarch64-darwin", "packages" .= packageInputs]
                    , object ["schemaVersion" .= (1 :: Int), "generationContext" .= generation, "configuration" .= configuration "aarch64-darwin", "packages" .= object []]
                    , object ["schemaVersion" .= (1 :: Int), "generationContext" .= generation, "configuration" .= configuration "x86_64-darwin", "packages" .= packageInputs]
                    , object ["schemaVersion" .= (1 :: Int), "generationContext" .= generation, "configuration" .= configuration "aarch64-darwin", "packages" .= packageInputsAt hash "2026-10-18T00:00:00Z"]
                    , object ["schemaVersion" .= (1 :: Int), "generationContext" .= generation, "configuration" .= configuration "aarch64-darwin", "packages" .= packageInputsAt (Text.replicate 64 "b") "2026-10-15T00:00:00Z"]
                    ]
            forM_ invalid $ \value -> do
                LBS.writeFile (root </> "context.json") (encode value)
                runArtifacts runner options >>= left
                artifacts root >>= (@?= first)
    , testCase "concurrent metadata or context changes preserve accepted artifacts" $
        fixture $ \root options -> do
            _ <- runArtifacts runner options >>= right
            first <- artifacts root
            forM_ [root </> "example.cabal", root </> "source.tar.gz", root </> "context.json"] $ \path -> do
                original <- BS.readFile path
                let mutating = ProcessRunner $ \spec -> do
                        if spec.executable == converterExecutable && spec.arguments /= ["--version"]
                            then BS.appendFile path "\n" else pure ()
                        runner.runProcess spec
                runArtifacts mutating options >>= left
                artifacts root >>= (@?= first)
                BS.writeFile path original
    , testCase "conversion failure and unowned output cannot replace user files" $
        fixture $ \root options -> do
            _ <- runArtifacts runner options >>= right
            first <- artifacts root
            let failing = ProcessRunner $ \spec ->
                    if spec.executable == converterExecutable && spec.arguments /= ["--version"]
                        then pure (Right (ProcessResult (ExitFailure 1) "" "invalid Cabal")) else runner.runProcess spec
            runArtifacts failing options >>= left
            artifacts root >>= (@?= first)
            let changedArchive = ProcessRunner $ \spec ->
                    if spec.executable == "nix" && take 2 spec.arguments == ["hash", "file"] && last spec.arguments == root </> "source.tar.gz"
                        then pure (Right (ProcessResult ExitSuccess (Text.replicate 64 "b") "")) else runner.runProcess spec
                changedUnpacked = ProcessRunner $ \spec ->
                    if spec.executable == "nix" && take 3 spec.arguments == ["--offline", "store", "prefetch-file"]
                        then pure (Right (ProcessResult ExitSuccess "{\"hash\":\"wrong-unpacked-hash\"}" "")) else runner.runProcess spec
            runArtifacts changedArchive options >>= left
            runArtifacts changedUnpacked options >>= left
            artifacts root >>= (@?= first)
            createDirectory (root </> "unowned")
            TextIO.writeFile (root </> "unowned/sentinel") "preserve user file\n"
            result <- try (runArtifacts runner options{outputDirectory = root </> "unowned"})
            case result of
                Left (_ :: IOException) -> pure ()
                Right value -> assertFailure ("expected refusal to replace unowned directory: " <> show value)
            TextIO.readFile (root </> "unowned/sentinel") >>= (@?= "preserve user file\n")
    , testCase "metadata containment and exact converter output are required" $
        fixture $ \root options -> do
            let wrongOutput = ProcessRunner $ \spec ->
                    if spec.executable == "nix" && take 3 spec.arguments == ["--offline", "derivation", "show"]
                        then pure (Right (ProcessResult ExitSuccess "{\"outputs\":{\"outputs\":{\"bin\":{\"path\":\"wrong-output\"}}}}" ""))
                        else runner.runProcess spec
            runArtifacts wrongOutput options >>= left
            generation <- right (generationContextValue generationContext)
            let input = case packageInputs of
                    Object fields -> case KeyMap.lookup "example" fields of
                        Just (Object package) -> Object (KeyMap.insert "example"
                            (Object (KeyMap.insert "metadataPath" (String "out/example.cabal") package)) fields)
                        _ -> packageInputs
                    _ -> packageInputs
                context = object ["schemaVersion" .= (1 :: Int), "generationContext" .= generation, "configuration" .= configuration "aarch64-darwin", "packages" .= input]
            createDirectory (root </> "out")
            TextIO.writeFile (root </> "out/example.cabal") "metadata\n"
            LBS.writeFile (root </> "context.json") (encode context)
            runArtifacts runner options >>= left
            TextIO.readFile (root </> "out/example.cabal") >>= (@?= "metadata\n")
    ]

fixture :: (FilePath -> ArtifactOptions -> IO a) -> IO a
fixture action = withSystemTempDirectory "complete-recipe-artifacts" $ \root -> do
    generation <- right (generationContextValue generationContext)
    LBS.writeFile (root </> "context.json") (encode (object
        ["schemaVersion" .= (1 :: Int), "generationContext" .= generation, "configuration" .= configuration "aarch64-darwin", "packages" .= packageInputs]))
    TextIO.writeFile (root </> "example.cabal") "metadata\n"
    TextIO.writeFile (root </> "source.tar.gz") "archive\n"
    action root (ArtifactOptions (root </> "context.json") (root </> "out") False)

generationContext :: GenerationContext
generationContext = GenerationContext
    (FreezeDocument (Map.singleton "example" (mkVersion [1])) Map.empty "2026-10-16T00:00:00Z")
    (Map.singleton "example" (PlanPackage "1" Hackage [object
        ["pkg-cabal-sha256" .= hash, "pkg-src-sha256" .= hash, "flags" .= object [], "component-name" .= ("lib" :: Text)]] ["base"]))
    Map.empty Map.empty (GenerationPolicy Map.empty Map.empty) Map.empty Map.empty Map.empty

configuration :: Text -> Value
configuration system = object
    [ "compilerKey" .= ("ghc9124" :: Text), "compilerVersion" .= ("9.12.4" :: Text)
    , "system" .= system, "channel" .= ("github" :: Text), "nixpkgsRevision" .= Text.replicate 40 "a"
    , "policyIdentity" .= hash, "converter" .= object
        ["derivation" .= ("/nix/store/fixed-converter.drv" :: Text), "output" .= output, "version" .= ("cabal2nix 2.21.3" :: Text)]
    ]

packageInputs :: Value
packageInputs = packageInputsAt hash "2026-10-15T00:00:00Z"

packageInputsAt :: Text -> Text -> Value
packageInputsAt metadataHash timestamp = object ["example" .= object
    [ "metadataPath" .= ("example.cabal" :: Text), "archivePath" .= ("source.tar.gz" :: Text), "unpackedHash" .= ("sha256-" <> Text.replicate 43 "a" <> "=")
    , "revision" .= object ["number" .= (1 :: Int), "sha256" .= metadataHash, "time" .= timestamp]
    , "nativeArguments" .= object []
    ]]

hash, output :: Text
hash = Text.replicate 64 "a"
output = "/nix/store/fixed-converter-bin"

converterExecutable :: FilePath
converterExecutable = Text.unpack output </> "bin/cabal2nix"

runner :: ProcessRunner
runner = ProcessRunner $ \spec -> pure $ Right $ ProcessResult ExitSuccess
    (if spec.executable == "nix" then case spec.arguments of
        "--offline" : "store" : "prefetch-file" : _ -> "{\"hash\":\"sha256-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=\"}"
        "--offline" : "derivation" : "show" : _ -> "{\"derivations\":{\"fixed-converter.drv\":{\"outputs\":{\"bin\":{\"path\":\"fixed-converter-bin\"}}}}}"
        _ -> hash
     else if spec.arguments == ["--version"] then "cabal2nix 2.21.3\n"
     else "{ mkDerivation, src }: mkDerivation { pname = \"example\"; inherit src; }\n") ""

artifacts :: FilePath -> IO [BS.ByteString]
artifacts root = traverse (BS.readFile . (root </>)) ["out/.recipe-artifacts", "out/manifest.json", "out/extension.nix", "out/packages/example.nix"]

right :: Show e => Either e a -> IO a
right = either (assertFailure . show) pure

left :: Show a => Either e a -> IO ()
left = either (const (pure ())) (assertFailure . ("expected failure: " <>) . show)
