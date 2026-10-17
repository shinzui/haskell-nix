{ lib, pkgs, mkFirstPartyPackageSet, compiler, channel ? "github" }:
let
  selected = captureCompatibility: mkFirstPartyPackageSet {
    inherit channel captureCompatibility;
    packageSet = "default";
  };
  construct = captureCompatibility: pkgs.haskell.packages.${compiler}.override {
    overrides = (selected captureCompatibility).haskellExtension pkgs.haskell.lib.compose pkgs;
  };
  ordinary = construct false;
  captured = construct true;
  names = [ "base64-bytestring" "cborg-json" "kioku-core" "unicode-data" ];
  identities = lib.genAttrs names (name: {
    ordinary = ordinary.${name}.drvPath;
    captured = captured.${name}.drvPath;
  });
  report = (import ../lib/capturedCompatibilityReport.nix { inherit lib; }) {
    scope = captured;
    inherit names channel;
    packageSet = "default";
    system = pkgs.stdenv.hostPlatform.system;
  };
  kioku = lib.findFirst (entry: entry.id == "legacy-kioku-core-v1") null report.entries;
  metadata = lib.findFirst (entry: entry.id == "legacy-cborg-json-v1") null report.entries;
  ghc914 = captured.ghc.version == "9.14.1";
in
assert lib.assertMsg (builtins.all (pair: pair.ordinary == pair.captured) (builtins.attrValues identities))
  "compatibility capture changed production derivations";
assert lib.assertMsg
  (builtins.getContext (builtins.toJSON captured.kioku-core.compatibilityObservations) != { }
    && builtins.getContext (builtins.toJSON report) == { })
  "compatibility report retained build dependencies from diagnostic strings";
assert lib.assertMsg
  (kioku.inputs.sourceIdentity == (import ../lib/compatibilitySourceIdentity.nix { inherit lib; }) ordinary.kioku-core.src
    && kioku.status == (if ghc914 then "selected-unverified" else "inactive-scope")
    && metadata.status == (if ghc914 then "selected-unverified" else "inactive-scope"))
  "compatibility report disagreed with selected inputs: ${builtins.toJSON {
    source = kioku.inputs.sourceIdentity;
    expectedSource = (import ../lib/compatibilitySourceIdentity.nix { inherit lib; }) ordinary.kioku-core.src;
    kiokuStatus = kioku.status;
    metadataStatus = metadata.status;
    compiler = captured.ghc.version;
  }}";
assert lib.assertMsg
  (!ghc914 || (
    builtins.elem "--ghc-option=-fno-opt-coercion" kioku.construction.after.effective.configureFlags
      && metadata.construction.before.effective.hooks.postPatch != metadata.construction.after.effective.hooks.postPatch
      && !metadata.retirementCandidate
  ))
  "compatibility report lost the actual flag/bounds repair or inferred unsafe metadata retirement";
{
  inherit report identities;
}
