[User guide](README.md)

# Channel reference

`haskell-nix` exposes the same shared GHC compatibility patches through two first-party
source channels. A channel chooses where the catalogued first-party packages come from; it
does not remove the common compatibility registry.

## GitHub and Hackage

| Property | GitHub channel | Hackage channel |
|----------|----------------|-----------------|
| Extension | `lib.haskellExtensions.github` | `lib.haskellExtensions.hackage` |
| Overlay | `overlays.github` | `overlays.hackage` |
| First-party source | Family revision locked in `flake.lock` | Official release tarball pinned in `packages/first-party-lock.json` |
| Availability | Every discovered package | Only packages with a non-null `hackage` record |
| Package version | Cabal version at the locked Git revision | Latest published version recorded by the updater |
| Network during evaluation | None | None |

Choose GitHub when a consumer needs an unpublished package or must follow the family source
revision as a unit. Choose Hackage when the consumer needs published release provenance.
The two recorded versions can differ after an upstream source version changes but before a
release is published.

## Current inventory

The committed lock currently has this family breakdown:

| Family | GitHub | Hackage | GitHub-only |
|--------|-------:|--------:|------------:|
| Baikai | 7 | 6 | 1 |
| Keiki | 3 | 3 | 0 |
| Keiro | 7 | 5 | 2 |
| Kioku | 5 | 5 | 0 |
| Kiroku | 8 | 6 | 2 |
| okf | 2 | 2 | 0 |
| openapi-hs | 1 | 1 | 0 |
| pg-migrate | 6 | 6 | 0 |
| pgmq-hs | 6 | 5 | 1 |
| relay-pagination | 4 | 4 | 0 |
| servant-openapi-hs | 1 | 1 | 0 |
| Settei | 8 | 8 | 0 |
| Shibuya | 4 | 2 | 2 |
| Shikumi | 13 | 11 | 2 |
| **Total** | **75** | **65** | **10** |

The GitHub-only packages are:

```text
baikai-smoke
jitsurei
keiro-test-support
kiroku-jitsurei
kiroku-test-support
pgmq-bench
shibuya-core-bench
shibuya-example
shikumi-cli
shikumi-jitsurei
```

The lock is authoritative when this snapshot changes. Read its totals with:

```bash
jq '
  [.families[].packages[]] as $packages
  | {
      github: ($packages | length),
      hackage: ($packages | map(select(.hackage != null)) | length),
      githubOnly: ($packages | map(select(.hackage == null)) | length)
    }
' packages/first-party-lock.json
```

List the public package names in either generated registry with:

```bash
nix eval --json .#lib.registries.github --apply builtins.attrNames
nix eval --json .#lib.registries.hackage --apply builtins.attrNames
```

The registry outputs also contain common compatibility entries, so use the package lock
when counting only generated first-party packages.

## Composition and precedence

Each public channel registry is the common compatibility registry composed with one
generated first-party registry. If a generated first-party name overlaps a common entry,
the selected generated entry wins. This lets the updater own first-party provenance while
the handwritten registry continues to supply unrelated compatibility dependencies.

The Hackage extension may provide internal null placeholders for unpublished siblings
mentioned only by disabled test or benchmark components. Those placeholders are not public
Hackage registry entries and cannot be selected as Hackage packages.

Use the direct extension or overlay patterns in [Consumer integration](consumer-integration.md)
to apply a channel. A consumer selects exactly one first-party channel for a package set;
using both overlays on the same package set makes source precedence implicit and is not a
supported composition pattern.

## Compatibility aliases

Older consumers remain on GitHub provenance through these exact aliases:

```text
lib.haskellExtension  -> lib.haskellExtensions.github
lib.registry          -> lib.registries.github
overlays.default      -> overlays.github
overlays.haskell      -> overlays.github
```

New configuration should use the named channel so provenance is visible at the call site.
