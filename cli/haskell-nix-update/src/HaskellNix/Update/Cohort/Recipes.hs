{-# LANGUAGE OverloadedRecordDot #-}

module HaskellNix.Update.Cohort.Recipes (
    RecipeConversion (..),
    recipeArguments,
    convertRecipe,
) where

import Control.Monad (unless)
import Control.Monad.Trans.Class (lift)
import Control.Monad.Trans.Except (ExceptT (..), runExceptT)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Pretty (prettyShow)
import Distribution.Version (Version)
import HaskellNix.Update.Cohort.GenerationTypes
import HaskellNix.Update.Process
import HaskellNix.Update.Types (UpdateError (..))
import System.Directory (makeAbsolute)

-- The generation owner supplies a classified solved package and the exact Cabal
-- file selected by its revision resolver. The source is bound separately by the
-- importing recursive Haskell scope, never to the converter's scratch directory.
data RecipeConversion = RecipeConversion
    { packageName :: !Text
    , classifiedPackage :: !ClassifiedPackage
    , compilerVersion :: !Version
    , system :: !Text
    , metadataPath :: !FilePath
    } deriving stock (Eq, Show)

recipeArguments :: RecipeConversion -> Either Text [String]
recipeArguments request = do
    unless (request.system `elem` ["aarch64-darwin", "x86_64-linux"])
        (Left "recipe conversion: unsupported explicit system")
    case request.classifiedPackage.packageClassification of
        CohortGenerated -> pure ()
        CohortSourcePinned _ -> pure ()
        _ -> Left "recipe conversion: only declared generated dependencies and source pins may be converted"
    flags <- selectedPackageFlags request.packageName request.classifiedPackage.selectedPackage
    pure $
        [ "--compiler=ghc-" <> prettyShow request.compilerVersion
        , "--system=" <> Text.unpack request.system
        , "--sha256="
        , "--no-hpack"
        , "--src-expression=src"
        , "--extra-arguments=src"
        ]
        <> ["--flag=" <> (if enabled then "" else "-") <> Text.unpack flag | (flag, enabled) <- Map.toAscList flags]
        <> [request.metadataPath]

-- executable must be selected from the pinned build-tool scope, not PATH. The
-- explicit generation manifest (M2) binds that selection to its derivation.
-- Hash before and after conversion, so metadata drift cannot be promoted.
convertRecipe :: ProcessRunner -> FilePath -> RecipeConversion -> IO (Either UpdateError Text)
convertRecipe runner converter request = runExceptT $ do
    arguments <- fromText (recipeArguments request)
    expected <- fromText (selectedMetadataHash request.packageName request.classifiedPackage.selectedPackage)
    absolute <- lift (makeAbsolute request.metadataPath)
    let hash = do
            output <- command "nix" ["hash", "file", "--type", "sha256", "--base16", absolute]
            unless (Text.strip output == expected) (failText "recipe conversion: selected Cabal metadata hash changed")
    hash
    output <- command converter (init arguments <> [absolute])
    hash
    unless (not (Text.null (Text.strip output)) && not (Text.pack absolute `Text.isInfixOf` output))
        (failText "recipe conversion: empty output or transient metadata path leaked into recipe")
    pure (Text.stripEnd output <> "\n")
  where
    command :: FilePath -> [String] -> ExceptT UpdateError IO Text
    command executable arguments = (.standardOutput) <$> ExceptT (runChecked runner (ProcessSpec executable arguments Nothing []))
    fromText :: Either Text a -> ExceptT UpdateError IO a
    fromText = ExceptT . pure . either (Left . UpdateError) Right
    failText :: Text -> ExceptT UpdateError IO a
    failText = fromText . Left
