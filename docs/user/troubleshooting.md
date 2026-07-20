[User guide](README.md)

# Troubleshooting

## Local Haskell overrides removed the shared patches

Symptom: packages from `haskell-nix` were present until the consumer called
`.override { overrides = ...; }` on the same compiler package set.

A later `.override` replaces the overlay's previous `overrides` value. Apply the selected
`lib.haskellExtensions.github` or `.hackage` constructor directly and combine it with local
overrides using `pkgs.lib.composeExtensions`. See
[Consumer integration](consumer-integration.md) for the complete expression and ordering.

## A package is missing from the Hackage channel

An unpublished package is deliberately absent rather than silently fetched from GitHub.
Check the generated registries and the package's lock record:

```bash
nix eval --json .#lib.registries.github --apply builtins.attrNames
nix eval --json .#lib.registries.hackage --apply builtins.attrNames
jq '.families[].packages[] | select(.name == "PACKAGE")' packages/first-party-lock.json
```

Use the GitHub channel if the lock record has `"hackage": null`. Otherwise, an unexpected
absence is a registry validation bug and should fail `nix flake check`.

## Refresh refuses dirty managed files

A mutating refresh protects `flake.lock` and `packages/first-party-lock.json` from being
overwritten. Inspect only those managed files first:

```bash
git status --short -- flake.lock packages/first-party-lock.json
git diff -- flake.lock packages/first-party-lock.json
```

Commit or intentionally stash those changes before retrying. Unrelated changes elsewhere
in the repository do not trigger this guard and should not be discarded.

## Offline check cannot find a Git revision

`check` asks Mori for the registered local checkout and reads the locked commit through
Git. Confirm the qualified project and path:

```bash
mori registry show OWNER/PROJECT --full
```

Fetch the missing revision in that registered checkout, or run a scoped refresh preview,
which may fetch the remote commit while leaving the managed lock files unchanged:

```bash
nix run .#haskell-nix-update -- refresh --family FAMILY --dry-run
```

Do not search `/nix/store` for a source checkout; the Mori path is the source of truth.

## An online Hackage or GitHub request fails transiently

`refresh` restores both managed lock files byte-for-byte when a failure happens after a
source input update. Confirm the rollback before retrying:

```bash
git diff --exit-code -- flake.lock packages/first-party-lock.json
nix run .#haskell-nix-update -- check
```

`refresh --dry-run` and `check --online` never write the managed files, so they are safe to
repeat after a network failure. If the error persists, run the scoped family command to
identify the failing repository or package.

## Refresh validation fails on a stale eval cache

Symptom: `refresh` restored the managed lock files cleanly (they are byte-for-byte
unchanged) but its validation failed, and a direct `nix flake check` reports either

```text
error: path '/nix/store/...-cabal2nix-<package>.drv' is not valid
error: evaluation of cached failed attribute 'checks.<system>.first-party-versions' unexpectedly succeeded
```

This is not a lock problem. The first-party checks force cabal2nix import-from-derivation
builds; a transient IFD or substituter failure (for example while fetching the `cabal2nix`
tool from `cache.nixos.org`) can be recorded in the Nix eval cache as a failed attribute.
Once the underlying build succeeds, cached-evaluation runs then abort with `unexpectedly
succeeded`. The updater now runs its validation with `--no-eval-cache`, so a current CLI
does not poison the cache; this remains a fallback for a poisoned cache left by an older
run or a manual `nix flake check`.

Clear the eval cache and retry:

```bash
rm -rf ~/.cache/nix/eval-cache-v*
nix run .#haskell-nix-update -- refresh --family FAMILY
```

To pre-warm the import-from-derivation builds without the cache before retrying:

```bash
nix flake check --no-build --no-eval-cache
```

## Family selection fails

List the accepted family names from the hand-authored catalog:

```bash
jq -r '.families[].name' config/first-party-families.json
```

Pass `--family` once for each distinct name. Unknown names and duplicate values are rejected
before any update begins.

## Flake checks pass but a package build fails

The flake suite validates schemas, exact versions, the updater, and overlay evaluation. It
does not compile every first-party package. Build the changed package directly, and run the
complete channel matrices for membership or shared compatibility changes. The exact matrix
commands are in [Updating first-party packages](updating-first-party-packages.md).
