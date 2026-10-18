---
id: 19
slug: pre-generate-complete-locked-nix-haskell-dependency-recipes
title: "Pre-generate complete locked Nix Haskell dependency recipes"
kind: exec-plan
created_at: 2026-10-14T15:21:55Z
intention: "intention_01m4xg1xp3ekf9m1dbc5fpsq9k"
mori_publish: true
master_plan: "docs/masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-14T15:21:55Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-14T15:34:19Z
      mode: "other"
      note: "Flesh out Horizon-inspired recipe generation with scoped no-IFD evidence and existing cohort ownership."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-14T17:32:37Z
      mode: "update"
      note: "Add cross-repository umbrella coordination and scoped Mori publication without changing implementation ownership."
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-10-17T03:25:59Z
      mode: "update"
      note: "Reconcile delivered prerequisites and strengthen maintenance, real-consumer integration, and measured total-cost acceptance."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-17T05:27:34Z
      mode: "implement"
      note: "Prototype exact-metadata conversion with the pinned cabal2nix tool and scoped no-IFD fixtures."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-17T23:16:39Z
      mode: "implement"
      note: "Export the accepted generation context with deterministic serialization, guarded staged publication, and native tests; keep complete recipe generation and performance adoption pending."
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-10-17T03:26:00Z
      verdict: "comments"
      note: "Reviewed against current repository contracts and applied maintenance/performance findings; new implementation and benchmark evidence remain pending."
---

# Pre-generate complete locked Nix Haskell dependency recipes

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective current. Update local ADRs when implementation establishes durable project decisions.

## Purpose / Big Picture


Evaluating a selected shared dependency should read its checked-in recipe rather than run cabal2nix before Nix can finish evaluation. Add deterministic, pre-generated full package recipes for an explicit locked dependency configuration. The recipes preserve exact sources, Hackage metadata, flags, native dependencies, and compatibility policy, and remain composable in the existing single Haskell package scope. After implementation, the scoped generated-dependency fixture evaluates with import-from-derivation disabled, regeneration is byte-identical, and the selected production configuration retains verified dependency identities.

Import-from-derivation (IFD) means Nix builds an output and imports the Nix expression inside that output during evaluation. Removing that step can reduce evaluation work; it does not provide incremental compilation of changed application modules. Benchmark evaluation separately, and make no speedup claim until measured.

This is a standalone follow-on to [plan 9](9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md). It neither repeats its solver/version-generation work nor becomes an adoption gate for its existing consumers. Real-runtime rollout also integrates with [plan 16](16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md). Plans 9 and 16 are Complete locally as of 2026-10-16; their explicit generation inputs, checked runtime constructor and retained configurations are available. New recipe artifacts and real-consumer adoption still require this plan's acceptance.

## Progress

2026-10-18 UTC fixed-source native matrix: immutable `44bb697` passes the complete Nix updater build and all 221 tests on both systems. Linux also passes the mixed local-input generation/check/repeat/drift pipeline, both scoped no-IFD roots, exact normalized legacy cmark-gfm derivation parity and the identical original-bounds 22-test suite. [Native matrix](../evidence/ep19/source-pin-native-matrix.json) retains the failed first setup (HTTP was blocked before its missing GNU tar could be realized), corrected bootstrap, all inputs, raw functions and logs. Both raw package functions equal Darwin. Generation-specific audit narrows the flag caveat: generation 1 Dhall inputs record TLS false and its Nix policy enables it; generations 2/3 already record true. The selected generation and policy must remain explicit. Context/factory binding, semantic component-role inventory, update/rollback and performance/cost adoption remain open.

2026-10-18 UTC fixed-source checkpoint: artifact inputs now optionally declare an immutable GitHub source pin, its independent raw archive/NAR/metadata hashes, and a pinned GNU tar identity. Exact source ownership/revision/subdirectory and archive metadata are verified; pinned metadata has no Hackage revision, and conversion-only metadata evidence leaves original solved observations intact. All 221 updater tests pass, including subdirectory selection, altered Git declarations and archive metadata rejection. The existing cmark-gfm fork at a9014e8 regenerates/checks byte-identically after relocation with HTTP proxies unreachable. Its raw converter output includes the explicit default-false pkgconfig flag; a metadata-hash-guarded spelling adapter restores exact legacy cmark-gfm and real Rei CLI derivations. Both roots pass no-IFD, and the identical strict baseline/candidate recipe passes all 22 tests with original bounds. Current Hackage and upstream/fork tags verify release 0.2.6; the frozen fork commit stays unchanged. [Fixed-source receipt](../evidence/ep19/source-pin-artifacts.json). Linux source-pin integration, a general retained factory/context adapter and effective Nix flag policy handoff remain open. In particular, both retained Dhall source profiles still record TLS false while its Nix hook deliberately enables it; do not convert that package from raw solved flags and infer dependency parity. M2/M3/M4 remain in progress.

