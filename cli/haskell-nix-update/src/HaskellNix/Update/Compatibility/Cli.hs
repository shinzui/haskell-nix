module HaskellNix.Update.Compatibility.Cli (CompatibilityCommand (..), compatibilityParser, runCompatibility) where

import Control.Exception (IOException, try)
import Data.ByteString qualified as BS
import Data.Aeson (eitherDecodeStrict')
import HaskellNix.Update.Compatibility.Verify
import HaskellNix.Update.Process (streamingProcessRunner)
import Data.Text (Text)
import Data.Text qualified as Text
import HaskellNix.Update.Compatibility.Types
import HaskellNix.Update.Compatibility.Report
import HaskellNix.Update.Types (UpdateError (..))
import Options.Applicative

data CompatibilityCommand = CompatibilityReport !FilePath !Bool | CompatibilityCheck !FilePath
    | CompatibilityVerify !FilePath !Text !FilePath
    | CompatibilityVerifyReceipt !FilePath !FilePath
    deriving stock (Eq, Show)

compatibilityParser :: Parser CompatibilityCommand
compatibilityParser = subparser
    (command "report" (info (CompatibilityReport <$> context <*> switch (long "json") <**> helper)
        (failureCode 2 <> progDesc "Report selected compatibility declarations and unverified evidence"))
    <> command "check" (info (CompatibilityCheck <$> context <**> helper)
        (failureCode 2 <> progDesc "Check compatibility declarations and required evidence without writes"))
    <> command "verify" (info (CompatibilityVerify <$> context <*> strOption (long "entry" <> metavar "ID") <*> strOption (long "out" <> metavar "DIR") <**> helper)
        (failureCode 2 <> progDesc "Run a constructed native strict-policy removal probe in a fresh directory"))
    <> command "verify-receipt" (info (CompatibilityVerifyReceipt <$> context <*> strOption (long "receipt" <> metavar "FILE") <**> helper)
        (failureCode 2 <> progDesc "Recheck exact receipt inputs and native Nix evidence without building")))
  where
    context = strOption (long "context" <> metavar "FILE" <> help "Explicit Nix-exported declaration or native probe context")

runCompatibility :: CompatibilityCommand -> IO (Either UpdateError Text)
runCompatibility selected = do
    bytes <- try (BS.readFile path)
    case bytes of
        Left (err :: IOException) -> pure (Left (UpdateError (Text.pack (show err))))
        Right content -> case selected of
            CompatibilityVerify _ entry destination -> case decodeProbeContext content of
                Left err -> pure (Left (UpdateError err))
                Right context -> runProbe streamingProcessRunner context entry destination
            CompatibilityVerifyReceipt _ receiptPath -> case decodeProbeContext content of
                Left err -> pure (Left (UpdateError err))
                Right context -> do
                    receiptBytes <- try (BS.readFile receiptPath)
                    case receiptBytes of
                        Left (err :: IOException) -> pure (Left (UpdateError (Text.pack (show err))))
                        Right raw -> case eitherDecodeStrict' raw of
                            Left err -> pure (Left (UpdateError (Text.pack err)))
                            Right receipt -> verifyProbeReceipt streamingProcessRunner context receipt
            _ -> pure $ case decodeCompatibilityContext content of
                Left err -> Left (UpdateError err)
                Right context -> case selected of
                    CompatibilityReport _ json -> Right (renderCompatibilityReport json context)
                    CompatibilityCheck _ -> either (Left . UpdateError) Right (checkCompatibilityReport context)
  where
    path = case selected of
        CompatibilityReport file _ -> file
        CompatibilityCheck file -> file
        CompatibilityVerify file _ _ -> file
        CompatibilityVerifyReceipt file _ -> file
