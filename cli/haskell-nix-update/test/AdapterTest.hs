module AdapterTest (tests) where

import Data.ByteString.Char8 qualified as ByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Git (discoverPackages)
import HaskellNix.Update.Hackage
import HaskellNix.Update.Mori (MoriProject (..), decodeMoriProject)
import HaskellNix.Update.Nix (decodeLockedRevision)
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
      testCase "Hackage selects the greatest normal release" testHackageNormal,
      testCase "Hackage falls back when no release is normal" testHackageFallback,
      testCase "Hackage 404 means unpublished" testHackage404,
      testCase "flake.lock resolves a named root input revision" testFlakeLock,
      testCase "Git discovery keeps exactly one-directory-deep Cabal files" testGitDiscovery
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

testHackageNormal :: IO ()
testHackageNormal = do
  release <-
    assertRight
      ( decodeHackageRelease
          (PackageName "example")
          (ByteString.pack "{\"1.0\":{\"status\":\"normal\"},\"2.0\":{\"status\":\"deprecated\"},\"1.5\":{\"status\":\"normal\"}}")
      )
  release @?= HackageRelease {version = testVersion "1.5", usedFallback = False}

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
        "{\"root\":\"root\",\"nodes\":{\"root\":{\"inputs\":{\"example-src\":\"example-src\"}},\"example-src\":{\"locked\":{\"rev\":\"0123456789abcdef0123456789abcdef01234567\"}}}}"
    )
    @?= Right (GitRevision "0123456789abcdef0123456789abcdef01234567")

testGitDiscovery :: IO ()
testGitDiscovery = do
  packages <- assertRight =<< discoverPackages fakeRunner "/repo" revision
  packages
    @?= [ DiscoveredPackage
            { name = PackageName "example-package",
              path = "example-package",
              version = testVersion "1.2.3"
            }
        ]
  where
    revision = GitRevision "0123456789abcdef0123456789abcdef01234567"
    fakeRunner = ProcessRunner $ \ProcessSpec {arguments} ->
      pure $ case arguments of
        ["-C", "/repo", "ls-tree", "-r", "--name-only", _] ->
          success
            ( Text.unlines
                [ "root.cabal",
                  "example-package/example-package.cabal",
                  "nested/example/example.cabal",
                  "example-package/README.md"
                ]
            )
        ["-C", "/repo", "show", objectPath]
          | "example-package/example-package.cabal" `Text.isSuffixOf` Text.pack objectPath ->
              success
                "cabal-version: 3.0\nname: example-package\nversion: 1.2.3\nbuild-type: Simple\n"
        _ -> Left (UpdateError ("unexpected fake command: " <> Text.pack (show arguments)))

success :: Text -> Either UpdateError ProcessResult
success standardOutput =
  Right ProcessResult {exitCode = ExitSuccess, standardOutput, standardError = ""}

testVersion :: String -> Version
testVersion value = maybe (error ("invalid test version: " <> value)) id (simpleParsec value)

assertRight :: Show error => Either error value -> IO value
assertRight = either (assertFailure . show) pure