2026-10-17 bounded artifact native supplement: immutable `5c29426` passes the complete Nix updater build and all 218 tests on aarch64-darwin and x86_64-linux in the translated Apple guest. The Linux installed CLI also generates/checks/repeats the same local one-root input, rejects metadata drift without replacing outputs, passes scoped no-IFD and preserves its retained runtime derivation through the unchanged reference guard. Its raw package function matches Darwin byte-for-byte. [Native matrix](../evidence/ep19/recipe-artifacts-native-matrix.json) retains all guest inputs, artifacts, commands and raw logs. This completes the bounded default-compiler matrix only; source-pin conversion, the retained factory adapter, broader update/rollback and performance/cost adoption remain open.

2026-10-17 bounded M2 artifacts: `cohort recipes generate/check --context FILE --out DIR` now reconverts exact local Hackage metadata, verifies solved raw archive and unpacked hashes, binds converter derivation/output/version, checks complete generated coverage and revision cutoff, and stages a portable manifest, extension and package functions. Offline check regenerates and compares without rewriting accepted artifacts. Ownership markers protect unrelated directories; concurrent context/input changes and drift reject publication. All 218 updater tests pass. A typed 39-package projection of generation 1 (one generated base64-bytestring root and 38 boot records) regenerates identically after relocation, passes scoped no-IFD, and preserves both dependency and actual immutable Rei CLI derivations through the unchanged runtime reference validator. The first extension eagerly forced final.ghc and recursed; validation is now delayed inside each package and the rejected artifacts are retained. [Prototype receipt](../evidence/ep19/recipe-artifacts-prototype.json). Source-pin conversion, complete context/export and native matrix coverage, the retained factory adapter, targeted update/rollback, performance and total-cost adoption remain open; M2/M3/M4 are not complete.

2026-10-17 M2 context handoff: `cohort generate --context-output FILE` exports every field of the accepted `GenerationContext` through a versioned reader that reuses the freeze parser and classifier. Selected version/boot/context files stage together; `--check` compares without rewriting; concurrent freeze/source/policy/lock changes reject promotion. An explicit `--repository` (default current directory) aligns lock capture and compiler selection. All 213 updater tests pass, including deterministic repeat, classification-preserving round trips, malformed contexts and guarded publication. Immutable `e4cb2f1` also passes the complete Nix updater build and installed CLI help on aarch64-darwin and x86_64-linux in the user-selected translated Apple guest; [native matrix](../evidence/ep19/generation-context-native-matrix.json). [Receipt](../evidence/ep19/generation-context-export.json). This is the source-context prerequisite only: complete recipe artifacts, offline artifact checking and converter/configuration bindings remain open, as do M3/M4 and performance adoption.

2026-10-17 bounded follow-up: all five actually used closed dependency roots preserve retained/generated/checked-constructor derivations, regenerate byte-identically and evaluate with IFD disabled. They include C sources and Custom Setup. Two redundant default-false flag spellings require explicit metadata-hash-guarded normalization after conversion; converter output files remain untouched. Five alternating scoped pairs measure 1.3501 → 1.1647 s (13.73%), below the predeclared 20% threshold. Whole-consumer pairs are diagnostic because brief producer commit hooks overlap that interval; no fine improvement claim or production promotion is accepted. [Receipt](../evidence/ep19/generated-recipe-five-root-followup.json). Package-set-wide expansion is not justified by these measurements.

2026-10-17 M1 prototype: generated native fixtures preserve all nine legacy derivations, revised metadata adds the required dependency, the flag changes behavior, and a pinned source retains Custom Setup plus explicit native zlib mapping. The generated fixture evaluates with IFD disabled and all executable checks pass. The shared Haskell conversion adapter verifies metadata before/after invocation and rejects drift, unsupported classifications and scratch-path leakage; all 174 updater tests pass (including the added transient-directory leak rejection). `base64-bytestring` 1.2.1.0 revision 1 is reachable in Rei's actual graph and preserves the exact retained, generated and checked-constructor derivation. Its generated scoped root evaluates without IFD. An initial bytestring-lexing prototype also matches, but is not reachable in the CLI and is not the sole real-consumer evidence.

