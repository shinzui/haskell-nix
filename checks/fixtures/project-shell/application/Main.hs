{-# LANGUAGE ForeignFunctionInterface #-}

module Main (main) where

import Foreign.C.String (CString, peekCString)
import ProjectShell.Dependency (answer)

foreign import ccall unsafe "zlibVersion" zlibVersion :: IO CString

main :: IO ()
main = do
    version <- zlibVersion >>= peekCString
    putStrLn (show answer <> ":" <> version)
