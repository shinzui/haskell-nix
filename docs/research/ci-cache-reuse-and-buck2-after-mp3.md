---
type: Research Document
title: CI cache reuse and whether to adopt Buck2 after MP-3
description: Preserve the case for implementing package-set alignment first, its limits for incremental compilation, and the evidence needed to revisit Buck2 afterward.
generated:
  by: process:codex
  at: "2026-09-28T19:55:57Z"
researchId: RES-1
status: active
scope: Static inspection of haskell-nix, Rei, Mori, the shared toolchain workflow, and upstream Buck2 Haskell rules; a CI-focused assessment and follow-up measurement design, without measured speedups or a Buck2 implementation.
reviews:
  - kind: model
    reviewer: codex-author
    reviewed_at: "2026-09-28T19:59:48Z"
    document_timestamp: "2026-09-28T19:55:57Z"
    scope: content-and-metadata
    outcome: commented
    provider: openai
    model: gpt-6
    effort: unspecified
    context: Author self-check against the inspected repository configurations, attributed plan evidence, pinned Buck2 source, and research profile. This is not independent review, benchmark validation, or approval of MP-3 implementation readiness.
relatedPlans:
  - mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
sources:
  - id: mp3
    resource: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
    title: Package-set alignment initiative and its recorded baseline
  - id: overrides
    resource: mori://shinzui/haskell-nix/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays
    title: Shared override ownership and recorded derivation differences
  - id: adoption
    resource: mori://shinzui/haskell-nix/plans/11-adopt-the-shared-package-set-in-rei-and-mori-rei-app
    title: Shared package-set and rei-core adoption
  - id: updates
    resource: mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
    title: Independent application updates and deployment parity
  - id: rei
    resource: mori://shinzui/rei
    title: Rei build configuration at 54c0a685f2b0e2632a3f1fefab820a1281aa50d9
  - id: mori
    resource: mori://shinzui/mori
    title: Mori build configuration at 5eb063d2ab5d1e9d15a67b4b5afb20d342486458
  - id: toolchain
    resource: mori://shinzui/haskell-nix-dev
    title: Toolchain build and cache workflow at 206ecd25bcb4a07581210bdae3e6f43c8fd179d8
  - id: nix-identity
    resource: https://nix.dev/manual/nix/2.34/store/derivation/outputs/input-address
    title: Nix input-addressed derivation outputs
  - id: buck-compile
    resource: mori://facebook/buck2
    title: prelude/haskell/compile.bzl at 6fb6303d82f343ae19ea11598d2179594983dbc1; file-level Mori URI pending
  - id: buck-caching
    resource: https://buck2.build/docs/rule_authors/content_based_paths/
    title: Buck2 action identity and content-based paths
  - id: buck-remote
    resource: https://buck2.build/docs/users/remote_execution/
    title: Buck2 remote execution and cache configuration
---

# CI cache reuse and whether to adopt Buck2 after MP-3

## Recommendation and when to return

Implement MP-3 before investing in a Buck2 migration. It addresses observed causes of
duplicate dependency builds across the application family, reduces duplicated build
configuration, and brings Cabal and Nix dependency versions into agreement. Those benefits
remain useful even if a finer-grained build system is adopted later.[^mp3]

Return to this record after the consumer adoption and update-policy work in MP-3 has landed
and the resulting dependency builds have been published to the cache used by CI. First
measure how much CI time still goes into compiling changed application packages. A Buck2
pilot becomes worthwhile if that remaining cost is substantial and frequent enough to
justify new build rules, target boundaries, and cache infrastructure.

This is a synthesis of the September 28 discussion, not an implementation plan or a measured
performance result. The user identified **both** repeated shared-dependency builds and
application rebuilds after small edits as problems. The recommendation is an engineering
assessment; no numerical speedup or payback period has been established. The research stays
`active` until the post-MP-3 measurements resolve the open questions. No independent review
or verification is claimed.

## Evidence and its limits

The assessment inspected source configuration and existing plan evidence. It did not run a
clean CI job, inspect a sample of production CI logs, query cache coverage, or implement
Buck2. Recorded deployment findings in the plans are historical evidence, not measurements
repeated during this discussion. Local checkouts need not match the revisions used by CI.

