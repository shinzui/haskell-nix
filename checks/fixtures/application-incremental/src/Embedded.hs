{-# LANGUAGE TemplateHaskell #-}
module Embedded (message) where

import Language.Haskell.TH (stringE)
import Language.Haskell.TH.Syntax (addDependentFile, runIO)

message :: String
message = $(do
  addDependentFile "message.txt"
  content <- runIO (readFile "message.txt")
  stringE content)
