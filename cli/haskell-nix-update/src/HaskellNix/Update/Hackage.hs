module HaskellNix.Update.Hackage
  ( HttpResponse (..),
    HttpClient (..),
    defaultHttpClient,
    decodeHackageRelease,
    queryHackage,
    packageMetadataUrl,
    packageArchiveUrl,
  )
where

import Control.Exception (try)
import Data.Aeson (Value, eitherDecodeStrict', withObject, (.:))
import Data.Aeson.Key qualified as Key
import Data.Aeson.KeyMap qualified as KeyMap
import Data.Aeson.Types (Parser, parseEither)
import Data.ByteString (ByteString)
import Data.ByteString.Lazy qualified as LazyByteString
import Data.Text (Text)
import Data.Text qualified as Text
import Distribution.Parsec (simpleParsec)
import Distribution.Pretty (prettyShow)
import Distribution.Types.Version (Version)
import HaskellNix.Update.Types
import Network.HTTP.Client qualified as Http
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Status qualified as HttpStatus

data HttpResponse = HttpResponse
  { statusCode :: !Int,
    body :: !ByteString
  }
  deriving stock (Eq, Show)

newtype HttpClient = HttpClient
  { performGet :: Text -> IO (Either UpdateError HttpResponse)
  }

defaultHttpClient :: IO HttpClient
defaultHttpClient = do
  manager <- Http.newManager tlsManagerSettings
  pure $ HttpClient (getWithManager manager)

queryHackage :: HttpClient -> PackageName -> IO (Either UpdateError (Maybe HackageRelease))
queryHackage HttpClient {performGet} packageName = do
  let url = packageMetadataUrl packageName
  response <- performGet url
  pure $ do
    HttpResponse {statusCode, body} <- prefixError ("Hackage request " <> url <> ": ") response
    case statusCode of
      200 -> Just <$> decodeHackageRelease packageName body
      404 -> Right Nothing
      other -> Left (UpdateError ("Hackage request " <> url <> " returned HTTP " <> Text.pack (show other)))

decodeHackageRelease :: PackageName -> ByteString -> Either UpdateError HackageRelease
decodeHackageRelease packageName bytes = do
  value <- firstError "invalid Hackage JSON" (eitherDecodeStrict' bytes)
  releases <- firstError "invalid Hackage release metadata" (parseEither parseReleases value)
  case releases of
    [] -> Left (UpdateError ("Hackage returned no versions for " <> packageNameText packageName))
    _ ->
      let normalReleases = [version | (version, status) <- releases, status == "normal"]
       in case normalReleases of
            [] -> Right HackageRelease {version = maximum releasesByVersion, usedFallback = True}
            _ -> Right HackageRelease {version = maximum normalReleases, usedFallback = False}
      where
        releasesByVersion = map fst releases

packageMetadataUrl :: PackageName -> Text
packageMetadataUrl packageName =
  "https://hackage.haskell.org/package/" <> packageNameText packageName <> ".json"

packageArchiveUrl :: PackageName -> Version -> Text
packageArchiveUrl packageName version =
  let stem = packageNameText packageName <> "-" <> Text.pack (prettyShow version)
   in "https://hackage.haskell.org/package/" <> stem <> "/" <> stem <> ".tar.gz"

getWithManager :: Http.Manager -> Text -> IO (Either UpdateError HttpResponse)
getWithManager manager url = do
  attempted <-
    try $ do
      request <- Http.parseRequest (Text.unpack url)
      response <- Http.httpLbs request manager
      pure
        HttpResponse
          { statusCode = HttpStatus.statusCode (Http.responseStatus response),
            body = LazyByteString.toStrict (Http.responseBody response)
          }
      :: IO (Either Http.HttpException HttpResponse)
  pure $ either (Left . UpdateError . (("request failed for " <> url <> ": ") <>) . Text.pack . show) Right attempted

parseReleases :: Value -> Parser [(Version, Text)]
parseReleases = withObject "Hackage releases" $ \fields ->
  traverse parseRelease (KeyMap.toList fields)
  where
    parseRelease (key, value) = do
      version <-
        maybe
          (fail ("invalid Hackage version key: " <> Text.unpack (Key.toText key)))
          pure
          (simpleParsec (Text.unpack (Key.toText key)))
      status <- withObject "Hackage release" (.: "status") value
      pure (version, status)

packageNameText :: PackageName -> Text
packageNameText (PackageName name) = name

firstError :: Text -> Either String value -> Either UpdateError value
firstError context = either (Left . UpdateError . ((context <> ": ") <>) . Text.pack) Right

prefixError :: Text -> Either UpdateError value -> Either UpdateError value
prefixError prefix = either (Left . UpdateError . (prefix <>) . message) Right