Five fresh baseline queries (evaluation cache disabled, warm sources/translation outputs) take 1.486–1.552 s for the scoped legacy root and 3.498–3.569 s for the real archived Rei consumer. Before candidate measurement, require at least 20% median saving for the scoped query, above this baseline spread. Report the full checked consumer separately. The captured reference still imports other unconverted packages (first observed: Diff); no whole-constructor no-IFD claim is made. Five alternating pairs preserve identical scoped and real-consumer derivations. Scoped medians are 1.363 s legacy and 1.105 s generated (18.9% reduction), below the predeclared 20% target. Full checked consumer medians are 3.526 s and 3.384 s (4.0%, within observed spread). [The retained receipt](../evidence/ep19/generated-recipe-prototype.json) records all pairs, RSS, exact converter/metadata/recipe identities and limitations. M1 correctness and measurement are established; this result does not justify broad migration or adoption. Generation/migration amortization and native Linux remain unproved.


- [x] (2026-10-17) M1: Exact-metadata conversion, native behavior, derivation parity, scoped no-IFD and real-consumer evaluation measured. The predeclared performance target is not met; retain the prototype without production promotion.
- [ ] M2: Add deterministic recipe generation, source/policy identity validation, and staged promotion.
- [ ] M3: Integrate a scoped generated recipe layer and verify build and derivation parity.
- [ ] M4: Adopt one accepted runtime configuration, measure evaluation, and document limits and ADRs.

## Surprises & Discoveries


2026-10-17: Converting one real dependency avoids its translation and preserves exact derivation identity, but the constructor/reference work dominates consumer evaluation. The 18.9% scoped saving misses the 20% target; the 4.0% consumer saving overlaps timing spread. Expanding conversion coverage needs another bounded measured experiment rather than an inference from the toy fixture.

The delivered generator renders version/source metadata and is active in production, while full recipe construction still uses evaluation-time cabal2nix paths. The runtime constructor imports captured recipe code and validates the final scope against an independent retained reference; a new recipe layer must cover both paths or its claimed no-IFD runtime evaluation can still fail.

## Decision Log

2026-10-17: The bounded artifact generator and offline checker consume supplied local archives and selected metadata. Verify their solved raw hash, unpacked NAR hash, revision cutoff and Cabal identity before promotion, and use the exact unstable converter selected by the pinned Haskell builder. Preserve all classifications and leave fixed source-pin construction with its current owner until its artifact path is implemented. Require a generator ownership marker before replacing directories, stage check output in a private temporary directory, and delay recursive-scope compiler assertions until package evaluation. This checkpoint adds no production selection or speed claim.


2026-10-16: Validate full conversion against a real retained dependency root early, capture new recipe code in a new retained generation, and exercise the actual constructor/reference guard for parity and end-to-end timing, keeping no-IFD claims scoped to generated roots. Own one targeted-update/rollback rehearsal using existing solver/report/publisher interfaces. Treat reduced evaluation and maintenance cost as measured outcomes, including regeneration and migration cost.

2026-10-14: Coordinate this workstream under [MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md). Scoped Mori publication records its production prerequisites and integration relationships; initial fixture work remains independent. Existing generator/runtime ownership and this plan's acceptance remain unchanged.


2026-10-14: Generate complete recipes as a separate follow-on to the accepted cohort contracts. Plan 9 owns source/revision lookup, classification, manifests, comparison, and publication; this plan extends those helpers without another parser or solver.

2026-10-14: Initially cover generated third-party Hackage dependencies and explicitly declared shared source pins in one configuration. Compiler-provided packages use the compiler; fully matching base recipes reuse the base; first-party and application-owned constructors remain unchanged and their remaining IFD is reported. Expand scope only with explicit tests.

2026-10-14: Keep existing policy and tools. Horizon's generated recipes motivate this work, but its profiling/Haddock/jailbreak choices and different compiler lines are not adopted. Preserve this repository's flags and compatibility repairs.

2026-10-14: If the prototype cannot reproduce source/metadata/flags or safely preserve effective build recipes, do not promote a production layer. Record the failed experiment and the concrete remediation needed; a successful fixture does not establish production readiness.

## Outcomes & Retrospective


