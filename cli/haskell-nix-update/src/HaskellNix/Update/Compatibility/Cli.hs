module HaskellNix.Update.Compatibility.Cli (CompatibilityCommand (..), compatibilityParser, runCompatibility) where

import Control.Exception (IOException, try)
import Data.ByteString qualified as BS
import Data.Text (Text)
import Data.Text qualified as Text
import HaskellNix.Update.Compatibility.Types
import HaskellNix.Update.Compatibility.Report
import HaskellNix.Update.Types (UpdateError (..))
import Options.Applicative

data CompatibilityCommand = CompatibilityReport !FilePath !Bool | CompatibilityCheck !FilePath
    deriving stock (Eq, Show)

compatibilityParser :: Parser CompatibilityCommand
compatibilityParser = subparser
    (command "report" (info (CompatibilityReport <$> context <*> switch (long "json") <**> helper)
        (failureCode 2 <> progDesc "Report selected compatibility declarations and unverified evidence"))
    <> command "check" (info (CompatibilityCheck <$> context <**> helper)
        (failureCode 2 <> progDesc "Check compatibility declarations and required evidence without writes")))
  where
    context = strOption (long "context" <> metavar "FILE" <> help "JSON exported by lib.compatibilityReport")

runCompatibility :: CompatibilityCommand -> IO (Either UpdateError Text)
runCompatibility selected = do
    bytes <- try (BS.readFile path)
    pure $ case bytes of
        Left (err :: IOException) -> Left (UpdateError (Text.pack (show err)))
        Right content -> case decodeCompatibilityContext content of
            Left err -> Left (UpdateError err)
            Right context -> case selected of
                CompatibilityReport _ json -> Right (renderCompatibilityReport json context)
                CompatibilityCheck _ -> either (Left . UpdateError) Right (checkCompatibilityReport context)
  where
    path = case selected of CompatibilityReport file _ -> file; CompatibilityCheck file -> file
