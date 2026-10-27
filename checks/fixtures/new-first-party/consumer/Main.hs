module Main (main) where

import Control.Exception (throwIO, try)
import Control.Monad (unless)
import Data.Aeson (eitherDecode)
import Data.ByteString.Char8 qualified as BS
import Data.Map.Strict qualified as Map
import Data.Vector qualified as Vector
import Hinagata.Types (mkDatabaseName)
import System.Exit (ExitCode (..))
import Test.Heni (decodeManifest)
import Test.Heni.Hspec (heniHspec)
import Test.Heni.Tasty (heniMain)
import Test.Hspec qualified as Hspec
import Test.Tasty.HUnit qualified as Tasty
import TypeSafe.Wire

main :: IO ()
main = do
  case mkDatabaseName "" of
    Left _ -> putStrLn "hinagata invalid identifier: rejected"
    Right _ -> fail "Hinagata accepted an invalid SQL identifier"
  let request =
        SystemOneRequest
          jevLatest
          (ContentText "offline check")
          (Vector.singleton ("valid", QuestionNoul (NoulQuestion Nothing Nothing)))
          Map.empty
  unless (eitherDecode (encodeSystemOneRequest request) == Right request) (fail "TypeSafe request round trip failed")
  putStrLn "typesafe request codec: passed"
  mapM_
    rejectDuplicate
    [ "{\"schemaVersion\":1,\"schemaVersion\":1}",
      "{\"schemaVersion\":1,\"commands\":{\"a\":{},\"\\u0061\":{}}}"
    ]
  putStrLn "heni duplicate keys: rejected"
  -- Execute both public framework entrypoints against this same Heni instance.
  runFramework (heniHspec (Hspec.it "rejects duplicate JSON keys" (rejectDuplicate "{\"a\":1,\"a\":2}")))
  runFramework (heniMain (Tasty.testCase "rejects escaped duplicate keys" (rejectDuplicate "{\"a\":1,\"\\u0061\":2}")))
  putStrLn "heni framework adapters: executed"
  where
    rejectDuplicate :: BS.ByteString -> IO ()
    rejectDuplicate bytes = case decodeManifest bytes of
      Left problem | "duplicate JSON object key" `BS.isInfixOf` BS.pack (show problem) -> pure ()
      result -> fail ("Heni strict duplicate-key decoding failed: " <> either show (const "accepted") result)

-- Framework runners may signal success through exitSuccess.
runFramework :: IO () -> IO ()
runFramework action = do
  result <- try action
  case result of
    Right () -> pure ()
    Left ExitSuccess -> pure ()
    Left failure -> throwIO (failure :: ExitCode)