M1 delivers a tested exact-metadata adapter, portable fixture recipes and measured real-root parity. The performance threshold was not met. The next bounded checkpoint adds generation-context export and staged generated-Hackage artifact generate/check commands with offline local-input verification and real runtime/consumer parity. Complete source-pin conversion, retained factory integration, production artifacts, retained-generation adoption and total-cost acceptance remain pending.

## Context and Orientation


`flake.nix` loads `overlays/registry.nix`, the first-party JSON catalog/lock, and `overlays/compatibility-profiles.nix`, then constructs extensions and overlays. `lib/mkHaskellExtension.nix` composes profiling/Haddock policy and version-scoped registry entries. `lib/mkFirstPartyRegistries.nix` uses `hself.callCabal2nix` for GitHub sources and `hself.callHackageDirect` for Hackage releases. These constructors remain the legacy path. A full recipe is a Nix function describing `mkDerivation` arguments, with dependency arguments resolved by the final recursive package scope's `callPackage`; it does not contain independently prebuilt dependency packages.

`cabal/cohort.freeze` records versions and index-state; `cabal/cohort-sources.json` records sources, metadata identities, flags, and dependency edges. An index-state is the cutoff selecting which Hackage observations and metadata revisions participate. A Hackage metadata revision can change dependency declarations without changing source version. Raw archive SHA256, unpacked-tree hash, and Cabal-file SHA256 identify different objects; keep all applicable identities distinct.

The delivered generator implementation exists in `cli/haskell-nix-update/src/HaskellNix/Update/Cohort/GenerationTypes.hs`, `Generate.hs`, `Render.hs`, and `Revision.hs`. `classifyCohort` takes an explicit `GenerationContext`; `renderCohortVersions` emits a version/source table rather than complete package recipes. `CohortGenerateTest.hs` exercises this preparation. Plan 9 owns the active generation CLI, policy classification, exact metadata lookup, executable manifests, comparator, and cache-publication mechanism. `lib/mkCohortVersionLayer.nix` and `lib/callCohortHackage.nix` instantiate the generated selections. `lib/mkCohortManifest.nix`, `scripts/cohort-manifest.py`, `scripts/cohort-compare.sh`, and `scripts/cohort-cache.py` provide delivered evidence and publication paths. Plan 16 owns `lib/mkRuntimePackageSet.nix`, whose returned `mkApplicationScope`, `validateApplicationScope`, and `mkApplicationManifest` enforce retained recipes. Both plans are Complete locally; `cabal/runtime-cache/keiro-runtime/1/support.json` and `2/support.json` bind accepted matrices to fingerprints. Extend their interfaces instead of recreating them.

[ADR 1](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md) requires one recursive dependency scope and cache identity based on actual inputs, not generation labels. [ADR 2](../adr/2-resolve-the-rei-family-cohort-upgrade-only.md) preserves upgrade-only floors and exact source/metadata/flag observations. [ADR 4](../adr/4-consumer-overlays-define-only-their-own-packages.md) keeps shared recipes in this channel. [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md) separates routine application edits from dependency changes and distinguishes build identity from version parity. [ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md) retains runtime-owned recipes and forbids application overlays from silently changing them. Apply all these constraints to the generated path.

The inspected pinned Nixpkgs `make-package-set.nix` implements `callHackageDirect` through `callCabal2nix`, which builds a cabal2nix expression before importing it. The relevant primary source is `mori://NixOS/nixpkgs`, project-relative `pkgs/development/haskell-modules/make-package-set.nix` at revision `d5dfd8e6716dde34398bc14bc87c10dece9c8c68` (project registry/file-level URI coverage pending). Resolve or acquire a scoped upstream checkout at the actual pin before implementing adapters. Search Mori first; never inspect `/nix/store` for source or generated expressions. Use Nix metadata APIs for build evidence. Do not choose new dependency bounds or pins without checking authoritative registries/releases; this plan requires no such change.

## Plan of Work


### Milestone 1: Prove exact metadata conversion and no-IFD evaluation


Add `checks/fixtures/generated-recipes/` with a small dependency, a dependent consumer, metadata-revision variants, a flag-dependent dependency, and a source-pin fixture. Add `checks/generated-recipes.nix`. Use a declared, pinned cabal2nix tool selected through the same build-tool scope as the channel, not an arbitrary `cabal2nix` on PATH. Inspect its source/help and verify its supported input formats before choosing invocation options. The channel's existing Cabal-version guard belongs to plan 9 and remains intact.

