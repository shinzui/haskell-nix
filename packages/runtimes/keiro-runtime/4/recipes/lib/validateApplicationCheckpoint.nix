# Bind reuse to an explicitly reviewed, successfully built clean checkpoint.
# Recomputing both records in today's scope cannot establish checkpoint origin.
{ lib }:
{ currentCompatibility, declaration, checkpoint, seedSourceCompatibility ? null }:
let
  shape = builtins.isAttrs declaration
    && builtins.attrNames declaration == [ "compatibility" "derivation" "schemaVersion" ]
    && declaration.schemaVersion == 1
    && builtins.isString declaration.derivation && declaration.derivation != ""
    && builtins.isAttrs declaration.compatibility;
  # This comparison must precede forcing the old package. A dependency update may
  # make old Haskell source impossible to construct or compile in the new scope.
  sameContext = shape && currentCompatibility == declaration.compatibility;
  seedDifferences = if seedSourceCompatibility == null then [ ] else
  builtins.filter
    (field: seedSourceCompatibility.${field} != (declaration.compatibility.${field} or null))
    (builtins.attrNames seedSourceCompatibility);
  sameSeedInputs = sameContext && seedDifferences == [ ];
  accepted = sameSeedInputs && checkpoint.drvPath == declaration.derivation;
in
{
  inherit accepted;
  differences =
    if !shape then [ "validatedCheckpoint" ]
    else if !sameContext then
      builtins.filter
        (field: (currentCompatibility.${field} or null) != (declaration.compatibility.${field} or null))
        (lib.unique (builtins.attrNames currentCompatibility ++ builtins.attrNames declaration.compatibility))
    else if !sameSeedInputs then seedDifferences
    else if !accepted then [ "validatedCheckpoint" ]
    else [ ];
  reason =
    if declaration == null then "no validated checkpoint declaration"
    else if !shape then "invalid checkpoint declaration"
    else if !sameContext then "validated checkpoint compatibility changed"
    else if !sameSeedInputs then "validated checkpoint source metadata changed"
    else if !accepted then "validated checkpoint derivation changed"
    else "validated checkpoint identity matches";
}
