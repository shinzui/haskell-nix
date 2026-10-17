# Diagnostic only: production recipe adoption requires a new retained generation.
{ selection, system ? "aarch64-darwin", packageName ? "base64-bytestring", applicationSource ? null }:
let
  channel = builtins.getFlake (toString ../../../.);
  pkgs = import channel.inputs.nixpkgs { inherit system; };
  runtime = channel.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (builtins.toPath selection)));
  retained = import (../../../. + "/${runtime.metadata.recipeDirectory}/generated/cohort-versions.nix");
  entry = retained.packages.${packageName};
  src = pkgs.fetchzip {
    url = "mirror://hackage/${packageName}-${entry.version}/${packageName}-${entry.version}.tar.gz";
    inherit (entry) sha256;
  };
  extension = final: _prev: {
    ${packageName} = pkgs.haskell.lib.compose.dontCheck
      (pkgs.haskell.lib.compose.overrideCabal
        (_: pkgs.lib.optionalAttrs (entry.revision != null) {
          revision = entry.revision.number;
          editedCabalFile = entry.revision.sha256;
        })
        (final.callPackage (./packages + "/${packageName}.nix") { inherit src; }));
  };
  legacyScope = runtime.mkApplicationScope pkgs (_: _: { });
  checkedScope = runtime.mkApplicationScope pkgs extension;
  # Scope the no-IFD query to this generated root. The real constructor above
  # independently validates all runtime-owned packages against its reference;
  # its remaining first-party IFD is deliberately still observable.
  scoped = pkgs.haskell.packages.ghc9124.override {
    overrides = pkgs.lib.composeExtensions
      (runtime.haskellExtension pkgs.haskell.lib.compose pkgs)
      extension;
  };
  legacyScoped = pkgs.haskell.packages.ghc9124.override {
    overrides = runtime.haskellExtension pkgs.haskell.lib.compose pkgs;
  };
  # A real mori://shinzui/rei consumer, with its archived owned recipe unchanged.
  # Source-file artifact URIs are pending. This is a diagnostic override only;
  # production adoption must capture both constructors in a new generation.
  applicationOverlay = import (builtins.toPath applicationSource + "/nix/haskell-overlay.nix") {
    inherit pkgs;
    gitRev = "4f209d3";
    haskellLib = pkgs.haskell.lib.compose;
  };
in
assert builtins.elem packageName [ "base64-bytestring" "bytestring-lexing" ];
{
  legacy = legacyScope.${packageName};
  generated = scoped.${packageName};
  checkedCandidate = checkedScope.${packageName};
  scopedLegacy = legacyScoped.${packageName};
  consumerLegacy = if applicationSource == null then null else
  (runtime.mkApplicationScope pkgs applicationOverlay).rei-cli;
  consumerCandidate = if applicationSource == null then null else
  (runtime.mkApplicationScope pkgs (pkgs.lib.composeExtensions extension applicationOverlay)).rei-cli;
  identity = {
    legacy = legacyScope.${packageName}.drvPath;
    generated = scoped.${packageName}.drvPath;
    checkedCandidate = checkedScope.${packageName}.drvPath;
    source = src.outPath;
    compiler = scoped.ghc.drvPath;
    inherit system packageName;
    runtime = runtime.metadata.fingerprint;
  };
}
