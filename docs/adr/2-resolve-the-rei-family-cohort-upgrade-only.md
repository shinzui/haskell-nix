# Resolve the Rei family cohort upgrade-only

Status: Accepted for implementation; published-cohort acceptance is pending.

Date: 2026-10-05

## Context

The Rei family currently records different Cabal and Nix dependency selections. Aligning
them must preserve versions already in use and make subsequent dependency changes explicit.
The selected first-party snapshots and the user's Effectful 2.7 requirement also constrain
the result. A successful application build alone cannot prove that another application's
dependencies have not been downgraded.

## Decision

Inventory contributor revisions and supported configurations explicitly, including local
packages and library, executable, test, benchmark and build-tool dependencies. Generate one
union stub from those declarations. Exclude contributor-owned packages and documented
dependencies vendored into consumers; preserve their provenance in the inventory.

For each released package, take the highest observed Hackage version across fresh contributor
plans, the recorded channel, deployed binaries, selected default first-party snapshots and
user policy floors. GHC boot packages follow the recorded compiler. A Git-only version does
not establish a Hackage floor. Retain exact source identities separately, including intentional
forks, rather than pretending that equal version strings imply equal sources.

Use distinct policy floors of Effectful 2.7.1.0 and effectful-core 2.7.1.1. Observed versions
can raise these floors further. Do not bridge either policy with allow-newer. Resolve a
conflict through an admitting release or a documented scoped exception for another package;
record the declared bound, compatibility evidence and retirement condition. Never silently
lower a floor or remove a capped dependency from the solve.

Write sorted version-only constraints with exactly one recorded index-state. Retain sources,
Cabal metadata, flags and dependency edges in the accompanying source manifest. Report every
missing or downgraded required package, policy target, consumer cap, selected first-party lag
and source pin. A freeze-only solve must reproduce the versions and manifest.

Routine targeted updates start from that freeze, unlock only requested package names and
hold unrelated versions exact. A conflict reports the need for explicit transitive unlocks
before changing the request. Retain the index-state, toolchain and contributor revisions.
Stage outputs, reject concurrent recorded-input changes and validate before promotion. Report
version, source, metadata, flag and policy changes with reverse paths to affected components.
An application update also retains the runtime projection unless explicitly updating runtime
dependencies, as specified by [ADR 7](7-compose-applications-on-retained-keiro-runtime-baselines.md).

The shared updater owns this model, parser and impact report. Nix generation and runtime
composition extend these interfaces. Broad cohort refresh remains an explicit operation.

## Alternatives and consequences

Taking the lowest common version would make alignment easier while regressing working
consumers. Independent application solves cannot establish one shared selection. A broad
update on every application change would repeatedly invalidate unrelated dependencies.

The union stub establishes a candidate selection; actual consumers still need to resolve and
compile with their supported flags and components. Version agreement alone does not establish
equal build inputs or cache reuse. [ADR 5](5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md)
defines the additional manifest, exact-binary and fresh-worker evidence.

## Validation

Plan 8 owns the inventories, freeze, report and targeted-update acceptance. Shared tests cover
maximum floors, excluded dependencies, Git-only sources, capped bounds, downgrade failures,
freeze normalization, unrelated-pin isolation, runtime ownership and transitive component
impact. The implementation checkpoint passes 81 updater tests.

Completion also requires a published-package solve, a zero-downgrade report, a deliberately
lowered-version negative report, a matching freeze-only plan, targeted-update conflict and
isolation experiments, and byte-identical regeneration. Those final experiments remain
pending. Plan 9 owns Nix generation and build/cache evidence; consumer adoption is separate.
