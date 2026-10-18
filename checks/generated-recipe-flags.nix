{ lib }:
let
  normalise = import ../lib/normaliseGeneratedRecipeFlags.nix { inherit lib; };
  hash = lib.concatStrings (lib.replicate 64 "a");
  rule = {
    version = "1.0";
    metadataSha256 = hash;
    flags.debug = false;
    reason = "Exact fixture metadata declares debug default false.";
  };
  args = {
    name = "fixture";
    version = "1.0";
    metadataSha256 = hash;
    selectedFlags.debug = false;
    rules.fixture = rule;
    haskellLib.overrideCabal = change: package: package // change package;
    package = { configureFlags = [ "-f-debug" "-fkeep" ]; source = "unchanged"; };
  };
  rejects = extra: !(builtins.tryEval (builtins.deepSeq (normalise (args // extra)) true)).success;
in
{
  testGeneratedFlagsRemoveOnlyReviewedRedundantSpelling = {
    expr = normalise args;
    expected = { configureFlags = [ "-fkeep" ]; source = "unchanged"; };
  };
  testGeneratedFlagsKeepUnknownPackage = {
    expr = normalise (args // { name = "other"; });
    expected = args.package;
  };
  testGeneratedFlagsKeepChangedMetadata = {
    expr = normalise (args // { metadataSha256 = lib.concatStrings (lib.replicate 64 "b"); });
    expected = args.package;
  };
  testGeneratedFlagsKeepNewVersion = {
    expr = normalise (args // { version = "2.0"; });
    expected = args.package;
  };
  testGeneratedFlagsRejectDifferentSelectedValue = {
    expr = rejects { selectedFlags.debug = true; };
    expected = true;
  };
  testGeneratedFlagsRejectMissingSelectedValue = {
    expr = rejects { selectedFlags = { }; };
    expected = true;
  };
  testGeneratedFlagsRejectMissingConverterSpelling = {
    expr = rejects { package.configureFlags = [ "-fkeep" ]; };
    expected = true;
  };
  testGeneratedFlagsRejectUnsupportedTrueDefaultRule = {
    expr = rejects { rules.fixture = rule // { flags.debug = true; }; };
    expected = true;
  };
  testGeneratedFlagsRejectMalformedMetadataIdentity = {
    expr = rejects { rules.fixture = rule // { metadataSha256 = "unbound"; }; };
    expected = true;
  };
}
