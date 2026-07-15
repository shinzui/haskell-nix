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

The production catalog is initially empty while the refresh command and family onboarding
are implemented. The follow-up updater provides the only production writer for
`packages/first-party-lock.json`; avoid hand-maintaining generated revisions, versions, or
hashes in parallel.

Schema and channel behavior are already deterministic and can be checked now:

```bash
jq empty config/first-party-families.json packages/first-party-lock.json
nix eval --json .#lib.registries.hackage --apply builtins.attrNames
nix eval --json .#lib.registries.github --apply builtins.attrNames
nix flake check --print-build-logs
```

The flake check rejects malformed fixtures, proves that unpublished packages are omitted
only from the Hackage registry, applies a local GitHub package under `ghc9122` and `ghc914`,
and evaluates both channel overlays.
