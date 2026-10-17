# A real no-entry probe, independent of production retirement. The selected
# cohort already supplies r3; both strict recipes must retain that exact source.
{ channel, system ? "aarch64-darwin", sourceChannel ? "github" }:
let
  pkgs = import channel.inputs.nixpkgs { inherit system; };
  lib = pkgs.lib;
  hl = pkgs.haskell.lib.compose;
  scope = pkgs.haskell.packages.ghc9141.override {
    overrides = channel.lib.haskellExtensions.${sourceChannel} hl pkgs;
  };
  name = "servant-docs";
  entryId = "legacy-servant-docs-v1";
  entry = (import ../generated/cohort-versions.nix).packages.servant-docs;
  rows = channel.lib.registries.${sourceChannel}.servant-docs;
  arguments = (import ../overlays/cohort-arguments.nix { inherit pkgs; }).servant-docs or { };
  raw = (import ../lib/callCohortHackage.nix { inherit lib; }) {
    inherit pkgs name entry arguments;
    hself = scope;
    haskellLib = hl;
  };
  validation = channel.lib.mkPackageValidation {
    inherit pkgs entryId;
    mkRecipe = { policyProfile, disabledEntryIds, ... }:
      let
        strict = (import ../lib/applyPackageBuildPolicy.nix) policyProfile hl raw;
        selectedRows = if builtins.elem entryId disabledEntryIds then [ ] else rows;
      in
      (
        (import ../lib/fixPackageByVersion.nix { inherit lib; })
          name
          selectedRows
          hl
          pkgs
          scope
          { servant-docs = strict; }
      ).servant-docs;
  };
  phases = [ "baseline" "candidate" ];
  graphs = lib.genAttrs phases (phase: channel.lib.mkCohortManifest {
    inherit pkgs scope;
    root = validation.${phase};
    context = { purpose = "servant-docs admitting-metadata no-entry probe"; inherit entryId sourceChannel; };
  });
  behavior = lib.genAttrs phases (phase: pkgs.runCommand "servant-docs-no-entry-behavior"
    { nativeBuildInputs = [ pkgs.gnugrep ]; }
    ''
      ${validation.${phase}}/bin/greet-docs > generated.md
      grep -Fq '## GET' generated.md
      grep -Fq '## POST' generated.md
      grep -Fq 'Hello, haskeller' generated.md
      mkdir "$out"
      cp generated.md "$out/"
      echo EP21_SERVANT_DOCS_NO_ENTRY_BEHAVIOR_PASSED
    '');
  descriptor = builtins.head (builtins.filter
    (row: row.id == entryId)
    channel.lib.compatibilityPolicy.catalog.entries);
  policyIdentity = builtins.hashString "sha256" (builtins.toJSON {
    strictProfile = channel.lib.compatibilityPolicy.policies.profiles.strict-v1;
    target = { inherit (descriptor) id effects applicability binding; };
  });
  context = channel.lib.mkCompatibilityProbeContext {
    inherit validation graphs policyIdentity;
    channel = sourceChannel;
    requiredSuites = [ "spec" ];
    behaviorProbes = lib.genAttrs phases (phase: { example = behavior.${phase}; });
  };
in
assert builtins.elem system [ "aarch64-darwin" "x86_64-linux" ];
assert builtins.elem sourceChannel [ "github" "hackage" ];
assert scope.ghc.version == "9.14.1";
assert entry.version == "0.13.1" && entry.revision == {
  number = "3";
  sha256 = "69402db0eb641ee31e20c6e449baf58dac5bbe190150d3eb6d7f5fe861275048";
};
assert builtins.length rows == 1 && (builtins.head rows).exceptionIds == [ entryId ];
assert validation.baseline.drvPath == validation.candidate.drvPath;
{
  inherit validation graphs behavior context;
  inherit (validation) baseline candidate;
  ordinary = scope.servant-docs;
}
