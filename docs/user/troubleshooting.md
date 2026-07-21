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

This looks like the stale eval cache above but is a different failure. Tell them apart:

| | Stale eval cache | Unbuilt cabal2nix derivation |
| --- | --- | --- |
| Also reports `unexpectedly succeeded` | often | never |
| `rm -rf ~/.cache/nix/eval-cache-v*` fixes it | yes | no |
| Retrying | may succeed | fails on the identical store path |

The first-party version checks force a cabal2nix import-from-derivation for every package at the
newly locked revision. Those derivations are computed during `nix flake check` evaluation but are
not realised in the store, so the import cannot build them. The same import through `nix eval`
succeeds, so evaluating the new packages once populates the store and lets the validation proceed.

The error names only the first derivation that is missing. Warming that one package moves the
error to the next, so warm the whole family in one pass rather than retrying `refresh` repeatedly.
Take the new revision, versions, and hashes from `refresh --dry-run`, which writes nothing.

Warm the GitHub channel at the proposed revision:

```bash
nix eval --no-eval-cache --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ flake.overlays.github ];
    };
    lock = builtins.fromJSON (builtins.readFile ./packages/first-party-lock.json);
    family = builtins.head (builtins.filter (f: f.name == "FAMILY") lock.families);
    src = builtins.fetchGit { url = "https://github.com/OWNER/FAMILY"; rev = "NEW_REV"; };
    warm = hp: package:
      let
        target = src + "/${package.path}";
        called =
          if package.cabal2nixOptions == ""
          then hp.callCabal2nix package.name target { }
          else hp.callCabal2nixWithOptions package.name target package.cabal2nixOptions { };
        result = builtins.tryEval called.version;
      in
      "${package.name}:" + (if result.success then result.value else "warmed");
  in
  {
    ghc9122 = map (warm pkgs.haskell.packages.ghc9122) family.packages;
    ghc914 = map (warm pkgs.haskell.packages.ghc914) family.packages;
  }
' --json
```

Warm the Hackage channel for every package whose release changed, using the versions and hashes
the dry run proposed:

```bash
nix eval --no-eval-cache --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ flake.overlays.hackage ];
    };
    new = [
      { pkg = "PACKAGE"; ver = "VERSION"; sha256 = "sha256-..."; }
    ];
    warm = hp: p:
      let result = builtins.tryEval (hp.callHackageDirect p { }).version;
      in "${p.pkg}:" + (if result.success then result.value else "warmed");
  in
  {
    ghc9122 = map (warm pkgs.haskell.packages.ghc9122) new;
    ghc914 = map (warm pkgs.haskell.packages.ghc914) new;
  }
' --json
```

Then rerun `refresh --family FAMILY` normally.

Four details matter:

1. Apply the matching channel overlay. A bare `nixpkgs` package set cannot resolve first-party
   dependencies and aborts the sweep with `function 'anonymous lambda' called without required
   argument '<dependency>'` before the remaining packages are warmed.
2. Warm both `ghc9122` and `ghc914`. The cabal2nix derivation differs per package set, so warming
   one compiler leaves the other unbuilt.
3. The GitHub sweep reads `path` and `cabal2nixOptions` from the current lock, which still holds
   the old revision. That is correct for a version or revision bump. If the update adds packages,
   the new ones are absent from that list and must be warmed separately.
4. The printed versions must match the versions `refresh --dry-run` proposed. A mismatch means the
   warm ran against the wrong revision, not that the lock is wrong.

Observed on Determinate Nix 3.17.0 (Nix 2.33.3).

### Warming a family that is not in the lock yet

The sweeps above load `flake.overlays.<channel>`, which a newly configured family cannot do:
until its generated records exist, config and lock disagree and the overlay throws. Warm a
new family through a plain `nixpkgs` package set instead, taking sources from
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
