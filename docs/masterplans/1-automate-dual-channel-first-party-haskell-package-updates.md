---
id: 1
slug: automate-dual-channel-first-party-haskell-package-updates
title: "Automate dual-channel first-party Haskell package updates"
kind: master-plan
created_at: 2026-07-15T17:12:50Z
intention: intention_01kv1bq794e62tthz1rj47dqrx
---

# Automate dual-channel first-party Haskell package updates

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Vision & Scope

After this initiative, `haskell-nix` exposes two reproducible first-party package channels.
The Hackage channel builds the latest published release of every catalogued package. The
GitHub channel builds every package from a family-wide source revision locked in
`flake.lock`, including packages that have not been published. Consumers select
`lib.haskellExtensions.hackage` or `lib.haskellExtensions.github` and the corresponding
overlay; the existing singular `lib.haskellExtension`, `lib.registry`, and
`overlays.default` remain compatibility aliases for the GitHub channel.

A maintainer refreshes all families with one Haskell command instead of editing dozens of
revision, hash, version, package-path, and registry entries. The command uses Mori's JSON
registry to locate the registered source repositories, advances named non-flake GitHub
inputs, discovers one-directory-deep Cabal packages at the locked revisions, checks the
official Hackage package metadata, prefetches Hackage archives, and atomically updates a
generated package lock. A deterministic check mode and Nix flake checks catch drift.

The initial onboarding covers pg-migrate, Keiro, Kiroku, the main Shibuya monorepo,
pgmq-hs, Shikumi, and Baikai. Research on 2026-07-15 found 51 packages: 41 have Hackage
releases whose latest versions match the current GitHub `master` Cabal versions, while 10
are currently GitHub-only. The initiative excludes separate Shibuya adapter repositories,
changes to upstream Haskell APIs or databases, automatic publishing to Hackage, edits to
downstream consumers, and automatic commits or pushes.


## Decomposition Strategy

The work is divided by functional concern into a Nix architecture plan, a Haskell tooling
plan, and an onboarding/integration plan. The first child defines the hand-authored family
catalog, generated lock schema, generic registry constructors, source-input plumbing, and
public channel interfaces. That contract must exist before tooling can safely write data.
The second child builds and tests the updater against that contract. The third child uses
both completed artifacts to onboard the seven real families, replace the current manual
pins, and perform the expensive package-set validation.

A single ExecPlan was rejected because it combined a public Nix API change, a new Haskell
program, and a 51-package migration into one document with too many integration points.
Keeping per-package Nix modules was rejected because it preserves the duplication that
makes updates difficult. A TypeScript generator was considered because Bun already runs
the planning initializers, but the user requested a Haskell helper and maintains explicit
Haskell conventions. Querying Hackage or GitHub during Nix evaluation was rejected because
it would make evaluation impure and non-reproducible; network discovery occurs only in the
explicit refresh command, and committed lock files drive builds.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 1 | Introduce manifest-driven Hackage and GitHub channels | docs/plans/1-introduce-manifest-driven-hackage-and-github-channels.md | None | None | Complete |
| 2 | Build the Haskell package refresh CLI | docs/plans/2-build-the-haskell-package-refresh-cli.md | EP-1 | None | Complete |
| 3 | Onboard and validate first-party package families | docs/plans/3-onboard-and-validate-first-party-package-families.md | EP-1, EP-2 | None | In Progress |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).


## Dependency Graph

EP-1 must complete first because it owns the JSON schemas, Nix constructors, source naming
convention, and public channel interface. EP-2 is a hard dependent: its Haskell data types,
rendering rules, and validation behavior must match those schemas exactly. EP-3 depends on
both earlier plans because the onboarding must be produced by the real updater and consumed
by the real registry implementation; manually preparing the final lock first would fail to
prove future updates are repeatable.

The default implementation order is therefore linear:

```text
EP-1 (channel foundation) -> EP-2 (refresh CLI) -> EP-3 (family onboarding and builds)
```

Research and test-fixture preparation for EP-2 can begin while EP-1 is in progress, but no
EP-2 production code should be committed against an assumed schema. Similarly, EP-3 source
inventory research is already recorded in its plan, but activation waits for both hard
dependencies.


## Integration Points

EP-1 owns `config/first-party-families.json`, the small hand-authored catalog of family
identity, Mori qualified name, GitHub input name, and exceptional Cabal options. EP-2 must
decode and validate it without adding undocumented fields. EP-3 adds the seven production
family records using that schema.

