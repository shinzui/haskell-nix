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

## Refresh validation fails on an unbuilt cabal2nix derivation

Symptom: `refresh` restored the managed lock files cleanly, and its validation failed with only

```text
error: path '/nix/store/...-cabal2nix-<package>.drv' is not valid
```

**`refresh` now prevents this on its own, and no manual step is expected.** Before running
`nix flake check`, it evaluates the check's own derivation path, which performs the same
import-from-derivation builds through a path that realises them:

```bash
nix eval --no-eval-cache --raw '.#checks.<system>.first-party-versions.drvPath'
```

The warm is best-effort: if it cannot run, `nix flake check` still decides the refresh and reports
the real failure, so a failed warm never masks a genuine one.

This section remains for the case where you meet the error outside `refresh` — running
`nix flake check` by hand after locking a new revision, for example. Run the command above from
the repository root and rerun the check.

Tell this apart from the stale eval cache above:

| | Stale eval cache | Unbuilt cabal2nix derivation |
| --- | --- | --- |
| Also reports `unexpectedly succeeded` | often | never |
| `rm -rf ~/.cache/nix/eval-cache-v*` fixes it | yes | no |
| Retrying | may succeed | fails on the identical store path |

### Why it must be that expression

The first-party version checks force a cabal2nix import-from-derivation for every package at the
newly locked revision. `nix flake check` computes those derivations during evaluation but does not
realise them, so the import cannot build them.

It is tempting to warm the packages by hand with `nix eval --impure` over `callCabal2nix`. **Do
not**: an impure evaluation computes a *different* derivation for the same package than the pure
evaluation `nix flake check` performs, so it warms derivations the check never asks for. The error
does not move, and it looks as though warming is not working. Two further traps in the same
direction:

- Passing the source as `src.outPath` rather than the input itself makes it a string rather than a
  path, and `callCabal2nix` filters only path sources — another different derivation.
- The error names only the first missing derivation, so warming one package at a time appears to
  make progress while each step is warming the wrong thing.

Evaluating `.#checks.<system>.first-party-versions.drvPath` sidesteps all of this by asking the
check itself, purely, for exactly what it is about to import.

Observed on Determinate Nix 3.17.0 (Nix 2.33.3).

### Warming a family that is not in the lock yet

This is the one case the automatic warm cannot cover, and the one case where an impure sweep over
a plain package set is the right tool rather than a trap: the check cannot be evaluated at all, so
there is no pure expression to ask.

A newly configured family cannot load `flake.overlays.<channel>`:
until its generated records exist, config and lock disagree and the overlay throws. Warm a
new family through a plain `nixpkgs` package set, taking sources from
`flake.inputs.<family>-src` and Hackage pins from `nix store prefetch-file --json --unpack`
against the release tarball.

A plain package set cannot resolve first-party dependencies, and `builtins.tryEval` does not
catch the resulting missing-argument error, so pass each first-party dependency explicitly
and warm dependencies before dependents:

```bash
nix eval --no-eval-cache --impure --json --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; };
    sweep = compiler:
      let
        hp = pkgs.haskell.packages.${compiler};
        dependency = hp.callCabal2nix "DEPENDENCY" flake.inputs.DEPENDENCY-src { };
      in
      [ dependency.version
        (hp.callCabal2nix "PACKAGE" flake.inputs.PACKAGE-src { DEPENDENCY = dependency; }).version
      ];
  in
  { ghc9122 = sweep "ghc9122"; ghc914 = sweep "ghc914"; }
'
```

Warm the matching Hackage pins the same way with `hp.callHackageDirect { pkg; ver; sha256; }`,
then run `refresh --family FAMILY` again. A new check fixture that calls `callCabal2nix` needs
the same treatment before its first `refresh`.

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
