{ lib }:
let
  validate = import ../lib/validateApplicationCheckpoint.nix { inherit lib; };
  currentCompatibility = { recipeIdentity = "reviewed-input-graph"; };
  declaration = { schemaVersion = 1; derivation = "reviewed-clean-seed.drv"; compatibility = currentCompatibility; };
  checkpoint.drvPath = declaration.derivation;
  run = extra: validate ({ inherit currentCompatibility declaration checkpoint; } // extra);
  rejectedWithoutSeed = changed: (run {
    inherit (changed) declaration;
    checkpoint = throw "invalid origin forced old source";
  }).accepted == false;
in
{
  testApplicationCheckpointRejectsReplacedSeedMetadataLazily = {
    expr = (run {
      seedSourceCompatibility.metadataIdentity = "replaced";
      checkpoint = throw "replaced Cabal metadata forced old package construction";
    }).differences;
    expected = [ "metadataIdentity" ];
  };
  testApplicationCheckpointReportsChangedInputs = {
    expr = (run { currentCompatibility = { recipeIdentity = "different"; }; }).differences;
    expected = [ "recipeIdentity" ];
  };
  testApplicationCheckpointAcceptsBoundOrigin = { expr = (run { }).accepted; expected = true; };
  testApplicationCheckpointMissingDeclarationIsLazy = { expr = rejectedWithoutSeed { declaration = null; }; expected = true; };
  testApplicationCheckpointRejectsUnknownSchemaLazily = {
    expr = rejectedWithoutSeed { declaration = declaration // { schemaVersion = 2; }; };
    expected = true;
  };
  testApplicationCheckpointRejectsUnknownFieldLazily = {
    expr = rejectedWithoutSeed { declaration = declaration // { guessed = true; }; };
    expected = true;
  };
  testApplicationCheckpointRejectsChangedCompilerOrDependencyLazily = {
    expr = (run {
      currentCompatibility = { recipeIdentity = "updated-toolchain-or-dependency"; };
      checkpoint = throw "updated context forced incompatible old source";
    }).accepted;
    expected = false;
  };
  testApplicationCheckpointRejectsReplacementWithSameProjection = {
    expr = (run { checkpoint.drvPath = "reconstructed-unvalidated-seed.drv"; }).accepted;
    expected = false;
  };
  testApplicationCheckpointRejectsEmptyDerivationLazily = {
    expr = rejectedWithoutSeed { declaration = declaration // { derivation = ""; }; };
    expected = true;
  };
  testApplicationCheckpointRejectsMalformedCompatibilityLazily = {
    expr = rejectedWithoutSeed { declaration = declaration // { compatibility = "guessed"; }; };
    expected = true;
  };
}
