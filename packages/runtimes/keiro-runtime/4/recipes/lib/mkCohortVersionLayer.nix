# Names come from the retained record, never from the package fixed point.
{ lib, captureCompatibility ? false, channel ? "github", generatedRecipes ? null }:
cohort: haskellLib: pkgs:
hself: hsuper:
let
  arguments = import ../overlays/cohort-arguments.nix { inherit pkgs; };
  call = import ./callCohortHackage.nix { inherit lib; };
  policySelection = import ./selectCohortBuildPolicy.nix { inherit lib; };
  profiles = (builtins.fromJSON (builtins.readFile ../config/package-build-policies.json)).profiles;
  generatedNames = if generatedRecipes == null then [ ] else builtins.attrNames generatedRecipes.context.packages;
  # Reuse selected construction policy and capture for both source paths.
  configure = name: entry: raw:
    let
      selection = policySelection.select {
        inherit name entry channel;
        compiler = hself.ghc.version;
        system = pkgs.stdenv.hostPlatform.system;
      };
      configured = (import ./applyPackageBuildPolicy.nix) selection.profile haskellLib raw;
      package = if selection.selectionId == null then configured else
      configured // { cohortBuildPolicySelection = selection; };
      profile = profiles.${selection.profile};
    in
    if !captureCompatibility then package else
    (import ./captureCompatibility.nix { inherit lib; }) {
      inherit name haskellLib;
      before = null;
      after = package;
      entry = {
        buildPolicyProfile = selection.profile;
        exceptionIds = [ "legacy-cohort-source-v1" ]
          ++ profile.tests.exceptionIds ++ profile.bounds.exceptionIds;
      };
    };
  generatedBinding = if generatedRecipes == null then true else
  let
    context = generatedRecipes.context;
    matches = name:
      let
        input = context.packages.${name};
        entry = cohort.packages.${name};
        selectedArguments = arguments.${name} or { };
        matchingArguments = builtins.attrNames input.nativeArguments == builtins.attrNames selectedArguments
          && builtins.all
          (argument: toString selectedArguments.${argument} == toString
            (lib.foldl' (scope: component: scope.${component}) pkgs
              (lib.splitString "." input.nativeArguments.${argument})))
          (builtins.attrNames input.nativeArguments);
        revision = if input.revision.number == 0 then null else {
          number = toString input.revision.number;
          sha256 = input.revision.sha256;
        };
      in
      if !(builtins.hasAttr name cohort.packages) || input ? sourcePin then false else
      matchingArguments && input.unpackedHash == entry.sha256 && revision == entry.revision
      && context.generationContext.sources.${name} == cohort.sourceManifest.${name}
      && (context.generationContext.freeze.flags.${name} or { }) == (cohort.flags.${name} or { });
  in
  if context.configuration.channel != channel
    || context.configuration.compilerVersion != cohort.ghc
    || context.configuration.nixpkgsRevision != cohort.nixpkgsBase
    || context.generationContext.freeze.indexState != cohort.indexState
    || !builtins.all matches generatedNames then
    throw "mkCohortVersionLayer: generated recipes do not match the selected Hackage cohort context"
  else true;
  generated = if generatedRecipes == null then { } else
  (import ./mkGeneratedRecipeExtension.nix { inherit lib; })
    {
      inherit (generatedRecipes) manifest recipes context;
      policyExtension = _final: previous: lib.genAttrs generatedNames
        (name: configure name cohort.packages.${name} previous.${name});
    }
    haskellLib
    pkgs
    hself
    hsuper;
in
builtins.seq generatedBinding (builtins.seq generated (lib.mapAttrs
  (name: entry:
    if builtins.hasAttr name hsuper && hsuper.${name} == null then null
    else if builtins.elem name generatedNames then generated.${name}
    else
      configure name entry (call {
        inherit hself haskellLib pkgs name entry;
        arguments = arguments.${name} or { };
      }))
  cohort.packages
  // lib.optionalAttrs ((pkgs.stdenv.hostPlatform.config or "") == "arm64-apple-darwin") {
  # cabal2nix's platform parser does not normalize Apple's arm64 spelling to
  # Cabal's aarch64 constructor. Evaluate arch() conditions for the real CPU.
  haskellSrc2nix = args:
    (hsuper.haskellSrc2nix args).overrideAttrs (previous: {
      buildCommand = builtins.replaceStrings
        [ "--system=arm64-apple-darwin" ]
        [ "--system=aarch64-apple-darwin" ]
        previous.buildCommand;
    });
}))