Prototype an explicit generation adapter in `cli/haskell-nix-update/src/HaskellNix/Update/Cohort/Recipes.hs`. Convert exact verified Cabal metadata from the selected index-state, with compiler/system and flags explicitly supplied. Emit a callable Nix function and stable source binding, not a transient absolute path to the generator's scratch directory. Preserve native and Setup dependencies and compiler-specific conditionals. A dependency enabled only by a revised Cabal file must appear in the generated function; applying that revision later merely as a build patch is insufficient.

Wire the fixture through `hself.callPackage` in one recursive scope. Evaluate its `drvPath` with `--option allow-import-from-derivation false`, build it, and run the consumer. Compare effective source, metadata, flags, dependency edges, and output behavior to the legacy constructor. M1 passes when the positive fixture evaluates without IFD and metadata/flag mutations produce the correct dependency changes. If conversion cannot preserve these facts, fix the adapter before proceeding.

Before expanding to all packages, repeat conversion/parity on one actually used generated dependency root from the accepted runtime, including its native/Setup dependencies. Capture baseline evaluation and full consumer-evaluation time, translation count and peak memory. Identify the fraction attributable to this layer and explicitly list remaining IFD from first-party, application, base and validation paths. Predeclare a practical reduction threshold above baseline variability; a no-IFD toy result alone does not justify a package-set-wide migration.

### Milestone 2: Generate and validate portable artifacts


Extend the updater with `cohort recipes generate --context FILE --out DIR` and `cohort recipes check --context FILE --out DIR`. The explicit recipe context is exported from plan 9's accepted generation context; add serialization using its types rather than another source inventory. For runtime generation, plan 16 passes a retained context, not the mutable default freeze. Generation may download verified inputs in an explicit staging directory; ordinary evaluation and offline artifact checking must not query Hackage or Mori.

Emit `manifest.json`, `extension.nix`, and package functions under `packages/` in the supplied output directory. The manifest records schema version, compiler key/version, system/configuration, nixpkgs revision, converter derivation/version, freeze/source-policy identity, and one record per package with its classification, exact source hashes or Git revision/subdirectory, Cabal revision/hash, flags, native/Setup dependency mapping, compatibility-policy identity, and recipe content hash. Every expected generated package occurs once. Boot/base/first-party/application classifications are recorded explicitly; no missing package is silently dropped. Include component roles so tests/build tools are not confused with runtime libraries.

Keep timestamps, support labels, output-directory names, and generation labels out of derivation inputs. Source bindings are stable content identities; recipe imports cannot retain `/tmp` paths or accidentally depend on the generation directory as a whole. Sort output deterministically. A content-identical recipe should retain its build identity after an unrelated manifest or selection-label change.

Stage artifacts and verify complete coverage, hashes, exact revised metadata, and context equality before promotion. Reject a concurrently changed freeze/source/policy input. `check` compares context/artifacts and regenerates when converter/source inputs are explicitly available; it returns 0 for exact agreement, 1 for drift or unverified identity, and 2 for invalid arguments. It must not rewrite outputs. Add tests to `CohortGenerateTest.hs` or a new `CohortRecipesTest.hs` registered in the Cabal test suite, covering revision-only changes, flags, missing hashes, duplicate ownership, unsupported format, transient-path leakage, and byte-identical second generation. M2 passes when a staged repeat produces no diff and negative inputs fail without promoting files.

### Milestone 3: Compose recipes without changing dependency ownership


Add `lib/mkGeneratedRecipeExtension.nix` taking validated `{ manifest; recipes; policyExtension; }`. It returns a Haskell extension that instantiates each generated function with `hself.callPackage` and applies the existing reviewed policy once in the established source/policy order. Integrate as an opt-in path through plan 9's generation layer and plan 16's runtime projection factory. Capture both candidate and reference constructors and their generated artifacts in a new retained generation/configuration. The current `mkRuntimePackageSet` imports captured libraries/registries and checks final dependency derivations against a captured independent reference; changing the live overlay alone cannot update historical generations. Preserve that guard and use the captured generated representation for both scopes. Build and compare a real consumer through `mkApplicationScope` and its reference validation. Probe the same path with IFD disabled to identify remaining excluded first-party/application/base work; because the validator evaluates all owned packages, this probe may still fail for a documented excluded constructor. The mandatory no-IFD gate covers the declared generated roots; it is not a promise that the entire runtime constructor is IFD-free. Never bypass production validation to obtain a no-IFD pass, and measure its full evaluation cost before adoption. Keep legacy `mkFirstPartyPackageSet` behavior, immutable historical selections, and channel aliases unchanged.

