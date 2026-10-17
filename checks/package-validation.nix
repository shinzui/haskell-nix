{ lib, pkgs, scope }:
let
  hl = pkgs.haskell.lib.compose;
  entryId = "fixture-compatibility-repair";
  serviceProbe = pkgs.runCommand "ep21-local-service-probe" { } ''
    mkdir -p "$out/bin"
    cat > "$out/bin/ep21-local-service" <<'SCRIPT'
    #!${pkgs.runtimeShell}
    exec ${pkgs.python3}/bin/python3 ${./fixtures/package-validation/local-service.py} "$@"
    SCRIPT
    chmod +x "$out/bin/ep21-local-service"
    "$out/bin/ep21-local-service" server service-port &
    servicePid=$!
    trap 'kill "$servicePid" 2>/dev/null || true' EXIT
    for attempt in {1..50}; do
      test -s service-port && break
      sleep 0.1
    done
    test "$("$out/bin/ep21-local-service" client service-port)" = EP21_LOCAL_SERVICE_OK
    wait "$servicePid"
  '';
  construct = variant: { policyProfile, disabledEntryIds, providedServices }:
    let
      raw = scope.callCabal2nix "package-validation-fixture" (./fixtures/package-validation + "/${variant}") { };
      policy = (import ../lib/applyPackageBuildPolicy.nix) policyProfile hl raw;
      settings = hl.overrideCabal (_: { doHaddock = false; enableLibraryProfiling = false; }) policy;
    in
    let
      repaired =
        if builtins.elem entryId disabledEntryIds then hl.disableCabalFlag "compatibility-repair" settings
        else hl.enableCabalFlag "compatibility-repair" settings;
    in
    if variant != "service" then repaired else
    hl.overrideCabal
      (_: {
        testToolDepends = [ providedServices.fixture-service ];
        preCheck = ''
          export EP21_SERVICE_CLIENT=${providedServices.fixture-service}/bin/ep21-local-service
          "$EP21_SERVICE_CLIENT" server service-port &
          servicePid=$!
          trap 'kill "$servicePid" 2>/dev/null || true' EXIT
          for attempt in {1..50}; do
            test -s service-port && break
            sleep 0.1
          done
        '';
        postCheck = ''
          wait "$servicePid"
        '';
      })
      repaired;
  validate = variant: (import ../lib/mkPackageValidation.nix { inherit lib; }) {
    inherit pkgs entryId;
    mkRecipe = construct variant;
  };
  needed = validate "needs-repair";
  fixed = validate "fixed";
  service = (import ../lib/mkPackageValidation.nix { inherit lib; }) {
    inherit pkgs entryId;
    mkRecipe = construct "service";
    requiredServices = [ "fixture-service" ];
    providedServices.fixture-service = serviceProbe;
  };
  manifest = package: (import ../lib/mkCohortManifest.nix { inherit lib; }) {
    inherit pkgs scope;
    root = package;
    context = { purpose = "explicit strict-validation fixture"; inherit entryId; };
  };
  manifests = {
    neededBaseline = manifest needed.baseline;
    fixedBaseline = manifest fixed.baseline;
    fixedCandidate = manifest fixed.candidate;
    serviceBaseline = manifest service.baseline;
    serviceCandidate = manifest service.candidate;
  };
  blocked = (import ../lib/mkPackageValidation.nix { inherit lib; }) {
    inherit pkgs entryId;
    mkRecipe = _: throw "missing service must block before recipe construction";
    requiredServices = [ "fixture-service" ];
  };
  behavior = package: pkgs.runCommand "strict-validation-behavior" { } ''
    test "$(${package}/bin/validation-probe)" = 42
    touch "$out"
  '';
  context = validation: (import ../lib/mkCompatibilityProbeContext.nix { inherit lib; }) {
    inherit validation;
    channel = "github";
    policyIdentity = builtins.hashString "sha256" (builtins.toJSON {
      profile = "strict-v1";
      inherit entryId;
    });
    requiredSuites = [ "fixture-tests" ];
    graphs = { baseline = manifest validation.baseline; candidate = manifest validation.candidate; };
    behaviorProbes = {
      baseline.executable = behavior validation.baseline;
      candidate.executable = behavior validation.candidate;
    };
  };
  contexts = { needed = context needed; fixed = context fixed; service = context service; };
  check = pkgs.runCommand "package-validation-fixtures" { } ''
    test -e ${manifests.neededBaseline}
    test -e ${manifests.fixedBaseline}
    test -e ${manifests.fixedCandidate}
    test -e ${manifests.serviceBaseline}
    test -e ${manifests.serviceCandidate}
    test "$(${needed.baseline}/bin/validation-probe)" = 42
    test "$(${fixed.baseline}/bin/validation-probe)" = 42
    test "$(${fixed.candidate}/bin/validation-probe)" = 42
    mkdir "$out"
    cp ${pkgs.writeText "needed-validation-context.json" (builtins.toJSON needed.context)} "$out/needed.json"
    cp ${pkgs.writeText "fixed-validation-context.json" (builtins.toJSON fixed.context)} "$out/fixed.json"
    cp ${pkgs.writeText "blocked-validation-context.json" (builtins.toJSON blocked.context)} "$out/blocked.json"
  '';
in
{ inherit needed fixed service blocked manifests contexts check; }
