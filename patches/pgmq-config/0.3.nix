# pgmq-config 0.3.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
{
  pkg = "pgmq-config";
  ver = "0.3.0.0";
  sha256 = "sha256-ooZgv8bqtWjhtmLw6rom75LGNRSwq8cUvdH9umjAMGQ=";
}
{ }))
