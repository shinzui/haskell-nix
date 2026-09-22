{
  description = "Version-scoped Haskell patch management for multi-repository Nix builds";

  inputs = {
    # The fleet's GHC toolchain flake and its single nixpkgs pin. Following that
    # nixpkgs keeps these patches, checks, and the updater on the exact package
    # sets consumers build against; consumers pair the two flakes with
    # `haskell-nix.inputs.haskell-nix-dev.follows = "haskell-nix-dev"`.
    haskell-nix-dev.url = "github:shinzui/haskell-nix-dev";
    nixpkgs.follows = "haskell-nix-dev/nixpkgs";
    flake-parts.follows = "haskell-nix-dev/flake-parts";
    treefmt-nix.follows = "haskell-nix-dev/treefmt-nix";
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
      mkHaskellExtension = import ./lib/mkHaskellExtension.nix { inherit lib; };
      mkHaskellOverlay = import ./lib/mkHaskellOverlay.nix { inherit lib; };
      mkFirstPartyRegistries = import ./lib/mkFirstPartyRegistries.nix { inherit lib; };
      compatibilityProfiles = import ./overlays/compatibility-profiles.nix;
      mkFirstPartyPackageSetFactory = import ./lib/mkFirstPartyPackageSet.nix {
        inherit lib mkFirstPartyRegistries mkHaskellExtension mkHaskellOverlay;
      };
      mkFirstPartyPackageSet = args: mkFirstPartyPackageSetFactory ({
        inherit commonRegistry compatibilityProfiles supportedGhcs;
      } // args);
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

      # The updater's closure is built from source for the same reason every
      # consumer's is (`haskell.packages.ghc9124.*` is absent from
      # cache.nixos.org), so it takes the same profiling and Haddock opt-outs.
      mkUpdaterHaskellPackages = pkgs:
        pkgs.haskell.packages.${defaultGhc}.override {
          overrides = composeManyExtensions [
            disableProfilingOverride
            disableHaddockOverride
            (hself: _hsuper: {
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
            })
          ];
        };

      mkUpdaterPackage = pkgs:
        (mkUpdaterHaskellPackages pkgs).callCabal2nix
          "haskell-nix-update"
          ./cli/haskell-nix-update
          { };

    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      inherit systems;
      imports = [ ./nix/tooling.nix ];

      flake = {
        overlays = {
          inherit (channelOverlays) hackage github;
          default = channelOverlays.github;
          haskell = channelOverlays.github;
        };

        lib = {
          tests = import ./checks/unit.nix { inherit lib; };
          inherit
            disableHaddockOverride
            disableProfilingOverride
            fixPackageByVersion
            mkChannelExtension
            mkFirstPartyPackageSet
            mkFirstPartyRegistries
            mkHaskellExtension
            mkHaskellOverlay
            registries
            haskellExtensions;

          inherit supportedGhcs defaultGhc;

          registry = registries.github;
          haskellExtension = haskellExtensions.github;
        };

      };

      perSystem = { system, ... }:
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
          toolchain = haskell-nix-dev.lib.${system}.ghcVersions.${defaultGhc};
        in
        {
          _module.args.pkgs = pkgsPlain;
          packages = {
            default = updater;
            haskell-nix-update = updater;
          };
          apps = {
            default = {
              type = "app";
              program = "${updater}/bin/haskell-nix-update";
            };
            haskell-nix-update = {
              type = "app";
              program = "${updater}/bin/haskell-nix-update";
            };
          };
          devShells.default = updaterHaskellPackages.shellFor {
            packages = _: [ updater ];
            nativeBuildInputs = [
              toolchain.cabal
              pkgsPlain.jq
              pkgsPlain.just
              pkgsPlain.nix-unit
              pkgsPlain.nix-diff
            ] ++ lib.optional (toolchain.hls != null) toolchain.hls;
          };
          checks = import ./checks/default.nix {
            inherit lib pkgsPlain pkgsGithub pkgsHackage updater firstPartyRegistries
              supportedGhcs defaultGhc firstPartyLock registries mkChannelExtension;
          };
        };
    };
}
