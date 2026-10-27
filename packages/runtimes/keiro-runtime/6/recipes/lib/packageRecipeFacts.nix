{ lib }:
{ haskellLib, package, includeTestDependencies ? false }:
let
  # Several Cabal arguments are consumed by generic-builder and absent from
  # the final derivation attributes. Inspect its actual overrideCabal boundary;
  # the diagnostic projection is never returned as a build input or built.
  arguments = package:
    if !(package ? override) then package else
    (haskellLib.overrideCabal
      (args: { passthru = (args.passthru or { }) // { compatibilityRecipeArguments = args; }; })
      package).compatibilityRecipeArguments;
  identify = package:
    let
      args = arguments package;
      sourceIdentity = (import ./compatibilitySourceIdentity.nix { inherit lib; }) package.src;
    in
    {
      inherit (package) version;
      derivation = package.drvPath;
      inherit sourceIdentity;
      metadataIdentity = builtins.hashString "sha256" (builtins.toJSON {
        source = sourceIdentity;
        revision = args.revision or null;
        editedCabalFile = args.editedCabalFile or null;
      });
      effective = {
        testsEnabled = args.doCheck or null;
        boundsRelaxed = args.jailbreak or null;
        configureFlags = args.configureFlags or [ ];
        buildFlags = args.buildFlags or [ ];
        testExecution = {
          customCheckPhase = (args.checkPhase or null) != null;
          targets = args.testTargets or (lib.splitString " " (args.testTarget or ""));
          flags = args.testFlags or [ ];
        };
        hooks = lib.genAttrs [ "prePatch" "postPatch" "preConfigure" "postConfigure" "preBuild" "postBuild" "preCheck" "postCheck" ]
          (name:
            let value = args.${name} or null; text = if value == null then "" else value; in
            if builtins.getContext text == { } then builtins.hashString "sha256" text else
            "nix-hook:" + builtins.unsafeDiscardStringContext (builtins.derivation {
              name = "compatibility-hook-identity";
              system = "builtin";
              builder = "builtin:compatibility-hook-identity";
              inherit text;
            }).drvPath);
        patches = map (import ./compatibilitySourceIdentity.nix { inherit lib; })
          (if (args.patches or null) == null then [ ] else args.patches);
        # Strict validation owns the additional test closure. Do not force disabled
        # test dependencies (which may be unavailable) during a production report.
        dependencies = lib.genAttrs ([ "buildDepends" "buildTools" "setupHaskellDepends" "libraryHaskellDepends" "executableHaskellDepends" "extraLibraries" "librarySystemDepends" "executableSystemDepends" "libraryFrameworkDepends" "executableFrameworkDepends" "pkg-configDepends" "libraryPkgconfigDepends" "executablePkgconfigDepends" "libraryToolDepends" "executableToolDepends" ] ++ lib.optionals includeTestDependencies [ "testDepends" "testHaskellDepends" "testSystemDepends" "testFrameworkDepends" "testPkgconfigDepends" "testToolDepends" ])
          (role: map
            (dependency:
              if dependency == null then { kind = "null"; resolution = "not-inferred"; }
              else if lib.isDerivation dependency then {
                derivation = dependency.drvPath;
                output = dependency.outputName or "out";
              } else { source = (import ./compatibilitySourceIdentity.nix { inherit lib; }) dependency; })
            (args.${role} or [ ]));
        testDependencyInventory = if includeTestDependencies then "declared" else "not-evaluated";
        revision = args.revision or null;
        editedCabalFile = args.editedCabalFile or null;
      };
    };
in
identify package
