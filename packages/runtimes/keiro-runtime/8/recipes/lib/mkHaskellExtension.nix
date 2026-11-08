# mkHaskellExtension ::
#   { registry : Registry
#   , extraOverrides ? HaskellExtension
#   , disableProfiling ? Bool
#   , disableHaddock ? Bool
#   }
#   -> HaskellLib -> Pkgs -> HaskellExtension
{ lib }:

{ registry
, extraOverrides ? (_: _: { })
, versionLayer ? (_: _: _: _: { })
, disableProfiling ? true
, disableHaddock ? true
, captureCompatibility ? false
}:

let
  fixPackageByVersion = import ./fixPackageByVersion.nix { inherit lib captureCompatibility; };
  disableProfilingOverride = import ./disableProfilingOverride.nix;
  disableHaddockOverride = import ./disableHaddockOverride.nix;
  composeManyExtensions = lib.composeManyExtensions or
    (extensions: lib.foldr lib.composeExtensions (_: _: { }) extensions);
  perPackageOverrides = lib.mapAttrsToList
    (name: table: fixPackageByVersion name table)
    registry;
in
haskellLib: pkgs:
composeManyExtensions
  (lib.optional disableProfiling disableProfilingOverride
    ++ lib.optional disableHaddock disableHaddockOverride
    ++ [ extraOverrides ]
    ++ [ (versionLayer haskellLib pkgs) ]
  ++ map (override: override haskellLib pkgs) perPackageOverrides)
