{ lib
, pkgsPlain
, pkgsGithub
, pkgsHackage
, updater
, cohortCompare
, cohortManifest
, nixpkgsRevision
, firstPartyRegistries
, supportedGhcs
, defaultGhc
, defaultSelectedFamilies
, firstPartyPackageSets
, registries
, mkChannelExtension
, mkFirstPartyPackageSet
, mkFirstPartyPackageSetFactory
, haskellExtensions
, auditConsumerOverlay
}:
let
  frozenParity = name: manifest: pkgsPlain.runCommand name
    { nativeBuildInputs = [ cohortCompare ]; manifestFile = manifest; }
    ''
      cohort-compare --freeze ${../cabal/cohort.freeze} \
        --sources ${../cabal/cohort-sources.json} --contributors ${../cabal/contributors.json} \
        --nix-policy ${../cabal/cohort-nix-policy.json} --nix-manifest "$manifestFile"
      touch "$out"
    '';
  dhallManifest = (import ../lib/mkCohortManifest.nix { inherit lib; }) {
    pkgs = pkgsPlain;
    scope = pkgsGithub.haskell.packages.${defaultGhc};
    root = pkgsGithub.haskell.packages.${defaultGhc}.dhall-json;
    localPackages = [ ];
    context = cohortManifest.declaration.context;
  };
  fixture = import ./first-party-registry.nix {
    inherit lib firstPartyRegistries supportedGhcs;
    pkgs = pkgsGithub;
  };
  recipeFixture = import ./generated-recipes.nix {
    pkgs = pkgsPlain;
    scope = pkgsPlain.haskell.packages.${defaultGhc};
  };
  applicationCheckpointFixture = import ./application-checkpoint.nix {
    pkgs = pkgsPlain;
    scope = pkgsPlain.haskell.packages.${defaultGhc};
  };
  projectShellFixture = import ./project-shell.nix {
    pkgs = pkgsPlain;
    scope = pkgsPlain.haskell.packages.${defaultGhc};
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

  curatedPackageSetChecks = lib.mapAttrs'
    (name: _: lib.nameValuePair "package-set-${name}"
      (import ./package-set-matrix.nix {
        inherit lib supportedGhcs mkFirstPartyPackageSet;
        packageSet = name;
        pkgs = pkgsPlain;
      }))
    (lib.filterAttrs (_: packageSet: packageSet.supportLevel == "curated")
      firstPartyPackageSets);
in
{
  generated-recipes = recipeFixture.parity;
  generated-recipes-no-ifd = recipeFixture.noIfd;
  application-incremental = import ./application-incremental.nix {
    pkgs = pkgsPlain;
    scope = pkgsGithub.haskell.packages.${defaultGhc};
  };
  cohort-pg-migrate-parity = frozenParity "cohort-pg-migrate-parity" cohortManifest;
  cohort-dhall-parity = frozenParity "cohort-dhall-parity" dhallManifest;
  cohort-cache = import ./cohort-cache.nix { pkgs = pkgsPlain; };
  cohort-serialise-ghc912 = import ./serialise-compatibility.nix {
    pkgs = pkgsPlain;
    scope = pkgsGithub.haskell.packages.${defaultGhc};
  };
  cohort-serialise-ghc914 = import ./serialise-compatibility.nix {
    pkgs = pkgsPlain;
    scope = pkgsGithub.haskell.packages.ghc9141;
  };
  cohort-manifest = import ./cohort-manifest.nix {
    inherit lib cohortCompare;
    pkgs = pkgsPlain;
    scope = pkgsGithub.haskell.packages.${defaultGhc};
  };
  cohort-manifest-ghc914 = import ./cohort-manifest.nix {
    inherit lib cohortCompare;
    pkgs = pkgsPlain;
    scope = pkgsGithub.haskell.packages.ghc9141;
  };
  cohort-compare = import ./cohort-compare.nix {
    pkgs = pkgsPlain;
    inherit cohortCompare;
  };
  cohort-versions = import ./cohort-versions.nix {
    inherit lib;
    pkgs = pkgsPlain;
    scopes = {
      github-ghc9124 = pkgsGithub.haskell.packages.ghc9124;
      hackage-ghc9124 = pkgsHackage.haskell.packages.ghc9124;
    };
  };
  registry-policy-only = pkgsPlain.runCommand "registry-policy-only"
    { nativeBuildInputs = [ pkgsPlain.python3 ]; }
    ''
      python3 ${../scripts/lint-registry-policy.py} ${../overlays} ${../patches}
      mkdir rejected-policy
      echo 'hself.callHackageDirect { pkg = "hasql"; ver = "1"; } { }' > rejected-policy/pin.nix
      if python3 ${../scripts/lint-registry-policy.py} rejected-policy > rejected.log 2>&1; then
        echo 'registry-policy-only: failed to reject a reintroduced pin' >&2
        exit 1
      fi
      grep -q 'pin.nix:1:' rejected.log
      touch "$out"
    '';
  cabal-version-support = import ./cabal-version-support.nix {
    inherit lib;
    pkgs = pkgsPlain;
    scopes = {
      github = pkgsGithub.haskell.packages.${defaultGhc};
      hackage = pkgsHackage.haskell.packages.${defaultGhc};
    };
  };

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
  application-checkpoint = applicationCheckpointFixture.check;
  project-shell = projectShellFixture.check;
  compatibility-policy =
    let
      tests = import ./compatibility-policy.nix { inherit lib; };
      failures = lib.filterAttrs (_: test: test.expr != test.expected) tests;
    in
    assert lib.assertMsg (failures == { })
      "compatibility-policy: ${lib.concatStringsSep ", " (builtins.attrNames failures)}";
    pkgsPlain.runCommand "compatibility-policy" { } ''
      touch "$out"
    '';

  compatibility-report =
    let
      tests = import ./compatibility-report.nix { inherit lib; };
      failures = lib.filterAttrs (_: test: test.expr != test.expected) tests;
      report = import ../lib/compatibilityReport.nix { inherit lib; };
      context = import ./fixtures/compatibility-policy/context.nix;
      declaration = pkgsPlain.writeText "compatibility-context.json" (builtins.toJSON (report context));
      required = pkgsPlain.writeText "compatibility-required.json" (builtins.toJSON (report (context // {
        requiredEvidence = [ "legacy-kioku-core-v1" ];
      })));
    in
    assert lib.assertMsg (failures == { }) "compatibility-report: failed pure checks";
    pkgsPlain.runCommand "compatibility-report" { nativeBuildInputs = [ updater pkgsPlain.jq ]; } ''
      haskell-nix-update compatibility report --context ${declaration} --json > report.json
      jq -e '.reportKind == "declaration-only"' report.json
      haskell-nix-update compatibility check --context ${declaration}
      if haskell-nix-update compatibility check --context ${required} > required.log 2>&1; then
        echo "required native evidence was incorrectly accepted" >&2
        exit 1
      fi
      grep -q 'required evidence is unverified' required.log
      mkdir "$out"
      cp report.json "$out/"
    '';

  compatibility-capture =
    let
      fixture = import ./compatibility-capture.nix {
        inherit lib mkFirstPartyPackageSet;
        pkgs = pkgsPlain;
        compiler = defaultGhc;
      };
      report = pkgsPlain.writeText "compatibility-captured.json" (builtins.toJSON fixture.report);
      identities = pkgsPlain.writeText "compatibility-captured-identities.json" (builtins.toJSON fixture.identities);
    in
    pkgsPlain.runCommand "compatibility-capture" { nativeBuildInputs = [ updater pkgsPlain.jq ]; } ''
      haskell-nix-update compatibility report --context ${report} --json > captured.json
      haskell-nix-update compatibility check --context ${report}
      jq -e '.entries[] | select(.id == "legacy-kioku-core-v1") | .construction.stage == "compatibility-row" and .inputs.derivation == .construction.before.derivation' captured.json
      jq -e '.entries[] | select(.id == "legacy-first-party-source-v1") | .construction.stage == "source-constructor" and .construction.before == null' captured.json
      jq -e '.entries[] | select(.id == "legacy-cborg-json-v1") | .construction.after.effective.editedCabalFile != null' captured.json
      mkdir "$out"
      cp captured.json "$out/"
      cp ${identities} "$out/identities.json"
    '';

  shared-overrides = import ./shared-overrides.nix {
    inherit lib defaultGhc;
    pkgs = pkgsPlain;
    haskellExtension = haskellExtensions.github;
  };

  consumer-overlay-audit = auditConsumerOverlay {
    pkgs = pkgsPlain;
    overlay = import ./fixtures/consumer-overlays/clean.nix { pkgs = pkgsPlain; };
    ownPackages = [ "consumer-overlay-example" ];
  };

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

  production-package-set-cache-identity =
    import ./production-package-set-cache-identity.nix {
      inherit lib supportedGhcs mkFirstPartyPackageSet;
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
} // (import ./cohort-parity.nix {
  inherit lib nixpkgsRevision;
  pkgs = pkgsPlain;
}) // curatedPackageSetChecks
