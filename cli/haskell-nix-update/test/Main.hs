module Main (main) where

import Data.ByteString qualified as ByteString
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import HaskellNix.Update.Catalog (decodeFamilyCatalog, encodeFamilyCatalog)
import HaskellNix.Update.Cli
import HaskellNix.Update.PackageLock (decodePackageLock, encodePackageLock)
import HaskellNix.Update.Types (FamilyCatalog)
import Options.Applicative (ParserResult (..), defaultPrefs, execParserPure)
import Paths_haskell_nix_update (getDataFileName)
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (assertBool, assertFailure, testCase, (@?=))

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "haskell-nix-update"
    [ catalogTests,
      packageLockTests,
      cliTests
    ]

catalogTests :: TestTree
catalogTests =
  testGroup
    "family catalog"
    [ testCase "valid fixture round-trips canonically" $ do
        bytes <- readFixture "valid/config.json"
        catalog <- assertRight (decodeFamilyCatalog bytes)
        let encoded = encodeFamilyCatalog catalog
        assertTrailingNewline encoded
        decodeFamilyCatalog (LazyByteString.toStrict encoded) @?= Right catalog,
      testCase "duplicate families are rejected" $
        assertInvalidCatalog "invalid/config-duplicate-family.json",
      testCase "unknown override keys are rejected" $
        assertInvalidCatalog "invalid/config-unknown-override-key.json"
    ]

packageLockTests :: TestTree
packageLockTests =
  testGroup
    "package lock"
    [ testCase "valid fixture round-trips canonically" $ do
        catalog <- readValidCatalog
        bytes <- readFixture "valid/lock.json"
        packageLock <- assertRight (decodePackageLock catalog bytes)
        let encoded = encodePackageLock packageLock
        assertTrailingNewline encoded
        decodePackageLock catalog (LazyByteString.toStrict encoded) @?= Right packageLock,
      testGroup
        "invalid EP-1 fixtures"
        [ testCase fileName (assertInvalidLock fileName)
          | fileName <-
              [ "invalid/lock-absolute-path.json",
                "invalid/lock-parent-path.json",
                "invalid/lock-mismatched-family.json",
                "invalid/lock-mismatched-input.json",
                "invalid/lock-malformed-version.json",
                "invalid/lock-malformed-hash.json",
                "invalid/lock-duplicate-package.json"
              ]
        ]
    ]

cliTests :: TestTree
cliTests =
  testGroup
    "CLI parser"
    [ testCase "refresh accepts repeatable family scope and dry-run" $
        case execParserPure defaultPrefs parserInfo ["refresh", "--family", "alpha", "--family", "beta", "--dry-run"] of
          Success (Refresh RefreshOptions {families, dryRun}) -> do
            families @?= ["alpha", "beta"]
            dryRun @?= True
          other -> assertFailure ("unexpected parser result: " <> show other),
      testCase "check defaults to all families and offline" $
        case execParserPure defaultPrefs parserInfo ["check"] of
          Success (Check CheckOptions {families, online}) -> do
            families @?= []
            online @?= False
          other -> assertFailure ("unexpected parser result: " <> show other)
    ]

assertInvalidCatalog :: FilePath -> IO ()
assertInvalidCatalog fileName = do
  bytes <- readFixture fileName
  assertLeft (decodeFamilyCatalog bytes)

assertInvalidLock :: FilePath -> IO ()
assertInvalidLock fileName = do
  catalog <- readValidCatalog
  bytes <- readFixture fileName
  assertLeft (decodePackageLock catalog bytes)

readValidCatalog :: IO FamilyCatalog
readValidCatalog = readFixture "valid/config.json" >>= assertRight . decodeFamilyCatalog

readFixture :: FilePath -> IO ByteString.ByteString
readFixture relativePath = getDataFileName ("test/fixtures/" <> relativePath) >>= ByteString.readFile

assertRight :: Show error => Either error value -> IO value
assertRight = either (assertFailure . show) pure

assertLeft :: Show value => Either Text value -> IO ()
assertLeft result =
  case result of
    Left _ -> pure ()
    Right value -> assertFailure ("expected validation failure, decoded: " <> show value)

assertTrailingNewline :: LazyByteString.ByteString -> IO ()
assertTrailingNewline bytes =
  assertBool "canonical JSON must end in exactly one newline" $
    not (LazyByteString.null bytes)
      && LazyByteString.last bytes == 10
      && (LazyByteString.length bytes == 1 || LazyByteString.index bytes (LazyByteString.length bytes - 2) /= 10)
