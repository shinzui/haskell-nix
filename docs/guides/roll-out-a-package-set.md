---
type: Guide
title: Roll out a first-party package set
description: Select a retained first-party generation and source channel, then validate and lock a consumer upgrade.
docId: DOC-4
tags: [adoption, package-sets, channels]
generated:
  by: process:codex
  at: 2026-09-22T22:46:10Z
---

[Adoption guides](README.md)

# Roll out a first-party package set

Use this guide after a consumer has integrated the haskell-nix extension. A package set
chooses a complete mapping of update groups to retained generations. The channel chooses
GitHub or Hackage sources for that selection.

## 1. Inspect available selections

Run these commands in the consumer repository, where `haskell-nix` is a locked input:

```bash
nix eval --impure --json --expr \
  '(builtins.getFlake (toString ./.)).inputs.haskell-nix.lib.firstPartyPackageSets'
nix eval --impure --json --expr \
  '(builtins.getFlake (toString ./.)).inputs.haskell-nix.lib.firstPartyGroupSnapshots'
```

Confirm a named set's `supportLevel` and selections before choosing it. `curated`
sets carry this repository's build evidence; `historical` sets remain selectable but
need consumer-owned compatibility checks. The
[package-set reference](../user/package-sets.md) explains family and group generations.

## 2. Make the selection explicit

Use a named set when it already represents the desired rollout:

```nix
selected = inputs.haskell-nix.lib.mkFirstPartyPackageSet {
  packageSet = "default";
  channel = "github";
};
```

To advance one retained group independently, start with a complete published mapping
and replace only that group's generation. Verify the actual generation in
`firstPartyGroupSnapshots` before editing; the number below is illustrative.

```nix
selected = inputs.haskell-nix.lib.mkFirstPartyPackageSet {
  selections = inputs.haskell-nix.lib.firstPartyPackageSets.default.selections // {
    keiro = 2;
  };
  channel = "github";
};
```

This merge tracks future `default` changes for other groups. To hold every group at a
fixed generation, copy the entire mapping into the consumer. Change `channel` to
`"hackage"` only after confirming that every needed first-party package has a
published release in the [channel reference](../user/channels.md).

## 3. Validate and lock the rollout

Build the consumer target that uses the selected package set, then review the flake
and lock changes together:

```bash
nix flake check
nix build .#YOUR-TARGET
git diff -- flake.nix flake.lock
```

When adopting a newer published haskell-nix revision, update that input in the
consumer first, inspect the newly available generations, make the selection change,
and rerun the same target:

```bash
nix flake update haskell-nix
nix flake check
nix build .#YOUR-TARGET
```

If a generation is unknown or an explicit mapping is incomplete, see
[Troubleshooting](../user/troubleshooting.md). Do not edit this repository's generated
package lock from a consumer.
