module Main (main) where

import Combined (combined)
import Embedded (message)

main :: IO ()
main = putStr (show combined ++ ":" ++ message)
