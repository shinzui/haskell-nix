# Names come from the retained record, never from the package fixed point.
{ lib, captureCompatibility ? false }:
cohort: haskellLib: pkgs:
hself: hsuper:
let
  arguments = import ../overlays/cohort-arguments.nix { inherit pkgs; };
  call = import ./callCohortHackage.nix { inherit lib; };
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
        package = (import ./applyPackageBuildPolicy.nix) "legacy-skip-enforce-v1" haskellLib raw;
      in
      if !captureCompatibility then package else
      (import ./captureCompatibility.nix { inherit lib; }) {
        inherit name haskellLib;
        before = null;
        after = package;
        entry = {
          buildPolicyProfile = "legacy-skip-enforce-v1";
          exceptionIds = [ "legacy-cohort-source-v1" "legacy-skip-enforce-v1-test-suppression" ];
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
