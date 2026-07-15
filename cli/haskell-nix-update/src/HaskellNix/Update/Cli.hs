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
import Options.Applicative

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
  case parsedCommand of
    Refresh RefreshOptions {families, dryRun} ->
      TextIO.putStrLn
        ( "Refresh workflow scaffolded for "
            <> renderFamilies families
            <> if dryRun then " (dry run)" else ""
        )
    Check CheckOptions {families, online} ->
      TextIO.putStrLn
        ( "Check workflow scaffolded for "
            <> renderFamilies families
            <> if online then " (online)" else " (offline)"
        )

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
        (info (Refresh <$> refreshOptionsParser) (progDesc "Refresh GitHub and Hackage package locks"))
        <> command
          "check"
          (info (Check <$> checkOptionsParser) (progDesc "Check package-lock drift without changing files"))
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

renderFamilies :: [Text] -> Text
renderFamilies [] = "all configured families"
renderFamilies selected = Text.intercalate ", " selected
