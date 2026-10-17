module Main (main) where
import Control.Monad (unless)
import System.Environment (getEnv)
import System.Exit (die)
import System.Process (readProcess)
import ValidationFixture (value)
main :: IO ()
main = do
  unless (value == 42) (die "EP21_REPAIR_REQUIRED")
  client <- getEnv "EP21_SERVICE_CLIENT"
  response <- readProcess client ["client", "service-port"] ""
  unless (response == "EP21_LOCAL_SERVICE_OK\n") (die "EP21_SERVICE_UNAVAILABLE")
  putStrLn "EP21_STRICT_SERVICE_TESTS_PASSED"
