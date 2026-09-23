---
type: Guide
title: Adopt haskell-nix in an existing flake
description: Wire shared Nix inputs and compose a selected haskell-nix extension with a consumer's Haskell overrides.
docId: DOC-2
tags: [adoption, flake, overrides]
generated:
  by: process:codex
  at: 2026-09-22T22:46:10Z
---

[Guides](README.md)

# Adopt haskell-nix in an existing flake

Use this guide when your project already has a Nix flake and builds packages from a
Nixpkgs Haskell package set. The result is one selected first-party package set composed
with any Haskell overrides owned by the consumer.

## 1. Share the toolchain inputs

Add these inputs to the consumer's `flake.nix`. If the flake already has
`haskell-nix-dev`, retain its existing declaration and make `haskell-nix` follow it.
`mori://shinzui/haskell-nix-dev` supplies the compiler sets and the Nixpkgs pin that
`haskell-nix` patches.

```nix
inputs = {
  haskell-nix-dev.url = "github:shinzui/haskell-nix-dev";
  nixpkgs.follows = "haskell-nix-dev/nixpkgs";
  haskell-nix = {
    url = "github:shinzui/haskell-nix";
    inputs.haskell-nix-dev.follows = "haskell-nix-dev";
  };
};
```

Resolve the inputs from the consumer repository, then review its lock-file change:

```bash
nix flake lock
git diff -- flake.lock
```

## 2. Select the source and compose overrides

In the consumer's outputs, construct the `default` package set for the `github` channel.
Apply its extension to the Haskell package set **before** local overrides so those local
overrides can see and extend the shared packages. Adapt `system`, compiler, and the local
overlay path to the consumer. If there is no local Haskell overlay, use
`(_: _: { })` in its place.

```nix
let
  system = "aarch64-darwin"; # use the consumer's system
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

Use `haskellPackages` where the consumer defines its package, shell, and checks. This
flake currently supports `ghc9124` and `ghc9141`; consult
`inputs.haskell-nix.lib.supportedGhcs` when updating the compiler choice. The
[`hackage` channel](../user/channels.md) uses recorded releases and omits unpublished
packages. Choose it only when every first-party package your target needs is published.

## 3. Build the consumer target

From the consumer repository, evaluate its flake and build a target that actually uses
`haskellPackages`:

```bash
nix flake check
nix build .#YOUR-TARGET
```

Replace `YOUR-TARGET` with an output in the consumer flake. If the target cannot find a
package on Hackage, check the [channel inventory](../user/channels.md). If local
overrides seem to remove shared patches, follow the
[overlay migration guide](move-from-an-overlay.md) or the
[troubleshooting guide](../user/troubleshooting.md).
