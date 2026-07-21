module HaskellNix.Update.Git
  ( ensureRevision,
    requireRevision,
    discoverPackages,
    remoteHead,
  )
where

import Data.Char (isHexDigit)
import Data.List (sortOn)
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import Distribution.Package (pkgName, pkgVersion)
import Distribution.PackageDescription (package, packageDescription)
import Distribution.PackageDescription.Parsec (parseGenericPackageDescriptionMaybe)
import Distribution.Types.PackageName (unPackageName)
import HaskellNix.Update.Process
import HaskellNix.Update.Types
import System.Exit (ExitCode (..))
import System.FilePath (splitDirectories, takeDirectory, takeExtension)

requireRevision :: ProcessRunner -> FilePath -> GitRevision -> IO (Either UpdateError ())
requireRevision runner repository revision = do
  result <- revisionExists runner repository revision
  pure $ case result of
    Left updateError -> Left updateError
    Right True -> Right ()
    Right False ->
      Left
        ( UpdateError
            ( "Git object "
                <> revisionText revision
                <> " is missing from "
                <> Text.pack repository
            )
        )

ensureRevision :: ProcessRunner -> FilePath -> GitRevision -> IO (Either UpdateError ())
ensureRevision runner repository revision = do
  exists <- revisionExists runner repository revision
  case exists of
    Left updateError -> pure (Left updateError)
    Right True -> pure (Right ())
    Right False -> do
      fetched <- runChecked runner (gitSpec repository ["fetch", "origin", Text.unpack (revisionText revision)])
      case fetched of
        Left updateError -> pure (Left updateError)
        Right _ -> requireRevision runner repository revision

discoverPackages :: ProcessRunner -> FilePath -> GitRevision -> IO (Either UpdateError [DiscoveredPackage])
discoverPackages runner repository revision = do
  treeResult <-
    runChecked
      runner
      (gitSpec repository ["ls-tree", "-r", "--name-only", Text.unpack (revisionText revision)])
  case treeResult of
    Left updateError -> pure (Left updateError)
    Right ProcessResult {standardOutput} -> do
      let cabalPaths = filter isRootPackagePath (map Text.unpack (Text.lines standardOutput))
      parsed <- traverse (readPackage runner repository revision) cabalPaths
      pure (sortOn packageKey <$> sequence parsed)
  where
    packageKey DiscoveredPackage {name = PackageName packageName} = packageName

remoteHead :: ProcessRunner -> Text -> IO (Either UpdateError GitRevision)
remoteHead runner github = do
  let url = "https://github.com/" <> github <> ".git"
  result <-
    runChecked
      runner
      ProcessSpec
        { executable = "git",
          arguments = ["ls-remote", Text.unpack url, "HEAD"],
          workingDirectory = Nothing,
          environmentAdditions = []
        }
  pure $ do
    ProcessResult {standardOutput} <- result
    case Text.words standardOutput of
      revision : _
        | validRevision revision -> Right (GitRevision revision)
      _ -> Left (UpdateError ("could not parse remote HEAD from " <> url))

revisionExists :: ProcessRunner -> FilePath -> GitRevision -> IO (Either UpdateError Bool)
revisionExists ProcessRunner {runProcess} repository revision = do
  result <- runProcess (gitSpec repository ["cat-file", "-e", Text.unpack (revisionText revision) <> "^{commit}"])
  pure $ case result of
    Left updateError -> Left updateError
    Right ProcessResult {exitCode = ExitSuccess} -> Right True
    Right ProcessResult {exitCode = ExitFailure _} -> Right False

readPackage :: ProcessRunner -> FilePath -> GitRevision -> FilePath -> IO (Either UpdateError DiscoveredPackage)
readPackage runner repository revision cabalPath = do
  result <-
    runChecked
      runner
      (gitSpec repository ["show", Text.unpack (revisionText revision) <> ":" <> cabalPath])
  pure $ do
    ProcessResult {standardOutput} <- result
    description <-
      maybe
        (Left (UpdateError ("could not parse " <> Text.pack cabalPath <> " at " <> revisionText revision)))
        Right
        (parseGenericPackageDescriptionMaybe (TextEncoding.encodeUtf8 standardOutput))
    let identifier = package (packageDescription description)
    Right
      DiscoveredPackage
        { name = PackageName (Text.pack (unPackageName (pkgName identifier))),
          path = takeDirectory cabalPath,
          version = pkgVersion identifier
        }

gitSpec :: FilePath -> [String] -> ProcessSpec
gitSpec repository arguments =
  ProcessSpec
    { executable = "git",
      arguments = "-C" : repository : arguments,
      workingDirectory = Nothing,
      environmentAdditions = []
    }

-- A family repository holds either a single package at its root or one package
-- per top-level directory. Deeper Cabal files belong to examples, fixtures, or
-- vendored trees and are never family packages.
isRootPackagePath :: FilePath -> Bool
isRootPackagePath path =
  case splitDirectories path of
    [fileName] -> isCabalFile fileName
    [directory, fileName] -> not (null directory) && isCabalFile fileName
    _ -> False
  where
    isCabalFile fileName = takeExtension fileName == ".cabal"

revisionText :: GitRevision -> Text
revisionText (GitRevision revision) = revision

validRevision :: Text -> Bool
validRevision value = Text.length value == 40 && Text.all isHexDigit value
