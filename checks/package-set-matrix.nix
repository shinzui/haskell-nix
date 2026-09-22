{ lib
, pkgs
, packageSet
, supportedGhcs
, mkFirstPartyPackageSet
}:

let
  consumerSource = ./fixtures/package-sets/consumer;

  cell = channel: ghc:
    let
      selected = mkFirstPartyPackageSet { inherit packageSet channel; };
      scope = (pkgs.extend selected.overlay).haskell.packages.${ghc};
      available = package:
        channel == "github" || package.hackage != null;
      packages = lib.concatMap
        (snapshot: builtins.filter available snapshot.packages)
        selected.selectedFamilies;
      expectedVersions = lib.listToAttrs (map
        (package: {
          name = package.name;
          value =
            if channel == "github" then
              package.version
            else
              package.hackage.version;
        })
        packages);
      versionMismatches = builtins.filter
        (name: scope.${name}.version != expectedVersions.${name})
        (builtins.attrNames expectedVersions);
      selectedPackages = map (package: scope.${package.name}) packages;
      consumer = scope.callCabal2nix "package-set-consumer" consumerSource { };
    in
    assert versionMismatches == [ ];
    {
      inherit channel ghc consumer selectedPackages versionMismatches;
      packageNames = map (package: package.name) packages;
    };

  cells = lib.concatMap
    (ghc: map (channel: cell channel ghc) [ "github" "hackage" ])
    supportedGhcs;
  dependencies = lib.concatMap
    (candidate: candidate.selectedPackages ++ [ candidate.consumer ])
    cells;
  results = lib.listToAttrs (map
    (candidate: {
      name = "${candidate.channel}-${candidate.ghc}";
      value = {
        packageCount = builtins.length candidate.packageNames;
        consumer = candidate.consumer.drvPath;
        inherit (candidate) versionMismatches;
      };
    })
    cells);
in
pkgs.runCommand "package-set-${packageSet}-matrix"
{
  buildInputs = dependencies;
  passthru = { inherit packageSet results; };
} ''
  echo '${builtins.toJSON results}'
  touch "$out"
''
