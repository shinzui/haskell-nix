{-# LANGUAGE OverloadedRecordDot #-}

module CohortGenerateTest (tests) where

import Data.Aeson (Value (..), object, (.=))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import Data.Time (UTCTime, defaultTimeLocale, parseTimeM)
import Distribution.Version (Version, mkVersion)
import HaskellNix.Update.Cohort.Freeze
import HaskellNix.Update.Cohort.Generate
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Cohort.Render
import HaskellNix.Update.Cohort.Revision
import HaskellNix.Update.Cohort.Types (PackageSource (..), PlanPackage (..))
import HaskellNix.Update.Types (SriHash (..))
import Paths_haskell_nix_update (getDataFileName)
import Test.Tasty
import Test.Tasty.HUnit

tests :: TestTree
tests =
    testGroup
        "cohort generation"
        [ testCase "shared valid fixture preserves flags and repository cutoff" $ do
            parsed <- fixture "valid" >>= right . parseFreezeDocument
            Map.keys parsed.freezeVersions @?= ["aeson", "blake3"]
            parsed.freezeFlags @?= Map.singleton "blake3" (Map.fromList [("portable", True), ("avx2", False)])
            parsed.freezeIndexState @?= "2026-10-06T21:15:24Z"
        , testCase "shared malformed fixtures fail" $ mapM_ (\name -> fixture name >>= assertLeft . parseFreezeDocument) ["duplicate", "range", "garbage", "duplicate-flags", "empty-entry", "flags-only"]
        , testCase "duplicate flags, fields and interior empty constraints fail" $
            mapM_
                (assertLeft . parseFreezeDocument)
                [ freeze "any.example ==1, any.example +foo -foo"
                , freeze "any.example ==1,, any.other ==2"
                , freeze "any.example ==1" <> "index-state: 2026-10-06T21:15:24Z\n"
                , freeze "any.example ==1" <> "constraints: any.other ==2\n"
                , "index-state: garbage\nconstraints: any.example ==1\n"
                , freeze "example ==1"
                , freeze "any.éxample ==1"
                , freeze "any.example ==1, any.example +éflag"
                ]
        , testCase "old version-only normalization remains compatible" $ normaliseCabalFreeze (freeze "any.example ==1, any.example +foo, any.example ==1") @?= Right (Map.singleton "example" testVersion)
        , testCase "all matching identities and explicit policy permit sameAsBase" $ do
            result <- right (classifyCohort sameBase)
            (result Map.! "example").packageClassification @?= CohortSameAsBase
        , testCase "metadata source flags and policy drift require generated override" $ do
            let different = package [identity (Text.replicate 64 "b") False]
                flagChange = package [identity hash True]
                sourceChange = package [object ["pkg-cabal-sha256" .= hash, "pkg-src-sha256" .= Text.replicate 64 "b"]]
            mapM_
                (\ctx -> right (classifyCohort ctx) >>= \result -> (result Map.! "example").packageClassification @?= CohortGenerated)
                [sameBase{basePackages = Map.singleton "example" different}, sameBase{basePackages = Map.singleton "example" flagChange}, sameBase{basePackages = Map.singleton "example" sourceChange}, sameBase{basePolicyIdentities = Map.singleton "example" "different"}, sameBase{basePolicyIdentities = Map.empty}]
        , testCase "component identity ordering and duplicate edges are canonical" $ do
            let one = identity hash False
                two = identity hash True
                selected = (package [one, two]){dependencies = ["base", "text"]}
                base = selected{identities = [two, one, one], dependencies = ["text", "base", "base"]}
            result <- right (classifyCohort sameBase{sources = Map.singleton "example" selected, basePackages = Map.singleton "example" base})
            (result Map.! "example").packageClassification @?= CohortSameAsBase
            (result Map.! "example").selectedPackage @?= selected
        , testCase "coverage missing identity ownership and testVersion conflicts fail" $
            mapM_
                (assertLeft . classifyCohort)
                [ context{sources = Map.empty}
                , context{sources = Map.insert "unfrozen" normal context.sources}
                , context{sources = Map.singleton "example" (package [])}
                , context{sources = Map.singleton "example" normal{version = "2"}}
                , context{firstParty = Map.singleton "example" (mkVersion [2])}
                , context{shippedBoot = Map.singleton "example" testVersion}
                , context{sources = Map.singleton "example" (package [object []])}
                , context{policy = GenerationPolicy (Map.singleton "example" owner) (Map.singleton "example" owner)}
                ]
        , testCase "boot and first-party packages are owned explicitly" $ do
            boot <- right (classifyCohort context{sources = Map.singleton "example" normal{source = Boot}, shippedBoot = Map.singleton "example" testVersion})
            (boot Map.! "example").packageClassification @?= CohortBoot
            first <- right (classifyCohort context{firstParty = Map.singleton "example" testVersion})
            (first Map.! "example").packageClassification @?= CohortFirstParty
        , testCase "unfrozen source pins retain all five explicit source identities" $ do
            let names = ["cmark-gfm", "dhall", "hs-opentelemetry-instrumentation-servant", "typeid-hs-pg-migrate", "typeid-hs-sql"]
                pinned = normal{source = SourcePin, identities = [pinIdentity]}
                ctx = context{sources = Map.union context.sources (Map.fromList [(name, pinned) | name <- names]), policy = GenerationPolicy Map.empty (Map.fromList [(name, owner) | name <- names])}
            result <- right (classifyCohort ctx)
            Map.size result @?= 6
            mapM_
                ( \name -> do
                    (result Map.! name).packageClassification @?= CohortSourcePinned owner
                    (result Map.! name).selectedPackage.identities @?= [pinIdentity]
                )
                names
            assertLeft (classifyCohort ctx{policy = GenerationPolicy Map.empty Map.empty})
            assertLeft (classifyCohort ctx{sources = Map.insert "dhall" pinned{identities = [identity hash False]} ctx.sources})
        , testCase "policy requires reason and canonical owner" $ mapM_ (\bad -> assertLeft (classifyCohort context{policy = GenerationPolicy (Map.singleton "example" bad) Map.empty})) [OwnedPolicy "" "mori://shinzui/haskell-nix", OwnedPolicy "owned" "bare-owner", OwnedPolicy "owned" "mori://x"]
        , testCase "revision cutoff is inclusive and independent of input order" $ do
            let revisions = [revision 2 future, revision 0 past, revision 1 cutoff]
            selectRevision cutoff hash revisions @?= Right (revision 1 cutoff)
            selectRevision cutoff hash (reverse revisions) @?= Right (revision 1 cutoff)
            assertBool "cutoff included in cache key" (revisionCacheKey "example" testVersion cutoff /= revisionCacheKey "example" testVersion future)
        , testCase "metadata mismatch duplicate revisions invalid hashes and future-only rows fail" $
            mapM_
                assertLeft
                [ selectRevision cutoff (Text.replicate 64 "b") [revision 0 past]
                , selectRevision cutoff hash [revision 0 past, revision 0 cutoff]
                , selectRevision cutoff hash [revision (-1) past]
                , selectRevision cutoff hash [(revision 0 past){revisionSha256 = "invalid"}]
                , selectRevision cutoff hash [revision 1 future]
                , selectRevision cutoff hash []
                ]
        , testCase "deterministic renderer retains flags and complete source provenance" $ do
            classified <- right (classifyCohort context{document = testDocument{freezeFlags = Map.singleton "example" (Map.singleton "portable" True)}, sources = Map.singleton "example" (package [identity hash True])})
            output <- right (renderCohortVersions metadata testDocument{freezeFlags = Map.singleton "example" (Map.singleton "portable" True)} classified entries)
            assertBool "metadata hash" (hash `Text.isInfixOf` output)
            assertBool "flags retained" ("portable" `Text.isInfixOf` output)
            assertBool "explicit unrevised null" ("revision = null" `Text.isInfixOf` output)
            output2 <- right (renderCohortVersions metadata testDocument{freezeFlags = Map.singleton "example" (Map.singleton "portable" True)} (Map.fromList (reverse (Map.toList classified))) entries)
            output2 @?= output
        , testCase "classification rejects freeze flags that differ from recorded identities" $
            assertLeft (classifyCohort context{document = testDocument{freezeFlags = Map.singleton "example" (Map.singleton "portable" True)}})
        , testCase "renderer canonicalizes component and dependency ordering" $ do
            let selected = normal{identities = [identity hash True, identity hash False], dependencies = ["text", "base"]}
                reversed = selected{identities = reverse selected.identities, dependencies = reverse selected.dependencies}
            first <- right (classifyCohort context{sources = Map.singleton "example" selected})
            second <- right (classifyCohort context{sources = Map.singleton "example" reversed})
            renderCohortVersions metadata testDocument first entries @?= renderCohortVersions metadata testDocument second entries
        , testCase "renderer rejects missing extra version metadata cutoff and hash proof" $ do
            classified <- right (classifyCohort context)
            mapM_
                (assertLeft . renderCohortVersions metadata testDocument classified)
                [Map.empty, Map.insert "extra" entry entries, Map.singleton "example" entry{generatedVersion = mkVersion [2]}, Map.singleton "example" entry{selectedRevision = (revision 0 past){revisionSha256 = Text.replicate 64 "b"}}, Map.singleton "example" entry{selectedRevision = revision 1 future}, Map.singleton "example" entry{unpackedHash = SriHash "garbage"}, Map.singleton "example" entry{unpackedHash = SriHash ("sha256-" <> Text.replicate 44 "=")}]
            assertLeft (renderCohortVersions metadata{generationIndexState = "2026-10-07T00:00:00Z"} testDocument classified entries)
        , testCase "Nix interpolation in policy data is escaped" $ do
            classified <- right (classifyCohort context{policy = GenerationPolicy (Map.singleton "example" owner{policyReason = "${unsafe}\n\"quoted\""}) Map.empty})
            output <- right (renderCohortVersions metadata testDocument classified Map.empty)
            assertBool "escaped interpolation" ("\\${unsafe}" `Text.isInfixOf` output)
        , testCase "boot renderer records compiler and orders names" $ renderBootPackages "ghc-9.12.4" (Map.fromList [("text", testVersion), ("base", testVersion)]) @?= "# Generated shipped boot package versions.\n{\n  ghc = \"ghc-9.12.4\";\n  packages = {\n    \"base\" = \"1\";\n    \"text\" = \"1\";\n  };\n}\n"
        ]

fixture :: String -> IO Text
fixture name = getDataFileName ("test/fixtures/cohort-freeze/" <> name <> ".freeze") >>= TextIO.readFile

testVersion :: Version
testVersion = mkVersion [1]
hash :: Text
hash = Text.replicate 64 "a"
timestamp :: Text
timestamp = "2026-10-06T21:15:24Z"
testDocument :: FreezeDocument
testDocument = FreezeDocument (Map.singleton "example" testVersion) Map.empty timestamp
freeze :: Text -> Text
freeze constraints = "index-state: " <> timestamp <> "\nconstraints: " <> constraints <> "\n"
normal :: PlanPackage
normal = package [identity hash False]
package :: [Value] -> PlanPackage
package identities = PlanPackage "1" Hackage identities []
identity :: Text -> Bool -> Value
identity metadataHash flag = object ["pkg-cabal-sha256" .= metadataHash, "pkg-src-sha256" .= hash, "flags" .= object ["portable" .= flag]]
pinIdentity :: Value
pinIdentity = object ["pkg-src-sha256" .= hash, "pkg-src" .= object ["type" .= ("source-repo" :: Text), "source-repo" .= object ["type" .= ("git" :: Text), "tag" .= Text.replicate 40 "a", "location" .= ("https://example.invalid/pin" :: Text)]]]
owner :: OwnedPolicy
owner = OwnedPolicy "fixture ownership" "mori://shinzui/haskell-nix"
context :: GenerationContext
context = GenerationContext testDocument (Map.singleton "example" normal) Map.empty Map.empty (GenerationPolicy Map.empty Map.empty) Map.empty Map.empty Map.empty
sameBase :: GenerationContext
sameBase = context{basePackages = context.sources, selectedPolicyIdentities = Map.singleton "example" "policy", basePolicyIdentities = Map.singleton "example" "policy"}
cutoff, past, future :: UTCTime
cutoff = time "2026-10-06T21:15:24Z"
past = time "2026-10-01T00:00:00Z"
future = time "2026-10-07T00:00:00Z"
time :: String -> UTCTime
time value = case parseTimeM True defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ" value of
    Just result -> result
    Nothing -> error "invalid static test timestamp"
revision :: Int -> UTCTime -> HackageRevision
revision number instant = HackageRevision number instant hash
entry :: GeneratedEntry
entry = GeneratedEntry testVersion (SriHash ("sha256-" <> Text.replicate 43 "A" <> "=")) (revision 0 past)
entries :: Map.Map Text GeneratedEntry
entries = Map.singleton "example" entry
metadata :: GenerationMetadata
metadata = GenerationMetadata hash timestamp "ghc-9.12.4" (Text.replicate 40 "a")
right :: (Show e) => Either e a -> IO a
right = either (assertFailure . show) pure
assertLeft :: (Show a) => Either e a -> Assertion
assertLeft (Left _) = pure ()
assertLeft (Right value) = assertFailure ("expected failure: " <> show value)
