# Names come from the retained record, never from the package fixed point.
{ lib }:
cohort: haskellLib: pkgs:
hself: hsuper:
let
  arguments = import ../overlays/cohort-arguments.nix { inherit pkgs; };
in
lib.mapAttrs
  (name: entry:
  if builtins.hasAttr name hsuper && hsuper.${name} == null then null
  else
    haskellLib.dontCheck (hself.callHackageDirect
      ({ pkg = name; ver = entry.version; sha256 = entry.sha256; }
        // lib.optionalAttrs (entry.revision != null) {
        rev = { revision = entry.revision.number; sha256 = entry.revision.sha256; };
      })
      (arguments.${name} or { })))
  cohort.packages
