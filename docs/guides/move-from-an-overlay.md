---
type: Guide
title: Move from an overlay to extension composition
description: Preserve shared haskell-nix patches when a consumer also overrides the same Haskell package set.
docId: DOC-3
tags: [adoption, overlays, overrides]
generated:
  by: process:codex
  at: 2026-09-22T22:46:10Z
---

[Adoption guides](README.md)

# Move from an overlay to extension composition

Use this guide when a consumer imports `inputs.haskell-nix.overlays.github` or
`.hackage` and later calls `.override { overrides = ...; }` on the same Haskell
package set. That later call replaces the earlier `overrides` value, including the
shared patches. Compose both extensions in one call instead.

## 1. Locate the two override points

Find the overlay in `import nixpkgs { overlays = ...; }` and the local Haskell
package-set override. Keep any unrelated Nixpkgs overlays. Record which channel the
consumer selected and which GHC package set its targets use.

## 2. Compose in one Haskell scope

Remove the haskell-nix overlay from the Nixpkgs import and put its selected Haskell
extension first in `composeExtensions`. Keep the consumer's local extension second.
This example uses the default GitHub set; change `channel` to `"hackage"` if that was
the consumer's original choice.

```nix
let
  pkgs = import nixpkgs { inherit system; };
  selected = inputs.haskell-nix.lib.mkFirstPartyPackageSet {
    packageSet = "default";
    channel = "github";
  };
  localOverrides = import ./nix/haskell-overlay.nix { inherit pkgs; };
  haskellPackages = pkgs.haskell.packages.ghc9124.override {
    overrides = pkgs.lib.composeExtensions
      (selected.haskellExtension pkgs.haskell.lib.compose pkgs)
      localOverrides;
  };
in
  haskellPackages
```

Update the consumer's package, shell, and check definitions to use this
`haskellPackages` value. Its local extension still runs after the shared one and can
deliberately refine shared package definitions. The
[integration reference](../user/consumer-integration.md) describes the extension
signature and ordering in detail.

## 3. Verify the change

Evaluate and build the same consumer target before and after the edit. After the edit,
the target should resolve through the composed package set:

```bash
nix flake check
nix build .#YOUR-TARGET
```

If the consumer does not have local Haskell overrides, it can keep the channel overlay;
there is no second package-set override to replace its patches.