EP-1 also owns the schema of `packages/first-party-lock.json`. It records the schema
version, each family's locked GitHub revision, discovered package name and source-relative
path, Cabal version, Cabal2nix options, and an optional Hackage `{ version, hash }` pin. EP-2
is the only production writer. EP-3 reviews and commits the generated data. Nix reads the
file with `builtins.fromJSON`; no generated Nix source is needed.

EP-1 defines `lib/mkFirstPartyRegistries.nix`, which transforms the lock plus a source
attribute set into `github` and `hackage` registries having the same record shape as
`overlays/registry.nix`. EP-3 composes those registries with the unchanged compatibility
registry. EP-2 may import the schemas for fixtures but must not duplicate registry logic.

EP-1 defines seven `flake = false` input naming rules using `<family>-src` keys and changes
`overlays/haskell-overlay.nix` to accept a registry argument. EP-2 invokes
`nix flake update <input>` and reads `flake.lock`; EP-3 adds the concrete inputs and confirms
the generated lock revisions agree with the Nix lock.

EP-1 owns the public outputs `lib.haskellExtensions.{hackage,github}`,
`lib.registries.{hackage,github}`, and `overlays.{hackage,github}` plus backward-compatible
singular aliases. EP-3 documents and exercises them from a consumer-shaped Nix expression.

EP-2 owns the Haskell package under `cli/haskell-nix-update/` and the executable contract
`haskell-nix-update refresh|check`. It must follow the standards in
`/Users/shinzui/Keikaku/bokuno/haskell-jitsurei`, especially GHC 9.12+, GHC2024, the common
extensions, postpositive qualified imports, and the optparse-applicative option-group
pattern. EP-3 consumes the executable through `nix run .#haskell-nix-update`.


## Progress

- [x] EP-1: Define and fixture-test the family catalog and generated package-lock schemas.
- [x] EP-1: Implement generic Hackage/GitHub registries and backward-compatible channel outputs.
- [x] EP-1: Add deterministic Nix evaluation checks and channel documentation.
- [x] EP-2: Scaffold the standards-compliant Haskell library, executable, tests, and Nix app.
- [x] EP-2: Implement Mori, Git, Hackage, Nix-lock, discovery, and atomic-write adapters.
- [x] EP-2: Implement refresh/check workflows with dry-run behavior and fixture/integration tests.
- [x] EP-3: Add the seven source inputs and production family catalog, then run the updater.
- [ ] EP-3: Activate both channels and remove superseded handwritten family patches.
- [ ] EP-3: Resolve both compiler sets, build the package matrices, and finalize consumer docs.


## Surprises & Discoveries

- EP-1 made JSON validation eager so `builtins.tryEval` rejects malformed manifests before
  a registry attribute is forced. It also requires every generated `cabal2nixOptions`
  value to mirror the config override or its empty default. EP-2 must preserve this exact
  rendering invariant when it becomes the production lock writer.

- The direct extension's compatibility signature is
  `HaskellLib -> Pkgs -> HaskellExtension`, not the one-argument constructor shown in the
  old user docs. EP-1 preserved the actual API and corrected the documentation. EP-3's
  consumer-shaped validation already describes the correct two-argument application.

- Function-valued Nix outputs cannot be proven equivalent with `==`, even when they are
  direct aliases. EP-1 validates the legacy extension behavior by applying it and comparing
  the produced package names. EP-3 should use the same behavioral strategy for final
  compatibility acceptance.

- EP-2's one-directory-deep discovery reads `.cabal` files through Git object commands but
  deliberately records their parent directories. This matches EP-1's GitHub registry,
  which appends the lock path to the family source and passes that directory to Cabal2nix.

- The pinned Nixpkgs has optparse-applicative 0.18.1.0, so EP-2 privately overrides it with
  the repository's audited 0.19 expression to obtain `parserOptionGroup`. The updater still
  uses the plain Nixpkgs GHC 9.12.2 set and does not depend on either generated channel.

- EP-3 found that exact catalog/lock equality made the first refresh from an empty generated
  lock impossible. The refresh decoder now permits a sorted subset and the planner adds new
  observed families, while `check`, final planning validation, and Nix registry construction
  remain exact. The source-input baseline and generated lock will therefore land in one
  retained working commit after a temporary clean baseline satisfies dirty-file protection.

