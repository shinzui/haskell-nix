---
id: 18
slug: accelerate-application-code-compilation-in-nix-builds
title: "Accelerate application code compilation in Nix builds"
kind: exec-plan
created_at: 2026-10-07T13:54:28Z
mori_publish: true
master_plan: "docs/masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-07T13:54:28Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-07T13:59:49Z
      mode: "other"
      note: "Flesh out initial follow-on proposal with MP-3 boundaries, native artifact feasibility, truthful evidence, and measured acceptance."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-07T14:38:55Z
      mode: "discuss"
      note: "Replace rejected Cabal artifact proposal with project Nix compilation work; prioritize pinned-builder intermediate reuse, measured invalidation fixes, and package-boundary pilots."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-14T17:32:37Z
      mode: "update"
      note: "Add cross-repository umbrella coordination and scoped Mori publication without changing implementation ownership."
---


# Accelerate application code compilation in Nix builds


This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective current. Distill accepted architectural decisions into `docs/adr/` during implementation.


## Purpose / Big Picture


Reduce the compilation time of changed application code during `nix build` in the Haskell CLI projects. The user confirmed that building a project with Nix already makes the subsequent dotfiles build fast. Deployment reuse is working; the expensive step is producing a new Nix build of the application itself. This plan supersedes the earlier Cabal-binary export proposal in this numbered plan.

The first implementation experiment uses a capability already present in the pinned Nixpkgs Haskell builder: retain a previous Nix build's intermediate compiler products, then supply them as declared inputs to a new sandboxed Nix build. GHC must still validate the new source and rebuild affected modules. If the experiment succeeds, an ordinary leaf edit can reuse unaffected modules without changing the user's Nix packaging/deployment workflow. Remove unnecessary source/revision invalidation, then measure package-level build settings and smaller compilation boundaries where substantial costs remain.

This follows [MasterPlan 3](../masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md). MP-3 owns the coherent dependency set, retained runtime generations, source/configuration policy, and actual executable build evidence. This plan owns application compilation after those dependencies are warm. It does not replace MP-3, add a dependency solver, change its pending acceptance, or require a remote cache, Cabal executable imports, or Buck2. Read-only diagnosis and fixtures can begin immediately; real consumer rollout uses the relevant accepted MP-3 package set and application adoption.


## Progress


- [ ] M1: Establish compilation baselines and prove Nix intermediate reuse with a small native fixture.
- [ ] M2: Pilot guarded Nix intermediate reuse in Rei and Mori and compare changed-code builds against clean builds.
- [ ] M3: Remove unrelated source and revision invalidation while preserving embedded resources and truthful provenance.
- [ ] M4: Measure bounded compiler parallelism and, if necessary, pilot smaller independently cached Cabal packages.
- [ ] M5: Roll out the validated policy and record application-build and dotfiles identity evidence.


## Surprises & Discoveries


The user's correction establishes that Nix output reuse between the project and dotfiles is already effective. The rejected proposal optimized a handoff that was not the reported bottleneck.

Inspection of the source of the currently used nixpkgs revision `d5dfd8e6716dde34398bc14bc87c10dece9c8c68` found `doInstallIntermediates`, `enableSeparateIntermediatesOutput`, and `previousIntermediates` in the Haskell generic builder. The same builder already enables parallel compilation by default and contains Darwin-specific behavior associated with separate intermediates. Those facts justify an experiment; they are not a measured speedup or proof of compatibility with the application builds.

At the 2026-10-07 source inspection, `mori://shinzui/rei` had 1,068 Haskell files under `rei-core/src` and 295 under `rei-cli/src`; `mori://shinzui/mori` had 744 under `mori-core/src` and 89 under `mori-cli/src`. These are filesystem counts, including generated files, not a count of modules compiled in a measured build. Local packages already disable profiling, Haddock, and Nix test execution in their current overlays. Simply proposing those switches again would not identify new savings.


## Decision Log


2026-10-14: Coordinate this workstream under [MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md). Scoped Mori publication records its production prerequisites and integration relationships; initial fixture work remains independent. Preserve the earlier declined intention association. Share effective compiler/source/policy identities and phase-separated measurements with plans 19 and 21 without introducing a Hard prerequisite on them.


