# Diagnostic attributes live on the returned derivation value, never in its
# builder arguments. Only the fields below are forced when a report is requested.
{ lib }:
{ name, entry, before, after, haskellLib, selected ? true }:
let
  sourceConstructor = (entry.sourceConstructor or false) || entry ? buildPolicyProfile;
  identify = package: (import ./packageRecipeFacts.nix { inherit lib; }) { inherit haskellLib package; };
  observation = {
    inherit name;
    exceptionIds = entry.observedExceptionIds or (entry.exceptionIds or [ ]);
    stage = if !selected then "unselected-row" else if sourceConstructor then "source-constructor" else "compatibility-row";
    profile = entry.buildPolicyProfile or null;
    # Source constructors may replace a missing stock package. Their input is
    # intentionally absent; the nested repair receives the actual selected one.
    before = if sourceConstructor then null else identify before;
    after = identify after;
  };
in
after // {
  compatibilityObservations = lib.unique
    (
      (if sourceConstructor then [ ] else before.compatibilityObservations or [ ])
      ++ (after.compatibilityObservations or [ ])
    ) ++ [ observation ];
}
