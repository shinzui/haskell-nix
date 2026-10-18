# Keep routine application changes independent of cohort and toolchain updates

Status: Accepted; Rei planning-prose source isolation is verified; wider reuse and changed-code timing gates remain pending.

Date: 2026-10-04

Revised: 2026-10-18

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

Audit source boundaries against every built Cabal component and compile-time file read.
Disabling tests does not make an entire test directory irrelevant: public support libraries
and installed utilities may still consume it. Exclude audited planning prose at its package
directory boundary, preserving Markdown embedded as help, prompts and templates. Filters must
also work when the checkout is reached through a symlink; uncanonicalized absolute-path
comparisons can silently include the intended exclusion. Keep positive invalidation probes
for source/resources alongside negative probes for irrelevant inputs.

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

Translate the selected Hackage metadata revision when constructing a Nix recipe,
then apply that same revision at build time. Applying it only after translation
can retain stale dependency edges. Evaluate platform conditions using Cabal's
architecture spelling: Apple's `arm64` must become `aarch64` for the pinned
cabal2nix parser. These translation inputs are part of dependency identity.

Require captured generic-builder arguments to reconstruct the exact actual derivation.
Reject lower-level recipe overrides whose source, hooks or other build inputs cannot be
represented by those arguments; use `overrideCabal` for supported recipe changes.

Record resolved Cabal flags from the actual recipe's configure replay, including
automatic/default decisions, rather than treating command-line flags as complete.
Record original and patched metadata digests, and require owned policy for source-altering
patch, configure, build and install hooks. A compiler-bundled build tool may
replace its Hackage counterpart only through an owned policy and verified actual
configured version, compiler path and reachable provider derivation.

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

Judge build optimizations by total time to a usable changed application and by their
amortized cost across a declared workflow. Record practical acceptance thresholds before
tuning, repeated paired timings and variability, compiler work, memory and input/cache state.
Include generation, seed creation/refresh, transfer, retention and migration rebuild costs;
a warm unchanged output is not a changed-code measurement. Keep production settings and
correctness gates equivalent. Keep an optimization opt-in or discard it when its benefit
is unproven or its cost is not repaid within the intended update/checkpoint cycle.

Benchmarks may share a host with unrelated work when measured resources have headroom.
Record hardware and concurrent compiler/test processes rather than rejecting their mere
presence. The Mac Studio policy uses one Nix job and sixteen requested build cores on
the 36-logical-CPU, 256-GiB host. Sample interval CPU idle, OS memory availability and VM/I/O
counters equally for both variants. Reject sampled CPU idle or memory availability below
10% continuously for at least fifteen seconds, missing observations, or a per-variant
timing range greater than 25% of its median. These diagnostics do not isolate thermal or
I/O effects; retain raw observations and alternating order. Declare changes before fresh
campaigns, keep the 20% improvement and existing amortization gates, and preserve earlier
excluded campaigns as diagnostics. The opt-in laptop compiler-idle guard remains available.

Evaluate package-set maintenance through a targeted update, deterministic regeneration,
impact/policy review, real consumer verification and rollback to a prior retained generation.
Record manual interventions and changed/unchanged recipe identities. Generated recipes remain
derived artifacts, not another editable authority. Reuse the existing solver, reports,
retained-runtime constructor and publisher. Run expensive strict validation explicitly or
in designated CI; routine evaluation, builds and shell entry consume recorded immutable
inputs without triggering that maintenance work. These requirements are acceptance policy,
not a claim that the planned optimizations already pass.

Preserve the user's advisory fleet guard: differing application channel revisions and shared
build identities warn, so a single-application hotfix remains possible. A mismatch against
an application's own freeze or missing/unverifiable build evidence fails. Initial alignment
acceptance separately requires equal identities where shared inputs are intended to match.

Application intermediate reuse is opt-in and uses an explicitly selected clean seed, never
an unbounded chain of previous candidates or a mutable external cache. Compare exact
source-independent recipe identities, retaining native/compiler tools, Setup/Cabal,
optimization/build ways, hooks and dependency inputs. Guard Cabal/Setup contents, source
layout and the declared generated-source writer separately. Only audited generated-source
content may be normalized. Invalid or mismatched records return the ordinary clean recipe
without evaluating an incompatible seed. Callers own truthful compatibility records; a
reported package version alone cannot establish safety. Native fixtures now prove selective
module reuse and error detection for the pinned GHC 9.12.4 builder, while real application
latency, retention and rollout acceptance remain independent gates. Revision provenance
belongs in its consuming source module instead of a package-wide compiler flag. Keep the
normal clean build while the checkpoint budget is unmet. The application-owned constructor
uses the same current recipe implementation for both explicit source selections, fingerprints
all non-Haskell inputs except audited GHC-tracked data, and retains a separately requestable
clean checkpoint. Its returned recursive scope contains the guarded package, so downstream
owned packages consume it. Reuse also requires an explicit declaration captured after a
successful clean checkpoint build, binding that actual derivation and its compatibility
record. Compare the current context and raw seed metadata with the recorded origin before
forcing the older package, then require the reconstructed checkpoint derivation to match exactly. Computing
both source records inside a changed current scope cannot establish origin: old Haskell
source may use an API removed by a same-version dependency update. Missing declarations and
changed origins select the ordinary clean package without adding an invalid seed. Candidate
declaration metadata alone is not native validation evidence. Native CLI checks prove current embedded help and truthful changed stamps;
they do not establish a default performance policy. Compare retained-runtime manifests against
the selected generation's captured freeze, preserving its reference validation even when a
newer channel default changes.

A fixed-checkpoint experiment may consume previous compiler products without exporting
another current checkpoint. Keep the clean seed export and exact origin/compatibility
guards. The additive `retainCurrentIntermediates` option defaults to the original
behavior; its false mode passes native Apple Silicon and translated Linux selective
reuse/source-error fixtures and real native Mori changed-value/closure checks. This
bounds per-edit intermediate retention. Five native pairs for `mori://shinzui/mori`
also establish lower changed-build latency, but [fresh checkpoint and full validation
costs](../evidence/ep18/mori-consume-only-full-cost.json) still exceed the ten-edit
budget before rollout. Removing unused current exports does not remove checkpoint
creation or guard replay costs. Preserve defaults until the complete workflow passes;
warmup-only amortization cannot establish that acceptance.

Package-boundary experiments must preserve source-generation ownership and original public
imports, and validate consumers that can depend directly on the stable package. Keep tests
and executable sources with their actual Cabal components; duplicated unbuilt Haskell files
can lose the formatter's component language settings. Source-inspection tests must follow
moved modules, and owned inventories must bind a real immutable producer revision. Public
reexports and matching executable behavior alone cannot replace full suite, ownership and
complete-cost acceptance. The [Mori core pilot](../evidence/ep18/mori-core-split-pilot.json)
passes its latency gate but leaves those adoption gates open.

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
must preserve unchanged dependencies and show actual remote substitution. Broader integration
and changed-code timing evidence remain pending. The scoped EP-18 Rei source-boundary result
and native acceptance are recorded in its plan and
[measurement receipt](../evidence/ep18/rei-documentation-rebuild.json). The five-pair 97.8%
saving applies to planning-prose edits at a fixed revision stamp; new commits still
invalidate the CLI for provenance.
