# Public release matching the accepted cohort floor and cached cleanup API.
# mori://shinzui/ephemeral-pg/packages/ephemeral-pg, v0.3.1.0 peeled to
# e38175c155c71a77284d3f4b321726755cdb1de8.
# mori://shinzui/ephemeral-pg/docs/guides + temporary-roots-and-stale-cleanup.md
# (artifact-level URI pending) requires a stable per-uid temporaryRoot.
# EP9's version layer retires this source replacement once its selection >=0.3.1.0.
# Retain the existing PostgreSQL integration-test exclusion; no bounds jailbreak.
{ pkg, lib, haskellLib, hself, ... }:
let
  selected =
    if lib.versionOlder pkg.version "0.3.1.0" then
      hself.callHackageDirect
        {
          pkg = "ephemeral-pg";
          ver = "0.3.1.0";
          sha256 = "0sr8xpglwkzk6bgxdm9n1zdndjdqp49sks57ck97525vj6m83z6h";
        }
        { }
    else pkg;
in
haskellLib.markUnbroken (haskellLib.dontCheck selected)
