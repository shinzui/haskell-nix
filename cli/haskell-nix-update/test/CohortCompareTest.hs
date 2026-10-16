module CohortCompareTest (tests) where

import Data.Aeson (Value (..), encode, object, (.=))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as LBS
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Text (Text)
import Data.Text qualified as Text
import HaskellNix.Update.Cohort.Compare (comparePlan, verifyCohortImport)
import HaskellNix.Update.Cohort.Types
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertBool, testCase)

tests :: TestTree
tests = testGroup "consumer cohort comparison"
    [ testCase "a consumer need not use every union package" $
        succeeds (check [row "lib" "1" "lib-id"])
    , testCase "wrong and correct instances fail together" $
        failsWith "multiple versions" (check [row "lib" "1" "correct", row "lib" "2" "wrong"])
    , testCase "every same-version component must carry matching metadata" $
        failsWith "source/metadata/flags" (check [row "lib" "1" "correct", change "pkg-cabal-sha256" (String (Text.replicate 64 "b")) (row "lib" "1" "wrong")])
    , testCase "missing source evidence fails" $
        failsWith "source/metadata/flags" (check [remove "pkg-src-sha256" (row "lib" "1" "lib-id")])
    , testCase "same-version source changes fail" $
        failsWith "source/metadata/flags" (check [change "pkg-src-sha256" (String (Text.replicate 64 "c")) (row "lib" "1" "lib-id")])
    , testCase "same-version flag changes fail" $
        failsWith "source/metadata/flags" (check [change "flags" (object ["fast" .= True]) (row "lib" "1" "lib-id")])
    , testCase "a source pin cannot masquerade as Hackage" $
        failsWith "source mismatch" (check [change "pkg-src" (object ["type" .= ("source-repo" :: Text)]) (row "lib" "1" "lib-id")])
    , testCase "unknown dependencies fail" $
        failsWith "missing other" (check [row "other" "1" "other-id"])
    , testCase "empty plans fail" $
        failsWith "no verifiable" (check [])
    , testCase "declared application packages are local" $
        succeeds (check [row "lib" "1" "lib-id", local "app"])
    , testCase "undeclared local packages cannot hide a dependency" $
        failsWith "undeclared local" (check [row "lib" "1" "lib-id", local "hidden"])
    , testCase "compiler provenance is checked" $
        failsWith "compiler" (comparePlan Set.empty freeze sources (plan "ghc-9.14.1" [row "lib" "1" "lib-id"]))
    , testCase "freeze and source versions cannot disagree" $
        failsWith "freeze/source version" (comparePlan Set.empty (Text.replace "lib ==1" "lib ==2" freeze) sources (plan "ghc-9.12.4" [row "lib" "1" "lib-id"]))
    , testCase "missing compiler evidence fails" $
        failsWith "compiler header" (comparePlan Set.empty (Text.unlines (drop 1 (Text.lines freeze))) sources (plan "ghc-9.12.4" [row "lib" "1" "lib-id"]))
    , testCase "explicit freeze flags must agree with recorded sources" $
        failsWith "freeze/source flags" (comparePlan Set.empty (Text.strip freeze <> ", any.lib +fast\n") sources (plan "ghc-9.12.4" [row "lib" "1" "lib-id"]))
    , testCase "duplicate unit IDs cannot obscure dependency edges" $
        failsWith "duplicate plan unit IDs" (check [row "lib" "1" "duplicate", row "unused" "1" "duplicate"])
    , testCase "cohort import supports continuation fields and ignores comments" $
        succeeds (verifyCohortImport revision ("-- import: stale/cohort.freeze\nimport:\n  common.config,\n  " <> importUrl <> "\n"))
    , testCase "a stale import fails even alongside the correct import" $
        failsWith "stale or missing" (verifyCohortImport revision ("import: " <> importUrl <> ", https://raw.githubusercontent.com/shinzui/haskell-nix/old/cabal/cohort.freeze\n"))
    , testCase "a commented import cannot prove current provenance" $
        failsWith "stale or missing" (verifyCohortImport revision ("-- import: " <> importUrl))
    , testCase "a mutable or abbreviated locked revision fails" $
        failsWith "full locked Git revision" (verifyCohortImport "main" ("import: " <> importUrl))
    , testCase "a matching hash on a different source host fails" $
        failsWith "stale or missing" (verifyCohortImport revision ("import: " <> Text.replace "raw.githubusercontent.com" "example.com" importUrl))
    ]
  where
    check rows = comparePlan (Set.singleton "app") freeze sources (plan "ghc-9.12.4" rows)
    revision = Text.replicate 40 "a"
    importUrl = "https://raw.githubusercontent.com/shinzui/haskell-nix/" <> revision <> "/cabal/cohort.freeze"

freeze :: Text
freeze = "-- Compiler: ghc-9.12.4\nindex-state: 2026-10-06T00:00:00Z\nconstraints: any.lib ==1, any.unused ==1\n"

sources :: Map.Map Text PlanPackage
sources = Map.fromList [(name, PlanPackage "1" Hackage [row name "1" name] []) | name <- ["lib", "unused"]]

row :: Text -> Text -> Text -> Value
row name version unitId = object
    [ "id" .= unitId, "pkg-name" .= name, "pkg-version" .= version
    , "type" .= ("configured" :: Text), "pkg-src" .= object ["type" .= ("repo-tar" :: Text)]
    , "pkg-src-sha256" .= Text.replicate 64 "a", "pkg-cabal-sha256" .= Text.replicate 64 "d"
    , "flags" .= object [], "depends" .= ([] :: [Text])
    ]

local :: Text -> Value
local name = change "pkg-src" (object ["type" .= ("local" :: Text)]) (row name "1" name)

plan :: Text -> [Value] -> ByteString
plan compiler rows = LBS.toStrict (encode (object ["compiler-id" .= compiler, "install-plan" .= rows]))

change :: Key.Key -> Value -> Value -> Value
change key value (Object fields) = Object (KeyMap.insert key value fields)
change _ _ value = value

remove :: Key.Key -> Value -> Value
remove key (Object fields) = Object (KeyMap.delete key fields)
remove _ value = value

succeeds :: Either Text Text -> IO ()
succeeds result = assertBool (show result) (either (const False) (const True) result)

failsWith :: Text -> Either Text Text -> IO ()
failsWith needle result = assertBool (show result) (either (Text.isInfixOf needle) (const False) result)
