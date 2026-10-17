module Main (main) where
import Control.Monad (unless)
import System.Exit (die)
import ValidationFixture (value)
main :: IO ()
main = do
  unless (value == 42) (die "EP21_REPAIR_REQUIRED")
  putStrLn "EP21_STRICT_TESTS_PASSED"
