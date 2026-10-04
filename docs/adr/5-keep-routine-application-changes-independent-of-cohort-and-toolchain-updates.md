# Keep routine application changes independent of cohort and toolchain updates

Status: Accepted for implementation; reuse and timing measurements are pending.

Date: 2026-10-04

## Context

MasterPlan 3 aligns the Cabal and Nix dependency versions used by the Rei family. The
practical goal is to reduce the time spent coordinating changes and rebuilding dependencies.
Version equality alone cannot establish that outcome. ADR 1 requires equal transitive build
inputs for cache reuse. Different sources, Cabal metadata revisions, flags, patches, compilers,
platforms or dependency derivations can produce different builds of the same version.

The [cache research](../research/ci-cache-reuse-and-buck2-after-mp3.md) identifies two further
limits: a changed Haskell package still recompiles under Nix, and successful local builds
do not establish that fresh CI workers can substitute their outputs. Runtime output closures
can also omit statically linked Haskell libraries, so they cannot prove dependency alignment.

## Decision

Treat application updates, dependency updates and toolchain updates as distinct operations.
An application update retains the channel, cohort, compiler, nixpkgs and toolchain pins.
Dependencies with unchanged transitive inputs retain their derivation and output identities.
Package source boundaries include all required build inputs and exclude unrelated sibling
sources and documentation. Git revision stamps affect only the outputs that use them.

A targeted dependency update starts with the previous freeze and holds unrelated versions
fixed. Report conflicts and the transitive unlocks required to solve them before widening
the update. Produce an impact report covering source, metadata and policy changes as well
as versions, with reverse dependency paths to affected application components. Keep broad
cohort refresh and compiler/toolchain refresh explicit. Upgrade-only remains in force.

Establish version parity from fresh Cabal plans for the supported test/benchmark/flag
configurations and from structured Nix manifests tied to the actual executable derivation.
The manifests identify package roles, versions, sources, metadata revisions, flags, policy,
derivation paths and output paths, together with the system and compiler. Verify dependency
edges using Nix metadata APIs. An arbitrary channel scope or an empty runtime closure is
insufficient evidence. Declare intentional source/flag exceptions with a reason and owner;
do not disguise them as version parity. Keep exact-binary release rehearsals.

The shared updater owns the cohort model, parser and targeted-update report. The generation
work owns manifest construction, comparison and recursive flake-lock resolution. Consumers
call those interfaces. Dotfiles orchestrates them without duplicating parsers. Recursive
`follows` paths must resolve to locked nodes, including application-to-library input paths.

Publish shared dependency outputs to the existing trusted binary cache before adoption.
Prove substitution on fresh CI workers for aarch64-darwin and x86_64-linux. At integration,
measure repeated builds, documentation edits, application leaf edits, shared-library edits,
targeted dependency upgrades and deliberate base upgrades. Separate evaluation, downloads,
dependency compilation, application compilation/linking and tests. An application-only edit
must incur zero avoidable shared dependency compilations. Record residual bottlenecks and
elapsed times before making any speedup claim.

Preserve the user's advisory fleet guard: differing application channel revisions and shared
build identities warn, so a single-application hotfix remains possible. A mismatch against
an application's own freeze or missing/unverifiable build evidence fails. Initial alignment
acceptance separately requires equal identities where shared inputs are intended to match.

## Alternatives and consequences

Version checks alone are cheaper to implement but can declare success while duplicate builds
and cold CI dependency compilation persist. A strict fleet-wide revision guard would couple
hotfixes to all applications and was already rejected by the user. This decision strengthens
the evidence for parity and reuse without adopting that coupling.

This does not promise module-level incremental Nix builds or interchangeability of Cabal and
Nix compiled artifacts. Application package compilation may remain the main cost after cache
reuse is fixed. Consider any further build-system work only after the measurements identify
that bottleneck. Keep existing immutable first-party snapshot/cache-identity checks passing.

## Validation

MasterPlan 3 assigns targeted update and impact reporting to plan 8; manifests, lock resolution,
comparison and cache publication to plan 9; consumer adoption and source boundaries to plans
11–13; and integration measurements to plan 14. Synthetic fixtures must reject missing static
dependencies, wrong and correct instances of one package together, invalid/cyclic `follows`,
stale Cabal imports and source metadata drift at unchanged versions. Positive experiments
must preserve unchanged dependencies and show actual remote substitution. All implementation
and timing evidence remains pending.
