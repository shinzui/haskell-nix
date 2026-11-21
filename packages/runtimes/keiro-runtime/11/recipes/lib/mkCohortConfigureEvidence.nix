{ package, ghc }:
# Replay the actual recipe through configure, using its exact patched metadata,
# compiler and dependency database. No Haskell library/executable is rebuilt.
package.overrideAttrs (_: previous: {
  name = "${package.pname}-${package.version}-cohort-configure";
  outputs = [ "out" ];
  prePhases = [ ];
  preConfigurePhases = [ ];
  phases = [
    "setupCompilerEnvironmentPhase"
    "unpackPhase"
    "recordMetadataPhase"
    "patchPhase"
    "compileBuildDriverPhase"
    "configurePhase"
    "installPhase"
  ];
  outputDev = "out";
  outputBin = "out";
  outputInclude = "out";
  outputLib = "out";
  outputDoc = "out";
  outputDevdoc = "out";
  outputMan = "out";
  outputDevman = "out";
  outputInfo = "out";
  separateDebugInfo = false;
  dontInstall = false;
  recordMetadataPhase = ''
    sha256sum -- "${package.pname}.cabal" | cut -d' ' -f1 > "$NIX_BUILD_TOP/cohort-original-metadata"
  '';
  installPhase = ''
    ${ghc}/bin/ghc $setupCompileFlags --make -o cohort-inspect-config \
      -odir "$builddir" -hidir "$builddir" ${./cohort-flags.hs}
    mkdir -p "$out"
    ./cohort-inspect-config "$out" > "$out/flags"
    cp "$NIX_BUILD_TOP/cohort-original-metadata" "$out/original-metadata-sha256"
    sha256sum -- "${package.pname}.cabal" | cut -d' ' -f1 > "$out/patched-metadata-sha256"
  '';
} // (if builtins.isAttrs (previous.outputChecks or null) then { outputChecks = { }; } else { }))