2026-10-07: Target the project's Nix compilation. The user explicitly rejected the Cabal executable handoff and clarified that a completed project Nix build already warms dotfiles. Replace that proposal throughout this plan, preserve the plan identity and authorship history, and record its revised title/path.

2026-10-07: Test the pinned builder's immutable intermediate reuse before undertaking a large package split. This keeps the existing source-built Nix outputs and actual derivation evidence. Adoption depends on observed module reuse and clean-build equivalence on native macOS; it is not assumed to work.

2026-10-07: Keep seed inputs explicit, bounded, and reproducible. No mutable compiler cache enters a sandbox, no latest-store-path lookup occurs during evaluation, and no unbounded chain of historical seeds becomes part of the build graph.

2026-10-07: Preserve MP-3's shared dependency policies. Scope intermediates and compilation settings to application-owned packages; never rehash the entire shared Haskell scope just to tune a CLI. The user declined an Intention association. This remains a follow-on, without changing MP-3's required child registry.


## Outcomes & Retrospective


(No implementation or timings yet. The initial artifact-handoff direction was rejected; this revision replaces it with a native Nix compilation experiment and measured adoption criteria.)


## Context and Orientation


A Nix derivation is a recipe with immutable declared inputs. An intermediate compilation product is a compiler-generated object or interface file that can be reused when the compiler verifies that its inputs are still valid. Ordinary project Nix builds currently start application compilation without previous products. Reusing dependency packages under MP-3 does not itself change that application build behavior.

This repository owns shared Haskell build-policy helpers and MP-3. Existing `lib/mkHaskellExtension.nix` composes channel policy; `lib/mkFirstPartyPackageSet.nix` constructs package selections while excluding irrelevant selection labels from derivation inputs. `checks/package-set-cache-identity.nix` provides useful patterns for proving which inputs preserve or change identities. MP-3 plans 8/9 own solving, generation, lock resolution, manifests, and comparisons; plan 16 owns retained runtime composition; plans 11–13 own application adoption; plan 14 owns deployment integration and measurements. Reuse their interfaces, and do not implement an alternate cohort or manifest parser here.

Relevant local ADRs were read. [ADR 4](../adr/4-consumer-overlays-define-only-their-own-packages.md) reserves shared recipes for the channel. [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md) requires stable inputs, true source boundaries, and measured reuse; it does not currently promise module-level incremental Nix compilation. [ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md) protects exact runtime selections/configuration. The [cache/Buck2 research](../research/ci-cache-reuse-and-buck2-after-mp3.md) identifies application recompilation as the next bottleneck after dependency reuse. Add a filesystem ADR when the intermediate policy has actual acceptance evidence. `mori.dhall` does not declare `docs/adr` as a profiled OKF bundle; preserve the existing ADR convention.

Cross-project file references below use a canonical project URI plus its project-relative path; file-level Mori handles are pending. Resolve checkout locations with `mori registry show PROJECT --full`. Never search or inspect `/nix/store` for source or intermediates. Use Nix metadata APIs and build logs as evidence; the Nix builder handles its own declared inputs.

In `mori://shinzui/rei` and `mori://shinzui/mori`, `flake.module.nix` constructs the Haskell scope and exports package outputs. `nix/haskell-overlay.nix` uses `callCabal2nix` for owned packages. The CLI package contains a library of command modules plus a small executable entry point. Both overlays pass a repository-wide `-DGIT_HASH` configure flag to the CLI. Mori's `mori-cli/src/Mori/Version.hs` and Rei's `rei-cli/src/Rei/Cli/Commands/Info.hs` also use GitHash Template Haskell, which evaluates code during compilation. Package metadata and Git stamping therefore need deliberate invalidation tests.

Mori embeds schema data from outside the CLI/core directories. Both projects embed help/prompts or generated declarations. In `mori://shinzui/mori`, `mori-cli/mori-cli.cabal` lists embedded help files explicitly so edits rebuild their text. In `mori://shinzui/rei`, `rei-core/rei-core.cabal` includes migrations and prompt/template files and treats missing listed modules as errors. Those inputs must survive any filter or package split. Generated Keiro module ownership/scaffolding paths must remain consistent.

