{-# LANGUAGE OverloadedRecordDot #-}
module RuntimeTest (tests) where

import Data.Aeson (object, (.=))
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import HaskellNix.Update.Cohort.Types (PackageSource (..), PlanPackage (..))
import HaskellNix.Update.Runtime
import HaskellNix.Update.Types qualified as FP
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))

tests :: TestTree
tests = testGroup "retained runtime contract"
    [ testCase "complete ownership and explicit configuration validate" $ validateRuntimeLock config firstParty lock @?= Right lock
    , testCase "missing dependency ownership is rejected" $ invalid record {ownership = Map.delete "base" record.ownership}
    , testCase "unreachable ownership is rejected" $ invalid record {ownership = Map.insert "unused" package record.ownership, roles = Map.insert "unused" ["library"] record.roles}
    , testCase "missing roles or source identities are rejected" $ do
        invalid record {roles = Map.delete "base" record.roles}
        invalid record {ownership = Map.insert "shared" package {identities = []} record.ownership}
    , testCase "same-version source and metadata conflicts are rejected" $ do
        invalid record {ownership = Map.insert "shared" package {identities = package.identities <> [object ["pkg-name" .= ("shared" :: Text), "pkg-version" .= ("1.0" :: Text), "flags" .= object ["different" .= True]]]} record.ownership}
        invalid record {ownership = Map.insert "shared" package {identities = [object ["pkg-name" .= ("other" :: Text), "pkg-version" .= ("1.0" :: Text)]]} record.ownership}
    , testCase "missing root and unknown group generations are rejected" $ do
        invalid record {roots = []}
        invalid record {selections = Map.singleton "core" 2}
        invalid record {selections = Map.singleton "unknown" 1}
    , testCase "unsupported compiler, flags and duplicate configurations are rejected" $ do
        invalid record {configurations = [configuration {compiler = "ghc9141"}]}
        invalid record {configurations = [configuration {disableProfiling = False}]}
        invalid record {configurations = [configuration, configuration]}
    , testCase "projection ownership, safe paths and hash shapes are required" $ do
        invalid record {projections = Map.empty}
        invalid record {projections = Map.singleton "../escape" hash}
        invalid record {fingerprint = "not-a-hash"}
        invalid record {components = Map.singleton "unowned" (object [])}
    , testCase "same-version retained source and policy tampering is detected" $ do
        validateProjectionHashes record record.projections @?= Right ()
        left (validateProjectionHashes record (Map.insert "fixture/policy" (Text.replicate 64 "b") record.projections))
        left (validateProjectionHashes record (Map.delete "fixture/sources" record.projections))
    , testCase "generation identities cannot be repeated or reordered" $ do
        left (validateRuntimeLock config firstParty (RuntimeLock 1 (Map.singleton "fixture" [record, record])))
        left (validateRuntimeLock config firstParty (RuntimeLock 1 (Map.singleton "fixture" [record {generation = 2}, record])))
    , testCase "complement mapping is explicit and equal duplicates are allowed" $ do
        composeRuntimeSelections ["core", "application"] (Map.singleton "core" 1) (Map.fromList [("core", 1), ("application", 3)]) @?= Right (Map.fromList [("core", 1), ("application", 3)])
        left (composeRuntimeSelections ["core", "application"] (Map.singleton "core" 1) Map.empty)
        left (composeRuntimeSelections ["core"] (Map.singleton "core" 1) (Map.singleton "core" 2))
    , testCase "Keiki, codec and all eight project identities are mandatory" $ do
        validateRuntimeConfig keiroConfig @?= Right keiroConfig
        let definition = keiroConfig.runtimes Map.! "keiro-runtime"
        mapM_ (\name -> left (validateRuntimeConfig (RuntimeConfig 1 (Map.singleton "keiro-runtime" (definition :: RuntimeDefinition) {roots = Map.delete name definition.roots})))) ["keiki", "keiki-codec-json", "hw-kafka-streamly"]
        left (validateRuntimeConfig (RuntimeConfig 1 (Map.singleton "keiro-runtime" definition {projects = tail definition.projects})))
    ]
  where
    invalid value = left (validateRuntimeLock config firstParty (RuntimeLock 1 (Map.singleton "fixture" [value])))

left :: Show a => Either Text a -> IO ()
left (Left _) = pure ()
left (Right value) = assertFailure ("expected rejection, accepted " <> show value)

hash :: Text
hash = Text.replicate 64 "a"

configuration :: RuntimeConfiguration
configuration = RuntimeConfiguration "aarch64-darwin" "ghc9124" "github" True True

package :: PlanPackage
package = PlanPackage "1.0" Hackage [object ["pkg-name" .= ("shared" :: Text), "pkg-version" .= ("1.0" :: Text)]] ["base"]

record :: RuntimeGeneration
record = RuntimeGeneration
    {generation = 1, selections = Map.singleton "core" 1, configurations = [configuration]
    , roots = ["shared"], ownership = Map.fromList [("shared", package), ("base", PlanPackage "4.21" Boot [object ["type" .= ("pre-existing" :: Text), "pkg-name" .= ("base" :: Text), "pkg-version" .= ("4.21" :: Text)]] [])]
    , roles = Map.fromList [("shared", ["library"]), ("base", ["compiler"])]
    , components = Map.empty, projections = Map.fromList [(file, hash) | file <- ["fixture/freeze", "fixture/sources", "fixture/versions", "fixture/policy", "fixture/recipes/registry.nix"]]
    , fingerprint = hash, recipeDirectory = "fixture/recipes", freezeFile = "fixture/freeze", sourceFile = "fixture/sources", versionFile = "fixture/versions", policyFile = "fixture/policy"}

config :: RuntimeConfig
config = RuntimeConfig 1 (Map.singleton "fixture" (RuntimeDefinition ["mori://shinzui/keiki"] ["core"] (Map.singleton "shared" (RuntimeRoot "mori://shinzui/keiki" "core" "library"))))

lock :: RuntimeLock
lock = RuntimeLock 1 (Map.singleton "fixture" [record])

firstParty :: FP.PackageSetLock
firstParty = FP.PackageSetLock 2 [] [FP.GroupSnapshot (FP.UpdateGroupName "core") (FP.SnapshotGeneration 1) [] "default"] [] "fixture"

keiroConfig :: RuntimeConfig
keiroConfig = RuntimeConfig 1 (Map.singleton "keiro-runtime" (RuntimeDefinition
    (map ("mori://shinzui/" <>) ["keiki", "keiro", "kiroku", "shibuya", "pgmq-hs", "settei", "pg-migrate", "hw-kafka-client"])
    ["keiki", "keiro", "kiroku", "shibuya", "pgmq-hs", "settei", "pg-migrate"]
    (Map.fromList [(name, RuntimeRoot (rootProject name) "core" "library") | name <- ["keiki", "keiki-codec-json", "keiro", "kiroku-store", "shibuya-core", "pgmq-core", "settei", "pg-migrate", "hw-kafka-client", "shibuya-pgmq-adapter", "shibuya-kiroku-adapter", "shibuya-kafka-adapter", "kafka-effectful", "hw-kafka-streamly"]])))

rootProject :: Text -> Text
rootProject name = "mori://shinzui/" <> case name of
    "keiro" -> "keiro"
    "kiroku-store" -> "kiroku"
    "shibuya-core" -> "shibuya"
    "pgmq-core" -> "pgmq-hs"
    "settei" -> "settei"
    "pg-migrate" -> "pg-migrate"
    "hw-kafka-client" -> "hw-kafka-client"
    _ -> "keiki"
