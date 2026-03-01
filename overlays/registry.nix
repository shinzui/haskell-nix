# Patch registry — single source of truth for all version-scoped patches.
#
# To add a new package:
#   1. Create patch file(s) under patches/<package>/<version>.nix
#   2. Add entry here mapping package name to version-range table
#
# Each entry is a list of { min, max, patch } where:
#   min — inclusive lower bound (lib.versionAtLeast)
#   max — exclusive upper bound (lib.versionOlder)
#   patch — path to a Nix file receiving { pkg, lib, haskellLib }
{
  hasql = [
    { min = "1.9";  max = "1.10"; patch = import ../patches/hasql/1.9.nix; }
    { min = "1.10"; max = "1.11"; patch = import ../patches/hasql/1.10.nix; }
  ];
}
