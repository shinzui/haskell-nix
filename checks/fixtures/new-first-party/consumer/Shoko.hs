module Main (main) where

import Data.Map.Strict qualified as Map
import Data.Text.IO qualified as Text
import Kafka.Version (librdkafkaVersion)
import Shoko.Adapter.Kafka (kafkaSettings)
import Shoko.Cli (runShokoCli)
import Shoko.Cli.Registry (Registry (..))

main :: IO ()
main = do
  -- Evaluating the C version function proves the installed native binding loads.
  Text.putStrLn ("librdkafka " <> librdkafkaVersion)
  case kafkaSettings "localhost:9092" Map.empty of
    Left problem -> fail (show problem)
    Right _ -> runShokoCli (Registry ["local"] [])
