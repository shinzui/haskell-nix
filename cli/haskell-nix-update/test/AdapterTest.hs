module AdapterTest (tests) where

import Data.Aeson (Value (..), encode, object, (.=))
import Data.Aeson qualified
import Data.Aeson.Key qualified as Key
import Data.ByteString.Lazy qualified as LazyByteString
import Data.ByteString.Char8 qualified as ByteString
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Git (discoverPackages)
import HaskellNix.Update.Hackage
import HaskellNix.Update.Mori (MoriProject (..), decodeMoriProject, locateMoriProject)
import HaskellNix.Update.Nix (decodeChannelRevision, decodeLockedRevision, decodeLockedSource, validatePackageSetSelection)
import HaskellNix.Update.Process
import HaskellNix.Update.Types
import System.Exit (ExitCode (..))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

tests :: TestTree
tests =
  testGroup
    "external adapters"
    [ testCase "Mori JSON exposes path and GitHub repositories" testMoriDecode,
      testCase "Mori can locate a project without repository metadata" testMoriLocateWithoutRepository,
      testCase "Mori rejects conflicting repository metadata" testMoriLocateMismatch,
      testCase "Hackage selects the greatest normal release" testHackageNormal,
      testCase "Hackage accepts live string release statuses" testHackageStringStatus,
      testCase "Hackage falls back when no release is normal" testHackageFallback,
      testCase "Hackage 404 means unpublished" testHackage404,
      testCase "flake.lock resolves a named root input revision" testFlakeLock,
      testCase "flake.lock decodes a complete immutable source descriptor" testFlakeLockedSource,
      testCase "flake.lock revision lookup supports Git and rejects short revisions" $ do
        decodeChannelRevision "example-src" (ByteString.pack (Text.unpack (Text.replace "\"github\"" "\"git\"" completeFlakeLock))) @?= Right (GitRevision "0123456789abcdef0123456789abcdef01234567")
        assertLeft (decodeLockedRevision "example-src" (ByteString.pack (Text.unpack (Text.replace "0123456789abcdef0123456789abcdef01234567" "0123456" completeFlakeLock)))),
      testCase "first-party revision lookup retains complete GitHub source validation" $ do
        assertLeft (decodeLockedRevision "example-src" (ByteString.pack (Text.unpack (Text.replace "\"github\"" "\"git\"" completeFlakeLock))))
        assertLeft (decodeLockedRevision "example-src" (ByteString.pack (Text.unpack (Text.replace "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" "invalid" completeFlakeLock)))),
      testCase "flake.lock resolves nested and recursive follows from its declared root" testNestedFollows,
      testCase "flake.lock rejects cyclic follows missing nodes and malformed paths" testInvalidFollows,
      testCase "package-set validation applies its Nix expression" testPackageSetValidationCommand,
      testCase "Git discovery keeps root and one-directory-deep Cabal files" testGitDiscovery
    ]

testMoriDecode :: IO ()
testMoriDecode = do
  MoriProject {path, githubRepositories} <-
    assertRight
      ( decodeMoriProject
          "{\"path\":\"/projects/example\",\"repositories\":[{\"github\":\"owner/example\"},{\"github\":null}]}"
      )
  path @?= "/projects/example"
  githubRepositories @?= ["owner/example"]

testMoriLocateWithoutRepository :: IO ()
testMoriLocateWithoutRepository = do
  MoriProject {path = projectPath} <- assertRight =<< locateMoriProject (moriRunner "[]") exampleFamily
  projectPath @?= "/projects/example"

testMoriLocateMismatch :: IO ()
testMoriLocateMismatch = do
  result <- locateMoriProject (moriRunner "[{\"github\":\"other/example\"}]") exampleFamily
  case result of
    Left _ -> pure ()
    Right project -> assertFailure ("expected repository mismatch, located: " <> show project)

exampleFamily :: FamilyConfig
exampleFamily =
  FamilyConfig
    { name = FamilyName "example",
      moriProject = "owner/example",
      github = "owner/example",
      githubInput = "example-src",
      packageOverrides = Map.empty,
      excludedPackages = Set.empty
    }

moriRunner :: Text -> ProcessRunner
moriRunner repositories = ProcessRunner $ \_ ->
  pure
    ( success
        ("{\"path\":\"/projects/example\",\"repositories\":" <> repositories <> "}")
    )

