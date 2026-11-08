{ lib, pkgs, mkRuntimePackageSet, mkCohortManifest }:
{ runtime, generation, applicationSelections, channel ? "github" }:
let
  selected = mkRuntimePackageSet { inherit runtime generation applicationSelections channel; };
  scope = selected.mkApplicationScope pkgs (_: _: { });
  dependencies = selected.metadata.roots;
  cabal = pkgs.writeText "runtime-proof.cabal" ''
    cabal-version: 3.0
    name: runtime-proof
    version: 1.0.0
    build-type: Simple
    license: BSD-3-Clause
    library
      exposed-modules: RuntimeProof
      build-depends: ${lib.concatStringsSep ", " ([ "base" ] ++ dependencies)}
      default-language: GHC2021
  '';
  src = pkgs.runCommand "runtime-proof-source" { } ''
    mkdir -p "$out"
    cp ${cabal} "$out/runtime-proof.cabal"
    echo 'module RuntimeProof () where' > "$out/RuntimeProof.hs"
  '';
  proof = scope.mkDerivation {
    pname = "runtime-proof";
    version = "1.0.0";
    inherit src;
    libraryHaskellDepends = map (name: scope.${name}) ([ "base" ] ++ dependencies);
    license = lib.licenses.bsd3;
    doHaddock = false;
    enableLibraryProfiling = false;
  };
in
{
  inherit selected scope proof;
  roots = pkgs.linkFarm "keiro-runtime-roots" (map (name: { inherit name; path = scope.${name}; }) dependencies);
  closure = pkgs.linkFarm "keiro-runtime-closure" (map (name: { inherit name; path = scope.${name}; })
    (builtins.filter (name: selected.metadata.ownership.${name}.source != "Boot") (builtins.attrNames selected.metadata.ownership)));
  manifest = mkCohortManifest {
    inherit pkgs scope;
    root = proof;
    context = selected.comparisonContext;
  };
}
