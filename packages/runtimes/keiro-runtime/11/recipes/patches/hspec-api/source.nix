# Heni's adapter uses the formatter API matching the already frozen hspec-core.
# Intended owner: mori://hspec/hspec/packages/hspec-api (registration pending).
# Immutable upstream 2.11.18 release, kept separate from shared Hackage selection.
{ hself, haskellLib, pkgs, ... }:
let
  source = pkgs.fetchFromGitHub {
    owner = "hspec";
    repo = "hspec";
    rev = "96242bf996b3eccc10cfe3406c16ffcb519b422d";
    hash = "sha256-u1y0oZlOrQKxI5PDTdDJYmF0qvf2USPTt9buYqbgSqc=";
  };
in
haskellLib.overrideCabal
  (drv: {
    passthru = (drv.passthru or { }) // {
      cohortSourceOrigin = { inherit source; subdirectory = "hspec-api"; };
    };
  })
  (hself.callCabal2nix "hspec-api" (source + "/hspec-api") { })
