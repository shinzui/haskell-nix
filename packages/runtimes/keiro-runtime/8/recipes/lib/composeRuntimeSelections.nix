{ lib }:
{ groups, runtimeSelections, applicationSelections ? { } }:
let
  overlap = lib.intersectLists (builtins.attrNames runtimeSelections) (builtins.attrNames applicationSelections);
  conflicts = builtins.filter (name: runtimeSelections.${name} != applicationSelections.${name}) overlap;
  selected = applicationSelections // runtimeSelections;
  expected = builtins.sort builtins.lessThan groups;
  missing = lib.subtractLists (builtins.attrNames selected) expected;
  unknown = lib.subtractLists expected (builtins.attrNames selected);
in
if conflicts != [ ] then
  throw "composeRuntimeSelections: application conflicts with runtime groups: ${lib.concatStringsSep ", " conflicts}"
else if missing != [ ] || unknown != [ ] then
  throw "composeRuntimeSelections: missing complementary groups: ${lib.concatStringsSep ", " missing}; unknown groups: ${lib.concatStringsSep ", " unknown}"
else if !builtins.all (value: builtins.isInt value && value > 0) (builtins.attrValues selected) then
  throw "composeRuntimeSelections: generations must be positive integers"
else selected
