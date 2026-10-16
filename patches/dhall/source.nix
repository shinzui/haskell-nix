# mori://dhall-lang/dhall-haskell: exact Cabal cohort source, subdirectory dhall.
# This commit already admits microlens 0.5, GHC 9.14/time 1.15 and TLS 0.4.
{ hself, haskellLib, pkgs, ... }:
let
  source = pkgs.fetchFromGitHub {
    owner = "dhall-lang";
    repo = "dhall-haskell";
    rev = "03b40e85d0c677350ad2a2f75ef92627d5952cee";
    hash = "sha256-ashbketzUtSHiTQBMlzyhCKGfr9/Dhxh7rudU4zPDl4=";
  };
in
haskellLib.dontCheck (haskellLib.overrideCabal
  (drv: {
    passthru = (drv.passthru or { }) // {
      cohortSourceOrigin = { inherit source; subdirectory = "dhall"; };
    };
  })
  (hself.callCabal2nix "dhall" (source + "/dhall") { }))
