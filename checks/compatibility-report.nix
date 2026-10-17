{ lib }:
let
  report = import ../lib/compatibilityReport.nix { inherit lib; };
  context = import ./fixtures/compatibility-policy/context.nix;
  result = report context;
  entry = value: id: builtins.head (builtins.filter (row: row.id == id) value.entries);
  rejects = value: { expr = !(builtins.tryEval (builtins.deepSeq value true)).success; expected = true; };
  policy = (import ../lib/mkCompatibilityPolicy.nix { inherit lib; }) (import ../overlays/registry.nix);
  editedPolicy = change: policy // { catalog = policy.catalog // { entries = map change policy.catalog.entries; }; };
in
{
  testReportGoldenMatchesAdapter = {
    expr = result == builtins.fromJSON (builtins.readFile ../cli/haskell-nix-update/test/fixtures/valid/compatibility-report.json);
    expected = true;
  };
  testReportSharesCompilerGuard = {
    expr = map (compiler: (entry (report (context // { ghc = context.ghc // { version = compiler; }; })) "legacy-kioku-core-v1").status)
      [ "9.14.1" "9.14.2" "9.12.4" ];
    expected = [ "selected-unverified" "inactive-scope" "inactive-scope" ];
  };
  testReportSourceGuardIsNeverInferred = {
    expr = (entry result "legacy-cborg-json-v1").sourceGuard;
    expected = "unverified";
  };
  testReportExactMetadataVersionGuard = {
    expr = (entry
      (report (context // {
        packages = context.packages // {
          cborg-json = context.packages.cborg-json // { version = "0.2.6.1"; };
        };
      })) "legacy-cborg-json-v1").status;
    expected = "inactive-row";
  };
  testReportBothChannelsAndRetainedConfigurations = {
    expr = map (channel: (entry (report (context // { inherit channel; })) "legacy-kioku-core-v1").status) [ "github" "hackage" ];
    expected = [ "selected-unverified" "selected-unverified" ];
  };
  testReportExplicitLegacyWaivers = {
    expr = map (id: (entry result id).status) [ "legacy-first-party-v1-test-suppression" "legacy-first-party-v1-bound-relaxation" ];
    expected = [ "selected-unverified" "selected-unverified" ];
  };
  testReportRequiresSelectedEvidence = {
    expr = builtins.length (report (context // { requiredEvidence = [ "legacy-kioku-core-v1" ]; })).problems;
    expected = 1;
  };
  testReportCannotHideMissingRequiredInstance = {
    expr = builtins.length (report (context // { packages = { }; requiredEvidence = [ "legacy-kioku-core-v1" ]; })).problems;
    expected = 1;
  };
  testReportProseDoesNotChangeIdentities = {
    expr =
      let
        changed = (import ../lib/compatibilityReport.nix {
          inherit lib;
          policy = editedPolicy (row: row // { reason = "Changed descriptive reason."; });
        }) context;
      in
      [ (result.inputIdentity == changed.inputIdentity) (result.policyIdentity == changed.policyIdentity) ];
    expected = [ true true ];
  };
  testReportEffectivePolicyChangesIdentity = {
    expr = result.policyIdentity != ((import ../lib/compatibilityReport.nix {
      inherit lib;
      policy = editedPolicy (row: row // { effects = row.effects ++ [ "fixture-change" ]; });
    }) context).policyIdentity;
    expected = true;
  };
  testReportMetadataAndSourceChangesIdentity = {
    expr = map
      (field: result.inputIdentity != (report (context // {
        packages = context.packages // {
          cborg-json = context.packages.cborg-json // { ${field} = "changed"; };
        };
      })).inputIdentity) [ "sourceIdentity" "metadataIdentity" "derivation" ];
    expected = [ true true true ];
  };
  testReportRejectMissingInputIdentity = rejects (report (context // {
    packages = {
      cborg-json = builtins.removeAttrs context.packages.cborg-json [ "sourceIdentity" ];
    };
  }));
  testReportRejectUnknownProfile = rejects (report (context // {
    packages = {
      cborg-json = context.packages.cborg-json // { profiles = [ "missing" ]; };
    };
  }));
  testReportRejectUnknownRequiredId = rejects (report (context // { requiredEvidence = [ "missing" ]; }));
  testReportRejectDuplicateRequiredIds = rejects (report (context // { requiredEvidence = [ "legacy-kioku-core-v1" "legacy-kioku-core-v1" ]; }));
  testReportRejectInvalidVersionFacts = rejects (report (context // {
    packages = {
      cborg-json = context.packages.cborg-json // { version = "unknown"; };
    };
  }));
  testReportRejectDuplicateProfileInstances = rejects (report (context // {
    packages = {
      cborg-json = context.packages.cborg-json // { profiles = [ "legacy-first-party-v1" "legacy-first-party-v1" ]; };
    };
  }));
  testReportRetirementThresholdIsOnlyACandidate = {
    expr =
      let
        candidate = (import ../lib/compatibilityReport.nix {
          inherit lib;
          policy = editedPolicy (row: if row.id != "legacy-kioku-core-v1" then row else row // {
            retirement = { kind = "selected-version"; threshold = "0.8.0.2"; condition = "Controlled fixture threshold, not an upstream claim."; };
          });
        }) context;
      in
      let row = entry candidate "legacy-kioku-core-v1";
      in [ row.retirementCandidate (row.unmetChecks != [ ]) (row.evidenceStatus == "unverified") ];
    expected = [ true true true ];
  };
  testCapturedAdmittingMetadataIsOnlyARetirementCandidate = {
    expr =
      let
        inputs = context.packages.cborg-json;
        before = inputs // { effective.editedCabalFile = "selected-admitting-metadata"; };
        captured = report (context // {
          packages.cborg-json = inputs // {
            selectedExceptionIds = [ "legacy-cborg-json-v1" ];
            inputsByException.legacy-cborg-json-v1 = inputs;
            construction.legacy-cborg-json-v1 = { stage = "compatibility-row"; inherit before; after = before; };
          };
        });
        row = entry captured "legacy-cborg-json-v1";
      in
      [ row.retirementCandidate (row.unmetChecks != [ ]) (row.evidenceStatus == "unverified") ];
    expected = [ true true true ];
  };
  testReportNeverRunsPatchFunctions = {
    expr =
      let
        lazyPolicy = policy // {
          registry = lib.mapAttrs (_: rows: map (row: row // { patch = throw "report forced a recipe"; }) rows) policy.registry;
        };
      in
      builtins.deepSeq ((import ../lib/compatibilityReport.nix { inherit lib; policy = lazyPolicy; }) context) true;
    expected = true;
  };
}
