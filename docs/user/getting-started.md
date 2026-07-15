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

## Choose a first-party channel

Use `lib.haskellExtensions.github` when you want every catalogued first-party package at
the family revision locked in this flake. This channel includes packages that have not been
published. Use `lib.haskellExtensions.hackage` when you want the latest published release
recorded in the package lock; packages without a Hackage release are absent from that
channel. The current lock contains 51 GitHub packages and 41 Hackage packages, so selecting
Hackage does not silently substitute GitHub source for the 10 unpublished names.

The legacy singular output `lib.haskellExtension` is an exact alias for the GitHub channel.
Likewise, `lib.registry`, `overlays.default`, and `overlays.haskell` alias their GitHub
counterparts.

## Recommended: direct extension composition

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

      firstPartyExtension = inputs.haskell-nix.lib.haskellExtensions.github;

      haskellPackages = pkgs.haskell.packages.ghc9122.override {
        overrides = pkgs.lib.composeExtensions
          (firstPartyExtension pkgs.haskell.lib.compose pkgs)
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

Each channel extension has the signature
`haskellLib -> pkgs -> hself -> hsuper -> { ... }`. Applying it to
`pkgs.haskell.lib.compose` and the top-level `pkgs` set yields the standard Haskell
package-set extension that slots into `composeExtensions`.

Ordering matters: `haskell-nix` patches go first (left argument) so your local overrides can build on top of them.

## Alternative: nixpkgs overlay

For simpler setups where you have no local Haskell overrides:

```nix
let
  pkgs = import nixpkgs {
    inherit system;
    overlays = [ inputs.haskell-nix.overlays.github ];
  };
in
  # pkgs.haskell.packages.ghc9122 and ghc914 now include all patches
```

Select `overlays.hackage` instead to use the Hackage channel. Both overlays apply patches
to `ghc9122` and `ghc914` automatically.

**Caveat**: calling `.override { overrides = ...; }` on a package set that received patches via the overlay **replaces** them. If you need local overrides, use the `haskellExtension` approach above. See [consumer-integration.md](consumer-integration.md) for a detailed explanation.

## Verify the setup

```bash
nix flake check
```

This validates both channel registries, applies the local first-party fixture under both
compiler sets, resolves every locked package to its exact version under `ghc9122` and
`ghc914`, and forces evaluation of both channel overlays.

To exercise an unpushed local `haskell-nix` change from a real consumer without rewriting
that consumer's lock file, run its normal build with an input override:

```bash
nix build --override-input haskell-nix path:/path/to/local/haskell-nix
```

The consumer still selects `.github` or `.hackage` in its own Nix configuration, so repeat
the validation with each provenance when a change affects both channels.

## Next steps

- [Adding patches](adding-patches.md) — how to add or modify entries in the patch registry
- [Consumer integration](consumer-integration.md) — detailed integration patterns and troubleshooting
- [Updating first-party packages](updating-first-party-packages.md) — the family config and generated package-lock contracts
