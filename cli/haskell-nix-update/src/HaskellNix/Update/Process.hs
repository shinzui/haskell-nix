module HaskellNix.Update.Process
  ( ProcessSpec (..),
    ProcessResult (..),
    ProcessRunner (..),
    defaultProcessRunner,
    streamingProcessRunner,
    runChecked,
    commandText,
  )
where

import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
import Control.Exception (IOException, SomeException, evaluate, throwIO, try)
import Data.ByteString (ByteString)
import Data.ByteString qualified as ByteString
import Data.Map.Strict qualified as Map
import Data.Text (Text)
import Data.Text qualified as Text
import Data.Text.Encoding qualified as TextEncoding
import HaskellNix.Update.Types (UpdateError (..))
import System.Environment (getEnvironment)
import System.Exit (ExitCode (..))
import System.IO (Handle, hClose, hFlush, stderr)
import System.Process (CreateProcess (..), StdStream (..), proc, readCreateProcessWithExitCode, waitForProcess, withCreateProcess)

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

-- | Captures both streams, printing nothing. Suited to output that is read by
-- another program, such as `just status` collecting the updater's stderr.
defaultProcessRunner :: ProcessRunner
defaultProcessRunner = mkProcessRunner $ \createProcess -> do
  (exitCode, standardOutput, standardError) <- readCreateProcessWithExitCode createProcess ""
  pure (exitCode, Text.pack standardOutput, Text.pack standardError)

-- | Captures both streams like 'defaultProcessRunner', but also copies stderr
-- to this process's stderr as it arrives. `nix` reports evaluation, fetching,
-- and builds on stderr, so without this a validation that takes an hour is
-- indistinguishable from a hang. Stdout stays captured only, since callers
-- parse it.
streamingProcessRunner :: ProcessRunner
streamingProcessRunner = mkProcessRunner $ \createProcess ->
  withCreateProcess
    createProcess {std_in = CreatePipe, std_out = CreatePipe, std_err = CreatePipe}
    $ \standardInputHandle standardOutputHandle standardErrorHandle processHandle ->
      case (standardInputHandle, standardOutputHandle, standardErrorHandle) of
        (Just inputHandle, Just outputHandle, Just errorHandle) -> do
          -- An empty stdin, as readCreateProcessWithExitCode gives.
          hClose inputHandle
          -- Drain stdout concurrently so a child that fills the stdout pipe
          -- cannot block while this thread is reading stderr.
          outputVar <- newEmptyMVar
          _ <- forkIO $ do
            drained <- try (ByteString.hGetContents outputHandle >>= evaluate)
            putMVar outputVar (drained :: Either SomeException ByteString)
          standardError <- teeToStderr errorHandle
          standardOutput <- takeMVar outputVar >>= either throwIO pure
          exitCode <- waitForProcess processHandle
          pure (exitCode, decode standardOutput, decode standardError)
        _ -> ioError (userError "process pipes were not created")
  where
    decode = TextEncoding.decodeUtf8Lenient

teeToStderr :: Handle -> IO ByteString
teeToStderr handle = go []
  where
    go chunks = do
      chunk <- ByteString.hGetSome handle 4096
      if ByteString.null chunk
        then hClose handle >> pure (ByteString.concat (reverse chunks))
        else do
          ByteString.hPut stderr chunk
          hFlush stderr
          go (chunk : chunks)

mkProcessRunner :: (CreateProcess -> IO (ExitCode, Text, Text)) -> ProcessRunner
mkProcessRunner run = ProcessRunner $ \spec@ProcessSpec {executable, arguments, workingDirectory, environmentAdditions} -> do
  inheritedEnvironment <- getEnvironment
  let mergedEnvironment =
        Map.toList
          (Map.union (Map.fromList environmentAdditions) (Map.fromList inheritedEnvironment))
      createProcess =
        (proc executable arguments)
          { cwd = workingDirectory,
            env = Just mergedEnvironment
          }
  attempted <- try (run createProcess) :: IO (Either IOException (ExitCode, Text, Text))
  pure $ case attempted of
    Left exception ->
      Left
        (UpdateError ("could not run " <> commandText spec <> ": " <> Text.pack (show exception)))
    Right (exitCode, standardOutput, standardError) ->
      Right ProcessResult {exitCode, standardOutput, standardError}

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

-- Keep the tail rather than the head of stderr. Tools like `nix` stream
-- progress ("evaluating 'apps'...") first and write the actual error trace
-- last, so a leading slice would surface only noise. Taking the end preserves
-- the failure message that explains why the command exited non-zero.
conciseStderr :: Text -> Text
conciseStderr value =
  case Text.strip value of
    "" -> ""
    stripped -> ": " <> Text.takeEnd 4000 stripped
