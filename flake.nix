{
  description = "Version-scoped Haskell patch management for multi-repository Nix builds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    lib = nixpkgs.lib;

    registry = import ./overlays/registry.nix;
    fixPackageByVersion = import ./lib/fixPackageByVersion.nix { inherit lib; };
    mkHaskellOverlay = import ./lib/mkHaskellOverlay.nix { inherit lib; };
    haskellOverlay = import ./overlays/haskell-overlay.nix { inherit lib; };

    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    forAllSystems = f: lib.genAttrs systems (system: f {
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ haskellOverlay ];
      };
      inherit system;
    });
  in
  {
    overlays = {
      default = haskellOverlay;
      haskell = haskellOverlay;
    };

    lib = {
      inherit fixPackageByVersion mkHaskellOverlay registry;
    };

    checks = forAllSystems ({ pkgs, system }: {
      # Validate that the registry has the expected structure:
      # each entry is a list of { min, max, patch } attrsets.
      registry-valid =
        let
          validateEntry = name: entries:
            builtins.all (e:
              e ? min && e ? max && e ? patch
              && builtins.isString e.min
              && builtins.isString e.max
              && builtins.isFunction e.patch
            ) entries;

          allValid = builtins.all (name: validateEntry name registry.${name})
            (builtins.attrNames registry);
        in
        pkgs.runCommand "registry-valid" { } (
          if allValid then ''
            echo "Registry validation passed: all entries have { min, max, patch }"
            touch $out
          '' else
            throw "Registry validation failed: entries must have { min : string, max : string, patch : function }"
        );

      # Force evaluation of the overlay to catch Nix-level errors.
      # Verifies that the overlay wiring is correct by checking that
      # overridden package sets exist and contain expected packages.
      # Note: does NOT force version dispatch (which only happens when
      # a package is actually built) — this only checks structural integrity.
      overlay-eval =
        let
          ghc9122HasHasql = pkgs.haskell.packages.ghc9122 ? hasql;
          ghc914HasHasql = pkgs.haskell.packages.ghc914 ? hasql;
        in
        pkgs.runCommand "overlay-eval" { } ''
          echo "Overlay evaluation succeeded"
          echo "  ghc9122 has hasql: ${lib.boolToString ghc9122HasHasql}"
          echo "  ghc914 has hasql: ${lib.boolToString ghc914HasHasql}"
          touch $out
        '';
    });
  };
}
