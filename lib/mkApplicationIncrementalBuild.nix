{ lib }:
{ pkgs
, package
, seedPackage
, currentCompatibility
, seedCompatibility
, enabled ? true
}:
let
  # recipeIdentity is the actual recipe projected onto a fixed dummy source.
  # It must include compiler/native tools, Setup/Cabal, build ways, flags, hooks
  # and dependency identities. Only explicitly declared generated source may be
  # normalized. The caller also fingerprints Cabal/Setup bytes and source layout.
  fields = [
    "packageName"
    "packageVersion"
    "compilerIdentity"
    "recipeIdentity"
    "metadataIdentity"
    "sourceLayoutIdentity"
    "generatedInputPolicy"
  ];
  valid = record: builtins.isAttrs record
    && (record.schemaVersion or null) == 1
    && builtins.all
    (field: builtins.isString (record.${field} or null) && record.${field} != "")
    fields
    && lib.subtractLists ([ "schemaVersion" ] ++ fields) (builtins.attrNames record) == [ ];
  recordsValid = valid currentCompatibility && valid seedCompatibility;
  differences = if !enabled then [ ] else if recordsValid then
    builtins.filter (field: currentCompatibility.${field} != seedCompatibility.${field}) fields
  else [ "invalid-compatibility-record" ];
  matchesPackage = record: recipe:
    builtins.isAttrs recipe
    && record.packageName == (recipe.pname or null) && record.packageVersion == (recipe.version or null)
    && record.compilerIdentity == (recipe.compiler.drvPath or null);
  identitiesValid = recordsValid
    && matchesPackage currentCompatibility package
    && matchesPackage seedCompatibility seedPackage;
  accepted = enabled && recordsValid && differences == [ ] && identitiesValid;
  overrideCabal = pkgs.haskell.lib.compose.overrideCabal;
  seed = overrideCabal
    (_: {
      doInstallIntermediates = true;
      enableSeparateIntermediatesOutput = true;
      previousIntermediates = null;
    })
    seedPackage;
  reason =
    if !enabled then "disabled"
    else if !recordsValid then "invalid compatibility record"
    else if differences != [ ] then "incompatible: ${lib.concatStringsSep ", " differences}"
    else if !identitiesValid then "record does not match package/compiler identity"
    else "compatible explicit seed";
in
{
  package = builtins.trace "application-incremental ${package.pname}: ${reason}" (
    if accepted then
      overrideCabal
        (_: {
          doInstallIntermediates = true;
          enableSeparateIntermediatesOutput = true;
          previousIntermediates = seed.intermediates;
        })
        package else package
  );
  # Do not retain/build a seed on the disabled or incompatible path.
  seed = if accepted then seed else null;
  compatibilityReport = {
    schemaVersion = 1;
    inherit enabled accepted reason differences;
  };
}
