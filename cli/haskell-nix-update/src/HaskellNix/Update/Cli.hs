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
import HaskellNix.Update.Types (FamilyName (..), RefreshTarget (..), UpdateError (..), UpdateGroupName (..))
import HaskellNix.Update.Workflow
import Options.Applicative
import System.Exit (exitFailure)
import System.IO qualified

data Command
  = Refresh !RefreshOptions
  | Check !CheckOptions
  deriving stock (Eq, Show)

data RefreshOptions = RefreshOptions
  { packageSet :: !(Maybe Text),
    targets :: ![RefreshTarget],
    compatibilityProfile :: !(Maybe Text),
    dryRun :: !Bool
  }
  deriving stock (Eq, Show)

data CheckOptions = CheckOptions
  { packageSet :: !(Maybe Text),
    targets :: ![RefreshTarget],
    online :: !Bool
  }
  deriving stock (Eq, Show)

runCli :: IO ()
runCli = do
  parsedCommand <- execParser parserInfo
  environment <- defaultWorkflowEnvironment
  result <- case parsedCommand of
    Refresh RefreshOptions {packageSet = Nothing, targets, compatibilityProfile = Nothing, dryRun}
      | Just families <- legacyFamilyTargets targets ->
          runRefreshWorkflow environment (defaultWorkflowPaths ".") families dryRun
    Refresh {} -> pure (Left (UpdateError "migrate-lock required before using package-set refresh options"))
    Check CheckOptions {packageSet = Nothing, targets, online}
      | Just families <- legacyFamilyTargets targets ->
          runCheckWorkflow environment (defaultWorkflowPaths ".") families online
    Check {} -> pure (Left (UpdateError "migrate-lock required before using package-set check options"))
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
    <$> packageSetOptionParser
    <*> targetOptionsParser
    <*> optional
      ( Text.pack
          <$> strOption
            ( long "compatibility-profile"
                <> metavar "PROFILE"
                <> help "Compatibility profile for a single resolved update group"
            )
      )
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
    <$> packageSetOptionParser
    <*> targetOptionsParser
    <*> parserOptionGroup
      "Behavior"
      ( switch
          ( long "online"
              <> help "Also compare remote Git and Hackage state"
          )
      )

packageSetOptionParser :: Parser (Maybe Text)
packageSetOptionParser =
  optional
    ( Text.pack
        <$> strOption
          ( long "package-set"
              <> metavar "SET"
              <> help "Named package set to refresh or check"
          )
    )

targetOptionsParser :: Parser [RefreshTarget]
targetOptionsParser =
  parserOptionGroup
    "Scope"
    ( many
        ( (TargetFamily . FamilyName . Text.pack)
            <$> strOption
              ( long "family"
                  <> metavar "FAMILY"
                  <> help "Select the update group containing a family; repeat as needed"
              )
            <|> (TargetGroup . UpdateGroupName . Text.pack)
              <$> strOption
                ( long "group"
                    <> metavar "GROUP"
                    <> help "Select an update group; repeat as needed"
                )
        )
    )

legacyFamilyTargets :: [RefreshTarget] -> Maybe [Text]
legacyFamilyTargets = traverse legacyFamily
  where
    legacyFamily (TargetFamily (FamilyName familyName)) = Just familyName
    legacyFamily TargetGroup {} = Nothing
