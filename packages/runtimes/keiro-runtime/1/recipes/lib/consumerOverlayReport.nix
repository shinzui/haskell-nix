# Names are sufficient: auditing an overlay must not fetch or build its values.
{ lib }:
{ channelPackages
, overlayPackages
, ownPackages
, siblingPackages ? [ ]
, exceptions ? { }
, generatedPackages ? [ ]
, frozenPackages ? [ ]
, sourcePackages ? [ ]
, runtimePackages ? [ ]
}:
let
  sorted = names: lib.sort builtins.lessThan (lib.unique names);
  owned = sorted (channelPackages ++ generatedPackages ++ frozenPackages
    ++ sourcePackages ++ runtimePackages);
  declarations = ownPackages ++ siblingPackages ++ builtins.attrNames exceptions;
  overlay = sorted overlayPackages;
  invalidReasons = builtins.filter
    (name:
      let reason = exceptions.${name}; in
      !(builtins.isString reason) || builtins.match "[[:space:]]*" reason != null)
    (builtins.attrNames exceptions);
  duplicateDeclarations = builtins.filter
    (name: builtins.length (builtins.filter (other: other == name) declarations) > 1)
    (sorted declarations);
  shadowing = builtins.filter (name: builtins.elem name owned) overlay;
  # A shared name is already diagnosed as shadowing; reserve undeclared for unknown names.
  undeclared = builtins.filter
    (name: !(builtins.elem name declarations) && !(builtins.elem name owned))
    overlay;
  unusedDeclarations = builtins.filter (name: !(builtins.elem name overlay)) (sorted declarations);
  invalidDeclarations = sorted (invalidReasons ++ duplicateDeclarations);
in
{
  inherit shadowing undeclared unusedDeclarations invalidDeclarations;
  ok = shadowing == [ ] && undeclared == [ ] && unusedDeclarations == [ ] && invalidDeclarations == [ ];
}
