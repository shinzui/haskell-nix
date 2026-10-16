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
  haskellLib.dontCheck = drv: drv // { doCheck = false; };
  selected = mkLayer cohort haskellLib { zlib = "native-zlib"; }
    { callHackageDirect = source: args: source // { disabledTestArguments = args; }; }
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
in
{
  testCohortLayerPreservesCompilerBoot = { expr = selected.boot; expected = null; };
  testCohortLayerAddsMissingPackage = {
    expr = selected.added;
    expected = { pkg = "added"; ver = "1"; sha256 = "retained-hash"; doCheck = false; disabledTestArguments = { }; };
  };
  testCohortLayerPassesSelectedMetadata = {
    expr = selected.revised.rev;
    expected = { revision = "2"; sha256 = "metadata-hash"; };
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
