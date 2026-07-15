{
  description = "Version-scoped Haskell patch management for multi-repository Nix builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

    registries = {
      hackage = commonRegistry // firstPartyRegistries.hackage;
      github = commonRegistry // firstPartyRegistries.github;
    };

    composeManyExtensions = lib.composeManyExtensions or
      (extensions: lib.foldr lib.composeExtensions (_: _: { }) extensions);

    mkHaskellExtension = registry:
      let
        perPackageOverrides = lib.mapAttrsToList
          (name: table: fixPackageByVersion name table)
          registry;
      in
      haskellLib: pkgs:
        composeManyExtensions (map (override: override haskellLib pkgs) perPackageOverrides);

    haskellExtensions = lib.mapAttrs
      (_: registry: mkHaskellExtension registry)
      registries;

    channelOverlays = lib.mapAttrs
      (_: registry: import ./overlays/haskell-overlay.nix { inherit lib registry; })
      registries;

    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    forAllSystems = f: lib.genAttrs systems (system:
      let
        pkgsGithub = import nixpkgs {
          inherit system;
          overlays = [ channelOverlays.github ];
        };
        pkgsHackage = import nixpkgs {
          inherit system;
          overlays = [ channelOverlays.hackage ];
        };
      in
      f { inherit system pkgsGithub pkgsHackage; });
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

    checks = forAllSystems ({ pkgsGithub, pkgsHackage, system }:
      let
        fixture = import ./checks/first-party-registry.nix {
          inherit lib;
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
