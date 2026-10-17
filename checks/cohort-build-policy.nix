{ lib }:
let
  configured = builtins.fromJSON (builtins.readFile ../config/cohort-build-policy-selections.json);
  rule = builtins.head configured.selections;
  profiles = (builtins.fromJSON (builtins.readFile ../config/package-build-policies.json)).profiles;
  make = selections: import ../lib/selectCohortBuildPolicy.nix { inherit lib profiles selections; };
  selector = make configured;
  facts = {
    name = rule.package;
    entry = { inherit (rule.eligibility) version sha256 revision; };
    compiler = "9.12.4";
    system = "aarch64-darwin";
    channel = "github";
  };
  legacy = { profile = "legacy-skip-enforce-v1"; selectionId = null; };
  invalid = change: {
    expr = (builtins.tryEval (builtins.deepSeq
      (make (configured // {
        selections = [ (change rule) ];
      }))
      true)).success;
    expected = false;
  };
  rejectsInput = entry: {
    expr = (builtins.tryEval (builtins.deepSeq (selector.select (facts // { inherit entry; })) true)).success;
    expected = false;
  };
in
{
  testCohortVerifiedPolicySelectsExactSource = {
    expr = selector.select facts;
    expected = { profile = rule.profile; selectionId = rule.id; };
  };
  testCohortVerifiedPolicyCoversBothChannelsAndVerifiedPlatforms = {
    expr = builtins.all
      (system: builtins.all
        (channel: (selector.select (facts // { inherit system channel; })).profile == rule.profile)
        [ "github" "hackage" ])
      [ "aarch64-darwin" "x86_64-linux" ];
    expected = true;
  };
  testCohortVerifiedPolicyKeepsOtherCompilerLegacy = {
    expr = selector.select (facts // { compiler = "9.14.1"; entry = throw "unselected source forced"; });
    expected = legacy;
  };
  testCohortVerifiedPolicyKeepsOtherPlatformLegacy = {
    expr = selector.select (facts // { system = "aarch64-linux"; entry = throw "unselected source forced"; });
    expected = legacy;
  };
  testCohortVerifiedPolicyDoesNotForceUnrelatedCompiler = {
    expr = selector.select (facts // { name = "unrelated"; compiler = throw "unrelated compiler forced"; });
    expected = legacy;
  };
  testCohortVerifiedPolicyRejectsSourceDrift = rejectsInput (facts.entry // {
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  });
  testCohortVerifiedPolicyRejectsNewVersionUntilReviewed = rejectsInput (facts.entry // { version = "0.5.0.17"; });
  testCohortVerifiedPolicyRejectsMetadataRevisionDrift = rejectsInput (facts.entry // {
    revision = { number = "1"; sha256 = rule.eligibility.sha256; };
  });
  testCohortVerifiedPolicyAcceptsReviewedCohortMetadataHash = {
    expr =
      let
        revision = { number = "2"; sha256 = "bad2c5f159ee81d2c2fd11e7957d76c4f37f3a40c9866f76014b131575aa35fe"; };
        reviewed = make (configured // {
          selections = [ (rule // { eligibility = rule.eligibility // { inherit revision; }; }) ];
        });
      in
      reviewed.select (facts // { entry = facts.entry // { inherit revision; }; });
    expected = { profile = rule.profile; selectionId = rule.id; };
  };
  testCohortVerifiedPolicyRequiresOwnedEvidence = invalid (value: value // { evidence = [ ]; });
  testCohortVerifiedPolicyRejectsUnknownProfile = invalid (value: value // { profile = "unknown"; });
  testCohortVerifiedPolicyRejectsLegacyWaiverSelection = invalid (value: value // { profile = legacy.profile; });
  testCohortVerifiedPolicyCannotAssumeAServiceEnvironment = {
    expr = (builtins.tryEval (builtins.deepSeq
      (import ../lib/selectCohortBuildPolicy.nix {
        inherit lib;
        selections = configured;
        profiles = profiles // {
          ${rule.profile} = profiles.${rule.profile} // {
            tests = profiles.${rule.profile}.tests // { services = [ "postgresql" ]; };
          };
        };
      })
      true)).success;
    expected = false;
  };
  testCohortVerifiedPolicyRejectsEmptyScope = invalid (value: value // {
    eligibility = value.eligibility // { systems = [ ]; };
  });
  testCohortVerifiedPolicyRejectsAmbiguousOwner = invalid (value: value // { owner = "haskell-nix"; });
  testCohortVerifiedPolicyRejectsOverlap = {
    expr = (builtins.tryEval (builtins.deepSeq
      (make (configured // {
        selections = [ rule (rule // { id = "another-selection"; }) ];
      }))
      true)).success;
    expected = false;
  };
  testCohortVerifiedPolicyProseAndEvidenceDoNotChangeSemantics = {
    expr = (make (configured // {
      selections = [ (rule // { reason = "Updated explanation"; evidence = [ "new-observation.json" ]; }) ];
    })).semanticSelections;
    expected = selector.semanticSelections;
  };
}