testHackageNormal :: IO ()
testHackageNormal = do
  release <-
    assertRight
      ( decodeHackageRelease
          (PackageName "example")
          (ByteString.pack "{\"1.0\":{\"status\":\"normal\"},\"2.0\":{\"status\":\"deprecated\"},\"1.5\":{\"status\":\"normal\"}}")
      )
  release @?= HackageRelease {version = testVersion "1.5", usedFallback = False}

testHackageStringStatus :: IO ()
testHackageStringStatus = do
  release <-
    assertRight
      ( decodeHackageRelease
          (PackageName "example")
          (ByteString.pack "{\"1.0\":\"normal\",\"2.0\":\"deprecated\"}")
      )
  release @?= HackageRelease {version = testVersion "1.0", usedFallback = False}

testHackageFallback :: IO ()
testHackageFallback = do
  release <-
    assertRight
      ( decodeHackageRelease
          (PackageName "example")
          (ByteString.pack "{\"1.0\":{\"status\":\"deprecated\"},\"2.0\":{\"status\":\"unpreferred\"}}")
      )
  release @?= HackageRelease {version = testVersion "2.0", usedFallback = True}

testHackage404 :: IO ()
testHackage404 = do
  let client = HttpClient (const (pure (Right HttpResponse {statusCode = 404, body = ""})))
  queryHackage client (PackageName "unpublished") >>= (@?= Right Nothing)

testFlakeLock :: IO ()
testFlakeLock =
  decodeLockedRevision
    "example-src"
    ( ByteString.pack
        (Text.unpack completeFlakeLock)
    )
    @?= Right (GitRevision "0123456789abcdef0123456789abcdef01234567")

testFlakeLockedSource :: IO ()
testFlakeLockedSource = do
  decodeLockedSource "example-src" (ByteString.pack (Text.unpack completeFlakeLock))
    @?= Right
      LockedSource
        { sourceType = "github",
          owner = "owner",
          repo = "example",
          rev = GitRevision "0123456789abcdef0123456789abcdef01234567",
          narHash = SriHash "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        }
  assertLeft
    ( decodeLockedSource
        "example-src"
        (ByteString.pack (Text.unpack (Text.replace "\"github\"" "\"gitlab\"" completeFlakeLock)))
    )

completeFlakeLock :: Text
completeFlakeLock =
  "{\"root\":\"root\",\"nodes\":{\"root\":{\"inputs\":{\"example-src\":\"example-src\"}},\"example-src\":{\"locked\":{\"type\":\"github\",\"owner\":\"owner\",\"repo\":\"example\",\"rev\":\"0123456789abcdef0123456789abcdef01234567\",\"narHash\":\"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"}}}}"

-- The root and channel node deliberately use nonstandard names.
lockFixture :: [(Text, Value)] -> ByteString.ByteString
lockFixture inputs = LazyByteString.toStrict $ encode $ object
  [ "root" .= ("entry" :: Text)
  , "nodes" .= object
      [ "entry" .= object ["inputs" .= object [Key.fromText key .= value | (key, value) <- inputs]]
      , "app" .= object ["inputs" .= object ["library" .= ("library-node" :: Text)]]
      , "library-node" .= object ["inputs" .= object ["channel" .= (["channel"] :: [Text])]]
      , "pinned" .= object ["locked" .= object
          [ "type" .= ("github" :: Text), "owner" .= ("shinzui" :: Text), "repo" .= ("haskell-nix" :: Text)
          , "rev" .= ("0123456789abcdef0123456789abcdef01234567" :: Text)
          , "narHash" .= ("sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" :: Text)
          ]]
      ]
  ]

testNestedFollows :: IO ()
testNestedFollows = do
  let inputs = [("application", String "app"), ("channel", String "pinned"), ("alias", toValue ["application", "library"]), ("root-alias", toValue [])]
      expected = Right (GitRevision "0123456789abcdef0123456789abcdef01234567")
  mapM_ (\path -> decodeLockedRevision path (lockFixture inputs) @?= expected)
    ["application/library/channel", "alias/channel", "root-alias/channel", "root-alias/root-alias/channel"]
  where
    toValue = Data.Aeson.toJSON :: [Text] -> Value

