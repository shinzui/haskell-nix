# Smallest admitting published release: mori://nikita-volkov/rebase/packages/rebase
# Hackage 1.22 matches upstream tag e5d80dc13648deef44986b68056bec614fd43b3d.
# https://github.com/nikita-volkov/rebase/tree/e5d80dc13648deef44986b68056bec614fd43b3d
# Retire when the selected version is already >=1.22; other compilers retain it.
{ pkg, lib, hself, ... }:
if pkg.version != "1.21.2"
  || !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  hself.callHackageDirect
  {
    pkg = "rebase";
    ver = "1.22";
    sha256 = "086k7y6llkxzpnx6ijx4rgqw94zp9zqys8llw9qwvydh30wfvprf";
  }
  { }
