---
type: Explanation
title: Package sets
description: Understand first-party package-set selection, retention, and cache behavior.
docId: DOC-7
tags: [package-sets, snapshots, cache]
generated:
  by: human:nadeem
  at: 2026-09-22T21:30:17Z
---

[User guide](README.md)

# Package sets

A package set lets a consumer update one first-party release line without moving every
other first-party package. Package selection and source provenance are separate choices:
choose a package set first, then choose its GitHub or Hackage channel.

## The model

A **family** is every package discovered in one source repository. All packages in the
Keiro repository, for example, share one source revision and move together.

An **update group** is one or more families that must move atomically. Most families are
implicit one-family groups. The explicit `shikumi-baikai` group contains Baikai and Shikumi,
so neither can be selected or refreshed alone.

A **family generation** is an immutable snapshot of one family's locked source, package
inventory, Hackage pins, Cabal2nix options, and exclusions. A **group generation** refers to
one family generation for every member of an update group and names the compatibility
profile that applies to that cohort.

A **named package set** is a complete mapping from every update group to one retained group
generation. `default` preserves the legacy outputs. Historical sets may retain old or mixed
selections for reproducibility without making them supported release lines.

A package set has a **support level**. `curated` sets are built by this repository across
both channels, every supported GHC, and every supported system. `historical` sets remain
selectable and reproducible but are not promised to keep building on future toolchains.
Consumer-owned mappings have no repository support designation.

A **compatibility profile** is an immutable, named registry fragment associated with a
group generation. If a workaround changes, maintainers add a new profile name rather than
changing the meaning of an old snapshot.

A **channel** chooses source provenance after selection. `github` uses the content-addressed
locked repository revision and includes unpublished packages. `hackage` uses recorded
release archives and omits packages whose Hackage pin is null. Changing channels does not
change the selected family or group generations.

## Select a named set

`lib.mkFirstPartyPackageSet` returns a registry, Haskell extension, Nixpkgs overlay, the
normalized selection, and selected-family metadata:

```nix
let
  selected = inputs.haskell-nix.lib.mkFirstPartyPackageSet {
    packageSet = "default";
    channel = "github"; # or "hackage"
  };

  haskellPackages = pkgs.haskell.packages.ghc9124.override {
    overrides = pkgs.lib.composeExtensions
      (selected.haskellExtension pkgs.haskell.lib.compose pkgs)
      myOverrides;
  };
in
  haskellPackages
```

Use `selected.overlay` instead when the consumer does not add another `overrides` value to
the same Haskell package set.

Inspect the names, support levels, and complete mappings without fetching package sources:

```bash
nix eval --json .#lib.firstPartyPackageSets
nix eval --json .#lib.firstPartyGroupSnapshots
```

## Own a complete selection

The constructor accepts `selections` instead of `packageSet`. Exactly one must be supplied,
and the mapping must contain every resolved group with a positive retained generation:

```nix
let
  liveDefault = inputs.haskell-nix.lib.firstPartyPackageSets.default.selections;
  selected = inputs.haskell-nix.lib.mkFirstPartyPackageSet {
    selections = liveDefault // {
      keiro = 2;
      okf = 1;
    };
    channel = "hackage";
  };
in
  selected.haskellExtension
```

Merging over `firstPartyPackageSets.default.selections` deliberately follows future default
generations for every group not overridden. To pin every group until you edit it, copy the
complete evaluated mapping into the consumer as literal attributes. Generation numbers are
opaque snapshot identities; confirm them against `firstPartyGroupSnapshots` instead of
inferring them from package versions.

Selections are always complete. Baikai and Shikumi move together, all packages from Keiro
move as one family, and the singleton OKF group can advance independently.

## Retention and topology

Published snapshots are append-only. Refreshing a curated set appends changed family and
group generations and moves only that named set; it does not rewrite other named sets.
Old discovery options and exclusions remain part of their family snapshots.

Schema version 2 fixes the family inventory and update-group membership. Adding or removing
a family, or regrouping existing families, needs a future explicit catalog migration. It
must not silently add a group to an existing complete consumer mapping.

## Cache contract

Package-set names and generation labels are selection metadata, not derivation inputs. Two
first-party derivations can reuse the same path only when all effective inputs are equal:

- system, compiler, and Nixpkgs;
- channel and selected source/version;
- the transitive dependency graph;
- compatibility profiles and patches; and
- profiling, Haddock, and other build settings.

The production checks prove that selecting OKF 0.9 instead of 0.8 leaves every Keiro 0.14
derivation unchanged under otherwise equal inputs. A consumer package that directly depends
on OKF may still rebuild, even when its Keiro dependency does not. This repository proves
derivation identity and buildability; it does not promise that any particular external
binary cache has published the resulting path.

First-party packages are currently built with Cabal bounds jailbroken and test suites
disabled by the generated registry. A curated matrix therefore proves the supported Nix
construction, not unmodified upstream bounds or upstream test-suite success.
