module Main (main) where

import Control.Monad (unless)
import Data.Aeson (eitherDecode)
import Data.ByteString.Char8 qualified as BS
import Data.Map.Strict qualified as Map
import Data.Vector qualified as Vector
import Hinagata.Types (mkDatabaseName)
import Test.Heni (decodeManifest)
import Test.Heni.Hspec (heniHspec)
import Test.Heni.Tasty (heniMain)
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
  -- Both adapter libraries must be linked against this same Heni instance.
  heniHspec `seq` heniMain `seq` putStrLn "heni framework adapters: linked"
  where
    rejectDuplicate bytes = case decodeManifest bytes of
      Left problem | "duplicate JSON object key" `BS.isInfixOf` BS.pack (show problem) -> pure ()
      result -> fail ("Heni strict duplicate-key decoding failed: " <> either show (const "accepted") result)
