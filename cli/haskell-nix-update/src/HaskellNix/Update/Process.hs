module HaskellNix.Update.Process
  ( ProcessSpec (..),
    ProcessResult (..),
    ProcessRunner (..),
    defaultProcessRunner,
    runChecked,
    commandText,
  )
where

import Control.Exception (IOException, try)
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import HaskellNix.Update.Types (UpdateError (..))
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.Process (CreateProcess (..), proc, readCreateProcessWithExitCode)

data ProcessSpec = ProcessSpec
  { executable :: !FilePath,
    arguments :: ![String],
    workingDirectory :: !(Maybe FilePath),
    environmentAdditions :: ![(String, String)]
  }
  deriving stock (Eq, Show)

data ProcessResult = ProcessResult
  { exitCode :: !ExitCode,
    standardOutput :: !Text,
    standardError :: !Text
  }
  deriving stock (Eq, Show)

newtype ProcessRunner = ProcessRunner
  { runProcess :: ProcessSpec -> IO (Either UpdateError ProcessResult)
  }

defaultProcessRunner :: ProcessRunner
defaultProcessRunner = ProcessRunner $ \spec@ProcessSpec {executable, arguments, workingDirectory, environmentAdditions} -> do
  inheritedEnvironment <- getEnvironment
  let mergedEnvironment =
        Map.toList
          (Map.union (Map.fromList environmentAdditions) (Map.fromList inheritedEnvironment))
      createProcess =
        (proc executable arguments)
          { cwd = workingDirectory,
            env = Just mergedEnvironment
          }
  attempted <-
    try (readCreateProcessWithExitCode createProcess "")
      :: IO (Either IOException (ExitCode, String, String))
  pure $ case attempted of
    Left exception ->
      Left
        (UpdateError ("could not run " <> commandText spec <> ": " <> Text.pack (show exception)))
    Right (exitCode, standardOutput, standardError) ->
      Right
        ProcessResult
          { exitCode,
            standardOutput = Text.pack standardOutput,
            standardError = Text.pack standardError
          }

runChecked :: ProcessRunner -> ProcessSpec -> IO (Either UpdateError ProcessResult)
runChecked ProcessRunner {runProcess} spec = do
  result <- runProcess spec
  pure $ case result of
    Left updateError -> Left updateError
    Right processResult@ProcessResult {exitCode = ExitSuccess} -> Right processResult
    Right ProcessResult {exitCode = ExitFailure status, standardError} ->
      Left
        ( UpdateError
            ( commandText spec
                <> " exited with status "
                <> Text.pack (show status)
                <> conciseStderr standardError
            )
        )

commandText :: ProcessSpec -> Text
commandText ProcessSpec {executable, arguments} =
  Text.unwords (Text.pack executable : map (quote . Text.pack) arguments)
  where
    quote value
      | Text.any (`elem` [' ', '\t', '\n']) value = "'" <> Text.replace "'" "'\\''" value <> "'"
      | otherwise = value

conciseStderr :: Text -> Text
conciseStderr value =
  case Text.strip value of
    "" -> ""
    stripped -> ": " <> Text.take 500 stripped