Treat an unsupported compiler/system/configuration as an explicit error for the selected generated layer; do not silently substitute a different configuration or fall back to live cabal2nix. Existing legacy consumers can keep their existing path. Audit conflicting source ownership through the existing consumer overlay audit. Add `generated-recipes-fresh`, `generated-recipes-no-ifd`, and `generated-recipes-parity` checks to `checks/default.nix`. The no-IFD check/query is scoped to the declared generated dependency roots; report first-party, application-owned, updater bootstrap, or base exceptions that still use IFD instead of claiming the whole flake is IFD-free.

Compare actual derivation identities and graph manifests with plan 9's comparator, not only package versions. An initial recipe representation change may legitimately alter a derivation; isolate and explain it, verify effective inputs, and keep the generated path opt-in until accepted. Unrelated selection/label changes must not alter generated dependency identities. Real version/source/metadata/flag/native dependency changes must invalidate affected dependents. M3 passes after fixture builds and supported native matrix comparisons establish these behaviors and existing cache-identity checks still pass.

### Milestone 4: Adopt one retained configuration and measure the result


Using the accepted plans 9 and 16 contracts, generate one candidate default-compiler runtime configuration for Apple Silicon and x86 Linux as separately explicit artifacts. Store retained artifacts using their runtime-generation scheme, with content identities for package recipes; do not mutate an older generation. Update runtime projections to consume those artifacts and compare a representative application through the existing manifest API. Keep non-target compilers/configurations and source channels explicit and do not broaden support from one successful cell.

Measure at least five paired trials of the same evaluation query before/after with warm source inputs but no target output build; use fresh Nix evaluation processes and control the evaluation cache identically, alternate baseline/candidate order, and record medians, spread, memory, converter work moved to regeneration, and exact roots/configuration. Also measure the full consumer query to expose remaining IFD. The scoped evaluation result must exceed the M1 threshold; if whole-consumer time is unchanged, describe that limit. Include initial rebuild/republish costs when representation changes derivations. Report regeneration/migration cost C and evaluation saving S, and ceil(C/S) uses to break even when S is positive. Keep production defaults unchanged until representative use repays the cost; no positive measured benefit means the evaluation-performance outcome remains unmet. Run no-IFD evaluation for those roots, native builds, actual executable parity, and publication through plan 9's existing cache mechanism. Changed application compilation remains owned by the independent [plan 18](18-accelerate-application-code-compilation-in-nix-builds.md); no incremental compiler benefit is claimed here.

Rehearse one real targeted package update in a disposable checkout with the existing `scripts/cohort-update.py`/`just cohort-update` workflow, holding unrelated versions, index-state and toolchain fixed. Use its impact report to explain source, metadata, flags, policy and reverse dependency changes; explicitly request any needed wider unlocks. Generate the candidate artifacts, run freshness/policy checks, compose and build an actual consumer, publish through the existing cache mechanism, then select the previous retained generation to demonstrate rollback. Repeat generation byte-for-byte and verify unaffected recipes/derivations and all old generation bytes remain unchanged. Also inject a stale/concurrent context and a dependency conflict: each must leave accepted artifacts untouched with an actionable reason. Do not hand-edit generated recipes or add a parallel solver.

Perform the rehearsal once after M2/M3 in fixtures and again here on the real configuration. Integrate EP-21's report when delivered; otherwise retain explicit current-policy evidence, with the final umbrella integration checking the report handoff. Record baseline/candidate maintenance elapsed time, commands/manual interventions, changed recipe count, affected dependent count and unexplained rebuilds. Acceptance requires a reproducible documented path without duplicated per-consumer pins; any increased maintenance cost must be explained against measured evaluation benefit rather than hidden.

Update `docs/user/maintainer-tools.md` and `docs/user/package-sets.md`, including reserved logs per their profiles. Create `docs/adr/8-pre-generate-locked-dependency-recipes-outside-nix-evaluation.md` only if that number is still unused at implementation; inspect local filenames first and allocate the next unused filesystem number otherwise. Record measured benefits and remaining IFD boundaries. M4 passes only when the exact targeted configuration is usable by a real application, fresh-worker cache publication evidence is retained by the existing owner, and all claimed evaluation improvements are measured.