In `mori://shinzui/dotfiles.nix`, `flake.nix` resolves effective application/toolchain inputs; `flake-modules/overlays.nix` wraps application outputs with `hsBin`/`hsBinShare` and `dontHaddock`. `home/mori.nix` and `home/rei.nix` consume those packages for launchd and shell configuration. Their compilation behavior does not require a new binary import mechanism. The future plan-14 guard still needs evidence tied to the actual Nix-built executable.

The primary source checked for the experiment is `mori://NixOS/nixpkgs`, project-relative `pkgs/development/haskell-modules/generic-builder.nix`, at the revision named above; local registry/source-file handles are pending. Its [upstream source](https://github.com/NixOS/nixpkgs/blob/d5dfd8e6716dde34398bc14bc87c10dece9c8c68/pkgs/development/haskell-modules/generic-builder.nix) defines the intermediate options. Refresh and inspect the effective project's builder if MP-3 changes the base before implementation. This plan selects no new compiler or nixpkgs revision.


## Plan of Work


### Milestone 1: Measure and prove the builder mechanism


Add `checks/fixtures/application-incremental/` with a small Haskell library and executable. The library has independent modules plus a dependent module, and source variants for an unchanged build, a leaf implementation edit, an exported-type edit, a removed module, and changed embedded data. Add `checks/application-incremental.nix` and expose its check from `flake.nix`. Use the same effective GHC/package-set configuration as the target application.

Construct a seed package with saved intermediates and a separate intermediates output. Construct a candidate of the same package with changed source and the seed output as its `previousIntermediates` input. All compilation happens through the ordinary Nix Haskell builder. A clean candidate builds the same changed source without a seed. Verify executable behavior and interface-change propagation against both candidates, and measure actual compiler invocations/reused modules from logs. The immutable seed is a normal declared dependency; do not copy the user's mutable Cabal build directory or search the store for an old package.

The option shape for the spike, using the current Haskell composition API, is:

```nix
let
  inherit (pkgs.haskell.lib.compose) overrideCabal;
  seed = overrideCabal (_: {
    doInstallIntermediates = true;
    enableSeparateIntermediatesOutput = true;
    previousIntermediates = null;
  }) seedRecipe;
  incremental = overrideCabal (_: {
    doInstallIntermediates = true;
    enableSeparateIntermediatesOutput = true;
    previousIntermediates = seed.intermediates;
  }) candidateRecipe;
in
incremental
```

`seedRecipe` and `candidateRecipe` are two explicitly constructed versions of the fixture package under one configuration. They are not recursive references to the package being built. Do not assume turning on these attributes is sufficient: investigate changed unit IDs, temporary build paths, GHC recompilation fingerprints, Template Haskell dependencies, timestamps, Cabal build layout, and Darwin linker behavior if reuse fails. Apply any necessary fix through a narrowly scoped helper only after isolating it in the fixture.

In disposable Rei and Mori checkouts, warm shared dependencies and record elapsed time, memory pressure, compiler/linker phases, effective flags, and application derivations for a real leaf edit. Record the source revisions and exact MP-3 selections. `nix build` of an unchanged output only measures cache lookup, so it is not the compilation baseline. Use source variants to request new application derivations without deleting existing outputs or forcing a rebuild of the dependency closure.

M1 passes when a leaf edit demonstrably reuses at least one unaffected fixture module while producing correct new behavior, a real interface/data edit invalidates its dependents correctly, and a clean comparison agrees. If the upstream mechanism recompiles everything, fails correctness, or requires unacceptable changes, record that result and prioritize the M4 package-boundary experiment. Do not claim incremental Nix support from option names alone.


### Milestone 2: Pilot guarded intermediate reuse in the application packages


Add `lib/mkApplicationIncrementalBuild.nix`, export it from `flake.nix`, and add validation fixtures. Its interface accepts an application recipe, an explicit seed recipe/source selection, current/seed compatibility records, and an enabled flag. A compatibility record contains package name/version, compiler/native tool identities, Cabal/Setup identity, build ways and optimization/CPP flags, generated-input policy, and the exact relevant Haskell/native dependency identities. Current source content may differ; structural or environment changes require a clean seed or a clean candidate. Conservative rejection is preferable to incorrectly reusing stale objects.

Begin with `rei-cli` under unchanged `rei-core` dependencies, then test `rei-core` and Mori's equivalent packages. A changed core library may change downstream package identities and legitimately prevent some reuse; measure that separately. Current package sources and seed sources are explicit pinned inputs, evaluated with the correct recipes and dependencies. Do not use arbitrary matching version strings as the compatibility test. The helper logs why a seed is accepted or why an ordinary clean build is selected. Wrong compiler, package metadata, build flags, or relevant dependency identities must reject reuse before compilation.

Use a fixed, explicitly chosen seed source revision initially. Build that seed with `previousIntermediates = null`. Routine source updates retain the seed and the shared MP-3 dependency inputs. This bounds the build graph; do not make each seed evaluate the prior incremental seed recursively. A deliberate checkpoint refresh builds a new clean seed. Measure checkpoint cost and accumulated source differences before selecting its frequency. A dependency or compiler update invalidates incompatible seeds explicitly.

In each owning project, wire the helper through unmanaged `flake.module.nix`/`nix/haskell-overlay.nix` and an optional `nix/application-incremental.nix`. Export the seed intermediates for explicit rooting/inspection through metadata, an incremental package, and a clean comparison package. Begin with opt-in outputs. Move the normal project/default output onto the tested policy only after native acceptance so dotfiles can request the same package identity; expose the clean package for reproducible cross-checks and recovery. Preserve MP-3 manifests, including the seed as a real auxiliary build input, without claiming it changes the compiler/dependency cohort.

M2 requires reduced compiler work and lower median elapsed application compilation for representative leaf edits in Rei and Mori at unchanged build settings, plus clean-build behavioral agreement. Run repeated trials and report their spread. Count one-time seed creation separately. Unchanged dependencies must retain their identities. Keep application runtime outputs separate from intermediate retention; verify metadata/closure size so runtime installation does not accidentally retain every historical intermediate checkpoint.


### Milestone 3: Remove avoidable source and revision invalidation


In the owning projects' package definitions, make each source input contain exactly its true build inputs, with stable source names. Use the pinned Nixpkgs source-filter helpers only after reading their source. Required licenses, Cabal/Setup files, generated modules, embedded schemas/help/prompts, vendor code, native inputs, and runtime data remain included. Unrelated documentation, sibling trees, and disabled-test sources may be excluded only after confirming that package generation or compile-time code does not consume them. A blanket Markdown exclusion would break embedded help.

Remove the changing repository revision from CLI-wide CPP compiler flags where it invalidates every module or makes every seed incompatible. Isolate source provenance in a small generated version component or runtime metadata, preserve the existing version output, and keep the actual repository revision in the build manifest. A version-only change may rebuild its small component and final dependents; expensive application libraries must retain their identities. Choose the exact representation using measured CLI import dependencies. Merely moving a Haskell module within the same Cabal package does not guarantee an independently cached Nix boundary.

Run identity and compiler-work experiments for unrelated prose, stamp-only changes, an embedded-help change, and a sibling-source change. Coordinate edits with MP-3 consumer plans 11–13, which already own source boundaries, rather than introducing conflicting filters. M3 passes when irrelevant inputs cease invalidating expensive packages, true embedded inputs remain visible, and version provenance is accurate. These fixes also benefit the clean path even if intermediate reuse is unavailable.


### Milestone 4: Tune measured compilation costs and test smaller package boundaries


Capture the actual builder flags first. The inspected builder already enables parallel compilation, so adding `enableParallelBuilding = true` alone is not an optimization. Compare bounded per-package worker counts and total simultaneously running builds under the Mac's memory budget. Avoid changing global daemon settings or oversubscribing several large GHC builds. Profiling and Haddock are already disabled for the inspected local packages; confirm the actual build ways and optimize only residual duplicated work. Record linking and Template Haskell costs separately.

Keep production optimization unchanged by default. If measurements show optimization dominates compilation, expose a separately named application-only fast build profile and compare its build time and representative runtime workloads. Never change the shared dependency set's optimization or replace production defaults without passing the runtime/release gates and documenting the measured tradeoff.

If whole-package rebuilding remains dominant, add `scripts/application-module-graph.py` and inspect the module import graph plus Cabal component metadata. Detect import cycles, generated ownership, Template Haskell/resource inputs, and dependencies hidden behind CPP; validate the inventory through the actual compiler. Select one stable low-dependency group and one frequently edited leaf group in the largest remaining package. Split a pilot into separate Cabal packages and separate Nix derivations, preserving public Haskell module names and test coverage. Internal sublibraries in one Cabal package are not sufficient evidence of independent Nix caching. Avoid an app-wide architectural refactor before the pilot shows benefit.

Update that application's `cabal.project`, package manifests, owned Nix overlay, module lists, generated-code tooling where applicable, tests, and MP-3 owned-package/manifests inventory. Dependencies flow from shared types/infrastructure to domains to adapters/CLI; do not create cyclic Cabal packages. A stable foundation change legitimately rebuilds downstream packages. A leaf-package edit must preserve unrelated application-package identities and compile fewer modules than the prior monolithic package. Compare against the same optimization/profile, seed policy, and shared dependency inputs. Adopt further boundaries only if measured savings justify the maintenance cost.


### Milestone 5: Roll out the winning policy without changing deployment semantics


Add `docs/guides/faster-application-nix-builds.md` and `scripts/measure-application-nix-builds.py`. Record before/after tests for unchanged builds, unrelated prose, embedded resources, a leaf edit, an interface change, a targeted dependency update, and a deliberate toolchain update. Report seed creation/refresh, evaluation, substitution, application compilation, linking, tests, and system assembly separately. List unexpectedly rebuilt modules/packages and explain unavoidable rebuilds.

Adopt the accepted helper/settings/boundaries independently across `mori://shinzui/rei`, `mori://shinzui/mori`, then the other MP-3 applications as their measured profiles justify. Keep shared rules here and owned recipe/source edits in their producing projects. In `mori://shinzui/dotfiles.nix`, compare the effective selected project package identity with its producing project under matching inputs. Updating the source input and then building Darwin must reuse the Nix output already produced in the project. Do not add an artifact-export adapter or bypass the existing parity guard.

Distill the validated application compilation policy into a filesystem ADR and update this plan with actual timings and remaining costs. Leave MP-3's dependency/cache/platform acceptance unchanged. Initial performance proof targets native `aarch64-darwin`; broader claimed support requires the same correctness/reuse fixtures on that platform. Do not activate production services or touch persistent databases during the benchmark experiments.


## Concrete Steps


From this repository, locate the current application/toolchain checkouts and inspect the effective package-set state:

```bash
mori registry show shinzui/rei --full
mori registry show shinzui/mori --full
mori registry show shinzui/haskell-nix-dev --full
mori registry show shinzui/dotfiles.nix --full
git status --short
```

From each application's disposable checkout, with recorded source and configuration, capture the package recipe metadata and build logs:

```bash
nix derivation show .#default > application-derivation.json
/usr/bin/time -p nix build .#default --print-build-logs --no-link
```

Use the same commands after a representative leaf edit to measure actual new compilation; an unchanged build is recorded separately. Keep benchmark files outside the source inputs. Do not delete store outputs or change compiler/dependency pins to simulate a source edit. Nix metadata APIs are permitted; direct traversal or inspection of store files is not.

The new fixture/check gate from this repository is:

```bash
nix build .#checks.aarch64-darwin.application-incremental
```

After M2 adds the application outputs, compare the same candidate source under both policies from its owning checkout:

```bash
/usr/bin/time -p nix build .#application-incremental --print-build-logs --no-link
/usr/bin/time -p nix build .#application-clean --print-build-logs --no-link
```

These are new outputs to implement. Expose corresponding seed-intermediates and package-specific variants through M2, and record their actual names in this section. A meaningful result includes correct changed behavior, unchanged shared dependencies, fewer compiled modules, and lower elapsed application compilation. Fill in this evidence only after measurement:

```text
seed compatibility: accepted or clean-build reason
leaf edit: clean compilation N modules; seeded compilation M modules
leaf edit: clean elapsed X seconds; seeded elapsed Y seconds
correctness: changed behavior and isolated tests agree
shared dependencies: unchanged
```

N/M/X/Y are measured values, not thresholds or promises. Clean and seeded candidates must have the same current source and compilation settings. Repeat trials using declared distinct source variants so already-cached outputs do not masquerade as fast compilation.


## Validation and Acceptance


The central acceptance is faster production of a new Nix application build after a leaf edit under the same dependency set and runtime build settings. Either validated intermediate reuse or validated smaller package boundaries must reduce actual compiler work and measured elapsed time. A fast subsequent dotfiles build alone does not satisfy this plan.

Fixture and native application checks must detect changed exported types, removed/renamed modules, modified generated or embedded inputs, and changed compiler/dependency/native/CPP configuration. Invalid seeds select a clean build with a clear reason; stale interfaces must never hide a source error or old runtime behavior. Compare isolated tests and executable behavior with a clean build. Compare byte hashes where deterministic outputs make that meaningful, and classify differences rather than treating differing hashes or identical version strings as proof by themselves.

Use existing MP-3 executable manifests and application release rehearsals. Seed intermediates are declared auxiliary build inputs; they do not replace true Haskell dependency records or permit source/flag exceptions without reasons. Package splitting updates the actual graph and owned-package inventory. Version stamping remains truthful; required embedded resources retain their content; unaffected application packages/dependencies preserve their identities where inputs match.

Publish real measurements, seed retention/checkpoint costs, runtime tradeoffs for any optional faster profile, and remaining bottlenecks. All fixtures and supported application tests pass before rollout. No new remote cache, Cabal binary handoff, source-built-package equivalence claim based solely on version parity, or production database mutation is part of acceptance.


## Idempotence and Recovery


Seeds are explicit immutable source/configuration checkpoints built without a predecessor. Re-running a build with the same source, configuration, and seed requests the same derivation. A deliberate seed refresh changes that input and incurs a measured checkpoint cost. Limit retained checkpoints and use explicit roots while benchmarking; do not remove unrelated roots or force garbage collection to test retention.

Keep `application-clean` available. If reuse fails or compatibility changes, use that normal source-built package. Never add a mutable home-directory compiler cache to the Nix sandbox, discover a seed by scanning the store, or let previous revisions form an unbounded recursive seed graph. The selected seed must be independently obtainable through its declared source inputs; behavior when rebuilding it from scratch is part of acceptance.

Use disposable checkouts and preserve foreign changes. In particular, the working dotfiles `flake.lock` had user changes during this discussion. Do not restore/reset that file while testing the plan. Application refactors are additive first; retain the prior package arrangement until the pilot proves correctness and benefit. Rollback changes only this plan's helper/owned recipe selection, leaving the shared MP-3 package set intact.


## Interfaces and Dependencies


`lib/mkApplicationIncrementalBuild.nix` accepts `{ package, seedPackage, currentCompatibility, seedCompatibility, enabled ? true }` and returns `{ package, seed, compatibilityReport }`. It uses the pinned Nixpkgs Haskell builder's intermediate options after M1 validation. The returned package is a normal source-built Haskell derivation; the report names accepted/rejected compatibility conditions. The seed recipe must not depend on the returned package or another incremental predecessor.

Application exports initially include `application-incremental`, `application-clean`, and the explicit seed intermediate output. Real applications may additionally expose package-specific outputs for core/CLI/API experiments. Application metadata, recipes, and compatibility computation are owned in their project; common validation/fixture machinery lives here. Source filters and provenance changes coordinate with MP-3 plans 11–13. Cohort/runtime/manifests still use MP-3's shared interfaces.

No dependency bounds or new pins are chosen during planning. Verify any required library API through Mori and the effective pinned source before implementing. The upstream builder capability was found in the current pinned source, but its behavior under the actual native application recipes remains an experimental prerequisite.


## Revision Notes


2026-10-07: Replaced the rejected local Cabal artifact-export proposal after the user clarified that the project `nix build` is the bottleneck and already warms dotfiles. Renamed the plan while preserving its number and provenance. Inspected the pinned Nixpkgs Haskell builder and prioritized a guarded intermediate-reuse experiment, then source/stamp isolation, measured compiler settings, and smaller Cabal-package pilots. No implementation or speedup is claimed.

2026-10-14: Added umbrella membership and scoped Mori opt-in while preserving implementation boundaries and existing prerequisites.
