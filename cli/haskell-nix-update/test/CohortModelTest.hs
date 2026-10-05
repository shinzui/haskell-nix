{-# LANGUAGE OverloadedRecordDot #-}

module CohortModelTest (tests) where

import Data.Aeson (object, (.=))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Distribution.PackageDescription.Parsec (parseGenericPackageDescription, runParseResult)
import Distribution.Version (mkVersion, withinRange)
import HaskellNix.Update.Cohort.Freeze
import HaskellNix.Update.Cohort.Impact
import HaskellNix.Update.Cohort.Model qualified as Model
import HaskellNix.Update.Cohort.Report qualified as Report
import HaskellNix.Update.Cohort.Types
import Test.Tasty
import Test.Tasty.HUnit

tests :: TestTree
tests =
    testGroup
        "cohort model"
        [ testCase "targeted updates retain unrelated pins and guard runtime ownership" $ do
            let frozen = Map.fromList [("leaf", mkVersion [1]), ("shared", mkVersion [2])]
                runtime = Map.singleton "shared" (mkVersion [2])
            retained <- right (retainedConstraints frozen runtime False ["leaf"])
            assertBool "shared stays exact" ("any.shared ==2" `Text.isInfixOf` retained)
            assertBool "requested leaf unlocked" (not ("any.leaf" `Text.isInfixOf` retained))
            assertLeft (retainedConstraints frozen runtime False ["shared"])
            _ <- right (retainedConstraints frozen runtime True ["shared"])
            assertLeft (retainedConstraints frozen runtime False ["missing"])
            assertLeft (retainedConstraints frozen (Map.singleton "shared" (mkVersion [3])) False ["leaf"])
            pure ()
        , testCase "metadata, flags and policy changes expose transitive benchmark impact" $ do
            let old = PlanPackage "1" Hackage [object ["pkg-cabal-sha256" .= ("old" :: Text), "flags" .= object ["feature" .= False]]] []
                new = old{identities = [object ["pkg-cabal-sha256" .= ("new" :: Text), "flags" .= object ["feature" .= True]]]}
                graph = Map.fromList [("middle", PlanPackage "1" Hackage [] ["changed"]), ("changed", old)]
                inv = inventory graph [DeclaredBound "middle" ">=1" "app.cabal" "benchmark:bench" "always" Nothing]
                report = impactReport (Map.singleton "changed" old) (Map.singleton "changed" new) Map.empty (Map.singleton "changed" (object ["tests" .= False])) [inv]
            assertBool "metadata and flags detected" ("cabal-metadata, flags, policy" `Text.isInfixOf` report)
            assertBool "component and transitive path" ("[benchmark:bench] -> middle -> changed" `Text.isInfixOf` report)
            impactReport (Map.singleton "changed" old) (Map.singleton "changed" old) Map.empty Map.empty [inv] @?= ""
        , testCase "generated stub parses with Cabal, including tools and multiple dependencies" $ do
            bounds <- right (Model.stubBounds Map.empty [inventory Map.empty [DeclaredBound "base" ">=4" "app.cabal" "library" "always" Nothing, DeclaredBound "text" ">=2" "app.cabal" "library" "always" Nothing, DeclaredBound "happy" ">=1.20" "app.cabal" "benchmark:bench" "always" (Just "happy")]])
            let generated = Model.renderStubCabal (fst bounds)
            _ <- right (snd (runParseResult (parseGenericPackageDescription (TextEncoding.encodeUtf8 generated))))
            pure ()
        , testCase "downgrade report fails and names policy floor evidence" $ do
            report <- right (Report.cohortReport (Map.singleton "effectful-core" (mkVersion [2, 6])) [] emptyNix Map.empty [Model.PolicyFloor "effectful-core" "2.7.1.1" "required fix"])
            Report.reportFailed report @?= True
            length report.downgrades @?= 1
        , testCase "highest recorded version wins across Cabal, channel, deployment and selected first-party" $ do
            let inv = inventory (Map.singleton "example" (PlanPackage "2.1" Hackage [] [])) []
                nix = NixInventory "channel" "dotfiles" "system" (Map.singleton "example" (Just "2.2")) (Map.singleton "app" (Map.singleton "example" "2.3"))
            floors <- right (Model.floorVersions [inv] nix (Map.singleton "example" "2.4") [])
            (floors Map.! "example").version @?= mkVersion [2, 4]
        , testCase "effectful policy floor excludes the regressed core" $ do
            floors <- right (Model.floorVersions [] emptyNix Map.empty [Model.PolicyFloor "effectful-core" "2.7.1.1" "performance fix"])
            (floors Map.! "effectful-core").version @?= mkVersion [2, 7, 1, 1]
        , testCase "Git-only versions and boot packages do not raise floors" $ do
            let inv = inventory (Map.fromList [("fork", PlanPackage "99" SourcePin [] []), ("base", PlanPackage "4.21" Boot [] [])]) []
            floors <- right (Model.floorVersions [inv] emptyNix Map.empty [])
            floors @?= Map.empty
        , testCase "a release-tag source counts when a contributor also uses that Hackage version" $ do
            let fork = inventory (Map.singleton "example" (PlanPackage "2" SourcePin [] [])) []
                release = inventory (Map.singleton "example" (PlanPackage "2" Hackage [] [])) []
            floors <- right (Model.floorVersions [fork, release] emptyNix Map.empty [])
            (floors Map.! "example").version @?= mkVersion [2]
        , testCase "a capped dependency stays in the stub and is reported" $ do
            let inv = inventory Map.empty [DeclaredBound "brick" "^>=2.6" "app.cabal" "library" "always" Nothing]
                floors = Map.singleton "brick" (Model.Floor (mkVersion [2, 9]) ["channel"])
            (bounds, caps) <- right (Model.stubBounds floors [inv])
            assertBool "retained dependency admits floor" (withinRange (mkVersion [2, 9]) (bounds Map.! ("brick", Nothing)))
            length caps @?= 1
        , testCase "excluded source dependencies never enter the stub" $ do
            let inv =
                    (inventory Map.empty [DeclaredBound "hasql-effectful" "<1" "app.cabal" "library" "always" Nothing])
                        { contributor = sampleContributor{excludedDependencies = [Exclusion "hasql-effectful" "vendored by consumer plan"]}
                        }
            (bounds, caps) <- right (Model.stubBounds Map.empty [inv])
            Map.null bounds @?= True
            null caps @?= True
        , testCase "freeze drops flags but round-trips one recorded index-state" $ do
            versions <- right (normaliseCabalFreeze "constraints: any.aeson ==2.2.5.1,\n  aeson +ordered-keymap,\n  any.base ==4.21.2.0\nactive-repositories: hackage.haskell.org\nindex-state: ignored\n")
            let rendered = renderCohortFreeze (FreezeHeader "2026-10-05T18:43:07Z" "ghc-9.12.4" "recorded" "cohort") versions
            parseCohortFreeze rendered @?= Right versions
        , testCase "conflicting versions and missing/duplicate index-state fail" $ do
            assertLeft (normaliseCabalFreeze "constraints: any.aeson ==2,\n  any.aeson ==3\n")
            assertLeft (parseCohortFreeze "constraints: any.aeson ==2\n")
            assertLeft (parseCohortFreeze "index-state: first\nindex-state: second\nconstraints: any.aeson ==2\n")
        ]

sampleContributor :: Contributor
sampleContributor = Contributor "app" "mori://example/app" "recorded" "application" ["app"] [] ["app.cabal"] Nothing Nothing [Configuration "default" Map.empty]

inventory :: Map.Map Text PlanPackage -> [DeclaredBound] -> Inventory
inventory packages bounds = Inventory sampleContributor "default" Nothing packages bounds ""

emptyNix :: NixInventory
emptyNix = NixInventory "channel" "dotfiles" "system" Map.empty Map.empty

right :: (Show e) => Either e a -> IO a
right = either (assertFailure . show) pure

assertLeft :: (Show a) => Either e a -> Assertion
assertLeft (Left _) = pure ()
assertLeft (Right result) = assertFailure ("expected failure: " <> show result)
