# mkHaskellOverlay :: { registry, compilers? } -> NixpkgsOverlay
#
# High-level combinator that turns a patch registry into a nixpkgs-level
# overlay applying version-scoped patches to multiple GHC package sets.
{ lib }:

{ registry
, compilers ? [ "ghc9122" "ghc914" ]
}:

let
  fixPackageByVersion = import ./fixPackageByVersion.nix { inherit lib; };

  # Build one Haskell-level override per registry entry
  perPackageOverrides = lib.mapAttrsToList
    (name: table: fixPackageByVersion name table)
    registry;

  # Compose all per-package overrides into a single Haskell extension.
  # Provide a local fallback for composeManyExtensions in case an older
  # nixpkgs lacks it.
  composeManyExtensions = lib.composeManyExtensions or
    (extensions: lib.foldr lib.composeExtensions (_: _: { }) extensions);

  # haskellLib and pkgs are passed at overlay-application time so patches
  # get access to the full haskell.lib.compose API and top-level nixpkgs.
  mkCombinedOverride = haskellLib: pkgs:
    composeManyExtensions (map (f: f haskellLib pkgs) perPackageOverrides);

in
# nixpkgs-level overlay
final: prev:
let
  applyToCompilerSet = compilerName:
    let
      hpkgs = prev.haskell.packages.${compilerName};
      haskellLib = prev.haskell.lib.compose;
    in
    hpkgs.override (old: {
      overrides = lib.composeExtensions
        (old.overrides or (_: _: { }))
        (mkCombinedOverride haskellLib prev);
    });

in
{
  haskell = prev.haskell // {
    packages = prev.haskell.packages // (
      lib.genAttrs compilers applyToCompilerSet
    );
  };

  # haskellPackages is a self-referencing alias to haskell.packages.<default-ghc>
  # in nixpkgs, so it automatically picks up our changes above — no separate
  # override needed (doing so causes infinite recursion).
}