The haskell-nix checkout was `a5f21611d6f5ebb06cc878b370ada2c7c20f1320`. In this repository,
the relevant files are `lib/mkFirstPartyPackageSet.nix`,
`lib/mkFirstPartyRegistries.nix`, `checks/package-set-cache-identity.nix`,
`checks/production-package-set-cache-identity.nix`, and MP-3 with its child plans.
The existing checks already protect identity reuse for selected unchanged dependency
families; their existence alone does not demonstrate that remote CI can download those
outputs.

Cross-repository file-level Mori URIs for the following source snapshots are pending.
Each path is qualified by its canonical owning project and the inspected commit:

| Project and snapshot | Project-relative evidence |
|---|---|
| `mori://shinzui/rei` at `54c0a685f2b0e2632a3f1fefab820a1281aa50d9` | `flake.lock`, `flake.module.nix`, `nix/haskell-overlay.nix`, `nix/haskell.nix`, `cabal.project`, `Justfile` |
| `mori://shinzui/mori` at `5eb063d2ab5d1e9d15a67b4b5afb20d342486458` | `flake.lock`, `flake.nix`, `flake.module.nix`, `nix/haskell-overlay.nix` |
| `mori://shinzui/haskell-nix-dev` at `206ecd25bcb4a07581210bdae3e6f43c8fd179d8` | `flake.nix`, `.github/workflows/build.yml` |
| `mori://facebook/buck2` at `6fb6303d82f343ae19ea11598d2179594983dbc1` | `prelude/haskell/compile.bzl`, especially the source collection and `compile` action |

Observed differences in the application checkouts:

| Input | Rei | Mori |
|---|---|---|
| Shared haskell-nix revision | `4cabd105d7cb9cc5a4805393bf19b11a6e01aac3` | Same |
| haskell-nix-dev revision | `206ecd25bcb4a07581210bdae3e6f43c8fd179d8` | `af29a4869ca87aea3eb3e9d6164e24f571412527` |
| Primary nixpkgs revision | `d5dfd8e6716dde34398bc14bc87c10dece9c8c68` | `4df1b885d76a54e1aa1a318f8d16fd6005b6401f` |
| OpenAPI package construction in consumer overlay | Hackage tarballs through `callHackageDirect` | GitHub source pins through `callCabal2nix` |

Sharing the channel revision therefore does not by itself establish matching dependency
builds. Different nixpkgs revisions do not prove that every package changes, but they make
whole-closure identity an unsafe assumption.[^rei][^mori]

The toolchain workflow builds the GHC/Cabal/HLS toolchain bundles on Apple Silicon macOS and
x86_64 Linux and configures Cachix publication. That establishes the intended toolchain
cache path, not coverage of every dependency used by the consumer applications. This
inspection did not establish whether another service already publishes those application
dependency closures.[^toolchain]

## Two different causes of cache misses

**Different builds of shared dependencies.** Ordinary input-addressed Nix outputs depend on
the derivation and its dependency identities. The same library version can be built with
different sources, patches, flags, compilers, native dependencies, or build policies and
produce a different cache identity. Differences can propagate to dependents. A frozen
version list is useful but is not proof of identical derivations.[^nix-identity]

**Whole-package rebuilding after an application edit.** Rei's Nix configuration constructs
its local packages through `callCabal2nix`. When a package's source input changes, a new
package derivation normally compiles it afresh; it does not automatically reuse the prior
derivation's module objects. Unchanged third-party dependencies can still be reused.
This differs from a persistent local Cabal build directory, where GHC can reuse previously
compiled modules.[^rei]

Improving one cause does not remove the other. A final application package missing the cache
after its source changes is expected; recompiling unchanged expensive dependencies is the
more useful initial signal. Compare avoided compilation time and CI elapsed time, not only
the percentage of all cache lookups that hit.

## What makes MP-3 worth implementing

