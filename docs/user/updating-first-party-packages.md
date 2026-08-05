[User guide](README.md)

# Updating first-party packages

First-party package channels are driven by two versioned JSON files and the source
revisions in `flake.lock`. The split keeps stable maintainer intent separate from generated
package metadata. Nix reads only checked-in files, so evaluating a channel never contacts
GitHub, Hackage, or Mori.

## Prerequisites

Run the updater from the repository root. Every configured `moriProject` must be registered
and point to a usable local Git checkout. Verify the repository identity and each family
before changing config:

```bash
mori show --full
mori registry show OWNER/PROJECT --full
```

The online paths also require access to GitHub, Hackage metadata and archives, and the Nix
substituters used by the flake. A normal refresh requires committed versions of
`flake.lock` and `packages/first-party-lock.json`; unrelated working-tree changes are
allowed.

## Family config

`config/first-party-families.json` is hand-authored. Each family identifies one registered
source repository and its non-flake Nix input:

```json
{
  "schemaVersion": 1,
  "families": [
    {
      "name": "example",
      "moriProject": "example/example",
      "github": "example/example",
      "githubInput": "example-src",
      "packageOverrides": {
        "example-special": {
          "cabal2nixOptions": "-f-example"
        }
      },
      "excludedPackages": [
        "example-demo"
      ]
    }
  ]
}
```

`name`, `moriProject`, `github`, and `githubInput` are required non-empty strings.
`github` uses the exact `owner/repository` form. The input name is `<family-name>-src` and
must be unique. `packageOverrides` is optional; its keys name discovered Cabal packages,
and `cabal2nixOptions` is the only supported override field.

`excludedPackages` is optional and lists discovered Cabal packages that never become family
packages. Package names must be globally unique across the lock, so a repository that carries
an example or fixture package whose name is already taken by another family excludes it here
rather than renaming it upstream. The list must be sorted and free of duplicates, and a name
cannot be both excluded and overridden.

Exclusions are checked against discovery: an entry that matches no discovered package fails
the refresh instead of silently doing nothing, so a rename upstream surfaces immediately. An
excluded package is never written to the lock, never queried on Hackage, and never appears in
either channel registry — consumers that need it must depend on it some other way.

`keiki` uses this for its `jitsurei` examples package, whose name collides with the unrelated
`jitsurei` in `keiro`.

## Generated package lock

`packages/first-party-lock.json` records the selected revision and every Cabal package
found at a family repository root or one directory below it:

```json
{
  "schemaVersion": 1,
  "families": [
    {
      "name": "example",
      "githubInput": "example-src",
      "githubRev": "0123456789abcdef0123456789abcdef01234567",
      "packages": [
        {
          "name": "example-core",
          "path": "example-core",
          "version": "1.2.0.0",
          "cabal2nixOptions": "",
          "hackage": {
            "version": "1.2.0.0",
            "hash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
          }
        }
      ]
    }
  ]
}
```

`githubRev` is the 40-character commit selected by `flake.lock`. Package paths are clean,
relative paths without `.` or `..` segments, except for a single-package repository whose
Cabal file sits at the repository root: that package records the exact path `"."` and is
built from the whole family source. Versions contain dot-separated non-negative integers. A package that has no official release uses `"hackage": null`; it appears only
in the GitHub channel. A published package records the latest Hackage version and its SRI
SHA-256 hash. Families and packages are sorted by name, and package names are globally
unique.

The lock mirrors each package's configured `cabal2nixOptions` value. Do not add fields to
either JSON file without increasing the schema version and updating the Nix validator and
refresh tool together. Unknown fields are rejected deliberately.

## Add a first-party family

A family is exactly one GitHub repository behind one `<family>-src` input, so repositories
that release together but live apart are onboarded as separate families. The repository
either holds a single package at its root or one package per top-level directory.

Adding a family requires a source input before the updater can generate its package records:

1. Register the repository with Mori and verify its qualified name with
   `mori registry show OWNER/PROJECT --full`.
2. Add a `flake = false` input named `<family>-src` to `flake.nix`.
3. Add the matching sorted family record to `config/first-party-families.json`.
4. Run `nix flake lock` to add the input node, then create a temporary local commit containing
   `flake.nix`, `flake.lock`, and the family config. The updater needs that clean managed-file
   baseline even though strict Nix evaluation will reject the temporary config/lock mismatch.
5. Preview and apply the refresh. Refresh accepts a package lock that is temporarily missing
   the new configured family, but the written lock and all normal checks require exact
   catalog/lock equality.
6. Stage the generated package lock and amend the temporary baseline commit before sharing
   it. The retained commit must contain the input, config, and generated family together so
   every published commit evaluates successfully.

```bash
nix run .#haskell-nix-update -- refresh --family FAMILY --dry-run
nix run .#haskell-nix-update -- refresh --family FAMILY
nix run .#haskell-nix-update -- check --family FAMILY --online
```

Review the new package paths, versions, publication state, and hashes before activating the
family in a consumer. Do not hand-create its generated lock records or add parallel entries
to `overlays/registry.nix`.

## Refresh and verification

To see which families are behind before changing anything, survey them:

