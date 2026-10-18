{-# LANGUAGE OverloadedRecordDot #-}

module CohortRecipeArtifactsTest (tests) where

import Control.Exception (IOException, try)
import Control.Monad (forM_)
import Data.Aeson (Value (..), encode, object, eitherDecodeStrict', (.=))
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
import HaskellNix.Update.Cohort.RecipeArtifacts (ArtifactOptions (..), runArtifacts, decodeRecipeContext, recipeContextValue)
import HaskellNix.Update.Cohort.Types (PlanPackage (..), PackageSource (..))
import HaskellNix.Update.Process
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
                    [ object ["schemaVersion" .= (3 :: Int), "generationContext" .= generation, "configuration" .= configuration "aarch64-darwin", "packages" .= packageInputs]
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
    , testCase "typed recipe context round trips Hackage and fixed sources" $ do
        let checkContext root _ = do
                bytes <- BS.readFile (root </> "context.json")
                original <- either assertFailure pure (eitherDecodeStrict' bytes)
                context <- right (decodeRecipeContext bytes)
                value <- right (recipeContextValue context)
                value @?= original
                decoded <- right (decodeRecipeContext (LBS.toStrict (encode value)))
                decoded @?= context
        fixture checkContext
        pinFixture checkContext
    , testCase "format two inventories component roles and rejects unverified role output" $
        fixture $ \root options -> do
            bytes <- BS.readFile (root </> "context.json")
            original <- either assertFailure pure (eitherDecodeStrict' bytes)
            value <- case original of
                Object fields -> pure (Object (KeyMap.insert "schemaVersion" (Number 2) fields))
                _ -> assertFailure "expected context object"
            context <- right (decodeRecipeContext (LBS.toStrict (encode value)))
            recipeContextValue context @?= Right value
            LBS.writeFile (root </> "context.json") (encode value)
            _ <- runArtifacts runner options >>= right
            first <- artifacts root
            manifest <- BS.readFile (root </> "out/manifest.json") >>= either assertFailure pure . eitherDecodeStrict'
            case manifest of
                Object fields -> do
                    KeyMap.lookup "schemaVersion" fields @?= Just (Number 2)
                    case KeyMap.lookup "packages" fields of
                        Just (Object packages) -> case KeyMap.lookup "example" packages of
                            Just (Object package) -> KeyMap.lookup "dependenciesByComponent" package @?= Just (object
                                ["libraryHaskellDepends" .= (["base"] :: [Text]), "testHaskellDepends" .= (["HUnit"] :: [Text])])
                            _ -> assertFailure "missing package"
                        _ -> assertFailure "missing package inventory"
                _ -> assertFailure "invalid manifest"
            let malformed = ProcessRunner $ \spec ->
                    if spec.executable == "nix" && take 2 spec.arguments == ["--offline", "eval"]
                        then pure (Right (ProcessResult ExitSuccess "{\"metadata\":{\"name\":\"example\",\"version\":\"1\",\"revision\":\"1\"},\"dependenciesByComponent\":{\"libraryHaskellDepends\":[false]}}" "")) else runner.runProcess spec
            runArtifacts malformed options >>= left
            artifacts root >>= (@?= first)
            forM_ [("wrong-package", "1"), ("example", "2")] $ \(name, revision) -> do
                let wrongIdentity = ProcessRunner $ \spec ->
                        if spec.executable == "nix" && take 2 spec.arguments == ["--offline", "eval"]
                            then pure (Right (ProcessResult ExitSuccess
                                ("{\"metadata\":{\"name\":\"" <> name <> "\",\"version\":\"1\",\"revision\":\"" <> revision <> "\"},\"dependenciesByComponent\":{}}") "")) else runner.runProcess spec
                runArtifacts wrongIdentity options >>= left
                artifacts root >>= (@?= first)
    , testCase "fixed source metadata is verified without inventing a Hackage revision" $
        pinFixture $ \root options -> do
            _ <- runArtifacts (pinRunner root) options >>= right
            first <- artifacts root
            _ <- runArtifacts (pinRunner root) options{checkOnly = True} >>= right
            artifacts root >>= (@?= first)
            value <- BS.readFile (root </> "out/manifest.json") >>= either assertFailure pure . eitherDecodeStrict'
            case value of
                Object manifest -> do
                    case KeyMap.lookup "packages" manifest of
                        Just (Object packages) -> case KeyMap.lookup "example" packages of
                            Just (Object package) -> KeyMap.lookup "revision" package @?= Just Null
                            _ -> assertFailure "missing pinned package"
                        _ -> assertFailure "missing package manifest"
                    case KeyMap.lookup "generationContext" manifest of
                        Just generation -> generation @?= either (error . show) id (generationContextValue pinGenerationContext)
                        _ -> assertFailure "missing original solved source context"
                _ -> assertFailure "invalid artifact manifest"
    , testCase "source pin subdirectories bind the exact archive member" $
        fixture $ \root options -> do
            context <- pinContextAt "https://github.com/shinzui/example" "packages/example" >>= right
            LBS.writeFile (root </> "context.json") (encode context)
            let inspect = ProcessRunner $ \spec -> do
                    if spec.executable == extractorExecutable && spec.arguments /= ["--version"]
                        then spec.arguments @?= ["--extract", "--to-stdout", "--file", root </> "source.tar.gz", "--", "example-" <> replicate 40 'a' <> "/packages/example/example.cabal"]
                        else pure ()
                    (pinRunner root).runProcess spec
            _ <- runArtifacts inspect options >>= right
            pure ()
    , testCase "source pin declaration and extracted metadata drift leave publication intact" $
        pinFixture $ \root options -> do
            _ <- runArtifacts (pinRunner root) options >>= right
            first <- artifacts root
            original <- BS.readFile (root </> "context.json")
            changed <- pinContext "https://github.com/shinzui/other" >>= right
            LBS.writeFile (root </> "context.json") (encode changed)
            runArtifacts (pinRunner root) options >>= left
            artifacts root >>= (@?= first)
            BS.writeFile (root </> "context.json") original
            let altered = ProcessRunner $ \spec ->
                    if spec.executable == extractorExecutable && spec.arguments /= ["--version"]
                        then pure (Right (ProcessResult ExitSuccess "changed source metadata\n" "")) else (pinRunner root).runProcess spec
            runArtifacts altered options >>= left
            artifacts root >>= (@?= first)
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
        "--offline" : "eval" : _ -> "{\"metadata\":{\"name\":\"example\",\"version\":\"1\",\"revision\":\"1\"},\"dependenciesByComponent\":{\"libraryHaskellDepends\":[\"base\"],\"testHaskellDepends\":[\"HUnit\"]}}"
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

pinGenerationContext :: GenerationContext
pinGenerationContext = pinGenerationContextAt "."

pinGenerationContextAt :: Text -> GenerationContext
pinGenerationContextAt subdirectory = generationContext
    { sources = Map.singleton "example" (PlanPackage "1" SourcePin [object
        ["pkg-src-sha256" .= hash, "flags" .= object [], "component-name" .= ("lib" :: Text)
        , "pkg-src" .= object ["type" .= ("source-repo" :: Text), "source-repo" .= object
            (["type" .= ("git" :: Text), "tag" .= Text.replicate 40 "a", "location" .= ("https://github.com/shinzui/example" :: Text)]
                <> ["subdir" .= subdirectory | subdirectory /= "."])]]] ["base"])
    , policy = GenerationPolicy Map.empty (Map.singleton "example" (OwnedPolicy "Fixed source fixture" "mori://shinzui/haskell-nix"))
    }

pinContext :: Text -> IO (Either Text Value)
pinContext repository = pinContextAt repository "."

pinContextAt :: Text -> Text -> IO (Either Text Value)
pinContextAt repository subdirectory = pure $ do
    generation <- generationContextValue (pinGenerationContextAt subdirectory)
    let cfg = case configuration "aarch64-darwin" of
            Object fields -> Object (KeyMap.insert "extractor" (object
                ["derivation" .= ("/nix/store/fixed-tar.drv" :: Text), "output" .= ("/nix/store/fixed-tar" :: Text), "version" .= ("tar (GNU tar) 1.35" :: Text)]) fields)
            other -> other
        packages = object ["example" .= object
            [ "metadataPath" .= ("example.cabal" :: Text), "archivePath" .= ("source.tar.gz" :: Text)
            , "unpackedHash" .= ("sha256-" <> Text.replicate 43 "a" <> "="), "revision" .= Null
            , "nativeArguments" .= object []
            , "sourcePin" .= object ["repository" .= repository, "revision" .= Text.replicate 40 "a", "subdirectory" .= subdirectory
                , "archiveSha256" .= Text.replicate 64 "b", "metadataSha256" .= hash]
            ]]
    pure (object ["schemaVersion" .= (1 :: Int), "generationContext" .= generation, "configuration" .= cfg, "packages" .= packages])

pinFixture :: (FilePath -> ArtifactOptions -> IO a) -> IO a
pinFixture action = fixture $ \root options -> do
    context <- pinContext "https://github.com/shinzui/example" >>= right
    LBS.writeFile (root </> "context.json") (encode context)
    action root options

extractorExecutable :: FilePath
extractorExecutable = "/nix/store/fixed-tar/bin/tar"

pinRunner :: FilePath -> ProcessRunner
pinRunner root = ProcessRunner $ \spec ->
    if spec.executable == "nix" && spec.arguments == ["--offline", "derivation", "show", "/nix/store/fixed-tar.drv"]
        then pure (Right (ProcessResult ExitSuccess "{\"fixed-tar.drv\":{\"outputs\":{\"out\":{\"path\":\"/nix/store/fixed-tar\"}}}}" ""))
    else if spec.executable == "nix" && spec.arguments == ["hash", "file", "--type", "sha256", "--base16", root </> "source.tar.gz"]
        then pure (Right (ProcessResult ExitSuccess (Text.replicate 64 "b") ""))
    else if spec.executable == extractorExecutable
        then pure (Right (ProcessResult ExitSuccess (if spec.arguments == ["--version"] then "tar (GNU tar) 1.35\n" else "metadata\n") ""))
    else runner.runProcess spec
