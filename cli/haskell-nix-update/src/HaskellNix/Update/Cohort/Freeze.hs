module HaskellNix.Update.Cohort.Freeze (
    parseCohortFreeze,
    normaliseCabalFreeze,
    renderCohortFreeze,
    FreezeHeader (..),
    FreezeDocument (..),
    parseFreezeDocument,
) where

import Control.Monad (foldM)
import Data.Char (isAlphaNum, isAscii, isDigit)
import Data.Map.Strict (Map)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Distribution.Pretty (prettyShow)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.Inventory (projectFields)
import HaskellNix.Update.Cohort.Model (parseVersion)

data FreezeHeader = FreezeHeader
    {indexState :: !Text, compiler :: !Text, haskellNixRevision :: !Text, command :: !Text}
    deriving stock (Eq, Show)

-- Generation retains flags and the cutoff rather than reconstructing them from
-- version constraints. The existing version-only APIs remain unchanged.
data FreezeDocument = FreezeDocument
    { freezeVersions :: !(Map Text Version)
    , freezeFlags :: !(Map Text (Map Text Bool))
    , freezeIndexState :: !Text
    }
    deriving stock (Eq, Show)

parseFreezeDocument :: Text -> Either Text FreezeDocument
parseFreezeDocument input = do
    fields <- foldM field [] (zip [1 :: Int ..] (Text.lines input))
    cutoff <- case [value | ("index-state", value) <- fields] of
        [value] -> case Text.words value of
            [timestamp] -> validateTimestamp timestamp
            ["hackage.haskell.org", timestamp] -> validateTimestamp timestamp
            _ -> Left "invalid cohort index-state"
        _ -> Left "cohort freeze must contain exactly one index-state"
    constraints <- case [value | ("constraints", value) <- fields] of
        [value] -> pure value
        _ -> Left "cohort freeze must contain exactly one constraints field"
    let pieces = map Text.strip (Text.splitOn "," constraints)
        entries = if not (null pieces) && Text.null (last pieces) then init pieces else pieces
    if any Text.null entries then Left "empty freeze constraint" else pure ()
    (versions, flags) <- foldM constraint (Map.empty, Map.empty) entries
    if Map.null versions then Left "cohort freeze contains no versions" else Right (FreezeDocument versions flags cutoff)
  where
    field acc (line, original)
        | Text.null stripped = Right acc
        | Text.isPrefixOf " " original || Text.isPrefixOf "\t" original = case acc of
            ("constraints", value) : rest -> Right (("constraints", value <> " " <> stripped) : rest)
            _ -> Left ("unexpected freeze continuation at line " <> Text.pack (show line))
        | otherwise = case Text.breakOn ":" stripped of
            (key, value) | key `elem` ["constraints", "index-state"] && not (Text.null value) -> Right ((key, Text.strip (Text.drop 1 value)) : acc)
            _ -> Left ("unknown freeze field at line " <> Text.pack (show line) <> ": " <> stripped)
      where
        stripped = Text.strip (fst (Text.breakOn "--" original))
    validateTimestamp timestamp = case parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" (Text.unpack timestamp) :: Maybe UTCTime of
        Just _ -> Right timestamp
        Nothing -> Left ("invalid cohort index-state: " <> timestamp)
    constraint (versions, flags) entry = case Text.words entry of
        [rawName, equality] | Just rawVersion <- Text.stripPrefix "==" equality -> addVersion rawName rawVersion
        [rawName, "==", rawVersion] -> addVersion rawName rawVersion
        rawName : assignments | not (null assignments) -> do
            name <- packageName rawName
            if Map.member name flags then Left ("duplicate freeze flags record for " <> name) else pure ()
            changes <- foldM (addFlag name) (Map.findWithDefault Map.empty name flags) assignments
            Right (versions, Map.insert name changes flags)
        _ -> Left ("invalid freeze constraint: " <> entry)
      where
        addVersion rawName rawVersion = do
            name <- packageName rawName
            if Text.null rawVersion || not (Text.all (\c -> isDigit c || c == '.') rawVersion)
                then Left ("invalid freeze version: " <> entry)
                else pure ()
            version <- parseVersion rawVersion
            if Map.member name versions then Left ("duplicate freeze version for " <> name) else Right (Map.insert name version versions, flags)
    packageName raw = case Text.stripPrefix "any." raw of
        Just name | not (Text.null name) && asciiAlphaNum (Text.head name) && Text.all (\c -> asciiAlphaNum c || c == '-') name -> Right name
        _ -> Left ("invalid qualified freeze package: " <> raw)
    addFlag name flags assignment = case Text.uncons assignment of
        Just (sign, flag)
            | sign `elem` ['+', '-'] && not (Text.null flag) && Text.all (\c -> asciiAlphaNum c || c `elem` ['_', '-']) flag ->
                if Map.member flag flags
                    then Left ("duplicate freeze flag for " <> name <> ": " <> flag)
                    else Right (Map.insert flag (sign == '+') flags)
        _ -> Left ("invalid freeze flag: " <> assignment)
    asciiAlphaNum c = isAscii c && isAlphaNum c

-- Reject malformed/version-range constraints instead of accepting partial data.
-- Cabal's flag assignments are the only constraint records deliberately dropped.
normaliseCabalFreeze :: Text -> Either Text (Map Text Version)
normaliseCabalFreeze input = foldM insert Map.empty entries
  where
    entries = [Text.strip item | ("constraints", value) <- projectFields input, item <- Text.splitOn "," value, not (Text.null (Text.strip item))]
    insert result entry = case Text.words entry of
        [name, equality] | Just version <- Text.stripPrefix "==" equality -> add result name version
        [name, "==", version] -> add result name version
        _ : flags | not (null flags) && all (\flag -> Text.isPrefixOf "+" flag || Text.isPrefixOf "-" flag) flags -> Right result
        _ -> Left ("invalid freeze constraint: " <> entry)
    add result qualifiedName rawVersion = do
        version <- parseVersion rawVersion
        let name = maybe qualifiedName id (Text.stripPrefix "any." qualifiedName)
        case Map.lookup name result of
            Just old | old /= version -> Left ("conflicting freeze versions for " <> name)
            _ -> Right (Map.insert name version result)

parseCohortFreeze :: Text -> Either Text (Map Text Version)
parseCohortFreeze input = do
    case [value | ("index-state", value) <- projectFields input] of
        [_] -> pure ()
        _ -> Left "cohort freeze must contain exactly one index-state"
    normaliseCabalFreeze input

renderCohortFreeze :: FreezeHeader -> Map Text Version -> Text
renderCohortFreeze FreezeHeader{indexState, compiler, haskellNixRevision, command} versions =
    Text.unlines
        ( [ "-- Generated by " <> command <> ". Do not edit."
          , "-- Compiler: " <> compiler
          , "-- haskell-nix: " <> haskellNixRevision
          , "index-state: hackage.haskell.org " <> indexState
          , "constraints:"
          ]
            <> zipWith (\prefix (name, version) -> prefix <> "any." <> name <> " ==" <> Text.pack (prettyShow version)) ("  " : repeat "  , ") (Map.toAscList versions)
        )
