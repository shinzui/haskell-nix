{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Revision (selectRevision, revisionCacheKey) where

import Data.Char (isHexDigit)
import Data.List (sortOn)
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Time (UTCTime)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.GenerationTypes (HackageRevision (..))

-- Cache metadata by cutoff independently of the unpacked source hash cache.
revisionCacheKey :: Text -> Version -> UTCTime -> (Text, Version, UTCTime)
revisionCacheKey package version cutoff = (package, version, cutoff)

selectRevision :: UTCTime -> Text -> [HackageRevision] -> Either Text HackageRevision
selectRevision cutoff expectedHash revisions = do
    if null revisions then Left "no Hackage metadata revisions" else pure ()
    if any (\r -> r.revisionNumber < 0 || Text.length r.revisionSha256 /= 64 || not (Text.all isHexDigit r.revisionSha256)) revisions
        then Left "invalid Hackage metadata revision"
        else pure ()
    if Set.size (Set.fromList (map (.revisionNumber) revisions)) /= length revisions
        then Left "duplicate Hackage metadata revision number"
        else pure ()
    case reverse (sortOn (.revisionNumber) (filter (\r -> r.revisionTime <= cutoff) revisions)) of
        [] -> Left "no Hackage metadata revision at the recorded index-state"
        selected : _
            | Text.toLower selected.revisionSha256 == Text.toLower expectedHash -> Right selected
            | otherwise -> Left "selected Hackage metadata hash differs from the cohort source manifest"
