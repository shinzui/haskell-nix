---
type: Guide
title: Create a first-party package set
description: Clone a named set, choose retained group generations, and validate its support level.
docId: DOC-5
tags: [maintainers, package-sets, snapshots]
generated:
  by: process:codex
  at: 2026-09-22T23:16:29Z
---

[Guides](README.md)

# Create a first-party package set

Use this guide in the **haskell-nix repository** when an existing named set is close to the
combination of first-party generations you want to retain. The updater owns
`packages/first-party-lock.json`; do not edit its snapshots or set mappings by hand. For a
consumer-owned selection that does not need a published name, use the
[package-set reference](../user/package-sets.md#own-a-complete-selection) instead.

## 1. Inspect the available sets and generations

Run these commands from the repository root:

```bash
nix eval --json .#lib.firstPartyPackageSets
nix eval --json .#lib.firstPartyGroupSnapshots
```

Choose the source set and the retained generation for each group you intend to change.
A set must select **every** update group. Cloning supplies the complete mapping; each
subsequent `select` changes one group. The snapshot output, rather than a version-shaped
set name, tells you which generation to use. The [package-set reference](../user/package-sets.md)
explains families, atomic update groups, channels, and support levels.

Before any mutation, commit existing changes to `flake.lock` and
`packages/first-party-lock.json`. The updater refuses to mutate a dirty managed lock file.
Other working-tree changes are allowed. Its commands support `--dry-run` for a preview.

## 2. Clone the closest set

Replace `SOURCE` and `CANDIDATE` with actual names. A clone is `historical` by default, so
the new selection is retained without a continuing build promise:

```bash
nix run .#haskell-nix-update -- package-set clone \
  --from SOURCE --to CANDIDATE --dry-run
nix run .#haskell-nix-update -- package-set clone \
  --from SOURCE --to CANDIDATE
git diff -- packages/first-party-lock.json
git add packages/first-party-lock.json
git commit -m 'chore(package-sets): create candidate package set'
```

Commit each successful mutation before the next one. The updater checks that both managed
lock files are clean even when the next command changes only the package lock.

## 3. Select the desired group generations

Copy one group's selection from another set when that set already has the generation:

```bash
nix run .#haskell-nix-update -- package-set select \
  --package-set CANDIDATE --group okf --from-package-set SOURCE
```

Or select a retained group generation found in `firstPartyGroupSnapshots`:

```bash
nix run .#haskell-nix-update -- package-set select \
  --package-set CANDIDATE --group okf --generation N
```

Run one `select` per group, review `git diff -- packages/first-party-lock.json`, and commit
each result before the next mutation. Use `--dry-run` first when you want to preview a
selection. Baikai and Shikumi, for example, belong to the single `shikumi-baikai` group;
select that group rather than either family separately. To create a **new** family or group
generation, follow [Updating first-party packages](../user/updating-first-party-packages.md#refresh-one-curated-set)
first; `select` only chooses retained generations.

If the chosen group needs a different existing compatibility profile, use `package-set
profile --package-set CANDIDATE --group GROUP --profile PROFILE`, then review and commit
the new group snapshot. A changed profile definition needs a new immutable profile name;
see the [maintainer runbook](../user/updating-first-party-packages.md#compose-and-promote-named-sets).

## 4. Validate the candidate

Inspect the resulting mapping and run the fast checks:

```bash
nix eval --json .#lib.firstPartyPackageSets
nix run .#haskell-nix-update -- check --package-set CANDIDATE
just nix-test
just fmt-check
nix flake check --no-build
git diff --check
```

The updater's `check` validates the selected sources and package discovery. A historical
set can remain at this support level when it is retained for reproducibility or tested by
its consumers. Before claiming curated support, run the same package and consumer build
matrix that the flake generates for curated sets. Run this command **on each supported
system**, replacing `CANDIDATE` with the new name:

```bash
nix build --impure --print-build-logs --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
  in import ./checks/package-set-matrix.nix {
    inherit (pkgs) lib;
    inherit pkgs;
    packageSet = "CANDIDATE";
    inherit (flake.lib) supportedGhcs mkFirstPartyPackageSet;
  }
'
```

This builds both `github` and `hackage` channels with every supported compiler and a
consumer fixture. Hackage omits packages without a published pin. The supported systems
and compiler sets are listed in the [user guide](../user/README.md#public-surface).

## 5. Promote a fully validated set, if needed

Once the candidate has passed the supported matrix, change its support level:

```bash
nix run .#haskell-nix-update -- package-set support \
  --package-set CANDIDATE --support-level curated --dry-run
nix run .#haskell-nix-update -- package-set support \
  --package-set CANDIDATE --support-level curated
```

Review and commit the lock change, then run `nix flake check --print-build-logs --keep-going`
on **each supported system**. The curated label adds the named set to the generated
`package-set-CANDIDATE` build check, covering both channels, every supported compiler,
the selected package inventory, and a consumer fixture. A check on one system does not
establish support on another. Keep the set historical if that full support promise is not
intended. The [rollout guide](roll-out-a-package-set.md) covers selecting the published set
in a consumer repository.
