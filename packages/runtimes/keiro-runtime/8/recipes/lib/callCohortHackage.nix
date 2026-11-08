{ lib }:
{ hself, haskellLib, pkgs, name, entry, arguments }:
if entry.revision == null then
  hself.callHackageDirect { pkg = name; ver = entry.version; sha256 = entry.sha256; } arguments
else
  let
    packageVersion = "${name}-${entry.version}";
    source = pkgs.fetchzip {
      url = "mirror://hackage/${packageVersion}/${packageVersion}.tar.gz";
      sha256 = entry.sha256;
    };
    revision = entry.revision;
    metadata = pkgs.fetchurl {
      url = "mirror://hackage/${packageVersion}/revision/${revision.number}.cabal";
      name = "${packageVersion}-r${revision.number}.cabal";
      sha256 = revision.sha256;
    };
    selectedMetadata = pkgs.runCommand "${packageVersion}-cohort-metadata"
      { selectedCabalFile = metadata; }
      ''
        mkdir -p "$out"
        cp "$selectedCabalFile" "$out/${name}.cabal"
      '';
    package = hself.callCabal2nixWithOptions name source
      { srcModifier = _: selectedMetadata; }
      arguments;
  in
  haskellLib.overrideCabal
    (_: {
      revision = revision.number;
      editedCabalFile = revision.sha256;
    })
    package
