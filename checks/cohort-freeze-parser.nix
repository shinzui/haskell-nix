{ lib }:
let
  parse = import ../lib/parseCohortFreeze.nix { inherit lib; };
  fixture = name: builtins.readFile
    (../cli/haskell-nix-update/test/fixtures/cohort-freeze + "/${name}.freeze");
  rejects = text: {
    expr = (builtins.tryEval (builtins.deepSeq (parse text) true)).success;
    expected = false;
  };
in
{
  testCohortFreezeValid = {
    expr = parse (fixture "valid");
    expected = {
      constraints = { aeson = "2.2.5.1"; blake3 = "0.3.1"; };
      flags.blake3 = [ "+portable" "-avx2" ];
      indexState = "2026-10-06T21:15:24Z";
    };
  };
  testCohortFreezeDuplicate = rejects (fixture "duplicate");
  testCohortFreezeRange = rejects (fixture "range");
  testCohortFreezeGarbage = rejects (fixture "garbage");
  testCohortFreezeEmptyEntry = rejects (fixture "empty-entry");
  testCohortFreezeDuplicateFlagRecords = rejects (fixture "duplicate-flags");
  testCohortFreezeFlagsOnly = rejects (fixture "flags-only");
  testCohortFreezeMissingIndex = rejects "constraints: any.aeson ==2.2.5.1";
  testCohortFreezeDuplicateIndex = rejects ''
    index-state: 2026-10-06T21:15:24Z
    index-state: 2026-10-06T21:15:24Z
    constraints: any.aeson ==2.2.5.1
  '';
  testCohortFreezeConflictingFlags = rejects ''
    index-state: 2026-10-06T21:15:24Z
    constraints: any.blake3 ==0.3.1, any.blake3 +portable -portable
  '';
  testCohortFreezeUnknownField = rejects ''
    index-state: 2026-10-06T21:15:24Z
    unexpected: value
    constraints: any.aeson ==2.2.5.1
  '';
  testCohortFreezeMatchesRecordedSources = {
    expr = (parse (builtins.readFile ../cabal/cohort.freeze)).constraints;
    expected = lib.mapAttrs (_: package: package.version)
      (lib.filterAttrs (_: package: package.source != "SourcePin")
        (builtins.fromJSON (builtins.readFile ../cabal/cohort-sources.json)));
  };
}
