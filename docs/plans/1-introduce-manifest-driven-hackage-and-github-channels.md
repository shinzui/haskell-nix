---
id: 1
slug: introduce-manifest-driven-hackage-and-github-channels
title: "Introduce manifest-driven Hackage and GitHub channels"
kind: exec-plan
created_at: 2026-07-15T17:12:57Z
intention: intention_01kv1bq794e62tthz1rj47dqrx
master_plan: "docs/masterplans/1-automate-dual-channel-first-party-haskell-package-updates.md"
---

# Introduce manifest-driven Hackage and GitHub channels

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan creates the reproducible Nix foundation for two first-party package channels. A
consumer can explicitly select a Hackage registry or a GitHub-source registry, while current
users of `lib.haskellExtension`, `lib.registry`, and `overlays.default` keep working through
GitHub-channel compatibility aliases. Package metadata comes from JSON rather than one Nix
entry and patch file per package.

At completion, a checked-in fixture proves that the same package catalog can generate a
Hackage replacement and a source-tree replacement, `nix flake check` validates both
registries under `ghc9122` and `ghc914`, and the public flake output names are stable for the
updater and onboarding plans that follow.


## Progress

- [ ] Add versioned family-config and generated package-lock schemas with valid and invalid fixtures.
- [ ] Implement `lib/mkFirstPartyRegistries.nix` and verify GitHub/Hackage registry shape from fixtures.
- [ ] Parameterize `overlays/haskell-overlay.nix` by registry and expose both channel outputs.
- [ ] Preserve singular GitHub compatibility aliases and existing registry behavior.
- [ ] Add channel evaluation checks, update user documentation, and run final validation.


## Surprises & Discoveries

(None yet.)


## Decision Log

- Decision: Use JSON for both schemas and read it with `builtins.fromJSON`.
  Rationale: Haskell and Nix can share the same versioned contract without generated Nix
  syntax or a new parser dependency.
  Date: 2026-07-15

- Decision: Keep human policy and generated state in separate files.
  Rationale: `config/first-party-families.json` changes only when a family or exception
  changes; `packages/first-party-lock.json` is rewritten by the updater whenever revisions
  or Hackage releases move.
  Date: 2026-07-15

- Decision: Keep singular public outputs as aliases for the GitHub channel.
  Rationale: The current registry already sources important first-party packages from
  GitHub, so changing existing consumers to Hackage would be a silent compatibility break.
  Date: 2026-07-15

- Decision: Represent Cabal2nix options as one string, empty when unused.
  Rationale: Existing special handling is already expressed as `"-f-example"`; a string maps
  directly to `callCabal2nixWithOptions` and avoids underspecified shell-argument joining.
  Date: 2026-07-15


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

This repository is a Nix flake. `flake.nix` imports `overlays/registry.nix`, converts each
registry record into a Haskell package-set extension through
`lib/fixPackageByVersion.nix`, and exposes one Haskell extension and one overlay.
`lib/mkHaskellOverlay.nix` applies a supplied registry to Nixpkgs' `ghc9122` and `ghc914`
sets. `overlays/haskell-overlay.nix` currently imports the registry internally, which means
it cannot be reused for two different channels. A registry maps a Cabal package name to a
list of records. The first-party records use `{ always = true; patch = <function>; }`, so
they can introduce packages absent from Nixpkgs without forcing a previous package version.

The repository presently mixes ordinary compatibility patches, Hackage tarball pins, and
GitHub monorepo pins in `overlays/registry.nix`. This plan introduces generic first-party
registries without removing those existing family entries; the final migration belongs to
`docs/plans/3-onboard-and-validate-first-party-package-families.md`. The Haskell writer is
specified separately in `docs/plans/2-build-the-haskell-package-refresh-cli.md` and is a hard
dependent of this schema.

Create `config/first-party-families.json` for hand-authored family policy. Its top-level
shape is:

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

`name`, `moriProject`, `github`, and `githubInput` are required non-empty strings and family
names and input names must be unique. `github` is exactly `owner/repository`.
`packageOverrides` defaults to an empty object. Each override key must name a discovered
package and currently supports only `cabal2nixOptions`, a string that defaults to empty.
The production file may start with an empty `families` array in this plan; EP-3 populates it.

