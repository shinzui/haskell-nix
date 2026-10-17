# Bounded follow-up to the one-root experiment. These real Rei dependencies have
# only compiler-provided Haskell dependencies, isolating the converted layer.
# Production adoption still requires a new retained generation and reference.
{ selection, system ? "aarch64-darwin", applicationSource ? null }:
let
  channel = builtins.getFlake (toString ../../../.);
  pkgs = import channel.inputs.nixpkgs { inherit system; };
  runtime = channel.lib.mkRuntimePackageSet
    (builtins.fromJSON (builtins.readFile (builtins.toPath selection)));
  retained = import (../../../. + "/${runtime.metadata.recipeDirectory}/generated/cohort-versions.nix");
  names = [ "base16-bytestring" "base64-bytestring" "cryptohash-sha256" "entropy" "file-embed" ];
  flagSpellings = builtins.fromJSON (builtins.readFile ./default-flag-spellings.json);
  sources = pkgs.lib.genAttrs names (name:
    let entry = retained.packages.${name};
    in pkgs.fetchzip {
      url = "mirror://hackage/${name}-${entry.version}/${name}-${entry.version}.tar.gz";
      inherit (entry) sha256;
    });
  extension = final: _: pkgs.lib.genAttrs names (name:
    let
      entry = retained.packages.${name};
      spelling = flagSpellings.${name} or null;
    in
    assert spelling == null || (entry.version == spelling.version
      && entry.revision != null && entry.revision.sha256 == spelling.metadataSha256);
    pkgs.haskell.lib.compose.dontCheck
      (pkgs.haskell.lib.compose.overrideCabal
        (args: pkgs.lib.optionalAttrs (entry.revision != null)
          {
            revision = entry.revision.number;
            editedCabalFile = entry.revision.sha256;
          } // pkgs.lib.optionalAttrs (spelling != null) {
          configureFlags = builtins.filter (flag: !(builtins.elem flag spelling.remove)) (args.configureFlags or [ ]);
        })
        (final.callPackage (./packages + "/${name}.nix") { src = sources.${name}; })));
  legacy = pkgs.haskell.packages.ghc9124.override {
    overrides = runtime.haskellExtension pkgs.haskell.lib.compose pkgs;
  };
  generated = pkgs.haskell.packages.ghc9124.override {
    overrides = pkgs.lib.composeExtensions
      (runtime.haskellExtension pkgs.haskell.lib.compose pkgs)
      extension;
  };
  checked = runtime.mkApplicationScope pkgs extension;
  identities = scope: pkgs.lib.genAttrs names (name: scope.${name}.drvPath);
  applicationOverlay = import (builtins.toPath applicationSource + "/nix/haskell-overlay.nix") {
    inherit pkgs;
    gitRev = "4f209d3";
    haskellLib = pkgs.haskell.lib.compose;
  };
in
{
  groupLegacy = identities legacy;
  groupGenerated = identities generated;
  checkedCandidates = identities checked;
  consumerLegacy = if applicationSource == null then null else
  (runtime.mkApplicationScope pkgs applicationOverlay).rei-cli;
  consumerCandidate = if applicationSource == null then null else
  (runtime.mkApplicationScope pkgs (pkgs.lib.composeExtensions extension applicationOverlay)).rei-cli;
  identity = {
    inherit names system;
    compiler = generated.ghc.drvPath;
    runtime = runtime.metadata.fingerprint;
    legacy = identities legacy;
    generated = identities generated;
    checked = identities checked;
    sources = pkgs.lib.mapAttrs (_: source: source.outPath) sources;
  };
}
