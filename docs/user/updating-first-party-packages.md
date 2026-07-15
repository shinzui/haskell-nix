# Updating first-party packages

First-party package channels are driven by two versioned JSON files and the source
revisions in `flake.lock`. The split keeps stable maintainer intent separate from generated
package metadata. Nix reads only checked-in files, so evaluating a channel never contacts
GitHub, Hackage, or Mori.

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
      }
    }
  ]
}
```

`name`, `moriProject`, `github`, and `githubInput` are required non-empty strings.
`github` uses the exact `owner/repository` form. The input name is `<family-name>-src` and
must be unique. `packageOverrides` is optional; its keys name discovered Cabal packages,
and `cabal2nixOptions` is the only supported override field.

## Generated package lock

`packages/first-party-lock.json` records the selected revision and every Cabal package
found one directory below a family repository root:

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
relative paths without `.` or `..` segments. Versions contain dot-separated non-negative
integers. A package that has no official release uses `"hackage": null`; it appears only
in the GitHub channel. A published package records the latest Hackage version and its SRI
SHA-256 hash. Families and packages are sorted by name, and package names are globally
unique.

The lock mirrors each package's configured `cabal2nixOptions` value. Do not add fields to
either JSON file without increasing the schema version and updating the Nix validator and
refresh tool together. Unknown fields are rejected deliberately.

## Refresh and verification

`haskell-nix-update` is the only production writer for
`packages/first-party-lock.json`. Preview all configured families, apply the refresh, and
then perform an online drift check with:

```bash
nix run .#haskell-nix-update -- refresh --dry-run
nix run .#haskell-nix-update -- refresh
nix run .#haskell-nix-update -- check --online
```

Add a repeatable `--family FAMILY` option to either subcommand to limit its scope. Without
that option, every configured family is processed.

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

## Review checklist

Before committing a refresh:

1. Confirm `flake.lock` changed only the intended `<family>-src` input nodes.
2. Review every generated family revision, package path, GitHub version, Hackage version,
   and archive hash. A package with no official release must retain `"hackage": null`.
3. Confirm the generated file still has sorted families, sorted globally unique package
   names, and only documented per-package Cabal2nix options.
4. Run a second `refresh --dry-run`; it must report `No changes.`
5. Run `check --online` and `nix flake check --print-build-logs`.

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
