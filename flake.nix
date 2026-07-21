{
  description = "Version-scoped Haskell patch management for multi-repository Nix builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    baikai-src = { url = "github:shinzui/baikai"; flake = false; };
    keiro-src = { url = "github:shinzui/keiro"; flake = false; };
    kioku-src = { url = "github:shinzui/kioku"; flake = false; };
    kiroku-src = { url = "github:shinzui/kiroku"; flake = false; };
    okf-src = { url = "github:shinzui/okf"; flake = false; };
    openapi-hs-src = { url = "github:shinzui/openapi-hs"; flake = false; };
    pg-migrate-src = { url = "github:shinzui/pg-migrate"; flake = false; };
    pgmq-hs-src = { url = "github:shinzui/pgmq-hs"; flake = false; };
    servant-openapi-hs-src = { url = "github:shinzui/servant-openapi-hs"; flake = false; };
    settei-src = { url = "github:shinzui/settei"; flake = false; };
    shibuya-src = { url = "github:shinzui/shibuya"; flake = false; };
    shikumi-src = { url = "github:shinzui/shikumi"; flake = false; };
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    lib = nixpkgs.lib;

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

    mkHaskellExtension = { registry, extraOverrides ? (_: _: { }) }:
      let
        perPackageOverrides = lib.mapAttrsToList
          (name: table: fixPackageByVersion name table)
          registry;
      in
      haskellLib: pkgs:
        composeManyExtensions
          ([ extraOverrides ] ++ map (override: override haskellLib pkgs) perPackageOverrides);

    haskellExtensions = {
      github = mkHaskellExtension { registry = registries.github; };
      hackage = mkHaskellExtension {
        registry = registries.hackage;
        extraOverrides = hackageDependencyOverrides;
      };
    };

    channelOverlays = {
      github = import ./overlays/haskell-overlay.nix {
        inherit lib;
        registry = registries.github;
      };
      hackage = import ./overlays/haskell-overlay.nix {
        inherit lib;
        registry = registries.hackage;
        extraOverrides = hackageDependencyOverrides;
      };
    };

    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    mkUpdaterHaskellPackages = pkgs:
      pkgs.haskell.packages.ghc9122.override {
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
        fixPackageByVersion
        mkFirstPartyRegistries
        mkHaskellOverlay
        registries
        haskellExtensions;

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

    devShells = forAllSystems ({ pkgsPlain, updaterHaskellPackages, updater, ... }: {
      default = updaterHaskellPackages.shellFor {
        packages = _: [ updater ];
        nativeBuildInputs = [ updaterHaskellPackages.cabal-install pkgsPlain.jq pkgsPlain.just ];
      };
    });

    checks = forAllSystems ({ pkgsGithub, pkgsHackage, updater, system, ... }:
      let
        fixture = import ./checks/first-party-registry.nix {
          inherit lib firstPartyRegistries;
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

        firstPartyVersionMismatches = {
          github-ghc9122 = versionMismatches
            pkgsGithub.haskell.packages.ghc9122
            githubExpectedVersions;
          github-ghc914 = versionMismatches
            pkgsGithub.haskell.packages.ghc914
            githubExpectedVersions;
          hackage-ghc9122 = versionMismatches
            pkgsHackage.haskell.packages.ghc9122
            hackageExpectedVersions;
          hackage-ghc914 = versionMismatches
            pkgsHackage.haskell.packages.ghc914
            hackageExpectedVersions;
        };

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

      # Force evaluation of the overlay to catch Nix-level errors.
      # Verify both channel overlays and both supported compiler sets.
      overlay-eval =
        let
          results = {
            github-ghc9122 = pkgsGithub.haskell.packages.ghc9122 ? hasql;
            github-ghc914 = pkgsGithub.haskell.packages.ghc914 ? hasql;
            hackage-ghc9122 = pkgsHackage.haskell.packages.ghc9122 ? hasql;
            hackage-ghc914 = pkgsHackage.haskell.packages.ghc914 ? hasql;
          };
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
