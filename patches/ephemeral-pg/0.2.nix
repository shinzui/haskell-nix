# ephemeral-pg 0.2.1.0 — pin from Hackage.
# Not in nixpkgs' GHC package set. Older keiro/kiroku only used it inside test
# suites (hence the historical empty stub + dontCheck), but the current
# kiroku-test-support / keiro-test-support import `EphemeralPg` from *library*
# code, so a real build of the package is required. It only spawns PostgreSQL at
# runtime, so dontCheck keeps the build offline.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "ephemeral-pg";
  ver = "0.2.1.0";
  sha256 = "sha256-2dJhEXgAzUOQo9hOogGvj9MOuE/RwfXpzEwuc32KXm0=";
} {}))