| Planned change | Expected benefit | Boundary of the claim |
|---|---|---|
| Move shared overrides into the channel and audit consumer overlays | Removes avoidable differences in dependency construction and their downstream rebuilds | Actual identity still depends on the selected base, package set, and build settings |
| Reuse Rei's exported library definition under matching dependencies | Lets Rei and mori-rei-app request the same expensive `rei-core` build | Exporting an extension alone is insufficient; prove equal resulting store paths |
| Stop ordinary application updates from also moving the base toolchain | Reduces accidental invalidation of large dependency trees | Deliberate toolchain upgrades still incur legitimate rebuilds |
| Generate Nix versions from the shared Cabal freeze and add parity checks | Reduces version drift, duplicate maintenance, and test/release dependency mismatches | Version parity alone neither proves identical build configurations nor shares Cabal and Nix compiled artifacts |

The plan's inventory records same-version libraries with different derivation paths and
duplicate `rei-core` builds in deployment. The expected benefit is grounded in those
observations rather than a generic claim that centralization is faster.[^overrides][^adoption]

The plan is broader than a cache optimization: upstream compatibility releases, application
upgrades, and deployment checks also serve correctness and maintenance. Those costs should
not be described as necessary solely to improve the cache hit rate. The strongest direct
performance contributions are shared build policy, dependency identity reuse, and stable
toolchain updates. MP-3 may initially require substantial rebuilding as the new cohort is
adopted; recurring savings should be measured after that warm-up.

The revised deployment policy deliberately allows a single application to move independently.
Differences across the family warn; mismatches against an application's own frozen versions
fail. Preserve that flexibility. Shared unchanged dependency subgraphs can remain reusable
without requiring every application to move in lockstep.[^updates]

## Where Buck2 could help, and where it cannot

Buck2 supplies action caching and remote execution. A build with smaller, well-specified
actions can reuse more work after a small edit and execute independent work remotely.
Actions still need stable inputs and commands, consistent toolchains, and an accessible
cache. Moving the existing configuration differences into Buck2 would not automatically
remove them.[^buck-caching][^buck-remote]

The inspected upstream Haskell implementation gathers a target's Haskell sources and
compiles them in one action per requested compilation variant. It does not enable
`no_outputs_cleanup`, so retained outputs are not being used for GHC incremental compilation
in that action. The object, interface, and stub outputs also explicitly opt out of
content-based paths in that revision. Buck2's general caching features must therefore not
be assumed to provide per-module or cross-configuration Haskell reuse automatically.[^buck-compile]

In the inspected Rei tree, there were 824 `.hs` source files under `rei-core/src` and 292
under `rei-cli/src`. These are filesystem counts, not a measured build action graph. Mapping
each large Cabal library to one equally large Buck2 target would retain a coarse rebuild
boundary and could lose the module reuse available in a warm local Cabal build.

A useful pilot must demonstrate smaller target boundaries or improved Haskell rules and
measure their effect. It must account for package metadata, generated modules, Template
Haskell inputs, native dependencies, and the target operating system. Using Nix to provide
the toolchain and native dependencies while Buck2 builds application code is a plausible
hybrid, not a validated integration from this research.

Do not infer a Haskell speedup from Buck2's published comparisons against Buck1. No Buck2
version, prelude pin, remote execution provider, or migration has been selected here.

## Post-MP-3 acceptance and measurement checklist

Use the actual CI operating system and architecture, compiler, dependency set, build flags,
test scope, and artifact requirements. Record their exact revisions before each comparison.
Repeat the exercise separately for each CI platform; a macOS build does not warm Linux
binary outputs.

1. **Prove cross-application identity.** Compare a representative set of expensive shared
   dependency identities from the actual consumer builds, including their build policies.
   Verify that Rei and mori-rei-app request the same `rei-core` output when their source and
   dependency inputs match. Classify intentional differences rather than treating all
   differences as defects.
2. **Prove remote cache availability.** Build and publish the dependency outputs through
   the existing CI/cache mechanism. On a fresh runner, build another aligned application.
   Verify that its unchanged shared dependencies are downloaded instead of compiled. A
   same-machine second build proves local reuse, not remote cache publication.
3. **Prove update isolation.** Apply an application-only change with dependency inputs
   unchanged. Confirm that it does not move the base toolchain or unexpectedly change
   shared third-party dependency identities.
