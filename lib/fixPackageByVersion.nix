# fixPackageByVersion :: String -> [{ min; max; patch }] -> HaskellLib -> (hself -> hsuper -> AttrSet)
#
# Core version-dispatch primitive. Given a package name and a version table,
# returns a Haskell-level override function that applies the matching patch
# for the resolved package version.
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
      match = lib.findFirst
        (entry:
          lib.versionAtLeast pkg.version entry.min
          && lib.versionOlder pkg.version entry.max)
        null
        table;
    in
    if match != null
    then match.patch { inherit pkg lib haskellLib; }
    else pkg;
}
