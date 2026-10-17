# fixPackageByVersion :: String -> [{ min; max; patch } | { always; patch }] -> HaskellLib -> Pkgs -> (hself -> hsuper -> AttrSet)
#
# Core version-dispatch primitive. Given a package name and a version table,
# returns a Haskell-level override function that applies the matching patch
# for the resolved package version.
#
# Entries may be version-scoped ({ min, max, patch }) or always-apply
# ({ always = true; patch }).  Always-apply entries skip version matching
# entirely, which avoids evaluating pkg.version — important for packages
# being replaced wholesale via callCabal2nix.
#
# IMPORTANT: The version check is deferred into the attribute value, not into
# the attrset structure. Using version-dependent conditionals to control which
# attributes EXIST (e.g., optionalAttrs) forces evaluation of hsuper.<pkg>,
# which triggers nixpkgs' splice machinery and causes infinite recursion.
# Instead, we always produce { <name> = ...; } and let the version dispatch
# happen lazily when the attribute is actually consumed.
{ lib }:

name: table: haskellLib: pkgs:

hself: hsuper:
{
  ${name} =
    let
      pkg = hsuper.${name};

      match = (import ./selectCompatibilityEntry.nix { inherit lib; }) table {
        version = pkg.version;
      };
    in
    if match != null
    then match.patch { inherit pkg lib haskellLib pkgs hself hsuper; }
    else pkg;
}
