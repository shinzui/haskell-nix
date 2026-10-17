# Diagnostic attributes live on the returned derivation value, never in its
# builder arguments. Only the fields below are forced when a report is requested.
{ lib }:
{ name, entry, before, after, haskellLib, selected ? true }:
let
  sourceConstructor = (entry.sourceConstructor or false) || entry ? buildPolicyProfile;
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
        hooks = lib.genAttrs [ "prePatch" "postPatch" "preConfigure" "postConfigure" "preBuild" "postBuild" "preCheck" "postCheck" ]
          (name:
            let text = args.${name} or ""; in
            if builtins.getContext text == { } then builtins.hashString "sha256" text else
            "nix-hook:" + builtins.unsafeDiscardStringContext (builtins.derivation {
              name = "compatibility-hook-identity";
              system = "builtin";
              builder = "builtin:compatibility-hook-identity";
              inherit text;
            }).drvPath);
        patches = map (import ./compatibilitySourceIdentity.nix { inherit lib; }) (args.patches or [ ]);
        # Strict validation owns the additional test closure. Do not force disabled
        # test dependencies (which may be unavailable) during a production report.
        dependencies = lib.genAttrs [ "setupHaskellDepends" "libraryHaskellDepends" "executableHaskellDepends" "librarySystemDepends" "executableSystemDepends" "libraryToolDepends" "executableToolDepends" ]
          (role: map
            (dependency:
              if dependency == null then { unavailable = true; }
              else if lib.isDerivation dependency then {
                derivation = dependency.drvPath;
                output = dependency.outputName or "out";
              } else { source = (import ./compatibilitySourceIdentity.nix { inherit lib; }) dependency; })
            (args.${role} or [ ]));
        testDependencyInventory = "not-evaluated";
        revision = args.revision or null;
        editedCabalFile = args.editedCabalFile or null;
      };
    };
  observation = {
    inherit name;
    exceptionIds = entry.observedExceptionIds or (entry.exceptionIds or [ ]);
    stage = if !selected then "unselected-row" else if sourceConstructor then "source-constructor" else "compatibility-row";
    profile = entry.buildPolicyProfile or null;
    # Source constructors may replace a missing stock package. Their input is
    # intentionally absent; the nested repair receives the actual selected one.
    before = if sourceConstructor then null else identify before;
    after = identify after;
  };
in
after // {
  compatibilityObservations = lib.unique
    (
      (if sourceConstructor then [ ] else before.compatibilityObservations or [ ])
      ++ (after.compatibilityObservations or [ ])
    ) ++ [ observation ];
}
