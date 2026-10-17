{ lib }:
let
  policy = (import ../lib/mkCompatibilityPolicy.nix { inherit lib; }) (import ../overlays/registry.nix);
  validate = catalog: policies: bindings:
    import ../lib/validateCompatibilityPolicy.nix { inherit lib; } {
      inherit catalog policies;
      recipeBindings = bindings;
    };
  bindings = builtins.filter (binding: binding.kind != "profile" || binding.name != "strict-v1") policy.recipeBindings;
  rejects = value: { expr = !(builtins.tryEval (builtins.deepSeq value true)).success; expected = true; };
  changeFirst = change: policy.catalog // {
    entries = [ (change (builtins.head policy.catalog.entries)) ] ++ builtins.tail policy.catalog.entries;
  };
  badCatalog = change: rejects (validate (changeFirst change) policy.policies bindings);
  badProfile = change: rejects (validate policy.catalog
    (policy.policies // {
      profiles = policy.policies.profiles // {
        legacy-first-party-v1 = change policy.policies.profiles.legacy-first-party-v1;
      };
    })
    bindings);
  apply = import ../lib/applyPackageBuildPolicy.nix;
  select = import ../lib/selectCompatibilityEntry.nix { inherit lib; };
  applies = import ../lib/compatibilityEntryApplies.nix { inherit lib; };
  validateEntries = import ../lib/validateCompatibilityEntries.nix { inherit lib; };
  haskellLib = {
    dontCheck = value: value ++ [ "skip-tests" ];
    doJailbreak = value: value ++ [ "relax-bounds" ];
    doCheck = value: value ++ [ "run-tests" ];
    dontJailbreak = value: value ++ [ "enforce-bounds" ];
  };
