{ lib }:
let
  mkLayer = import ../lib/mkCohortVersionLayer.nix { inherit lib; };
  recipe = revision: { version = "1"; sha256 = "retained-hash"; inherit revision; };
  cohort.packages = {
    boot = recipe null;
    added = recipe null;
    revised = recipe { number = "2"; sha256 = "metadata-hash"; };
    hasql-dynamic-statements = recipe null;
    zlib = recipe null;
  };
  haskellLib = {
    dontCheck = drv: drv // { doCheck = false; };
    overrideCabal = change: drv: drv // change drv;
  };
  selected = mkLayer cohort haskellLib
    {
      zlib = "native-zlib";
      fetchzip = source: source;
      fetchurl = source: source;
      runCommand = name: attrs: script: { inherit name attrs script; };
    }
    {
      callHackageDirect = source: args: source // { disabledTestArguments = args; };
      callCabal2nixWithOptions = name: source: options: args: {
        inherit source;
        translatedMetadata = options.srcModifier source;
        disabledTestArguments = args;
      };
    }
    { boot = null; };
  extension =
    (import ../lib/mkHaskellExtension.nix { inherit lib; })
      {
        versionLayer = mkLayer { packages.example = recipe null; };
        extraOverrides = _: _: { example = { version = "extra"; stages = [ "extra" ]; }; };
        registry.example = [{
          always = true;
          patch = { pkg, ... }: pkg // { stages = pkg.stages ++ [ "policy" ]; };
        }];
      }
      haskellLib
      { };
  base = {
    mkDerivation = args: args;
    callHackageDirect = source: _: { version = source.ver; stages = [ "generated" ]; };
    example = { version = "base"; stages = [ "base" ]; };
  };
  composed = extension base base;
  normalizedPlatform = mkLayer { packages = { }; } haskellLib
    { stdenv.hostPlatform.config = "arm64-apple-darwin"; }
    { }
    {
      haskellSrc2nix = _: {
        overrideAttrs = change: change {
          buildCommand = "cabal2nix --system=arm64-apple-darwin source";
        };
      };
    };
in
{
  testCohortLayerNormalizesAppleArchitectureForCabalConditions = {
    expr = (normalizedPlatform.haskellSrc2nix { }).buildCommand;
    expected = "cabal2nix --system=aarch64-apple-darwin source";
  };
  testCohortLayerPreservesCompilerBoot = { expr = selected.boot; expected = null; };
  testCohortLayerAddsMissingPackage = {
    expr = selected.added;
    expected = { pkg = "added"; ver = "1"; sha256 = "retained-hash"; doCheck = false; disabledTestArguments = { }; };
  };
  testCohortLayerPassesSelectedMetadata = {
    expr = {
      inherit (selected.revised) revision editedCabalFile;
      translated = selected.revised.translatedMetadata.attrs.selectedCabalFile;
      sourceHash = selected.revised.source.sha256;
    };
    expected = {
      revision = "2";
      editedCabalFile = "metadata-hash";
      sourceHash = "retained-hash";
      translated = {
        url = "mirror://hackage/revised-1/revision/2.cabal";
        name = "revised-1-r2.cabal";
        sha256 = "metadata-hash";
      };
    };
  };
  testCohortLayerDoesNotInventRevisionZeroOverride = { expr = selected.added ? rev; expected = false; };
  testCohortLayerCanConstructPackageWithoutDisabledTestDependencies = {
    expr = selected.hasql-dynamic-statements.doCheck;
    expected = false;
  };
  testCohortLayerRejectsUseOfDisabledTestDependency = {
    expr = (builtins.tryEval selected.hasql-dynamic-statements.disabledTestArguments.pqi-native).success;
    expected = false;
  };
  testCohortLayerResolvesNativeZlibOutsideHaskellScope = {
    expr = selected.zlib.disabledTestArguments.zlib;
    expected = "native-zlib";
  };
  testCohortLayerPolicyWrapsGeneratedSelection = {
    expr = composed.example;
    expected = { version = "1"; stages = [ "generated" "policy" ]; doCheck = false; };
  };
  testCohortLayerKeepsGlobalBuildFlags = {
    expr = composed.mkDerivation { };
    expected = { enableLibraryProfiling = false; doHaddock = false; };
  };
}
