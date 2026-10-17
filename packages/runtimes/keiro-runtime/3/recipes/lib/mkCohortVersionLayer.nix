# Names come from the retained record, never from the package fixed point.
{ lib, captureCompatibility ? false, channel ? "github" }:
cohort: haskellLib: pkgs:
hself: hsuper:
let
  arguments = import ../overlays/cohort-arguments.nix { inherit pkgs; };
  call = import ./callCohortHackage.nix { inherit lib; };
  policySelection = import ./selectCohortBuildPolicy.nix { inherit lib; };
  profiles = (builtins.fromJSON (builtins.readFile ../config/package-build-policies.json)).profiles;
in
lib.mapAttrs
  (name: entry:
    if builtins.hasAttr name hsuper && hsuper.${name} == null then null
    else
      let
        raw = call {
          inherit hself haskellLib pkgs name entry;
          arguments = arguments.${name} or { };
        };
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
      })
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
}