in
{
  testCompatibilityEmptySelectorsRemainLazy = {
    expr = validateEntries { empty = [ ]; };
    expected = true;
  };
  testCompatibilityAdjacentRangesDoNotOverlap = {
    expr = validateEntries { example = [{ min = "1"; max = "2"; } { min = "2"; max = "3"; }]; };
    expected = true;
  };
  testCompatibilityRejectNewOverlappingRanges = rejects (validateEntries {
    example = [{ min = "1"; max = "3"; } { min = "2"; max = "4"; }];
  });
  testCompatibilityRejectNewDuplicateAlwaysRows = rejects (validateEntries {
    example = [{ always = true; } { always = true; }];
  });
  testCompatibilityRejectNewAlwaysAndRangeOverlap = rejects (validateEntries {
    example = [{ always = true; } { min = "1"; max = "2"; }];
  });
  testCompatibilityRejectReversedSelectorRange = rejects (validateEntries {
    example = [{ min = "3"; max = "2"; }];
  });
  testCompatibilityExactCompilerAndReleasedSources = {
    expr = map (facts: applies "legacy-kioku-core-v1" facts) [
      { compiler = "9.14.1"; version = "0.8.0.2"; }
      { compiler = "9.14.1"; version = "0.9.0.2"; }
      { compiler = "9.14.2"; version = "0.9.0.2"; }
      { compiler = "9.14.1"; version = "0.8.0.3"; }
      { compiler = "9.12.4"; version = "0.8.0.2"; }
    ];
    expected = [ true true false false false ];
  };
  testCompatibilityMetadataRequiresExactVersion = {
    expr = map (version: applies "legacy-cborg-json-v1" { inherit version; compiler = "9.14.1"; })
      [ "0.2.6.0" "0.2.6.0.1" "0.2.6.1" ];
    expected = [ true false false ];
  };
  testCompatibilityMetadataCompilerRange = {
    expr = map (compiler: applies "legacy-servant-v1" { inherit compiler; version = "0.20.3.0"; })
      [ "9.12.4" "9.14.1" "9.15.1" ];
    expected = [ false true false ];
  };
  testCompatibilityTickerRequiresNativeCell = {
    expr = map (system: applies "legacy-doctest-v1" { inherit system; compiler = "9.12.4"; version = "0.24.3"; })
      [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
    expected = [ false true false ];
  };
  testCompatibilityIndependentUnicodeEffects = {
    expr = map (id: applies id { compiler = "9.12.4"; version = "0.6.0"; })
      [ "legacy-unicode-data-v1" "legacy-unicode-data-metadata-v1" ];
    expected = [ true false ];
  };
  testCompatibilityUnknownCompilerCannotMatch = {
    expr = applies "legacy-kioku-core-v1" { version = "0.8.0.2"; };
    expected = false;
  };
  testCompatibilityAlwaysDoesNotForceVersion = {
    expr = (select [{ always = true; id = "first"; } { always = true; id = "second"; }] {
      version = throw "always dispatch forced the replaced package";
    }).id;
    expected = "first";
  };
  testCompatibilityAlwaysPrecedesRanges = {
    expr = (select [{ min = "1"; max = "2"; id = "range"; } { always = true; id = "always"; }] { version = "1.5"; }).id;
    expected = "always";
  };
  testCompatibilityHalfOpenDispatch = {
    expr = map
      (version:
        let entry = select [{ min = "1"; max = "2"; id = "range"; }] { inherit version; };
        in if entry == null then null else entry.id) [ "0.9" "1" "1.5" "2" ];
    expected = [ null "range" "range" null ];
  };
  testCompatibilityLegacyFirstMatchingRow = {
    expr = (select [{ min = "1"; max = "3"; id = "first"; } { min = "2"; max = "4"; id = "second"; }] { version = "2.5"; }).id;
    expected = "first";
  };
  testCompatibilityCatalogComplete = {
    expr = builtins.deepSeq (validate policy.catalog policy.policies bindings) true;
    expected = true;
  };
  testCompatibilityCatalogNoPackageEvaluation = {
    expr = builtins.all (rows: builtins.all (row: row.exceptionIds != [ ]) rows) (builtins.attrValues policy.registry);
    expected = true;
  };
  testCompatibilityGeneratedPoliciesDeclared = {
    expr = policy.generatedPolicyProfiles;
    expected = { firstParty = "legacy-first-party-v1"; cohort = "legacy-skip-enforce-v1"; };
  };
  testCompatibilityRejectMissingId = badCatalog (entry: builtins.removeAttrs entry [ "id" ]);
  testCompatibilityRejectEmptyReason = badCatalog (entry: entry // { reason = ""; });
  testCompatibilityRejectBlankReason = badCatalog (entry: entry // { reason = "   "; });
  testCompatibilityRejectAmbiguousOwner = badCatalog (entry: entry // { owner = "kioku"; });
  testCompatibilityRejectMalformedGuard = badCatalog (entry: entry // {
    applicability = entry.applicability // { compiler = { min = "9.15"; max = "9.14"; exact = null; }; };
  });
  testCompatibilityRejectUnknownGuard = badCatalog (entry: entry // {
    applicability = entry.applicability // { compiler = { min = "nonsense"; max = "next"; exact = null; }; };
  });
  testCompatibilityRejectUnknownSystem = badCatalog (entry: entry // {
    applicability = entry.applicability // { systems = [ "unknown-machine" ]; };
  });
  testCompatibilityRejectAmbiguousGuard = badCatalog (entry: entry // {
    applicability = entry.applicability // { compiler = { min = "9.14"; max = "9.15"; exact = [ "9.14.1" ]; }; };
  });
  testCompatibilityRejectUnknownEffect = badCatalog (entry: entry // { effects = [ "magic" ]; });
  testCompatibilityRejectInventedEvidence = badCatalog (entry: entry // {
    evidence = entry.evidence // { status = "passed"; };
  });
  testCompatibilityRejectDanglingEvidence = badCatalog (entry: entry // {
    evidence = entry.evidence // { references = [ "missing-receipt" ]; };
  });
  testCompatibilityRejectDuplicateIds = rejects (validate
    (policy.catalog // {
      entries = policy.catalog.entries ++ [ (builtins.head policy.catalog.entries) ];
    })
    policy.policies
    bindings);
  testCompatibilityRejectMissingCoverage = rejects (validate
    (policy.catalog // {
      entries = builtins.tail policy.catalog.entries;
    })
    policy.policies
    bindings);
  testCompatibilityRejectOrphanBinding = badCatalog (entry: entry // {
    binding = { kind = "registry-row"; package = "missing-recipe"; row = 0; };
  });
  testCompatibilityRejectDanglingWaiver = badProfile (profile: profile // {
    tests = profile.tests // { exceptionIds = [ "nonexistent" ]; };
  });
  testCompatibilityRejectMissingTestWaiver = badProfile (profile: profile // {
    tests = profile.tests // { exceptionIds = [ ]; };
  });
  testCompatibilityRejectMissingBoundsWaiver = badProfile (profile: profile // {
    bounds = profile.bounds // { exceptionIds = [ ]; };
  });
  testCompatibilityRejectWrongWaiverEffect = badProfile (profile: profile // {
    bounds = profile.bounds // { exceptionIds = profile.tests.exceptionIds; };
  });
  testCompatibilityRejectInvalidPolicyMode = badProfile (profile: profile // {
    tests = profile.tests // { mode = "automatic"; };
  });
  testCompatibilityRejectMutatedLegacyProfile = badProfile (profile: profile // {
    tests = profile.tests // { mode = "run"; exceptionIds = [ ]; };
    bounds = profile.bounds // { mode = "enforce"; exceptionIds = [ ]; };
  });
  testCompatibilityLegacyFirstPartyPolicyOrder = {
    expr = apply "legacy-first-party-v1" haskellLib [ "source" ];
    expected = [ "source" "relax-bounds" "skip-tests" ];
  };
  testCompatibilityCohortPreservesBounds = {
    expr = apply "legacy-skip-enforce-v1" haskellLib [ "source" ];
    expected = [ "source" "skip-tests" ];
  };
  testCompatibilityStrictConstructionSetsBothModes = {
    expr = apply "strict-v1" haskellLib [ "source" ];
    expected = [ "source" "enforce-bounds" "run-tests" ];
  };
  testCompatibilityLegacyLayerPreservesInheritedTestPolicy = {
    expr = apply "legacy-run-relax-v1" haskellLib [ "source-with-earlier-test-waiver" ];
    expected = [ "source-with-earlier-test-waiver" "relax-bounds" ];
  };
  testCompatibilityRejectChangingLegacyConstruction = badProfile (profile: profile // {
    construction = "complete";
  });
}
