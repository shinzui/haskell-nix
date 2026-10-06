# Coupled released wrapper for the selected admitting rebase 1.22.
# mori://nikita-volkov/rerebase, rerebase.cabal (artifact-level URI pending).
# Hackage 1.22 matches upstream tag d018faa2bd3416dfa11aca236d00e761aa9144ab,
# https://github.com/nikita-volkov/rerebase/tree/d018faa2bd3416dfa11aca236d00e761aa9144ab
# and retains the exact rebase ==1.22 dependency. Retire once selected >=1.22.
{ pkg, lib, hself, ... }:
if pkg.version != "1.21.2"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  hself.callHackageDirect
  {
    pkg = "rerebase";
    ver = "1.22";
    sha256 = "0a4q7vzi3mny0xrljqsadcz40v0vr17qqmpdanpyia57lcanc1qw";
  }
  { }