- Mori has no GitHub repository metadata for Baikai, Keiro, or Shikumi, although it does
  provide their registered local paths. The updater now accepts an empty repository list and
  uses the catalog slug for remote operations, but still rejects conflicting non-empty Mori
  metadata. Live Hackage metadata also uses direct string statuses, so the decoder accepts
  both that shape and the object-shaped test fixtures.


## Decision Log

- Decision: Use three child ExecPlans ordered foundation, updater, then onboarding.
  Rationale: Each produces independently verifiable behavior, while the hard dependencies
  prevent the CLI and migration from inventing competing schemas.
  Date: 2026-07-15

- Decision: Expose separate Hackage and GitHub channels, with existing singular outputs
  remaining aliases for GitHub.
  Rationale: One Haskell package-set attribute cannot represent both sources simultaneously.
  Separate channels make provenance selectable, while the alias preserves current consumers
  that already rely on GitHub-only Keiro, Kiroku, and Shibuya packages.
  Date: 2026-07-15

- Decision: Store family policy in `config/first-party-families.json` and generated package
  state in `packages/first-party-lock.json`.
  Rationale: Separating stable human intent from volatile revisions, versions, paths, and
  hashes makes reviews clear and prevents hand edits to generated state.
  Date: 2026-07-15

- Decision: Lock GitHub repositories as named `flake = false` inputs.
  Rationale: Nix then owns immutable revisions and content hashes in `flake.lock`; updating a
  family uses the supported `nix flake update <input>` workflow instead of manually editing
  `fetchFromGitHub` hashes.
  Date: 2026-07-15

- Decision: Build the updater in Haskell and treat
  `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei` as normative.
  Rationale: This follows the user's explicit preference and gives the repository a typed,
  tested parser for Mori, Hackage, and Nix JSON rather than shell pipelines.
  Date: 2026-07-15

- Decision: Discover only Cabal packages exactly one directory below each registered
  repository root, with explicit per-package overrides in the catalog.
  Rationale: All 51 requested packages use that layout. It includes benchmarks, examples,
  smoke packages, and test support while excluding nested fixtures and
  `pg-migrate/examples/basic` without a long handwritten include list.
  Date: 2026-07-15

- Decision: Keep all online discovery outside Nix evaluation.
  Rationale: The refresh command may query Mori, GitHub remotes, and Hackage, but committed
  `flake.lock` and package-lock data must be sufficient for deterministic evaluation and
  building.
  Date: 2026-07-15

- Decision: Preserve exact package-lock validation at steady state while allowing refresh to
  bootstrap newly configured families from a subset lock.
  Rationale: This breaks the catalog/lock onboarding cycle without weakening successful
  refresh output, offline/online checks, or Nix evaluation.
  Date: 2026-07-15


## Outcomes & Retrospective

EP-1 and EP-2 completed on 2026-07-15. The reproducible channel foundation, strict JSON
contracts, public outputs, and compatibility aliases are now paired with a tested Haskell
refresh/check CLI. Its 32 offline tests cover adapters, deterministic planning, dry-run,
partial updates, no-change behavior, dirty-file refusal, failures, and byte-for-byte
rollback. EP-3 is dependency-ready and is the only remaining child; initiative-level
outcomes will be finalized after the seven-family onboarding and package builds complete.


## Revision Note

2026-07-15: Marked EP-1 complete, recorded its schema and compatibility discoveries for
dependent plans, and identified EP-2 as the next dependency-ready work stream.

2026-07-15: Began EP-2 after verifying EP-1 complete. The refresh CLI now owns the active
implementation slot; EP-3 remains blocked until this plan finishes.

2026-07-15: Completed EP-2 after its packaged build, 32-test offline suite, grouped CLI
help, real empty-catalog check, development-shell Cabal test, and full flake check passed.
EP-3 is now dependency-ready and awaits explicit continuation.

2026-07-15: Began EP-3 after verifying EP-1 and EP-2 complete. The seven-family onboarding,
dual-channel activation, package-matrix validation, and final consumer documentation now
own the active implementation slot.

2026-07-15: EP-3's first production dry-run found and repaired bootstrap validation, missing
Mori GitHub metadata, and live Hackage JSON shape assumptions. All 37 offline updater tests
and the 51-package online dry-run now pass; production lock generation is next.

2026-07-15: Generated and audited the production lock after the updater proved rollback on
a transient Hackage response failure. The lock contains 7 families, 51 GitHub packages, 41
Hackage pins, 10 GitHub-only packages, exact flake revisions, and no dry-run drift. Channel
activation and retirement of handwritten family pins are next.
