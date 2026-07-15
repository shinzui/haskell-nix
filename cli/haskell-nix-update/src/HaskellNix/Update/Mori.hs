module HaskellNix.Update.Mori
  ( MoriProject (..),
    decodeMoriProject,
    locateMoriProject,
  )
where

import Data.Aeson (Value, eitherDecodeStrict', withObject, (.:), (.:?))
import Data.Aeson.Types (Parser, parseEither)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import HaskellNix.Update.Process
import HaskellNix.Update.Types

data MoriProject = MoriProject
  { path :: !FilePath,
    githubRepositories :: ![Text]
  }
  deriving stock (Eq, Show)

decodeMoriProject :: Text -> Either UpdateError MoriProject
decodeMoriProject output = do
  value <- firstError "invalid Mori JSON" (eitherDecodeStrict' (TextEncoding.encodeUtf8 output))
  firstError "invalid Mori project" (parseEither parseMoriProject value)

locateMoriProject :: ProcessRunner -> FamilyConfig -> IO (Either UpdateError MoriProject)
locateMoriProject runner FamilyConfig {name = FamilyName familyName, moriProject, github} = do
  result <-
    runChecked
      runner
      ProcessSpec
        { executable = "mori",
          arguments = ["registry", "show", Text.unpack moriProject, "--json", "--full"],
          workingDirectory = Nothing,
          environmentAdditions = []
        }
  pure $ do
    ProcessResult {standardOutput} <- prefixError ("family " <> familyName <> ": ") result
    project@MoriProject {githubRepositories} <- decodeMoriProject standardOutput
    if null githubRepositories || github `elem` githubRepositories
      then Right project
      else
        Left
          ( UpdateError
              ( "family "
                  <> familyName
                  <> ": configured GitHub repository "
                  <> github
                  <> " is not present in Mori metadata"
              )
          )

parseMoriProject :: Value -> Parser MoriProject
parseMoriProject = withObject "Mori project" $ \fields -> do
  path <- fields .: "path"
  repositories <- fields .: "repositories" :: Parser [Value]
  githubRepositories <- concat <$> traverse parseRepository repositories
  pure MoriProject {path, githubRepositories}

parseRepository :: Value -> Parser [Text]
parseRepository = withObject "Mori repository" $ \fields -> do
  github <- fields .:? "github"
  pure (maybe [] pure github)

firstError :: Text -> Either String value -> Either UpdateError value
firstError context = either (Left . UpdateError . ((context <> ": ") <>) . Text.pack) Right

prefixError :: Text -> Either UpdateError value -> Either UpdateError value
prefixError prefix = either (Left . UpdateError . (prefix <>) . message) Right
