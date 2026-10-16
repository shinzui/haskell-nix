{ lib }:
let
  cohort = import ../generated/cohort-versions.nix;
  pkgs = {
    haskell.compiler.ghc9124.version = "9.12.4";
    runCommand = name: _: _: { inherit name; };
  };
  accepts = overrides: (builtins.tryEval
    (import ./cohort-parity.nix ({
      inherit lib pkgs cohort;
      nixpkgsRevision = cohort.nixpkgsBase;
    } // overrides)).cohort-generated-fresh).success;
  rejectsCohort = changes: { expr = accepts { cohort = cohort // changes; }; expected = false; };
in
{
  testGeneratedCohortFresh = { expr = accepts { }; expected = true; };
  testGeneratedCohortRejectsUnknownSchema = rejectsCohort { schemaVersion = 2; };
  testGeneratedCohortRejectsFlagDrift = rejectsCohort { flags.aeson.unrecorded = true; };
  testGeneratedCohortRejectsWrongVersion = rejectsCohort {
    packages = cohort.packages // { aeson = cohort.packages.aeson // { version = "0"; }; };
  };
  testGeneratedCohortRejectsMissingPackage = rejectsCohort {
    packages = builtins.removeAttrs cohort.packages [ "aeson" ];
  };
  testGeneratedCohortRejectsMetadataDrift = rejectsCohort {
    packages = cohort.packages // {
      aeson = cohort.packages.aeson // { revision = { number = "1"; sha256 = "incorrect"; }; };
    };
  };
  testGeneratedCohortRejectsDuplicateOwnership = rejectsCohort {
    firstParty = cohort.firstParty ++ [ "aeson" ];
  };
  testGeneratedCohortRejectsSourceDrift = rejectsCohort {
    sourceManifest = cohort.sourceManifest // {
      aeson = cohort.sourceManifest.aeson // { identities = [ ]; };
    };
  };
  testGeneratedCohortRejectsStaleFreeze = { expr = accepts { freezeSha256 = "stale"; }; expected = false; };
  testGeneratedCohortRejectsWrongCompiler = {
    expr = accepts { boot = (import ../generated/ghc-boot-packages.nix) // { ghc = "other"; }; };
    expected = false;
  };
  testGeneratedCohortRejectsWrongNixpkgs = { expr = accepts { nixpkgsRevision = "other"; }; expected = false; };
}
