# Bind catalog rows to the actual executable registry without forcing packages.
{ lib }:
registry:
let
  catalog = builtins.fromJSON (builtins.readFile ../config/compatibility-exceptions.json);
  policies = builtins.fromJSON (builtins.readFile ../config/package-build-policies.json);
  rowBinding = package: row: { kind = "registry-row"; inherit package row; };
  recipeBindings = lib.concatLists
    (lib.mapAttrsToList
      (package: rows: lib.imap0 (row: _: rowBinding package row) rows)
      registry)
  ++ map (name: { kind = "profile"; inherit name; }) (builtins.attrNames policies.profiles)
  ++ [
    { kind = "generated-first-party"; name = "source-constructor"; }
    { kind = "generated-cohort"; name = "source-constructor"; }
  ];
  # A strict profile has no waivers. Coverage concerns executable effects, not
  # profiles that intentionally declare neither tests nor bounds exceptions.
  coveredBindings = builtins.filter
    (binding: binding.kind != "profile" ||
      policies.profiles.${binding.name}.tests.exceptionIds
        ++ policies.profiles.${binding.name}.bounds.exceptionIds != [ ])
    recipeBindings;
  validated = builtins.seq ((import ./validateCompatibilityEntries.nix { inherit lib; }) registry)
    (import ./validateCompatibilityPolicy.nix { inherit lib; } {
      inherit catalog policies;
      recipeBindings = coveredBindings;
    });
  idsFor = binding: map (entry: entry.id)
    (builtins.filter (entry: entry.binding == binding) catalog.entries);
  annotated = lib.mapAttrs
    (package: rows: lib.imap0
      (row: entry: entry // {
        exceptionIds = idsFor (rowBinding package row);
        sourceConstructor = builtins.any
          (record: record.binding == rowBinding package row && builtins.elem "source-replacement" record.effects)
          catalog.entries;
      })
      rows)
    registry;
in
builtins.seq validated {
  inherit catalog policies recipeBindings;
  generatedPolicyProfiles = {
    firstParty = "legacy-first-party-v1";
    cohort = "legacy-skip-enforce-v1";
  };
  registry = annotated;
}
