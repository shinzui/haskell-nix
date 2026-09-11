# hasql-notifications 0.2.5.0 — the last release targeting hasql 1.10
# (`hasql >=1.10 && <1.11`); 0.2.6.0 moves to hasql 2.0.
#
# The release nixpkgs ships (0.2.4.0) only supports hasql < 1.10 and fails to
# compile against the hasql 1.10 the keiro stack uses (Hasql.Connection /
# Hasql.Session no longer export withLibPQConnection / run / sql).
# doJailbreak relaxes any remaining bounds against the pinned package set;
# dontCheck skips the postgres-backed test suite.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "hasql-notifications";
  ver = "0.2.5.0";
  sha256 = "sha256-iLw/CEQclpzJI9ep47Mgrzkin3oXdQwL4+UEH5/NU4Y=";
} { }))
