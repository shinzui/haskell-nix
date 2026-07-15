module HaskellNix.Update.Cli
  ( Command (..),
    RefreshOptions (..),
    CheckOptions (..),
    parserInfo,
    runCli,
  )
where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import HaskellNix.Update.Types (UpdateError (..))
import HaskellNix.Update.Workflow
import Options.Applicative
import System.Exit (exitFailure)
import System.IO qualified

data Command
  = Refresh !RefreshOptions
  | Check !CheckOptions
  deriving stock (Eq, Show)

data RefreshOptions = RefreshOptions
  { families :: ![Text],
    dryRun :: !Bool
  }
  deriving stock (Eq, Show)

data CheckOptions = CheckOptions
  { families :: ![Text],
    online :: !Bool
  }
  deriving stock (Eq, Show)

runCli :: IO ()
runCli = do
  parsedCommand <- execParser parserInfo
  environment <- defaultWorkflowEnvironment
  result <- case parsedCommand of
    Refresh RefreshOptions {families, dryRun} ->
      runRefreshWorkflow environment (defaultWorkflowPaths ".") families dryRun
    Check CheckOptions {families, online} ->
      runCheckWorkflow environment (defaultWorkflowPaths ".") families online
  case result of
    Right summary -> TextIO.putStrLn summary
    Left UpdateError {message} -> TextIO.hPutStrLn System.IO.stderr message >> exitFailure

parserInfo :: ParserInfo Command
parserInfo =
  info
    (commandParser <**> helper)
    ( fullDesc
        <> header "Refresh first-party Haskell package channels"
        <> progDesc "Refresh or validate GitHub and Hackage package locks"
    )

commandParser :: Parser Command
commandParser =
  subparser
    ( command
        "refresh"
        ( info
            (Refresh <$> refreshOptionsParser <**> helper)
            (fullDesc <> progDesc "Refresh GitHub and Hackage package locks")
        )
        <> command
          "check"
          ( info
              (Check <$> checkOptionsParser <**> helper)
              (fullDesc <> progDesc "Check package-lock drift without changing files")
          )
    )

refreshOptionsParser :: Parser RefreshOptions
refreshOptionsParser =
  RefreshOptions
    <$> familyOptionsParser
    <*> parserOptionGroup
      "Behavior"
      ( switch
          ( long "dry-run"
              <> help "Show the refresh plan without changing managed lock files"
          )
      )

checkOptionsParser :: Parser CheckOptions
checkOptionsParser =
  CheckOptions
    <$> familyOptionsParser
    <*> parserOptionGroup
      "Behavior"
      ( switch
          ( long "online"
              <> help "Also compare remote Git and Hackage state"
          )
      )

familyOptionsParser :: Parser [Text]
familyOptionsParser =
  parserOptionGroup
    "Scope"
    ( many
        ( Text.pack
            <$> strOption
              ( long "family"
                  <> metavar "FAMILY"
                  <> help "Limit work to a family; repeat for multiple families"
              )
        )
    )
