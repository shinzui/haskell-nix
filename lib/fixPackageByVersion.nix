# fixPackageByVersion :: String -> [{ min; max; patch } | { always; patch }] -> HaskellLib -> (hself -> hsuper -> AttrSet)
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

name: table: haskellLib:

hself: hsuper:
{
  ${name} =
    let
      pkg = hsuper.${name};

      alwaysEntry = lib.findFirst (e: e.always or false) null table;

      versionMatch =
        if alwaysEntry != null then null
        else lib.findFirst
          (e: !(e.always or false)
            && lib.versionAtLeast pkg.version e.min
            && lib.versionOlder pkg.version e.max)
          null
          table;

      match = if alwaysEntry != null then alwaysEntry else versionMatch;
    in
    if match != null
    then match.patch { inherit pkg lib haskellLib hself hsuper; }
    else pkg;
}