Create `packages/first-party-lock.json` as generated state. Its shape is:

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
        },
        {
          "name": "example-dev",
          "path": "example-dev",
          "version": "0.1.0.0",
          "cabal2nixOptions": "",
          "hackage": null
        }
      ]
    }
  ]
}
```

The lock family names and input names must match the config. `githubRev` is a 40-character
Git commit recorded in `flake.lock`. Package names are globally unique, `path` is a clean
relative path with no `..`, and versions contain dot-separated non-negative integers.
Packages are sorted by name within families; families are sorted by name. A non-null
Hackage pin contains the latest official Hackage version at refresh time and the SRI hash
of the unpacked release tarball. The GitHub version and Hackage version may differ; each
channel reports the version of its own source.


## Plan of Work

### Milestone 1: Define schemas and generic registry construction

Add the two production JSON files with empty family arrays and add fixture files under
`checks/fixtures/first-party/` containing one published package, one unpublished package,
one package with Cabal2nix options, and invalid examples for duplicate names, absolute or
parent-traversing paths, unknown override keys, mismatched family/input names, and malformed
versions and hashes.

Add `lib/mkFirstPartyRegistries.nix`. It accepts `{ sources, config, lock }`, validates all
cross-file invariants before constructing patches, and returns `{ github, hackage }`.
GitHub contains every locked package and selects `sources.${githubInput} + "/${path}"`.
Hackage contains only packages whose `hackage` field is non-null and uses
`hself.callHackageDirect`. Both paths wrap results with
`haskellLib.dontCheck (haskellLib.doJailbreak ...)`. GitHub calls `callCabal2nix` for an
empty option string and `callCabal2nixWithOptions` otherwise. Do not perform network access
or inspect `flake.lock` inside this function.

Add an evaluation-only test expression under `checks/first-party-registry.nix` that imports
valid fixtures with a local fixture source and asserts the exact attribute names in both
channels. Invalid fixtures must be evaluated through `builtins.tryEval` and rejected. A
small source fixture with a valid `.cabal` file proves that applying the GitHub patch yields
the expected version.

### Milestone 2: Expose selectable channels without breaking consumers

Change `overlays/haskell-overlay.nix` from `{ lib }:` to `{ lib, registry }:` and remove its
internal import of `overlays/registry.nix`. In `flake.nix`, parse the production JSON files,
construct an empty source map for the initial empty catalog, call
`lib/mkFirstPartyRegistries.nix`, and compose each generated channel on top of the existing
common registry with the channel winning on duplicate names.

Expose `lib.registries.hackage`, `lib.registries.github`,
`lib.haskellExtensions.hackage`, `lib.haskellExtensions.github`,
`overlays.hackage`, and `overlays.github`. Keep `lib.registry`,
`lib.haskellExtension`, `overlays.default`, and `overlays.haskell` as exact aliases of the
GitHub counterparts. Refactor the repeated registry-to-extension logic into a local function
so the channel outputs cannot drift. Existing `nix flake check` must still pass before any
production family is migrated.

### Milestone 3: Make the contract observable and documented

Add flake checks that validate both production registries and run the fixture assertions for
the current system. Extend `README.md`, `docs/user/getting-started.md`, and
`docs/user/consumer-integration.md` with explicit Hackage/GitHub selection examples and the
compatibility-alias guarantee. Add `docs/user/updating-first-party-packages.md` describing
the two JSON files as contracts while deferring the refresh command to EP-2.

The milestone is complete when `nix flake check` passes, `nix eval` shows both channel
outputs, the invalid fixtures are rejected, and the legacy output names evaluate equal to
their GitHub aliases.


## Concrete Steps

Run from `/Users/shinzui/Keikaku/bokuno/haskell-nix`. Start with `mori show --full` and
`git status --short --branch`; preserve unrelated changes. Create and edit files with
patches, then parse every Nix and JSON artifact:

```bash
jq empty config/first-party-families.json packages/first-party-lock.json
nix-instantiate --parse lib/mkFirstPartyRegistries.nix >/dev/null
nix-instantiate --parse checks/first-party-registry.nix >/dev/null
```

After Milestone 1, run the focused fixture expression described by the new check and record
the observed GitHub and Hackage attribute lists in Progress. Commit a working state with:

```text
feat(registry): add first-party channel schemas

MasterPlan: docs/masterplans/1-automate-dual-channel-first-party-haskell-package-updates.md
ExecPlan: docs/plans/1-introduce-manifest-driven-hackage-and-github-channels.md
```

After wiring the flake outputs, inspect them and run all checks:

```bash
nix flake show
nix eval --json .#lib.registries.hackage --apply builtins.attrNames
nix eval --json .#lib.registries.github --apply builtins.attrNames
nix flake check --print-build-logs
git diff --check
```

With the initial empty production catalog, both generated first-party lists are empty but
the composed registries still contain all common compatibility entries. `nix flake show`
must display `overlays.hackage` and `overlays.github`. Commit the channel plumbing and final
documentation in working increments using Conventional Commit subjects and both trailers.


## Validation and Acceptance

`nix flake check` must exit zero. The fixture check must prove that the GitHub registry
contains the published, unpublished, and special-option packages, while the Hackage registry
omits only the unpublished package. Applying the fixture GitHub patch under both `ghc9122`
and `ghc914` must expose the version declared by its local Cabal file. Each invalid fixture
must fail validation before it can construct a patch.

The public output acceptance is behavioral: a consumer-shaped expression using
`lib.haskellExtensions.hackage` evaluates, the same expression with `.github` evaluates,
and the old singular expression still evaluates without source changes. Evaluating
`lib.registry == lib.registries.github` and the corresponding extension/overlay aliases
must return true where Nix permits direct equality, or an exact attribute-name comparison
must prove equivalence where functions cannot be compared.


## Idempotence and Recovery

Parsing, evaluation, and checks are safe to repeat. This plan adds no online update process
and writes no external repository. Keep the current `overlays/registry.nix` entries active
until EP-3 so reverting channel plumbing does not lose packages. If a schema change becomes
necessary during implementation, update both fixture sets, all validation code, the
Decision Log, and EP-2's documented Haskell types before committing. Never accept unknown
JSON fields silently; version the schema instead.


## Interfaces and Dependencies

`lib/mkFirstPartyRegistries.nix` must have this conceptual interface:

```text
mkFirstPartyRegistries :
  { sources : AttrSet Path, config : FamilyConfig, lock : PackageLock }
  -> { github : Registry, hackage : Registry }
```

`Registry` is the existing `package-name -> [PatchRecord]` attribute set, and a patch
function retains the existing input contract
`{ pkg, lib, haskellLib, pkgs, hself, hsuper } -> Derivation`.
`config/first-party-families.json` and `packages/first-party-lock.json` are the shared
interfaces with EP-2 and EP-3. EP-1 owns their schema. EP-2 may not change it without first
updating this plan and the master plan. EP-3 owns production records only after both hard
dependencies complete.

The only external Nix APIs used here are `builtins.fromJSON`, `builtins.readFile`,
`hself.callCabal2nix`, `hself.callCabal2nixWithOptions`, and
`hself.callHackageDirect`, all already represented in this repository. No Haskell code or
source dependency is added in this child plan.
