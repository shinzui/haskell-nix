{ lib }:
let
  fix = captureCompatibility: import ../lib/fixPackageByVersion.nix { inherit lib captureCompatibility; };
  package = {
    version = "0.8.0.2";
    drvPath = "fixture-before.drv";
    src = "fixture-selected-source";
    doCheck = true;
    jailbreak = false;
    configureFlags = [ "inherited" ];
  };
  row = {
    always = true;
    exceptionIds = [ "legacy-kioku-core-v1" ];
    patch = { pkg, ... }: (builtins.removeAttrs pkg [ "compatibilityObservations" ]) // {
      drvPath = "fixture-after.drv";
      configureFlags = pkg.configureFlags ++ [ "repair" ];
    };
  };
  observed = (fix true "kioku-core" [ row ] { } { } { } { kioku-core = package; }).kioku-core;
  event = lib.last observed.compatibilityObservations;
  report = scope: (import ../lib/capturedCompatibilityReport.nix { inherit lib; }) {
    inherit scope;
    names = [ "kioku-core" ];
    packageSet = "fixture";
    channel = "github";
    system = "aarch64-darwin";
  };
  scope = { ghc = { version = "9.14.1"; drvPath = "fixture-ghc.drv"; }; kioku-core = observed; };
  entry = lib.findFirst (entry: entry.id == "legacy-kioku-core-v1") null (report scope).entries;
  rejects = value: { expr = !(builtins.tryEval (builtins.deepSeq value true)).success; expected = true; };
in
{
  testCaptureRecordsRealBoundary = {
    expr = [ event.before.derivation event.after.derivation event.before.sourceIdentity ];
    expected = [ "fixture-before.drv" "fixture-after.drv" "fixture-selected-source" ];
  };
  testCaptureRecordsExactFlagsAndInheritedPolicy = {
    expr = [ event.before.effective.configureFlags event.after.effective.configureFlags ] ++ [ event.before.effective.boundsRelaxed ];
    expected = [ [ "inherited" ] [ "inherited" "repair" ] false ];
  };
  testCaptureReadsHiddenCabalArguments = {
    expr =
      let
        hidden = package // { override = _: throw "mock override must not run"; };
        haskellLib.overrideCabal = f: drv: drv // (f {
          revision = "4";
          editedCabalFile = "fixture-revision-sha256";
          jailbreak = true;
          doCheck = false;
        }).passthru;
        value = (fix true "kioku-core" [ row ] haskellLib { } { } { kioku-core = hidden; }).kioku-core;
        actual = (lib.last value.compatibilityObservations).before.effective;
      in
      [ actual.revision actual.editedCabalFile actual.boundsRelaxed ];
    expected = [ "4" "fixture-revision-sha256" true ];
  };
  testCaptureOffDoesNotForceDiagnosticFields = {
    expr = (fix false "example" [{ always = true; patch = _: { marker = "ordinary"; src = throw "must stay lazy"; }; }] { } { } { } { }).example.marker;
    expected = "ordinary";
  };
  testCaptureSourceReplacementNeverForcesStock = {
    expr =
      let
        value = (fix true "example" [ (row // { sourceConstructor = true; patch = _: package; }) ] { } { } { }
          { example = throw "missing stock package must stay lazy"; }).example;
      in
      (lib.last value.compatibilityObservations).before;
    expected = null;
  };
  testCaptureUnmatchedRowsAreRecorded = {
    expr =
      let value = (fix true "example" [{ min = "2"; max = "3"; patch = _: throw "inactive patch"; }] { } { } { } { example = package; }).example;
      in (lib.last value.compatibilityObservations).stage;
    expected = "unselected-row";
  };
  testCaptureSurvivesOverrideDroppingMetadata = {
    expr =
      let
        prior = (fix true "kioku-core" [ (row // { exceptionIds = [ "prior" ]; }) ] { } { } { } { kioku-core = package; }).kioku-core;
        current = (fix true "kioku-core" [ row ] { } { } { } { kioku-core = prior; }).kioku-core;
      in
      map (event: event.exceptionIds) current.compatibilityObservations;
    expected = [ [ "prior" ] [ "legacy-kioku-core-v1" ] ];
  };
  testCapturedReportUsesBeforeRepairInputs = {
    expr = [ entry.inputs.derivation entry.construction.after.derivation entry.status ];
    expected = [ "fixture-before.drv" "fixture-after.drv" "selected-unverified" ];
  };
  testCapturedReportChecksEffectiveTestSuppression = {
    expr =
      let
        value = (fix true "kioku-core" [
          (row // {
            sourceConstructor = true;
            exceptionIds = [ "legacy-first-party-v1-test-suppression" ];
            patch = _: package;
          })
        ]
          { }
          { }
          { }
          { kioku-core = package; }).kioku-core;
      in
      (report (scope // { kioku-core = value; })).problems;
    expected = [ "declared test suppression not visible: legacy-first-party-v1-test-suppression/kioku-core" ];
  };
  testCapturedReportRejectsMissingCapture = rejects (report (scope // { kioku-core = package; }));
  testCapturedReportRejectsDuplicateEntryOrigins = rejects (report (scope // {
    kioku-core = observed // {
      compatibilityObservations = [ event event ];
    };
  }));
  testCapturedReportRejectsUnknownBindings = rejects (report (scope // {
    kioku-core = observed // {
      compatibilityObservations = [ (event // { exceptionIds = [ "unknown" ]; }) ];
    };
  }));
  testCapturedReportRejectsWrongPackageObservation = rejects (report (scope // {
    kioku-core = observed // {
      compatibilityObservations = [ (event // { name = "another-package"; }) ];
    };
  }));
}
