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
      mkFirstPartyPackageSet = mkFirstPartyPackageSetFactory {
        cohortVersions = import ./generated/cohort-versions.nix;
        config = firstPartyConfig;
        lock = firstPartyLock;
        inherit commonRegistry compatibilityProfiles supportedGhcs;
      };
      mkRuntimePackageSet = import ./lib/mkRuntimePackageSet.nix { inherit lib; };
      runtimeLock = builtins.fromJSON (builtins.readFile ./packages/runtime-lock.json);
      runtimePackageSets = lib.mapAttrs
        (runtime: records: map
          (record:
            let
              retained = builtins.fromJSON (builtins.readFile (./. + "/${record.recipeDirectory}/packages/first-party-lock.json"));
              complete = builtins.head (builtins.filter (set: set.name == retained.defaultPackageSet) retained.packageSets);
              complement = builtins.filter (selection: !(builtins.hasAttr selection.group record.selections)) complete.groups;
              supportPath = ./. + "/cabal/runtime-cache/${runtime}/${toString record.generation}/support.json";
              support =
                if builtins.pathExists supportPath then
                  builtins.fromJSON (builtins.readFile supportPath)
                else { status = "unverified"; configurations = [ ]; };
              supportValid = support.status == "unverified" || (
                support.schemaVersion == 1 && support.status == "verified"
                  && support.configurations != [ ]
                  && support.runtime == runtime && support.generation == record.generation
                  && support.runtimeFingerprint == record.fingerprint
                  && builtins.all (configuration: builtins.elem configuration record.configurations) support.configurations
              );
            in
            assert supportValid;
            record // {
              inherit support;
              applicationSelections = lib.listToAttrs (map
                (selection: {
                  name = selection.group;
                  value = selection.generation;
                })
                complement);
            })
          records)
        runtimeLock.runtimes;
      defaultPackageSet = firstPartyLock.defaultPackageSet;
      channelPackageSets = lib.genAttrs [ "github" "hackage" ]
        (channel: mkFirstPartyPackageSet {
          packageSet = defaultPackageSet;
          inherit channel;
        });
      registries = lib.mapAttrs (_: packageSet: packageSet.registry)
        channelPackageSets;
      firstPartyRegistries = registries;
      defaultSelectedFamilies = channelPackageSets.github.selectedFamilies;

      firstPartyPackageSets = lib.listToAttrs (map
        (packageSet: {
          name = packageSet.name;
          value = {
            inherit (packageSet) supportLevel;
            selections = lib.listToAttrs (map
              (selection: {
                name = selection.group;
                value = selection.generation;
              })
              packageSet.groups);
          };
        })
        firstPartyLock.packageSets);
      firstPartyGroupSnapshots = firstPartyLock.groupSnapshots;

      composeManyExtensions = lib.composeManyExtensions or
        (extensions: lib.foldr lib.composeExtensions (_: _: { }) extensions);

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
        (mkFirstPartyPackageSet {
          packageSet = defaultPackageSet;
          inherit channel disableProfiling disableHaddock;
        }).haskellExtension;

      haskellExtensions = lib.mapAttrs (_: packageSet: packageSet.haskellExtension)
        channelPackageSets;
      channelOverlays = lib.mapAttrs (_: packageSet: packageSet.overlay)
        channelPackageSets;
      consumerOverlayAudit = import ./lib/mkConsumerOverlayAudit.nix {
        inherit lib registries haskellExtensions defaultGhc;
      };
      inherit (consumerOverlayAudit) consumerOverlayReport auditConsumerOverlay;

      # haskell-nix-dev's systems: its nixpkgs (26.11) dropped x86_64-darwin.
      # Production test workloads currently run only on amd64 Linux; keep
      # Apple Silicon for native development and x86_64 Linux for deployment.
      systems = [ "x86_64-linux" "aarch64-darwin" ];

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
          mkCohortManifest = import ./lib/mkCohortManifest.nix { inherit lib; };
          parseCohortFreeze = import ./lib/parseCohortFreeze.nix { inherit lib; };
          # Retained cohort data used by generation, parity and consumer tools.
          cohort =
            let
              freeze = (import ./lib/parseCohortFreeze.nix { inherit lib; })
                (builtins.readFile ./cabal/cohort.freeze);
            in
            {
              inherit freeze;
              versions = import ./generated/cohort-versions.nix;
              boot = import ./generated/ghc-boot-packages.nix;
              versionTable = freeze.constraints;
            };
          tests = import ./checks/unit.nix { inherit lib; };
          inherit
            disableHaddockOverride
            disableProfilingOverride
            fixPackageByVersion
            mkChannelExtension
            mkFirstPartyPackageSet
            mkRuntimePackageSet
            runtimePackageSets
            mkFirstPartyRegistries
            mkHaskellExtension
            mkHaskellOverlay
            registries
            haskellExtensions
            firstPartyPackageSets
            firstPartyGroupSnapshots
            consumerOverlayReport
            auditConsumerOverlay;

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
          cohortCompare = pkgsPlain.writeShellApplication {
            name = "cohort-compare";
            runtimeInputs = [ updater pkgsPlain.curl pkgsPlain.coreutils pkgsPlain.python3 ];
            text = ''
              manifest_tool=${./scripts/cohort-manifest.py}
            '' + builtins.readFile ./scripts/cohort-compare.sh;
          };
          cohortCache = pkgsPlain.writeShellApplication {
            name = "cohort-cache";
            runtimeInputs = [ pkgsPlain.python3 pkgsPlain.nix pkgsPlain.cachix ];
            text = ''exec python3 ${./scripts/cohort-cache.py} "$@"'';
          };
          runtimeOutputs = lib.genAttrs [ "github" "hackage" ] (channel:
            (import ./lib/mkRuntimeOutputs.nix {
              inherit lib mkRuntimePackageSet;
              pkgs = pkgsPlain;
              mkCohortManifest = import ./lib/mkCohortManifest.nix { inherit lib; };
            }) {
              runtime = "keiro-runtime";
              generation = 1;
              inherit channel;
              applicationSelections = {
                kioku = 8;
                okf = 5;
                openapi-hs = 1;
                relay-pagination = 3;
                servant-openapi-hs = 1;
                shikumi-baikai = 9;
              };
            });
          runtimeImport = pkgsPlain.writeShellApplication {
            name = "runtime-import";
            runtimeInputs = [ pkgsPlain.python3 ];
            text = ''
              export SSL_CERT_FILE="${pkgsPlain.cacert}/etc/ssl/certs/ca-bundle.crt"
              exec python3 ${./scripts/runtime-import.py} "$@"
            '';
          };
          toolchain = haskell-nix-dev.lib.${system}.ghcVersions.${defaultGhc};
          cohortVersions = import ./generated/cohort-versions.nix;
          cohortScope = pkgsGithub.haskell.packages.${defaultGhc};
          cohortNames = builtins.attrNames (lib.filterAttrs
            (name: package: package.source != "Boot"
              && !(builtins.hasAttr name cohortVersions.policy
              && !cohortVersions.policy.${name}.sourcePinned))
            cohortVersions.sourceManifest);
          cohortFarm = name: names: pkgsPlain.linkFarm name
            (map (package: { name = package; path = cohortScope.${package}; }) names);
          cohortManifest = (import ./lib/mkCohortManifest.nix { inherit lib; }) {
            pkgs = pkgsPlain;
            scope = cohortScope;
            root = cohortScope.pg-migrate-cli;
            localPackages = [ ];
            context = {
              versions = cohortVersions;
              boot = import ./generated/ghc-boot-packages.nix;
              configurationPolicy = builtins.fromJSON (builtins.readFile ./cabal/cohort-nix-policy.json);
              nixpkgsRevision = nixpkgs.rev;
              channel = "github";
              sourceContext = channelPackageSets.github.sourceContext;
              channelRevision = inputs.self.rev or inputs.self.dirtyRev or null;
            };
          };
        in
        {
          _module.args.pkgs = pkgsPlain;
          packages = {
            default = updater;
            haskell-nix-update = updater;
            cohort-compare = cohortCompare;
            cohort-cache = cohortCache;
            runtime-import = runtimeImport;
            keiro-runtime-verifier = import ./checks/runtime-verifier.nix {
              inherit lib mkRuntimePackageSet;
              channelRevision = inputs.self.rev or inputs.self.dirtyRev or "uncommitted";
              pkgs = pkgsPlain;
            };
            keiro-runtime-hackage-verifier = import ./checks/runtime-verifier.nix {
              inherit lib mkRuntimePackageSet;
              channel = "hackage";
              channelRevision = inputs.self.rev or inputs.self.dirtyRev or "uncommitted";
              pkgs = pkgsPlain;
            };
            keiro-runtime = runtimeOutputs.github.roots;
            keiro-runtime-hackage = runtimeOutputs.hackage.roots;
            keiro-runtime-closure = runtimeOutputs.github.closure;
            keiro-runtime-hackage-closure = runtimeOutputs.hackage.closure;
            keiro-runtime-manifest = runtimeOutputs.github.manifest;
            keiro-runtime-hackage-manifest = runtimeOutputs.hackage.manifest;
            keiro-runtime-proof = runtimeOutputs.github.proof;
            cohort-manifest = cohortManifest;
            cohort-closure = cohortFarm "cohort-closure" cohortNames;
            cohort-roots = cohortFarm "cohort-roots" [
              "keiro"
              "kiroku-store"
              "kioku-core"
              "shibuya-pgmq-adapter"
              "pg-migrate-cli"
              "baikai-kit"
              "claude"
              "openai"
              "relay-pagination-servant"
              "servant-openapi-hs"
              "warp"
              "wai-app-static"
              "brick"
              "sbv"
              "dhall"
              "hs-opentelemetry-exporter-otlp"
              "streamly"
              "generic-lens"
            ];
          };
          apps = {
            runtime-import = {
              type = "app";
              program = "${runtimeImport}/bin/runtime-import";
            };
            cohort-cache = {
              type = "app";
              program = "${cohortCache}/bin/cohort-cache";
            };
            cohort-compare = {
              type = "app";
              program = "${cohortCompare}/bin/cohort-compare";
            };
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
          # Native pkg-config inputs needed to solve every contributor configuration.
          devShells.runtime-integration =
            let
              postgres17 = pkgsPlain.postgresql_17.withPackages (extensions: [ extensions.pg_partman ]);
              postgres18 = pkgsPlain.postgresql_18.withPackages (extensions: [ extensions.pg_partman ]);
            in
            pkgsPlain.mkShell {
              nativeBuildInputs = [ postgres18 pkgsPlain.python3 pkgsPlain.coreutils ];
              KENSHOU_PG17_BIN = "${postgres17}/bin";
              KENSHOU_PG18_BIN = "${postgres18}/bin";
              KENSHOU_KAFKA_RUNTIME = "container";
            };
          devShells.cohort-inventory = pkgsPlain.mkShell {
            inputsFrom = [ self.devShells.${system}.default ];
            COHORT_GHC = "${pkgsPlain.haskell.packages.${defaultGhc}.ghc}/bin/ghc";
            COHORT_GHC_PKG = "${pkgsPlain.haskell.packages.${defaultGhc}.ghc}/bin/ghc-pkg";
            nativeBuildInputs = [ pkgsPlain.pkg-config pkgsPlain.python3 ];
            buildInputs = [ pkgsPlain.xz pkgsPlain.zlib pkgsPlain.postgresql.dev pkgsPlain.openssl.dev ];
          };
          checks = (import ./checks/default.nix {
            nixpkgsRevision = nixpkgs.rev;
            inherit lib pkgsPlain pkgsGithub pkgsHackage updater cohortCompare cohortManifest firstPartyRegistries
              supportedGhcs defaultGhc defaultSelectedFamilies registries mkChannelExtension
              mkFirstPartyPackageSet mkFirstPartyPackageSetFactory firstPartyPackageSets
              haskellExtensions auditConsumerOverlay;
          }) // {
            runtime-github-parity = import ./checks/runtime-parity.nix {
              inherit lib updater;
              pkgs = pkgsPlain;
              manifest = runtimeOutputs.github.manifest;
              record = runtimeOutputs.github.selected.metadata;
            };
            runtime-hackage-parity = import ./checks/runtime-parity.nix {
              inherit lib updater;
              pkgs = pkgsPlain;
              manifest = runtimeOutputs.hackage.manifest;
              record = runtimeOutputs.hackage.selected.metadata;
            };
            runtime-import = pkgsPlain.runCommand "runtime-import-fixtures"
              {
                nativeBuildInputs = [ pkgsPlain.python3 ];
              } ''
              python3 ${./checks/runtime-import.py} ${./scripts/runtime-import.py} ${./.}
              touch "$out"
            '';
            runtime-kafka-close = import ./checks/runtime-kafka-close.nix {
              inherit lib mkRuntimePackageSet;
              pkgs = pkgsPlain;
            };
            runtime-hackage-composition = import ./checks/runtime-composition.nix {
              inherit lib mkRuntimePackageSet;
              pkgs = pkgsPlain;
              channel = "hackage";
            };
            runtime-composition = import ./checks/runtime-composition.nix {
              inherit lib mkRuntimePackageSet;
              pkgs = pkgsPlain;
            };
          };
        };
    };
}
