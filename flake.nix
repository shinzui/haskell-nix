{
  description = "Version-scoped Haskell patch management for multi-repository Nix builds";

  inputs = {
    # The fleet's GHC toolchain flake and its single nixpkgs pin. Following that
    # nixpkgs keeps these patches, checks, and the updater on the exact package
    # sets consumers build against; consumers pair the two flakes with
    # `haskell-nix.inputs.haskell-nix-dev.follows = "haskell-nix-dev"`.
    haskell-nix-dev.url = "github:shinzui/haskell-nix-dev";
    nixpkgs.follows = "haskell-nix-dev/nixpkgs";
    baikai-src = { url = "github:shinzui/baikai"; flake = false; };
    keiki-src = { url = "github:shinzui/keiki"; flake = false; };
    keiro-src = { url = "github:shinzui/keiro"; flake = false; };
    kioku-src = { url = "github:shinzui/kioku"; flake = false; };
    kiroku-src = { url = "github:shinzui/kiroku"; flake = false; };
    okf-src = { url = "github:shinzui/okf"; flake = false; };
    openapi-hs-src = { url = "github:shinzui/openapi-hs"; flake = false; };
    pg-migrate-src = { url = "github:shinzui/pg-migrate"; flake = false; };
    pgmq-hs-src = { url = "github:shinzui/pgmq-hs"; flake = false; };
    relay-pagination-src = { url = "github:shinzui/relay-pagination"; flake = false; };
    servant-openapi-hs-src = { url = "github:shinzui/servant-openapi-hs"; flake = false; };
    settei-src = { url = "github:shinzui/settei"; flake = false; };
    shibuya-src = { url = "github:shinzui/shibuya"; flake = false; };
    shikumi-src = { url = "github:shinzui/shikumi"; flake = false; };
  };

  outputs = { self, nixpkgs, haskell-nix-dev, ... }@inputs:
  let
    lib = nixpkgs.lib;

    # The GHC package sets this flake patches and checks are exactly the ones
    # haskell-nix-dev ships toolchains for. The list is system-independent;
    # reading its names from one system's `ghcVersions` forces no toolchain.
    devGhcs = haskell-nix-dev.lib.x86_64-linux;
    supportedGhcs = builtins.attrNames devGhcs.ghcVersions;
    inherit (devGhcs) defaultGhc;

    commonRegistry = import ./overlays/registry.nix;
    firstPartyConfig = builtins.fromJSON
      (builtins.readFile ./config/first-party-families.json);
    firstPartyLock = builtins.fromJSON
      (builtins.readFile ./packages/first-party-lock.json);
    firstPartySources = lib.listToAttrs (map
      (family: {
        name = family.githubInput;
        value = inputs.${family.githubInput};
      })
      firstPartyConfig.families);

    fixPackageByVersion = import ./lib/fixPackageByVersion.nix { inherit lib; };
    disableProfilingOverride = import ./lib/disableProfilingOverride.nix;
    disableHaddockOverride = import ./lib/disableHaddockOverride.nix;
    mkHaskellOverlay = import ./lib/mkHaskellOverlay.nix { inherit lib; };
    mkFirstPartyRegistries = import ./lib/mkFirstPartyRegistries.nix { inherit lib; };
    firstPartyRegistries = mkFirstPartyRegistries {
      sources = firstPartySources;
      config = firstPartyConfig;
      lock = firstPartyLock;
    };

    githubOnlyPackageNames = lib.concatMap
      (family: map (package: package.name)
        (builtins.filter (package: package.hackage == null) family.packages))
      firstPartyLock.families;

    # Published family Cabal files can mention an unpublished sibling only in
    # tests or benchmarks. Null placeholders let callPackage resolve those
    # disabled components without adding the names to the Hackage registry.
    hackageDependencyOverrides = _: _:
      lib.genAttrs githubOnlyPackageNames (_: null);

    registries = {
      hackage = commonRegistry // firstPartyRegistries.hackage;
      github = commonRegistry // firstPartyRegistries.github;
    };

    composeManyExtensions = lib.composeManyExtensions or
      (extensions: lib.foldr lib.composeExtensions (_: _: { }) extensions);

    mkHaskellExtension =
      { registry
      , extraOverrides ? (_: _: { })
      , disableProfiling ? true
      , disableHaddock ? true
      }:
      let
        perPackageOverrides = lib.mapAttrsToList
          (name: table: fixPackageByVersion name table)
          registry;
      in
      haskellLib: pkgs:
        composeManyExtensions
          (lib.optional disableProfiling disableProfilingOverride
            ++ lib.optional disableHaddock disableHaddockOverride
            ++ [ extraOverrides ]
            ++ map (override: override haskellLib pkgs) perPackageOverrides);

    # What distinguishes the two channels, independent of build settings.
    channelSpecs = {
      github = { registry = registries.github; };
      hackage = {
        registry = registries.hackage;
        extraOverrides = hackageDependencyOverrides;
      };
    };

    # Public constructor for consumers that want a build setting other than the
    # one this flake imposes. `lib.haskellExtensions.*` is this with every option
    # left at its default.
    #
    # Both build settings default to ON as of the profiling/Haddock flip: this
    # fleet ships CLI tools, nothing consumes the `p_` way or the `doc` output,
    # and `haskell.packages.ghc9124.*` is absent from cache.nixos.org, so every
    # consumer was compiling both twice over from source. A consumer that does
    # want either back passes `false` explicitly, and `haskell.lib.compose`
    # still re-applies per package on top of the scope.
    mkChannelExtension =
      { channel ? "github"
      , disableProfiling ? true
      , disableHaddock ? true
      }:
      mkHaskellExtension (channelSpecs.${channel} // {
        inherit disableProfiling disableHaddock;
      });

    haskellExtensions = lib.mapAttrs (_: mkHaskellExtension) channelSpecs;

    channelOverlays = {
      github = import ./overlays/haskell-overlay.nix {
        inherit lib;
        registry = registries.github;
        compilers = supportedGhcs;
      };
      hackage = import ./overlays/haskell-overlay.nix {
        inherit lib;
        registry = registries.hackage;
        compilers = supportedGhcs;
        extraOverrides = hackageDependencyOverrides;
      };
    };

    # haskell-nix-dev's systems: its nixpkgs (26.11) dropped x86_64-darwin.
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];

    mkUpdaterHaskellPackages = pkgs:
      pkgs.haskell.packages.${defaultGhc}.override {
        overrides = hself: _hsuper: {
          optparse-applicative =
            let
              haskellLib = pkgs.haskell.lib.compose;
            in
            haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix
              "optparse-applicative"
              (builtins.fetchTarball {
                url = "https://hackage.haskell.org/package/optparse-applicative-0.19.0.0/optparse-applicative-0.19.0.0.tar.gz";
                sha256 = "sha256-dhqvRILfdbpYPMxC+WpAyO0KUfq2nLopGk1NdSN2SDM=";
              })
              { }));
        };
      };

    mkUpdaterPackage = pkgs:
      (mkUpdaterHaskellPackages pkgs).callCabal2nix
        "haskell-nix-update"
        ./cli/haskell-nix-update
        { };

    forAllSystems = f: lib.genAttrs systems (system:
      let
        pkgsPlain = import nixpkgs { inherit system; };
        pkgsGithub = import nixpkgs {
          inherit system;
          overlays = [ channelOverlays.github ];
        };
        pkgsHackage = import nixpkgs {
          inherit system;
          overlays = [ channelOverlays.hackage ];
        };
        updaterHaskellPackages = mkUpdaterHaskellPackages pkgsPlain;
        updater = mkUpdaterPackage pkgsPlain;
      in
      f {
        inherit system pkgsPlain pkgsGithub pkgsHackage updaterHaskellPackages updater;
      });
  in
  {
    overlays = {
      inherit (channelOverlays) hackage github;
      default = channelOverlays.github;
      haskell = channelOverlays.github;
    };

    lib = {
      inherit
        disableHaddockOverride
        disableProfilingOverride
        fixPackageByVersion
        mkChannelExtension
        mkFirstPartyRegistries
        mkHaskellOverlay
        registries
        haskellExtensions;

      inherit supportedGhcs defaultGhc;

      registry = registries.github;
      haskellExtension = haskellExtensions.github;
    };

    packages = forAllSystems ({ updater, ... }: {
      default = updater;
      haskell-nix-update = updater;
    });

    apps = forAllSystems ({ updater, ... }: {
      default = {
        type = "app";
        program = "${updater}/bin/haskell-nix-update";
      };
      haskell-nix-update = {
        type = "app";
        program = "${updater}/bin/haskell-nix-update";
      };
    });

    # The updater's Haskell dependencies come from `shellFor`; cabal and HLS come
    # from the haskell-nix-dev toolchain for the same GHC, so the editor setup
    # matches every other fleet project (and HLS is a Cachix hit).
    devShells = forAllSystems ({ pkgsPlain, updaterHaskellPackages, updater, system, ... }:
      let
        toolchain = haskell-nix-dev.lib.${system}.ghcVersions.${defaultGhc};
      in
      {
        default = updaterHaskellPackages.shellFor {
          packages = _: [ updater ];
          nativeBuildInputs = [ toolchain.cabal pkgsPlain.jq pkgsPlain.just ]
            ++ lib.optional (toolchain.hls != null) toolchain.hls;
        };
      });

    checks = forAllSystems ({ pkgsPlain, pkgsGithub, pkgsHackage, updater, system, ... }:
      let
        fixture = import ./checks/first-party-registry.nix {
          inherit lib firstPartyRegistries supportedGhcs;
          pkgs = pkgsGithub;
        };

        validateEntry = name: entries:
          builtins.all (entry:
            if entry ? always && entry.always then
              entry ? patch && builtins.isFunction entry.patch
            else
              entry ? min && entry ? max && entry ? patch
              && builtins.isString entry.min
              && builtins.isString entry.max
              && builtins.isFunction entry.patch
          ) entries;

        validateRegistry = registry:
          builtins.all
            (name: validateEntry name registry.${name})
            (builtins.attrNames registry);

        lockedPackages = lib.concatMap
          (family: family.packages)
          firstPartyLock.families;

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
      in {
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
            overrides = (mkChannelExtension args)
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
    });
  };
}
