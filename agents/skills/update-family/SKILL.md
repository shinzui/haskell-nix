---
name: update-family
description: >
  Update one first-party Haskell package family to its latest GitHub HEAD (git sha) and latest
  Hackage releases by driving the haskell-nix-update CLI, then verify. Rewrites flake.lock and
  packages/first-party-lock.json for the named family only. TRIGGER when: the user wants to bump,
  refresh, or update a first-party family (e.g. baikai, keiro, kioku, kiroku, pg-migrate, pgmq-hs,
  settei, shibuya, shikumi) to the newest source revision and Hackage versions.
argument-hint: <family-name>
user-invocable: true
---

# Update Family Skill

Update a single first-party Haskell package family so both channels track upstream: the **GitHub
channel** to the family's latest remote `HEAD` (git sha) and the **Hackage channel** to each
package's latest published release. The mechanism is the repository's own `haskell-nix-update` CLI —
**never hand-edit `flake.lock`, `packages/first-party-lock.json`, or `overlays/registry.nix`.** That
CLI is the only sanctioned writer of the generated lock; hand edits break the strict Nix validator.

The argument is a single family name. If none was given, ask for one before proceeding. Do not
default to "all families" — this skill scopes to one family via `--family`.

Read [Updating first-party packages](../../../docs/user/updating-first-party-packages.md) and
[Troubleshooting](../../../docs/user/troubleshooting.md) for the authoritative contract; this skill
is the operational runbook that follows it.

## What "update" means here

For the named family, a mutating `refresh`:

1. Reads the family's remote GitHub `HEAD` and, if it moved, runs `nix flake update` on the
   `<family>-src` input so `flake.lock` pins the new sha — then **asserts** the locked head equals
   the queried head.
2. Discovers every Cabal package one directory below the family root at the locked revision.
3. Queries Hackage for each package's latest release and prefetches its archive for the SRI hash.
4. Rewrites `packages/first-party-lock.json` atomically (`githubRev`, per-package `version`, and
   `hackage: {version, hash}` — or `hackage: null` for unpublished packages).
5. Runs the flake validation. Any failure **after** an input update restores both managed files
   byte-for-byte; the command never commits or pushes.

## Preconditions — check before running

Run everything from the repository root.

1. **Managed files must be clean.** A mutating refresh refuses to start if `flake.lock` or
   `packages/first-party-lock.json` has uncommitted changes. Confirm:

   ```bash
   git status --short -- flake.lock packages/first-party-lock.json
   ```

   If dirty, commit or stash those two files first (unrelated working-tree changes are fine and must
   not be discarded).

2. **The family name must be valid.** List the accepted names from the hand-authored catalog and
   confirm the argument is present:

   ```bash
   jq -r '.families[].name' config/first-party-families.json
   ```

   Unknown names are rejected by the CLI before any work begins.

3. **The family's source must be locatable via Mori.** `refresh` resolves the registered local
   checkout through Mori and reads Git objects from it. If a revision is missing locally the refresh
   fetches it, but the project must be registered. If in doubt:

   ```bash
   mori registry show shinzui/<family> --full
   ```

   Do not search `/nix/store` for a checkout — the Mori path is the source of truth.

## Procedure

Substitute the real family name for `FAMILY` throughout.

### 1. Preview (no writes)

```bash
nix run .#haskell-nix-update -- refresh --family FAMILY --dry-run
```

This reads remote heads, Cabal metadata, and Hackage releases and prefetches archives, but changes
nothing. Show the user the proposed changes. If it reports `No changes.`, the family is already
current — stop and report that; there is nothing to commit.

### 2. Apply

```bash
nix run .#haskell-nix-update -- refresh --family FAMILY
```

On success it prints the applied changes and has already run the flake validation. On failure it
restores `flake.lock` and `packages/first-party-lock.json` byte-for-byte — verify with
`git diff --exit-code -- flake.lock packages/first-party-lock.json` before retrying, and see
Troubleshooting for transient-network vs. dirty-file vs. missing-revision cases.

Two distinct failures produce a clean rollback plus a cabal2nix error. Do not conflate them:

- `evaluation of cached failed attribute 'checks.<system>.first-party-versions' unexpectedly
  succeeded` is a poisoned Nix eval cache. Clear it with `rm -rf ~/.cache/nix/eval-cache-v*` and
  retry. The current CLI validates with `--no-eval-cache`, so this should only come from an older
  run or a manual `nix flake check`.
- `path '...-cabal2nix-<pkg>.drv' is not valid`, **alone**, is the unbuilt-derivation case in step
  2a. Clearing the eval cache does not fix it, and retrying fails on the identical store path.

Both are covered in Troubleshooting.

### 2a. Pre-warm when validation cannot build cabal2nix derivations

`nix flake check` cannot realise cabal2nix import-from-derivation for packages at a newly locked
revision, so `refresh` can fail with `path '...-cabal2nix-<pkg>.drv' is not valid`. The error names
only the first missing derivation, so retrying `refresh` walks the family one package per attempt.

Pre-warming the family with `nix eval` — which performs the same import successfully — avoids the
loop entirely. The dry run in step 1 already produced the revision, versions, and hashes the warm
needs, so run the two `nix eval` sweeps from the **"Refresh validation fails on an unbuilt cabal2nix
derivation"** section of [Troubleshooting](../../../docs/user/troubleshooting.md): one over the
GitHub channel at the proposed revision, one over the Hackage channel for every changed release.
Cross-check that the versions they print match the dry run before applying.

Warming is cheap relative to a failed refresh and is safe to run unconditionally, so prefer it up
front for any family whose source revision moved rather than waiting for the failure.

### 3. Verify

```bash
nix run .#haskell-nix-update -- refresh --family FAMILY --dry-run   # must now report: No changes.
nix run .#haskell-nix-update -- check --family FAMILY --online
nix flake check --print-build-logs
```

`check --online` compares the lock against live GitHub `HEAD` and Hackage state; `nix flake check`
validates schemas, exact versions, the updater tests, and both channel overlays. Note that
`nix flake check` does **not** compile the whole inventory — if this update changed package
membership or shared compatibility, build the family's packages directly (the full GHC 9.12.2 channel
matrix commands are in the updating doc).

### 4. Review the diff

Inspect exactly what changed and confirm it matches intent:

```bash
git --no-pager diff -- flake.lock packages/first-party-lock.json
```

Confirm: only the `FAMILY-src` node moved in `flake.lock`; the family's `githubRev` is the new
40-char sha; package `version`/`hackage` fields updated as expected; unpublished packages still carry
`"hackage": null`; families and package names remain sorted and globally unique.

### 5. Docs (only if membership or publication changed)

If the set of packages or any package's published/unpublished state changed, update the snapshot
counts and GitHub-only names in [docs/user/channels.md](../../../docs/user/channels.md). A pure
version/sha bump with unchanged membership needs no doc edit.

## Commit

Commit only when the user asks (per repo git policy, commit to the current branch — do not create a
branch). Follow Conventional Commits; a bump is typically `build(deps)`:

```text
build(deps): bump FAMILY to <version> (github + hackage channels)
```

Stage `flake.lock`, `packages/first-party-lock.json`, and any `docs/user/channels.md` edit together
so every published commit evaluates successfully. See `git log` (e.g. commit `6d36015`) for the
established message style.