## Concrete Steps


Run from this repository. Initial fixture commands and updater subcommands below are deliverables added by this plan; the context files must be exported from the accepted generator before production commands can run.

```bash
nix develop -c cabal test all --test-show-details=direct
nix eval --raw .#checks.aarch64-darwin.generated-recipes-no-ifd.drvPath --option allow-import-from-derivation false
nix build --no-link --print-build-logs .#checks.aarch64-darwin.generated-recipes-parity
nix run .#haskell-nix-update -- cohort recipes generate --context checks/fixtures/generated-recipes/context.json --out generated/recipe-fixture
nix run .#haskell-nix-update -- cohort recipes check --context checks/fixtures/generated-recipes/context.json --out generated/recipe-fixture
nix flake check --print-build-logs
just check-docs
nix fmt -- --ci
```

Repeat generation in a second temporary output directory and compare with `diff -ru`; expect no differences. The no-IFD query prints one derivation path without attempting a cabal2nix build. A deliberately changed Cabal revision or source hash makes `check` exit 1 and leaves accepted outputs byte-identical. Run the corresponding native x86 Linux targets on the configured native builder. Use Nix metadata APIs and saved structured manifests for comparison; never traverse the store or infer static dependency parity from runtime filename lists.

## Validation and Acceptance


Acceptance covers exact metadata conversion, flags, source pins/subdirectories, native and Setup dependencies, deterministic portable artifacts, stale/concurrent input rejection, safe staged promotion, and no-IFD evaluation of declared roots. Compare sources and effective recipes at identical versions, including a revision-only change that adds a dependency. Reject duplicate/conflicting ownership and unsupported configuration selection.

Build both targeted systems and preserve all existing first-party/channel/cache-identity checks. Record actual generated and legacy root identities and executable behavior using the shared comparator. Production publication and fresh-worker substitution use plan 9's machinery; no second publisher is introduced. Report the remaining IFD classes, and distinguish lower evaluation cost from unchanged whole-package recompilation. A positive toy fixture alone cannot complete production acceptance. The real constructor/reference-validation path, targeted-update/rollback rehearsal, predeclared evaluation improvement and total-cost comparison are required; a maintenance-only result cannot be reported as faster builds.

## Idempotence and Recovery


Generation writes only to a staging/output directory and promotes after verified context equality. Repeating generation/check is deterministic. A download, converter, unsupported-format, or concurrent-change failure leaves accepted artifacts untouched. Retained runtime generations are append-only. Restore the prior explicit recipe mode in a consumer if rollout fails; retain the failed candidate and evidence for diagnosis, without altering older runtime definitions. Do not update compiler pins, clear stores, rewrite snapshots, or remove user-generated files to obtain a passing comparison.

## Interfaces and Dependencies


`HaskellNix.Update.Cohort.Recipes` extends the existing `GenerationContext`, `ClassifiedPackage`, `GenerationMetadata`, and revision helpers with an explicit `RecipeGenerationContext` containing system/compiler/tool identities and effective configuration. Separate pure validation/rendering from downloading and converter execution. The generation CLI takes a serialized context and destination; there is no implicit latest/default selection. The manifest and extension describe one recursive scope and retain source/metadata/flag/policy/native identities.

`lib/mkGeneratedRecipeExtension.nix` instantiates full package functions in the final scope and preserves policy ordering. Plan 9 owns the generator context, classifications, comparator, manifests, and cache publication. Plan 16 owns retained-runtime schema and conflicts. This plan owns recipe conversion/artifacts, no-IFD guards, and evaluation measurements. It is not a prerequisite for finishing either existing plan; activation consumes their accepted outputs afterward. The system-independent toolchain metadata initiative in `mori://shinzui/haskell-nix-dev/masterplans/2-publish-verified-haskell-toolchain-capabilities-and-support-evidence` is an optional integration aid, not a hard dependency.

## Revision Notes


2026-10-14: Created from the Horizon comparison, reconciled existing cohort/runtime ownership, and checked native plan structure, canonical references, milestones, and intention bindings. This records planning, not implementation or independent review.

2026-10-14: Added umbrella membership and scoped Mori opt-in while preserving implementation boundaries and existing prerequisites.

2026-10-16: Updated delivered generator/runtime context; added early real-root measurements, captured-reference parity and scoped no-IFD validation, targeted-update/rollback evidence and regeneration/migration amortization before default adoption.
