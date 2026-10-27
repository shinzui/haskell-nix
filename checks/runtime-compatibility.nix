{ lib, pkgs, updater, mkRuntimePackageSet, channel }:
let
  record = builtins.head (builtins.filter (row: row.generation == 3)
    (builtins.fromJSON (builtins.readFile ../packages/runtime-lock.json)).runtimes.keiro-runtime);
  retained = builtins.fromJSON (builtins.readFile
    (../. + "/${record.recipeDirectory}/packages/first-party-lock.json"));
  complete = builtins.head (builtins.filter
    (row: row.name == retained.defaultPackageSet)
    retained.packageSets);
  applicationSelections = lib.listToAttrs
    (map
      (selection: lib.nameValuePair selection.group selection.generation)
      (builtins.filter (selection: !(builtins.hasAttr selection.group record.selections)) complete.groups)) // import ../lib/catalogApplicationComplements.nix;
  select = generation: captureCompatibility: mkRuntimePackageSet {
    runtime = "keiro-runtime";
    inherit generation captureCompatibility channel applicationSelections;
  };
  ordinary = select 3 false;
  captured = select 3 true;
  scope = captured.mkApplicationScope pkgs (_: _: { });
  reference = ordinary.mkApplicationScope pkgs (_: _: { });
  names = [ "bytestring-lexing" "servant-docs" "kioku-core" "unicode-data" ];
  identities = lib.genAttrs names (name: {
    ordinary = reference.${name}.drvPath;
    captured = scope.${name}.drvPath;
  });
  report = captured.compatibilityReport { inherit pkgs scope names; };
  lexical = builtins.head (builtins.filter
    (row: row.id == "legacy-cohort-source-v1" && row.package == "bytestring-lexing")
    report.entries);
  oldRejected = generation: !(builtins.tryEval (builtins.deepSeq (select generation true).selections true)).success;
  defaultRejected = !(builtins.tryEval (ordinary.compatibilityReport {
    inherit pkgs names;
    scope = { };
  })).success;
in
assert oldRejected 1 && oldRejected 2;
assert defaultRejected;
assert builtins.all (pair: pair.ordinary == pair.captured) (builtins.attrValues identities);
assert report.problems == [ ];
assert report.configuration.runtimeConfiguration.fingerprint == record.fingerprint;
assert lexical.construction.after.effective.testsEnabled;
assert !lexical.construction.after.effective.boundsRelaxed;
assert builtins.any (row: row.id == "legacy-servant-docs-v1") report.entries;
{
  inherit report identities;
  check = pkgs.runCommand "retained-runtime-compatibility-${channel}"
    { nativeBuildInputs = [ updater ]; }
    ''
      haskell-nix-update compatibility check --context ${pkgs.writeText "retained-context.json" (builtins.toJSON report)}
      mkdir "$out"
      cp ${pkgs.writeText "retained-report.json" (builtins.toJSON report)} "$out/report.json"
    '';
}
