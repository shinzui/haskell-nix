# User guide

Use this guide to consume the flake, choose a first-party source channel, or maintain the
shared package definitions. The consumer path needs only the first three pages; the
maintainer pages describe repository changes and validation.

## Choose a guide

| Goal | Guide |
|------|-------|
| Add `haskell-nix` to a project | [Getting started](getting-started.md) |
| Select independent first-party release lines | [Package sets](package-sets.md) |
| Compare GitHub and Hackage package sources | [Channel reference](channels.md) |
| Compose the selected channel with local Haskell overrides | [Consumer integration](consumer-integration.md) |
| Add or change a shared compatibility patch | [Adding patches](adding-patches.md) |
| Refresh or onboard first-party package families | [Updating first-party packages](updating-first-party-packages.md) |
| Format Nix, run fast contract tests, and diagnose derivation changes | [Maintainer tools](maintainer-tools.md) |
| Diagnose integration, refresh, or validation failures | [Troubleshooting](troubleshooting.md) |

## Public surface

New consumers should choose an explicit package set and channel with
`lib.mkFirstPartyPackageSet`. The legacy default shortcuts remain available:

```text
lib.haskellExtensions.github
lib.haskellExtensions.hackage
overlays.github
overlays.hackage
```

The direct Haskell extension is recommended when a consumer also has local Haskell
overrides. The Nixpkgs overlay is convenient when the consumer does not override the same
Haskell package set again. The flake exports outputs for `x86_64-linux` and
`aarch64-darwin`. The deployment test cluster currently has only amd64 Linux nodes, while
haskell-nix-dev's nixpkgs dropped `x86_64-darwin`; its channel overlays and checks target the
`ghc9124` and `ghc9141` package sets.

The current default package set contains 78 packages in the GitHub channel and 68 published
packages in the Hackage channel. Ten unpublished packages are intentionally GitHub-only.
See the [channel reference](channels.md) for the family breakdown and commands that read the
current lock instead of relying on these snapshot counts.

## Consumer and maintainer boundaries

Consumers update only their `haskell-nix` flake input and select a package set and channel.
They do not edit the generated package lock or copy entries from this repository.

Maintainers use two separate sources of truth:

- `overlays/registry.nix` contains shared compatibility patches used by both channels.
- `config/first-party-families.json` declares first-party families, while the updater owns
  immutable records in `packages/first-party-lock.json` and current tracking inputs in
  `flake.lock`.

Keeping those paths separate prevents a first-party source update from becoming a
handwritten compatibility pin.
