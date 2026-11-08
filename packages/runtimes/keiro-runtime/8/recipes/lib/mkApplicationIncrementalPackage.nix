# Construct application-owned experiments in the caller's retained runtime scope.
# The caller supplies one current recipe implementation for both explicit sources.
{ lib }:
{ pkgs
, mkScope
, overlayFor
, source
, seedSource
, packageName
, revision
, seedRevision
, validatedCheckpoint ? null
, enabled ? true
, retainCurrentIntermediates ? true
, trackedDataFile ? (_: false)
}:
let
  haskellLib = pkgs.haskell.lib.compose;
  project = package: haskellLib.overrideCabal
    (_: { src = builtins.toFile "application-compatibility-source" ""; })
    package;
  sourceCompatibility = directory:
    let
      packageRoot = directory + "/${packageName}";
      walk = prefix: path:
        lib.concatMap
          (name:
            let relative = if prefix == "" then name else "${prefix}/${name}";
            in if (builtins.readDir path).${name} == "directory"
            then if builtins.elem name [ ".git" "dist-newstyle" "result" ]
            then [ ] else walk relative (path + "/${name}")
            else [ relative ])
          (builtins.attrNames (builtins.readDir path));
      files = walk "" packageRoot;
      # Only Haskell and explicitly audited GHC-tracked embedded data may vary.
      # Hash every other file: native code, preprocessor inputs and generator
      # scripts must not accidentally bypass the guard through a new extension.
      guardedFiles = builtins.filter
        (name: builtins.elem name [ "Setup.hs" "Setup.lhs" "package.yaml" ]
          || lib.hasSuffix ".cabal" name
          || !(lib.hasSuffix ".hs" name || lib.hasSuffix ".lhs" name || trackedDataFile name))
        files;
      metadata = map
        (name: {
          inherit name;
          hash = builtins.hashFile "sha256" (packageRoot + "/${name}");
        })
        guardedFiles;
    in
    {
      metadataIdentity = builtins.hashString "sha256" (builtins.toJSON metadata);
      sourceLayoutIdentity = builtins.hashString "sha256" (builtins.toJSON files);
      generatedInputPolicy = builtins.hashString "sha256" (builtins.toJSON {
        writer = "source-local-revision-v1";
        trackedDataFiles = builtins.filter trackedDataFile files;
      });
    };
  compatibility = directory: package: projected: sourceCompatibility directory // {
    schemaVersion = 1;
    inherit packageName;
    packageVersion = package.version;
    compilerIdentity = package.compiler.drvPath;
    recipeIdentity = projected.drvPath;
  };
  previousScope = mkScope (overlayFor { source = seedSource; revision = seedRevision; });
  previousProjection = mkScope (final: prev:
    let owned = (overlayFor { source = seedSource; revision = "<revision>"; }) final prev;
    in owned // { ${packageName} = project owned.${packageName}; });
  previousPackage = previousScope.${packageName};
  seedCompatibility = compatibility seedSource previousPackage previousProjection.${packageName};
  checkpoint = haskellLib.overrideCabal
    (_: {
      doInstallIntermediates = true;
      enableSeparateIntermediatesOutput = true;
      previousIntermediates = null;
    })
    previousPackage;
  checkpointDeclaration = {
    schemaVersion = 1;
    derivation = checkpoint.drvPath;
    compatibility = seedCompatibility;
  };
  # Replace the package inside the caller's recursive scope, so downstream owned
  # packages consume the guarded library. The previous source keeps its own
  # dependency scope. The declaration binds its actual validated derivation,
  # preventing reconstruction of old source against unvalidated new inputs.
  haskellExtension = final: prev:
    let
      owned = (overlayFor { inherit source revision; }) final prev;
      normalized = (overlayFor { inherit source; revision = "<revision>"; }) final prev;
      clean = owned.${packageName};
      currentCompatibility = compatibility source clean (project normalized.${packageName});
      checkpointValidation = (import ./validateApplicationCheckpoint.nix { inherit lib; }) {
        inherit currentCompatibility checkpoint;
        declaration = validatedCheckpoint;
        seedSourceCompatibility = sourceCompatibility seedSource;
      };
      guarded =
        if enabled && !checkpointValidation.accepted then {
          package = builtins.trace "application-incremental ${clean.pname}: ${checkpointValidation.reason}" clean;
          seed = null;
          compatibilityReport = {
            schemaVersion = 1;
            inherit enabled;
            accepted = false;
            reason = checkpointValidation.reason;
            inherit (checkpointValidation) differences;
          };
        } else
          (import ./mkApplicationIncrementalBuild.nix { inherit lib; }) {
            inherit pkgs enabled currentCompatibility seedCompatibility retainCurrentIntermediates;
            package = clean;
            seedPackage = previousPackage;
          };
      state = guarded // { inherit clean checkpoint checkpointDeclaration currentCompatibility seedCompatibility; };
    in
    owned // {
      # Descriptive state stays outside mkDerivation's arguments. Do not add a
      # fake package to the scope or make this state part of the build identity.
      ${packageName} = guarded.package // {
        applicationIncremental = state;
        passthru = (guarded.package.passthru or { }) // { applicationIncremental = state; };
      };
    };
  scope = mkScope haskellExtension;
in
scope.${packageName}.applicationIncremental // {
  package = scope.${packageName};
  inherit scope haskellExtension;
}
