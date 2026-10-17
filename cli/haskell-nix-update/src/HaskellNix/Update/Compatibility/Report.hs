{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Compatibility.Report (renderCompatibilityReport, checkCompatibilityReport) where

import Data.Aeson.Encode.Pretty (encodePretty)
import Data.ByteString.Lazy qualified as LBS
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding (decodeUtf8)
import HaskellNix.Update.Compatibility.Types

renderCompatibilityReport :: Bool -> CompatibilityContext -> Text
renderCompatibilityReport json context
    | json = decodeUtf8 (LBS.toStrict (encodePretty context.document))
    | otherwise = Text.unlines
        ("Compatibility declaration report (native evidence unverified)" :
         [e.entryId <> "/" <> e.package <> ": " <> e.status | e <- context.entries])

checkCompatibilityReport :: CompatibilityContext -> Either Text Text
checkCompatibilityReport context
    | null context.problems = Right "Compatibility declarations valid; native evidence remains unverified"
    | otherwise = Left (Text.unlines context.problems)