testInvalidFollows :: IO ()
testInvalidFollows = do
  let valid = [("channel", String "pinned")]
      cyclic = [("channel", Data.Aeson.toJSON (["other"] :: [Text])), ("other", Data.Aeson.toJSON (["channel"] :: [Text]))]
  mapM_ (\(path, inputs) -> assertLeft (decodeLockedRevision path (lockFixture inputs)))
    [ ("channel", cyclic)
    , ("channel", [("channel", String "absent-node")])
    , ("channel", [("channel", Data.Aeson.toJSON (["absent-input"] :: [Text]))])
    , ("absent-input", valid)
    , ("", valid)
    , ("/channel", valid)
    , ("channel/", valid)
    , ("channel", [("channel", Bool True)])
    , ("channel", [("channel", Data.Aeson.toJSON ([""] :: [Text]))])
    , ("channel", [("channel", Data.Aeson.toJSON (["bad/path"] :: [Text]))])
    ]

testPackageSetValidationCommand :: IO ()
testPackageSetValidationCommand = do
  captured <- newIORef Nothing
  let runner = ProcessRunner $ \spec -> do
        writeIORef captured (Just spec)
        pure (success "[]")
  validatePackageSetSelection runner "/repo" "candidate-set" >>= (@?= Right ())
  observed <- readIORef captured
  case observed of
    Just ProcessSpec {executable, arguments, workingDirectory} -> do
      executable @?= "nix"
      workingDirectory @?= Just "/repo"
      take 7 arguments @?= ["eval", "--impure", "--no-eval-cache", "--json", "--expr", validateExpression, "--apply"]
      last arguments @?= "validate: validate \"candidate-set\""
    Nothing -> assertFailure "package-set validation did not invoke Nix"
  where
    validateExpression =
      "packageSet: let flake = builtins.getFlake (toString ./.); constructor = flake.lib.mkFirstPartyPackageSet; validate = channel: let selected = constructor { inherit packageSet channel; }; in builtins.deepSeq selected.selections (builtins.deepSeq selected.selectedFamilies (builtins.attrNames selected.registry)); in map validate [\"github\" \"hackage\"]"

testGitDiscovery :: IO ()
testGitDiscovery = do
  packages <- assertRight =<< discoverPackages fakeRunner "/repo" revision
  packages
    @?= [ DiscoveredPackage
            { name = PackageName "example-package",
              path = "example-package",
              version = testVersion "1.2.3"
            },
          DiscoveredPackage
            { name = PackageName "example-root",
              path = ".",
              version = testVersion "4.0.0"
            }
        ]
  where
    revision = GitRevision "0123456789abcdef0123456789abcdef01234567"
    fakeRunner = ProcessRunner $ \ProcessSpec {arguments} ->
      pure $ case arguments of
        ["-C", "/repo", "ls-tree", "-r", "--name-only", _] ->
          success
            ( Text.unlines
                [ "example-root.cabal",
                  "example-package/example-package.cabal",
                  "nested/example/example.cabal",
                  "example-package/README.md"
                ]
            )
        ["-C", "/repo", "show", objectPath]
          | "example-package/example-package.cabal" `Text.isSuffixOf` Text.pack objectPath ->
              success
                "cabal-version: 3.0\nname: example-package\nversion: 1.2.3\nbuild-type: Simple\n"
          | ":example-root.cabal" `Text.isSuffixOf` Text.pack objectPath ->
              success
                "cabal-version: 3.0\nname: example-root\nversion: 4.0.0\nbuild-type: Simple\n"
        _ -> Left (UpdateError ("unexpected fake command: " <> Text.pack (show arguments)))

success :: Text -> Either UpdateError ProcessResult
success standardOutput =
  Right ProcessResult {exitCode = ExitSuccess, standardOutput, standardError = ""}

testVersion :: String -> Version
testVersion value = maybe (error ("invalid test version: " <> value)) id (simpleParsec value)

assertRight :: Show error => Either error value -> IO value
assertRight = either (assertFailure . show) pure

assertLeft :: Show value => Either error value -> IO ()
assertLeft result =
  case result of
    Left _ -> pure ()
    Right value -> assertFailure ("expected failure, got " <> show value)
