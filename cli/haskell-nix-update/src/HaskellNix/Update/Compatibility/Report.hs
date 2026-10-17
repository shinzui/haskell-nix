{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Compatibility.Report (renderCompatibilityReport, checkCompatibilityReport, compatibilityImpact, renderCompatibilityImpact) where

import Data.Aeson (Value (..), object, (.=))
import Data.Aeson.Encode.Pretty (encodePretty)
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KM
import Data.ByteString.Lazy qualified as LBS
import Data.List (nub, sort)
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

-- Compare observed declarations rather than implementing version dispatch again.
-- Unchanged inputs preserve their evidence context, not an invented pass status.
compatibilityImpact :: CompatibilityContext -> CompatibilityContext -> Value
compatibilityImpact before after = object
    [ "schemaVersion" .= (1 :: Int)
    , "reportKind" .= ("declaration-impact" :: Text)
    , "beforeInputIdentity" .= field "inputIdentity" before.document
    , "afterInputIdentity" .= field "inputIdentity" after.document
    , "beforePolicyIdentity" .= field "policyIdentity" before.document
    , "afterPolicyIdentity" .= field "policyIdentity" after.document
    , "nativeEvidenceStatus" .= ("unverified" :: Text)
    , "receiptReuse" .= ("Exact receipt verification remains required; this report never rebinds a receipt to a new context." :: Text)
    , "entries" .= map describe keys
    ]
  where
    key entry = (entry.entryId, entry.package)
    old = [(key entry, entry) | entry <- before.entries]
    new = [(key entry, entry) | entry <- after.entries]
    keys = sort (nub (map fst old ++ map fst new))
    globalPolicyChanged = field "policyIdentity" before.document /= field "policyIdentity" after.document
    configuration context = value "configuration" context.document
    configurationChanges = ["configuration." <> name | name <- ["system", "channel", "ghc", "packageSet", "runtimeConfiguration"],
        field name (configuration before) /= field name (configuration after)]
    describe instanceKey@(entryId, package) =
        let previous = lookup instanceKey old
            current = lookup instanceKey new
            previousRow = maybe Null (.entryDocument) previous
            currentRow = maybe Null (.entryDocument) current
            status = maybe "absent" (.status)
            availability = ["instance" | previous == Nothing || current == Nothing]
            applicability = ["applicability" | status previous /= status current]
            inputChanges = ["inputs." <> name | name <- ["version", "sourceIdentity", "metadataIdentity", "derivation"],
                field name (value "inputs" previousRow) /= field name (value "inputs" currentRow)]
            capturedChanges = ["construction" | field "construction" previousRow /= field "construction" currentRow]
            declaredChanges = [name | name <- ["effects", "sourceGuard", "retirementCandidate", "unmetChecks", "required"],
                field name previousRow /= field name currentRow]
            semanticChanges = case (field "semanticIdentity" previousRow, field "semanticIdentity" currentRow) of
                (Just a, Just b) -> ["semanticPolicy" | a /= b]
                _ -> ["policy-impact-unknown-without-entry-identity" | globalPolicyChanged]
            changes = availability ++ applicability ++ configurationChanges ++ inputChanges ++ capturedChanges ++ declaredChanges ++ semanticChanges
            active = status current == "selected-unverified"
            requirements = if active then value "unmetChecks" currentRow else Null
            probe = if active && not (null changes) then object
                [ "command" .= (["haskell-nix-update", "compatibility", "verify", "--context", "NEW_NATIVE_PROBE_CONTEXT.json", "--entry", entryId, "--out", "NEW_OUTPUT_DIRECTORY"] :: [Text])
                , "requirements" .= requirements
                , "contextRequirement" .= ("Export the new selected recipe's native probe context; a declaration report is not executable verification evidence." :: Text)
                ] else Null
        in object
            [ "id" .= entryId, "package" .= package
            , "beforeStatus" .= status previous, "afterStatus" .= status current
            , "changedApplicability" .= (not (null applicability))
            , "declarationInputsUnchanged" .= null changes
            , "changeReasons" .= changes
            , "evidenceStatus" .= ("unverified" :: Text)
            , "requiredRevalidation" .= (if null changes then Null else requirements)
            , "nextProbe" .= probe
            ]
    field :: Text -> Value -> Maybe Value
    field name (Object fields) = KM.lookup (Key.fromText name) fields
    field _ _ = Nothing
    value name = maybe Null id . field name

renderCompatibilityImpact :: Bool -> CompatibilityContext -> CompatibilityContext -> Text
renderCompatibilityImpact json before after =
    (if json then "" else "Compatibility update impact (native evidence unverified)\n")
    <> decodeUtf8 (LBS.toStrict (encodePretty (compatibilityImpact before after)))
