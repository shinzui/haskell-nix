{ lib
, pkgs
, supportedGhcs
, mkFirstPartyPackageSet
}:

let
  baselineName = "keiro-0-14-okf-0-8";
  mixedName = "keiro-0-14-okf-0-9";

  packageNames = channel: family: selectedFamilies:
    let
      snapshots = builtins.filter (snapshot: snapshot.family == family) selectedFamilies;
      snapshot = builtins.head snapshots;
      available = package:
        channel == "github" || package.hackage != null;
    in
    map (package: package.name) (builtins.filter available snapshot.packages);

  pathsFor = packageSet: channel: ghc: family:
    let
      selected = mkFirstPartyPackageSet { inherit packageSet channel; };
      scope = (pkgs.extend selected.overlay).haskell.packages.${ghc};
    in
    lib.genAttrs
      (packageNames channel family selected.selectedFamilies)
      (name: scope.${name}.drvPath);

  cell = channel: ghc:
    let
      baselineKeiro = pathsFor baselineName channel ghc "keiro";
      mixedKeiro = pathsFor mixedName channel ghc "keiro";
      baselineOkf = pathsFor baselineName channel ghc "okf";
      mixedOkf = pathsFor mixedName channel ghc "okf";
    in
    {
      keiroEqual = baselineKeiro == mixedKeiro;
      okfDifferent = builtins.all
        (name: baselineOkf.${name} != mixedOkf.${name})
        (builtins.attrNames baselineOkf);
      keiroPaths = baselineKeiro;
      baselineOkfPaths = baselineOkf;
      mixedOkfPaths = mixedOkf;
    };

  cells = lib.listToAttrs (lib.concatMap
    (ghc: map
      (channel: {
        name = "${channel}-${ghc}";
        value = cell channel ghc;
      })
      [ "github" "hackage" ])
    supportedGhcs);
  all = predicate: builtins.all predicate (builtins.attrValues cells);
  results = {
    githubKeiroEqual = builtins.all
      (ghc: cells."github-${ghc}".keiroEqual)
      supportedGhcs;
    hackageKeiroEqual = builtins.all
      (ghc: cells."hackage-${ghc}".keiroEqual)
      supportedGhcs;
    githubOkfDifferent = builtins.all
      (ghc: cells."github-${ghc}".okfDifferent)
      supportedGhcs;
    hackageOkfDifferent = builtins.all
      (ghc: cells."hackage-${ghc}".okfDifferent)
      supportedGhcs;
    inherit cells;
  };
in
assert all (result: result.keiroEqual && result.okfDifferent);
pkgs.runCommand "production-package-set-cache-identity"
{
  passthru = { inherit results; };
} ''
  echo '${builtins.unsafeDiscardStringContext (builtins.toJSON results)}'
  touch "$out"
''