```bash
just status                 # every configured family
just status FAMILY [...]    # narrow to named families
```

The survey writes nothing. It runs one `refresh --dry-run` per family and tags each result by
the kind of drift found: `git-commit` when the family's GitHub head moved, `hackage-release`
when a package has a new or changed published release, and `source-version`, `membership`,
`hackage-withdrawn`, or `hackage-rehash` for the remaining cases. A family tagged only
`git-commit` has unreleased commits; a family tagged only `hackage-release` published without
a source change reaching the locked head.

Per-family dry runs keep a transient GitHub or Hackage failure to a single `query-failed` row
rather than aborting the survey the way one all-family dry run would. Each family is retried
once before it is reported as failed, and those rows are safe to rerun.

`haskell-nix-update` is the only production writer for
`packages/first-party-lock.json`. Preview all configured families, apply the refresh, and
then perform an online drift check with:

```bash
nix run .#haskell-nix-update -- refresh --dry-run
nix run .#haskell-nix-update -- refresh
nix run .#haskell-nix-update -- check --online
```

Pass `--family FAMILY` once per distinct family to limit either subcommand. Without that
option, every configured family is processed. Unknown family names and duplicate values are
rejected before work begins.

`refresh --dry-run` reads remote Git heads, Cabal package metadata, and Hackage releases and
prefetches proposed archives, but it does not change either managed lock file. A normal
refresh refuses to begin when `flake.lock` or `packages/first-party-lock.json` already has
uncommitted changes. It updates only inputs whose remote head moved, writes the generated
lock atomically, and runs the flake validation. Any failure after input updates restores
both managed files byte-for-byte. The command never commits or pushes.

The normal `refresh` invocation is the single production update command. The dry-run is a
review aid, not an alternate writer, and a successful refresh preserves non-selected
families when `--family` limits the operation.

`check` is network-free. It validates both JSON contracts, verifies each package-lock
revision against `flake.lock`, locates the registered checkout through Mori, requires the
Git object to exist locally, and reparses the root Cabal packages. `check --online` also
compares remote heads and current Hackage publication/version state, while still making no
writes.

Schema and channel behavior can also be checked directly:

```bash
jq empty config/first-party-families.json packages/first-party-lock.json
nix eval --json .#lib.registries.hackage --apply builtins.attrNames
nix eval --json .#lib.registries.github --apply builtins.attrNames
nix flake check --print-build-logs
```

The flake check rejects malformed fixtures, runs the updater's offline unit and workflow
tests, proves that unpublished packages are omitted only from the Hackage registry, applies
a local GitHub package under `ghc9122` and `ghc914`, and evaluates both channel overlays.

It does not compile the complete first-party inventory. For package membership or shared
compatibility changes, build both GHC 9.12.2 matrices from the repository root.

GitHub builds every locked package:

```bash
nix build --no-link --keep-going --print-build-logs --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ flake.overlays.github ];
    };
    lock = builtins.fromJSON (builtins.readFile ./packages/first-party-lock.json);
    names = builtins.concatMap
      (family: map (package: package.name) family.packages)
      lock.families;
  in
  map (name: pkgs.haskell.packages.ghc9122.${name}) names
'
```

Hackage builds only published records:

```bash
nix build --no-link --keep-going --print-build-logs --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ flake.overlays.hackage ];
    };
    lock = builtins.fromJSON (builtins.readFile ./packages/first-party-lock.json);
    packages = builtins.concatMap (family: family.packages) lock.families;
    names = map (package: package.name)
      (builtins.filter (package: package.hackage != null) packages);
  in
  map (name: pkgs.haskell.packages.ghc9122.${name}) names
'
```

## Review checklist

Before committing a refresh:

1. Confirm `flake.lock` changed only the intended `<family>-src` input nodes.
2. Review every generated family revision, package path, GitHub version, Hackage version,
   and archive hash. A package with no official release must retain `"hackage": null`.
3. Confirm the generated file still has sorted families, sorted globally unique package
   names, and only documented per-package Cabal2nix options.
4. Run a second `refresh --dry-run`; it must report `No changes.`
5. Run `check --online` and `nix flake check --print-build-logs`.
6. Update the snapshot counts and GitHub-only names in `docs/user/channels.md` when package
   membership or publication state changes.

For changes that alter package membership or compatibility, build both complete GHC 9.12.2
channel matrices before merging. GitHub must build every locked package; Hackage must build
only records whose `hackage` field is non-null.

## Validate from a downstream consumer

An unpushed checkout can be tested without changing a consumer lock:

```bash
nix build --override-input haskell-nix path:/path/to/local/haskell-nix
nix develop --override-input haskell-nix path:/path/to/local/haskell-nix
```

Run the consumer's normal target with its GitHub selection and, when supported by that
consumer, its Hackage selection. The override changes only where the `haskell-nix` flake is
loaded from; channel selection remains explicit in the consumer's `flake.nix`.

See [Troubleshooting](troubleshooting.md) for dirty managed files, missing Mori revisions,
transient online failures, unbuilt cabal2nix derivations, and the difference between flake
evaluation checks and complete package builds.
