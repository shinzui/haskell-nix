# Getting started

## Add the flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    haskell-nix.url = "github:shinzui/haskell-nix";
  };

  outputs = { nixpkgs, ... }@inputs:
    # ...
}
```

`haskell-nix` pins its own nixpkgs but does not impose it on consumers — you use your own nixpkgs as usual.

## Recommended: `haskellExtension`

Compose `haskellExtension` with your local overrides via `composeExtensions`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    haskell-nix.url = "github:shinzui/haskell-nix";
  };

  outputs = { nixpkgs, ... }@inputs:
    let
      system = "aarch64-darwin"; # or your system
      pkgs = import nixpkgs { inherit system; };

      haskellPackages = pkgs.haskell.packages.ghc9122.override {
        overrides = pkgs.lib.composeExtensions
          (inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose)
          (import ./nix/haskell-overlay.nix { inherit pkgs; });
      };
    in {
      devShells.${system}.default = haskellPackages.shellFor {
        packages = p: [ p.my-package ];
        buildInputs = [ haskellPackages.cabal-install ];
      };
    };
}
```

`haskellExtension` has the signature `haskellLib -> hself -> hsuper -> { ... }`. Partially applying it with `pkgs.haskell.lib.compose` yields a standard Haskell package set extension that slots directly into `composeExtensions`.

Ordering matters: `haskell-nix` patches go first (left argument) so your local overrides can build on top of them.

## Alternative: nixpkgs overlay

For simpler setups where you have no local Haskell overrides:

```nix
let
  pkgs = import nixpkgs {
    inherit system;
    overlays = [ inputs.haskell-nix.overlays.default ];
  };
in
  # pkgs.haskell.packages.ghc9122 and ghc914 now include all patches
```

This applies patches to `ghc9122` and `ghc914` automatically.

**Caveat**: calling `.override { overrides = ...; }` on a package set that received patches via the overlay **replaces** them. If you need local overrides, use the `haskellExtension` approach above. See [consumer-integration.md](consumer-integration.md) for a detailed explanation.

## Verify the setup

```bash
nix flake check
```

This runs two checks:
- **registry-valid** — validates that all registry entries have the expected structure
- **overlay-eval** — forces evaluation of the overlay to catch wiring errors

## Next steps

- [Adding patches](adding-patches.md) — how to add or modify entries in the patch registry
- [Consumer integration](consumer-integration.md) — detailed integration patterns and troubleshooting
