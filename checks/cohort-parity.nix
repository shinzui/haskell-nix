{ lib
, pkgs
, nixpkgsRevision
, cohort ? import ../generated/cohort-versions.nix
, boot ? import ../generated/ghc-boot-packages.nix
, freeze ? (import ../lib/parseCohortFreeze.nix { inherit lib; })
    (builtins.readFile ../cabal/cohort.freeze)
, recorded ? builtins.fromJSON (builtins.readFile ../cabal/cohort-sources.json)
, freezeSha256 ? builtins.hashFile "sha256" ../cabal/cohort.freeze
}:
let
  names = builtins.attrNames freeze.constraints;
  excluded = builtins.attrNames
    (lib.filterAttrs (_: policy: !policy.sourcePinned) cohort.policy);
  pinned = builtins.attrNames
    (lib.filterAttrs (_: policy: policy.sourcePinned) cohort.policy);
  classified = builtins.attrNames cohort.packages
    ++ cohort.boot ++ cohort.firstParty ++ cohort.sameAsBase ++ excluded;
  canonical = lib.mapAttrs (_: package: package // {
    dependencies = lib.unique (builtins.sort builtins.lessThan package.dependencies);
    identities = lib.unique (builtins.sort
      (a: b: builtins.toJSON a < builtins.toJSON b)
      package.identities);
  });
  versionMismatches = builtins.filter
    (name: cohort.packages.${name}.version != (freeze.constraints.${name} or null))
    (builtins.attrNames cohort.packages);
  metadataMismatches = builtins.filter
    (name:
      let entry = cohort.packages.${name};
      in entry.revision != null && !(builtins.all
        (identity: (identity.pkg-cabal-sha256 or null) == entry.revision.sha256)
        cohort.sourceManifest.${name}.identities))
    (builtins.attrNames cohort.packages);
  results = {
    schema = cohort.schemaVersion == 1;
    freezeHash = cohort.freezeSha256 == freezeSha256;
    indexState = cohort.indexState == freeze.indexState;
    flags = lib.mapAttrs
      (_: changes: builtins.sort builtins.lessThan
        (lib.mapAttrsToList (name: enabled: (if enabled then "+" else "-") + name) changes))
      cohort.flags
    == lib.mapAttrs (_: flags: builtins.sort builtins.lessThan flags) freeze.flags;
    compiler = cohort.ghc == boot.ghc && boot.ghc == pkgs.haskell.compiler.ghc9124.version;
    nixpkgs = cohort.nixpkgsBase == nixpkgsRevision;
    completeClassification = builtins.sort builtins.lessThan classified == names;
    noDuplicateClassification = builtins.length classified == builtins.length (lib.unique classified);
    exactSources = canonical recorded == canonical cohort.sourceManifest;
    sourcePinOwnership = builtins.all
      (name: builtins.hasAttr name recorded && recorded.${name}.source == "SourcePin"
        && lib.hasPrefix "mori://" cohort.policy.${name}.owner
        && cohort.policy.${name}.reason != "")
      pinned
    && builtins.sort builtins.lessThan pinned == builtins.attrNames
      (lib.filterAttrs (_: package: package.source == "SourcePin") recorded);
    generatedVersions = versionMismatches == [ ];
    selectedMetadata = metadataMismatches == [ ];
    bootVersions = builtins.all
      (name: (boot.packages.${name} or null) == freeze.constraints.${name})
      cohort.boot;
  };
  failures = builtins.filter (name: !results.${name}) (builtins.attrNames results);
  expectedBoot = pkgs.writeText "cohort-boot-packages.txt"
    (lib.concatMapStrings (name: "${name} ${boot.packages.${name}}\n")
      (builtins.attrNames boot.packages));
in
{
  cohort-generated-fresh =
    if failures != [ ] then
      throw "cohort-generated-fresh: ${builtins.toJSON { inherit failures versionMismatches metadataMismatches; }}"
    else
      pkgs.runCommand "cohort-generated-fresh"
        { passthru.results = results; }
        ''touch "$out"'';

  ghc-boot-packages = pkgs.runCommand "cohort-ghc-boot-packages"
    {
      nativeBuildInputs = [ pkgs.haskell.compiler.ghc9124 pkgs.diffutils pkgs.coreutils pkgs.gnused ];
      passthru.results = { compiler = boot.ghc; packages = boot.packages; };
    }
    ''
      export LC_ALL=C
      ghc-pkg list --global --simple-output | tr ' ' '\n' \
        | sed -e '/^$/d' -e 's/-\([0-9][0-9.]*\)$/ \1/' | sort > actual
      diff -u ${expectedBoot} actual
      touch "$out"
    '';
}
