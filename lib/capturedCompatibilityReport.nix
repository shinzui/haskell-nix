# Consume observations made inside the actual recursive scope, preserving its
# final dependency instances. Reconstructing a second unpatched scope is unsound.
{ lib, policy ? (import ./mkCompatibilityPolicy.nix { inherit lib; }) (import ../overlays/registry.nix) }:
{ scope, names, packageSet, channel, system, runtimeConfiguration ? null, requiredEvidence ? [ ] }:
let
  catalogById = lib.listToAttrs (map (entry: lib.nameValuePair entry.id entry) policy.catalog.entries);
  packages = lib.genAttrs names (name:
    let
      observations = scope.${name}.compatibilityObservations or
        (throw "compatibility capture: ${name} has no construction observations; enable captureCompatibility in the selected constructor");
      selected = builtins.filter (event: event.exceptionIds != [ ]) observations;
      pairs = lib.concatMap (event: map (id: { inherit id event; }) event.exceptionIds) selected;
      ids = map (pair: pair.id) pairs;
      bindings = map (id: catalogById.${id}.binding or (throw "compatibility capture: unknown observed exception ${id}")) ids;
      last = lib.last observations;
      input = event: if event.before == null then event.after else event.before;
    in
    if observations == [ ] || lib.unique ids != ids || !builtins.all (event: event.name == name) observations then
      throw "compatibility capture: empty, duplicate or wrong-package observations for ${name}"
    else last.after // {
      selectedExceptionIds = ids;
      profiles = lib.unique (map (binding: binding.name) (builtins.filter (binding: binding.kind == "profile") bindings));
      generated = lib.unique (map (binding: binding.kind) (builtins.filter (binding: builtins.elem binding.kind [ "generated-first-party" "generated-cohort" ]) bindings));
      inputsByException = lib.listToAttrs (map (pair: lib.nameValuePair pair.id (input pair.event)) pairs);
      construction = lib.listToAttrs (map
        (pair: lib.nameValuePair pair.id {
          inherit (pair.event) stage before after;
          changedFields = if pair.event.before == null then [ ] else
          builtins.filter
            (field: pair.event.before.${field} != pair.event.after.${field})
            [ "version" "sourceIdentity" "metadataIdentity" "derivation" "effective" ];
        })
        pairs);
    });
in
if !builtins.isList names || names == [ ] || lib.unique names != names then
  throw "compatibility capture: names must be a nonempty unique package list"
else
  (import ./compatibilityReport.nix { inherit lib policy; }) {
    inherit packages packageSet channel system runtimeConfiguration requiredEvidence;
    ghc = { inherit (scope.ghc) version; derivation = scope.ghc.drvPath; };
  }