4. **Measure the remaining work.** Record wall time, compilation time where available,
   cache transfer time, packages compiled, and test/link time. Keep logs and a run identity
   with the measurements. Report dependency compilation separately from application
   compilation and cache downloads.

Use these scenarios for the baseline and any later Buck2 pilot:

| Scenario | Question |
|---|---|
| Same revision, fresh runner, populated remote cache | Can CI actually retrieve all expected reusable outputs? |
| Small leaf-module implementation change | How much application compilation does a narrow edit cause? |
| Widely imported interface change | What is the cost of legitimately affected dependents? |
| One first-party dependency upgrade | Does invalidation follow the affected dependency graph? |
| Deliberate toolchain upgrade | What is the unavoidable cold-build cost under each approach? |

For each unexpected rebuild, classify the cause: a different build identity; a matching
identity whose output is absent or unavailable; or a genuine changed input. Repair cache
publication, permissions, configuration, and retention failures before attributing their
cost to the build engine. Do not erase a working developer store to simulate a fresh runner.

No quantified cache-hit or latency target was agreed in this conversation. Before a pilot,
choose a practical CI time budget and an acceptable maintenance cost. Compare repeated runs
under equivalent conditions and report the one-time migration/cache warm-up cost separately.

## Decision after measurement

Keep the aligned Nix builds if unchanged dependencies are reliably reused and the remaining
application compilation meets the CI time budget. If expected shared dependencies still
compile, diagnose identity or cache delivery first. If application compilation remains the
dominant recurring cost after those checks, prototype Buck2 on one representative chain of
Haskell targets, retaining the established toolchain initially.

Promote that pilot only if it shows useful CI savings after small edits, preserves required
tests and artifacts, works on the target platforms, and has acceptable ongoing rule and
dependency maintenance. Smaller Cabal packages or a carefully restored Cabal build cache
are also candidate follow-ups; neither was evaluated in this session. Matching Cabal and
Nix versions is not sufficient to interchange their compiled build directories.

Open questions for the resumed discussion are the actual CI time split, dependency cache
coverage after MP-3, the application modules driving the critical path, feasible Haskell
target boundaries, and whether remote execution improves enough work to cover its cost.
Append the measured results to this record, or create a follow-up research record linked
to `RES-1`, before making a migration decision.

## Source notes

[^mp3]: MP-3 and its child-plan contracts in this repository, inspected on 2026-09-28. The recommendation assesses the cache-related design; it is not a full implementation-readiness audit of every child plan.
[^overrides]: Plan 10's inventory and recorded derivation comparisons. Those prior comparisons were read, not rerun during this discussion.
[^adoption]: Plan 11's shared-library adoption and equal-output acceptance criteria.
[^updates]: Plan 14's revised warning/failure policy and replacement of application updates that also move the base toolchain.
[^rei]: `mori://shinzui/rei`, at the revision and project-relative paths in the evidence table; file-level URI pending.
[^mori]: `mori://shinzui/mori`, at the revision and project-relative paths in the evidence table; file-level URI pending.
[^toolchain]: `mori://shinzui/haskell-nix-dev`, at the revision and project-relative workflow path in the evidence table; file-level URI pending.
[^nix-identity]: [Nix manual: input-addressed derivation outputs](https://nix.dev/manual/nix/2.34/store/derivation/outputs/input-address), consulted on 2026-09-28.
[^buck-compile]: `mori://facebook/buck2`, `prelude/haskell/compile.bzl` at `6fb6303d82f343ae19ea11598d2179594983dbc1` (file-level URI pending). [Upstream source retrieval](https://github.com/facebook/buck2/blob/6fb6303d82f343ae19ea11598d2179594983dbc1/prelude/haskell/compile.bzl#L220), checked on 2026-09-28. Recheck the chosen prelude revision before a pilot; this implementation detail may change.
[^buck-caching]: [Buck2 content-based paths and action identity](https://buck2.build/docs/rule_authors/content_based_paths/), consulted on 2026-09-28. Deduplication depends on eligible inputs, outputs, and paths; identical contents alone do not promise reuse across unrelated targets.
[^buck-remote]: [Buck2 remote execution configuration](https://buck2.build/docs/users/remote_execution/), consulted on 2026-09-28.
