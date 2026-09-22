{ lib
, pkgsPlain
, pkgsGithub
, pkgsHackage
, updater
, firstPartyRegistries
, supportedGhcs
, defaultGhc
, defaultSelectedFamilies
, registries
, mkChannelExtension
, mkFirstPartyPackageSet
, mkFirstPartyPackageSetFactory
}:
let
  fixture = import ./first-party-registry.nix {
    inherit lib firstPartyRegistries supportedGhcs;
    pkgs = pkgsGithub;
  };

  validateEntry = name: entries:
    builtins.all
      (entry:
        if entry ? always && entry.always then
          entry ? patch && builtins.isFunction entry.patch
        else
          entry ? min && entry ? max && entry ? patch
          && builtins.isString entry.min
          && builtins.isString entry.max
          && builtins.isFunction entry.patch
      )
      entries;

  validateRegistry = registry:
    builtins.all
      (name: validateEntry name registry.${name})
      (builtins.attrNames registry);

  lockedPackages = lib.concatMap
    (family: family.packages)
    defaultSelectedFamilies;

  githubExpectedVersions = lib.listToAttrs (map
    (package: {
      name = package.name;
      value = package.version;
    })
    lockedPackages);

  hackageExpectedVersions = lib.listToAttrs (map
    (package: {
      name = package.name;
      value = package.hackage.version;
    })
    (builtins.filter (package: package.hackage != null) lockedPackages));

  versionMismatches = packages: expected:
    builtins.filter
      (name: packages.${name}.version != expected.${name})
      (builtins.attrNames expected);

  # One entry per channel and supported GHC, e.g. `github-ghc9124`.
  perChannelGhc = f: lib.listToAttrs (lib.concatMap
    (ghc: [
      { name = "github-${ghc}"; value = f pkgsGithub.haskell.packages.${ghc} githubExpectedVersions; }
      { name = "hackage-${ghc}"; value = f pkgsHackage.haskell.packages.${ghc} hackageExpectedVersions; }
    ])
    supportedGhcs);

  firstPartyVersionMismatches = perChannelGhc versionMismatches;

  allFirstPartyVersionsMatch = builtins.all
    (names: names == [ ])
    (builtins.attrValues firstPartyVersionMismatches);
in
{
  # Validate that the registry has the expected structure:
  # each entry is a list of { min, max, patch } or { always, patch } attrsets.
  registry-valid =
    let
      allValid = validateRegistry registries.github
        && validateRegistry registries.hackage;
    in
    pkgsGithub.runCommand "registry-valid" { } (
      if allValid then ''
        echo "Registry validation passed for GitHub and Hackage channels"
        touch "$out"
      '' else
        throw "Registry validation failed: entries must have { min, max, patch } or { always = true; patch }"
    );

  first-party-registry = fixture.check;

  package-set-contract =
    let
      fixtureRoot = ./fixtures/package-sets;
      config = builtins.fromJSON (builtins.readFile (fixtureRoot + "/valid-config.json"));
      lock = builtins.fromJSON (builtins.readFile (fixtureRoot + "/valid-lock.json"));
      validated = import ../lib/validateFirstPartyPackageSetLock.nix {
        inherit lib config lock;
      };
      project = name: map
        (snapshot: { inherit (snapshot) family generation; })
        (validated.select name);
      results = {
        default = project "default";
        historical = project "historical";
      };
    in
    assert results.default == [
      { family = "baikai"; generation = 1; }
      { family = "keiro"; generation = 1; }
      { family = "okf"; generation = 2; }
      { family = "shikumi"; generation = 1; }
    ];
    assert results.historical == [
      { family = "baikai"; generation = 1; }
      { family = "keiro"; generation = 1; }
      { family = "okf"; generation = 1; }
      { family = "shikumi"; generation = 1; }
    ];
    pkgsPlain.runCommand "package-set-contract"
      {
        passthru = { inherit results; };
      } ''
      echo '${builtins.toJSON results}'
      touch "$out"
    '';

  package-set-cache-identity = import ./package-set-cache-identity.nix {
    inherit lib defaultGhc supportedGhcs;
    mkFirstPartyPackageSet = mkFirstPartyPackageSetFactory;
    pkgs = pkgsPlain;
  };

  package-set-real-source =
    let
      flakeLock = builtins.fromJSON (builtins.readFile ../flake.lock);
      locked = flakeLock.nodes."okf-src".locked;
      descriptor = {
        inherit (locked) type owner repo rev narHash;
      };
      fetched = builtins.fetchTree descriptor;
      results.revisionMatches = fetched.rev == descriptor.rev;
    in
    assert results.revisionMatches;
    pkgsPlain.runCommand "package-set-real-source"
      {
        passthru = { inherit results; };
      } ''
      echo '${builtins.toJSON results}'
      touch "$out"
    '';

  first-party-versions =
    assert allFirstPartyVersionsMatch;
    pkgsGithub.runCommand "first-party-versions" { } ''
      echo '${builtins.toJSON firstPartyVersionMismatches}'
      touch "$out"
    '';

  haskell-nix-update = updater;

  # The build-setting flags must reach the package scope by default and be
  # answerable by a consumer that wants either setting back. `doHaddock` is
  # observable through `enableSeparateDocOutput`, which defaults to it: no
  # Haddock, no `doc` output. Profiling has no such observable, so Haddock
  # stands in for both -- they compose identically, through one
  # `mkDerivation` override in the scope.
  build-setting-flags =
    let
      mkSet = args: pkgsPlain.haskell.packages.${defaultGhc}.override {
        overrides =
          (mkChannelExtension args)
            pkgsPlain.haskell.lib.compose
            pkgsPlain;
      };
      hasDocOutput = set: builtins.elem "doc" set.hasql.outputs;

      results = {
        # Reading the extension the default way now drops Haddock, and the
        # flag reaches every package in the scope rather than the top one.
        default-drops-haddock = !(hasDocOutput (mkSet { }));
        # The default is answerable: a consumer that wants documentation
        # back says so, and gets it for the whole set.
        explicit-false-keeps-haddock =
          hasDocOutput (mkSet { disableHaddock = false; });
        # The two settings stay independent. Answering one must not answer
        # the other, which is what a single shared `mkDerivation` override
        # would silently do if they were ever collapsed.
        profiling-flag-does-not-answer-haddock =
          !(hasDocOutput (mkSet { disableProfiling = false; }));
        # It sets a default, not a ceiling: `overrideCabal` re-applies its
        # attrs on top of the scope's `mkDerivation`, so a consumer can
        # still ask for documentation on one particular package.
        per-package-opt-back-in =
          builtins.elem "doc"
            (pkgsPlain.haskell.lib.compose.doHaddock
              (mkSet { }).hasql).outputs;
      };
      failures = builtins.filter (name: !results.${name})
        (builtins.attrNames results);
    in
    assert failures == [ ];
    pkgsPlain.runCommand "build-setting-flags" { } ''
      echo 'Build-setting flags behave as documented: ${builtins.toJSON results}'
      touch "$out"
    '';

  # Force evaluation of the overlay to catch Nix-level errors.
  # Verify both channel overlays under every supported compiler set.
  overlay-eval =
    let
      results = perChannelGhc (packages: _: packages ? hasql);
      allPresent = builtins.all
        (name: results.${name})
        (builtins.attrNames results);
    in
    assert allPresent;
    pkgsGithub.runCommand "overlay-eval" { } ''
      echo 'Overlay evaluation succeeded: ${builtins.toJSON results}'
      touch "$out"
    '';
}
