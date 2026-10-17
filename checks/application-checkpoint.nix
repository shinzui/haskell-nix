# Old source uses an API removed by a same-version dependency update. Rebuilding
# it in the new scope is invalid even though today's reconstructed records match.
{ pkgs, scope }:
let
  inherit (pkgs) lib;
  make = import ../lib/mkApplicationIncrementalPackage.nix { inherit lib; };
  root = ./fixtures/application-checkpoint;
  mkScope = variant: overlay: scope.override {
    overrides = lib.composeExtensions
      (final: _: {
        checkpoint-dependency = final.callPackage
          ({ mkDerivation, base }: mkDerivation {
            pname = "checkpoint-dependency";
            version = "1.0";
            src = root + "/${variant}/dependency";
            libraryHaskellDepends = [ base ];
            doCheck = false;
            doHaddock = false;
            license = lib.licenses.bsd3;
          })
          { };
      })
      overlay;
  };
  overlayFor = { source, revision }: final: _: {
    checkpoint-app = final.callPackage
      ({ mkDerivation, base, checkpoint-dependency }: mkDerivation {
        pname = "checkpoint-app";
        version = "1.0";
        src = source + "/checkpoint-app";
        isLibrary = false;
        isExecutable = true;
        executableHaskellDepends = [ base checkpoint-dependency ];
        doCheck = false;
        doHaddock = false;
        license = lib.licenses.bsd3;
      })
      { };
  };
  arguments = {
    inherit pkgs overlayFor;
    source = root + "/original";
    seedSource = root + "/original";
    packageName = "checkpoint-app";
    revision = "1111111";
    seedRevision = "1111111";
    mkScope = mkScope "original";
  };
  original = make arguments;
  declared = original.checkpointDeclaration;
  accepted = make (arguments // { validatedCheckpoint = declared; });
  updated = make (arguments // {
    mkScope = mkScope "updated";
    source = root + "/updated";
    validatedCheckpoint = declared;
  });
  replacedSeed = make (arguments // {
    seedSource = root + "/updated";
    validatedCheckpoint = declared;
  });
  invalidMetadataSource = root + "/invalid-metadata";
  invalidMetadataSeed = make (arguments // {
    seedSource = invalidMetadataSource;
    validatedCheckpoint = declared;
    overlayFor = args:
      if toString args.source == toString invalidMetadataSource then
        throw "replaced seed metadata forced the old package constructor"
      else overlayFor args;
  });
  validate = import ../lib/validateApplicationCheckpoint.nix { inherit lib; };
  lazyContextRejection = validate {
    currentCompatibility = { recipeIdentity = "new"; };
    declaration = { schemaVersion = 1; derivation = "old"; compatibility = { recipeIdentity = "old"; }; };
    checkpoint = throw "an incompatible checkpoint must not be forced";
  };
  check = pkgs.runCommand "application-checkpoint-origin"
    {
      old = original.checkpoint;
      current = updated.package;
      seeded = accepted.package;
      replaced = replacedSeed.package;
    } ''
    test "$($old/bin/checkpoint-app)" = 41
    test "$($seeded/bin/checkpoint-app)" = 41
    test "$($current/bin/checkpoint-app)" = 42
    test "$($replaced/bin/checkpoint-app)" = 41
    mkdir "$out"
    printf '%s\n' 'validated origin: 41; updated clean: 42; replacement rejected: 41' > "$out/result"
  '';
in
assert !original.compatibilityReport.accepted;
assert accepted.compatibilityReport.accepted;
assert !updated.compatibilityReport.accepted;
assert updated.seed == null && updated.package.drvPath == updated.clean.drvPath;
assert updated.compatibilityReport.reason == "validated checkpoint compatibility changed";
assert !replacedSeed.compatibilityReport.accepted;
assert replacedSeed.compatibilityReport.reason == "validated checkpoint derivation changed";
assert replacedSeed.seed == null && replacedSeed.package.drvPath == replacedSeed.clean.drvPath;
assert !invalidMetadataSeed.compatibilityReport.accepted;
assert invalidMetadataSeed.compatibilityReport.reason == "validated checkpoint source metadata changed";
assert invalidMetadataSeed.seed == null && invalidMetadataSeed.package.drvPath == original.clean.drvPath;
assert !lazyContextRejection.accepted;
{
  inherit check;
  # Deliberate negative build: old Haskell source against the updated dependency
  # must fail with oldValue missing. It is absent from updated.package's graph.
  unsafeCheckpoint = updated.checkpoint;
  identity = {
    originalDeclaration = declared;
    inherit (updated) currentCompatibility compatibilityReport;
    clean = updated.clean.drvPath;
    guarded = updated.package.drvPath;
    replacedSeedReport = replacedSeed.compatibilityReport;
    invalidMetadataSeedReport = invalidMetadataSeed.compatibilityReport;
    unsafeCheckpoint = updated.checkpoint.drvPath;
  };
}
