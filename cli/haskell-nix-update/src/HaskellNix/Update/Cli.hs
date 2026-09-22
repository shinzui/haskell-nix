module HaskellNix.Update.Cli
  ( Command (..),
    RefreshOptions (..),
    CheckOptions (..),
    MigrateOptions (..),
    PackageSetCommand (..),
    parserInfo,
    runCli,
  )
where

import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.IO qualified as TextIO
import HaskellNix.Update.Types (FamilyName (..), PackageSetCommand (..), PackageSetSupportLevel (..), RefreshTarget (..), SnapshotGeneration (..), UpdateError (..), UpdateGroupName (..))
import HaskellNix.Update.Workflow
import Options.Applicative
import System.Exit (exitFailure)
import System.IO qualified

data Command
  = Refresh !RefreshOptions
  | Check !CheckOptions
  | MigrateLock !MigrateOptions
  | PackageSetCommand !PackageSetCommand
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

data MigrateOptions = MigrateOptions
  { packageSet :: !Text,
    importSets :: ![(Text, Text)],
    dryRun :: !Bool
  }
  deriving stock (Eq, Show)

runCli :: IO ()
runCli = do
  parsedCommand <- execParser parserInfo
  environment <- defaultWorkflowEnvironment
  result <- case parsedCommand of
    Refresh RefreshOptions {packageSet, targets, compatibilityProfile, dryRun} ->
      runRefreshCommand environment (defaultWorkflowPaths ".") packageSet targets compatibilityProfile dryRun
    Check CheckOptions {packageSet, targets, online} ->
      runCheckCommand environment (defaultWorkflowPaths ".") packageSet targets online
    MigrateLock MigrateOptions {packageSet, importSets, dryRun} ->
      runMigrateLockWorkflow environment (defaultWorkflowPaths ".") packageSet importSets dryRun
    PackageSetCommand packageSetCommand ->
      runPackageSetCommand environment (defaultWorkflowPaths ".") packageSetCommand
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
        <> command
          "migrate-lock"
          ( info
              (MigrateLock <$> migrateOptionsParser <**> helper)
              (fullDesc <> progDesc "Migrate the flat lock and optionally import historical sets")
          )
        <> command
          "package-set"
          ( info
              (PackageSetCommand <$> packageSetCommandParser <**> helper)
              (fullDesc <> progDesc "Compose and label named package sets")
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

migrateOptionsParser :: Parser MigrateOptions
migrateOptionsParser =
  MigrateOptions
    <$> ( Text.pack
            <$> strOption
              ( long "package-set"
                  <> metavar "NAME"
                  <> value "default"
                  <> showDefault
                  <> help "Name of the migrated current package set"
              )
        )
    <*> many
      ( option
          (eitherReader parseImportSet)
          ( long "import-set"
              <> metavar "NAME=GIT_COMMIT"
              <> help "Import a historical flat lock from a repository commit"
          )
      )
    <*> dryRunParser

packageSetCommandParser :: Parser PackageSetCommand
packageSetCommandParser =
  subparser
    ( command "clone" (info (cloneParser <**> helper) (fullDesc <> progDesc "Clone a complete package set"))
        <> command "select" (info (selectParser <**> helper) (fullDesc <> progDesc "Replace one group selection"))
        <> command "profile" (info (profileParser <**> helper) (fullDesc <> progDesc "Select a compatibility profile for one group"))
        <> command "support" (info (supportParser <**> helper) (fullDesc <> progDesc "Change a package-set support label"))
    )

cloneParser :: Parser PackageSetCommand
cloneParser =
  ClonePackageSet
    <$> textOption "from" "SOURCE" "Source package set"
    <*> textOption "to" "TARGET" "New package-set name"
    <*> option supportLevelReader (long "support-level" <> metavar "curated|historical" <> value Historical <> showDefaultWith renderSupportLevel)
    <*> dryRunParser

selectParser :: Parser PackageSetCommand
selectParser =
  SelectPackageSetGroup
    <$> textOption "package-set" "SET" "Package set to change"
    <*> (UpdateGroupName <$> textOption "group" "GROUP" "Update group to replace")
    <*> ( (Left . SnapshotGeneration <$> option auto (long "generation" <> metavar "N" <> help "Existing group generation"))
            <|> (Right <$> textOption "from-package-set" "SOURCE" "Copy this group's selection from another set")
        )
    <*> dryRunParser

profileParser :: Parser PackageSetCommand
profileParser =
  ProfilePackageSetGroup
    <$> textOption "package-set" "SET" "Package set to change"
    <*> (UpdateGroupName <$> textOption "group" "GROUP" "Update group to reprofile")
    <*> textOption "profile" "PROFILE" "Compatibility profile"
    <*> dryRunParser

supportParser :: Parser PackageSetCommand
supportParser =
  SetPackageSetSupport
    <$> textOption "package-set" "SET" "Package set to relabel"
    <*> option supportLevelReader (long "support-level" <> metavar "curated|historical")
    <*> dryRunParser

textOption :: String -> String -> String -> Parser Text
textOption optionName placeholder description =
  Text.pack <$> strOption (long optionName <> metavar placeholder <> help description)

dryRunParser :: Parser Bool
dryRunParser = switch (long "dry-run" <> help "Validate and report without changing managed files")

supportLevelReader :: ReadM PackageSetSupportLevel
supportLevelReader = eitherReader $ \case
  "curated" -> Right Curated
  "historical" -> Right Historical
  unknownLevel -> Left ("unknown support level: " <> unknownLevel)

renderSupportLevel :: PackageSetSupportLevel -> String
renderSupportLevel Curated = "curated"
renderSupportLevel Historical = "historical"

parseImportSet :: String -> Either String (Text, Text)
parseImportSet importSpec =
  case Text.breakOn "=" (Text.pack importSpec) of
    (name, commit)
      | not (Text.null name), Just expression <- Text.stripPrefix "=" commit, not (Text.null expression) -> Right (name, expression)
    _ -> Left "expected NAME=GIT_COMMIT"
