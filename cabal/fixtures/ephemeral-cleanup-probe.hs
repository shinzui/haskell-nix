{-# LANGUAGE GHC2024 #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE OverloadedStrings #-}

-- Compile against the actual helper in mori://shinzui/mori.
import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Data.Aeson (encode, object, (.=))
import Data.ByteString.Lazy.Char8 qualified as Bytes
import EphemeralPg qualified as Pg
import System.IO (hFlush, stdout)
import System.Posix.Process (getProcessID)
import TestSupport.EphemeralDatabase (startTracked)

main :: IO ()
main = do
  database <- startTracked >>= either (fail . show) pure
  pid <- getProcessID
  Bytes.putStrLn $
    encode $
      object
        [ "dataDirectory" .= database.dataDirectory,
          "connectionString" .= Pg.connectionString database,
          "consumerPid" .= (fromIntegral pid :: Int)
        ]
  hFlush stdout
  forever (threadDelay 1000000)
