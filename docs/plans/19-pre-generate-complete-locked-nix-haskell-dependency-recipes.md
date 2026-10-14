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
---

# Pre-generate complete locked Nix Haskell dependency recipes

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective current. Update local ADRs when implementation establishes durable project decisions.

## Purpose / Big Picture


Evaluating a selected shared dependency should read its checked-in recipe rather than run cabal2nix before Nix can finish evaluation. Add deterministic, pre-generated full package recipes for an explicit locked dependency configuration. The recipes preserve exact sources, Hackage metadata, flags, native dependencies, and compatibility policy, and remain composable in the existing single Haskell package scope. After implementation, the scoped generated-dependency fixture evaluates with import-from-derivation disabled, regeneration is byte-identical, and the selected production configuration retains verified dependency identities.

Import-from-derivation (IFD) means Nix builds an output and imports the Nix expression inside that output during evaluation. Removing that step can reduce evaluation work; it does not provide incremental compilation of changed application modules. Benchmark evaluation separately, and make no speedup claim until measured.

This is a standalone follow-on to [plan 9](9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md). It neither repeats its solver/version-generation work nor becomes an adoption gate for its existing consumers. Real-runtime rollout also integrates with [plan 16](16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md). Fixture work can start now; production generation waits for accepted explicit generation inputs from plan 9, and retained-runtime adoption waits for plan 16's delivered configuration.

## Progress


- [ ] M1: Prove a complete recipe can be generated from exact locked metadata and evaluated without IFD.
- [ ] M2: Add deterministic recipe generation, source/policy identity validation, and staged promotion.
- [ ] M3: Integrate a scoped generated recipe layer and verify build and derivation parity.
- [ ] M4: Adopt one accepted runtime configuration, measure evaluation, and document limits and ADRs.

## Surprises & Discoveries


No implementation measurements are recorded. The current generator preparation renders version/source metadata, while production source construction still uses evaluation-time cabal2nix paths.

## Decision Log


2026-10-14: Coordinate this workstream under [MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md). Scoped Mori publication records its production prerequisites and integration relationships; initial fixture work remains independent. Existing generator/runtime ownership and this plan's acceptance remain unchanged.


2026-10-14: Generate complete recipes as a separate follow-on to the accepted cohort contracts. Plan 9 owns source/revision lookup, classification, manifests, comparison, and publication; this plan extends those helpers without another parser or solver.

2026-10-14: Initially cover generated third-party Hackage dependencies and explicitly declared shared source pins in one configuration. Compiler-provided packages use the compiler; fully matching base recipes reuse the base; first-party and application-owned constructors remain unchanged and their remaining IFD is reported. Expand scope only with explicit tests.

2026-10-14: Keep existing policy and tools. Horizon's generated recipes motivate this work, but its profiling/Haddock/jailbreak choices and different compiler lines are not adopted. Preserve this repository's flags and compatibility repairs.

2026-10-14: If the prototype cannot reproduce source/metadata/flags or safely preserve effective build recipes, do not promote a production layer. Record the failed experiment and the concrete remediation needed; a successful fixture does not establish production readiness.

## Outcomes & Retrospective


Planning only. Recipe artifacts, generation commands, production adoption, and performance evidence remain pending.

## Context and Orientation


`flake.nix` loads `overlays/registry.nix`, the first-party JSON catalog/lock, and `overlays/compatibility-profiles.nix`, then constructs extensions and overlays. `lib/mkHaskellExtension.nix` composes profiling/Haddock policy and version-scoped registry entries. `lib/mkFirstPartyRegistries.nix` uses `hself.callCabal2nix` for GitHub sources and `hself.callHackageDirect` for Hackage releases. These constructors remain the legacy path. A full recipe is a Nix function describing `mkDerivation` arguments, with dependency arguments resolved by the final recursive package scope's `callPackage`; it does not contain independently prebuilt dependency packages.

`cabal/cohort.freeze` records versions and index-state; `cabal/cohort-sources.json` records sources, metadata identities, flags, and dependency edges. An index-state is the cutoff selecting which Hackage observations and metadata revisions participate. A Hackage metadata revision can change dependency declarations without changing source version. Raw archive SHA256, unpacked-tree hash, and Cabal-file SHA256 identify different objects; keep all applicable identities distinct.

Generator preparation already exists in `cli/haskell-nix-update/src/HaskellNix/Update/Cohort/GenerationTypes.hs`, `Generate.hs`, `Render.hs`, and `Revision.hs`. `classifyCohort` takes an explicit `GenerationContext`; `renderCohortVersions` emits a version/source table rather than complete package recipes. `CohortGenerateTest.hs` exercises this preparation. Plan 9 still owns activation, generation CLI, policy classification, exact metadata lookup, executable manifests, comparator, and cache-publication mechanism. Plan 16 owns retained runtime records and guarded application composition. At implementation time read their delivered interfaces; do not overwrite their types or presume unchecked milestones are complete.

[ADR 1](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md) requires one recursive dependency scope and cache identity based on actual inputs, not generation labels. [ADR 2](../adr/2-resolve-the-rei-family-cohort-upgrade-only.md) preserves upgrade-only floors and exact source/metadata/flag observations. [ADR 4](../adr/4-consumer-overlays-define-only-their-own-packages.md) keeps shared recipes in this channel. [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md) separates routine application edits from dependency changes and distinguishes build identity from version parity. [ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md) retains runtime-owned recipes and forbids application overlays from silently changing them. Apply all these constraints to the generated path.

The inspected pinned Nixpkgs `make-package-set.nix` implements `callHackageDirect` through `callCabal2nix`, which builds a cabal2nix expression before importing it. The relevant primary source is `mori://NixOS/nixpkgs`, project-relative `pkgs/development/haskell-modules/make-package-set.nix` at revision `d5dfd8e6716dde34398bc14bc87c10dece9c8c68` (project registry/file-level URI coverage pending). Resolve or acquire a scoped upstream checkout at the actual pin before implementing adapters. Search Mori first; never inspect `/nix/store` for source or generated expressions. Use Nix metadata APIs for build evidence. Do not choose new dependency bounds or pins without checking authoritative registries/releases; this plan requires no such change.

## Plan of Work


### Milestone 1: Prove exact metadata conversion and no-IFD evaluation


Add `checks/fixtures/generated-recipes/` with a small dependency, a dependent consumer, metadata-revision variants, a flag-dependent dependency, and a source-pin fixture. Add `checks/generated-recipes.nix`. Use a declared, pinned cabal2nix tool selected through the same build-tool scope as the channel, not an arbitrary `cabal2nix` on PATH. Inspect its source/help and verify its supported input formats before choosing invocation options. The channel's existing Cabal-version guard belongs to plan 9 and remains intact.

Prototype an explicit generation adapter in `cli/haskell-nix-update/src/HaskellNix/Update/Cohort/Recipes.hs`. Convert exact verified Cabal metadata from the selected index-state, with compiler/system and flags explicitly supplied. Emit a callable Nix function and stable source binding, not a transient absolute path to the generator's scratch directory. Preserve native and Setup dependencies and compiler-specific conditionals. A dependency enabled only by a revised Cabal file must appear in the generated function; applying that revision later merely as a build patch is insufficient.

Wire the fixture through `hself.callPackage` in one recursive scope. Evaluate its `drvPath` with `--option allow-import-from-derivation false`, build it, and run the consumer. Compare effective source, metadata, flags, dependency edges, and output behavior to the legacy constructor. M1 passes when the positive fixture evaluates without IFD and metadata/flag mutations produce the correct dependency changes. If conversion cannot preserve these facts, fix the adapter before proceeding.

### Milestone 2: Generate and validate portable artifacts


Extend the updater with `cohort recipes generate --context FILE --out DIR` and `cohort recipes check --context FILE --out DIR`. The explicit recipe context is exported from plan 9's accepted generation context; add serialization using its types rather than another source inventory. For runtime generation, plan 16 passes a retained context, not the mutable default freeze. Generation may download verified inputs in an explicit staging directory; ordinary evaluation and offline artifact checking must not query Hackage or Mori.

Emit `manifest.json`, `extension.nix`, and package functions under `packages/` in the supplied output directory. The manifest records schema version, compiler key/version, system/configuration, nixpkgs revision, converter derivation/version, freeze/source-policy identity, and one record per package with its classification, exact source hashes or Git revision/subdirectory, Cabal revision/hash, flags, native/Setup dependency mapping, compatibility-policy identity, and recipe content hash. Every expected generated package occurs once. Boot/base/first-party/application classifications are recorded explicitly; no missing package is silently dropped. Include component roles so tests/build tools are not confused with runtime libraries.

Keep timestamps, support labels, output-directory names, and generation labels out of derivation inputs. Source bindings are stable content identities; recipe imports cannot retain `/tmp` paths or accidentally depend on the generation directory as a whole. Sort output deterministically. A content-identical recipe should retain its build identity after an unrelated manifest or selection-label change.

Stage artifacts and verify complete coverage, hashes, exact revised metadata, and context equality before promotion. Reject a concurrently changed freeze/source/policy input. `check` compares context/artifacts and regenerates when converter/source inputs are explicitly available; it returns 0 for exact agreement, 1 for drift or unverified identity, and 2 for invalid arguments. It must not rewrite outputs. Add tests to `CohortGenerateTest.hs` or a new `CohortRecipesTest.hs` registered in the Cabal test suite, covering revision-only changes, flags, missing hashes, duplicate ownership, unsupported format, transient-path leakage, and byte-identical second generation. M2 passes when a staged repeat produces no diff and negative inputs fail without promoting files.

### Milestone 3: Compose recipes without changing dependency ownership


Add `lib/mkGeneratedRecipeExtension.nix` taking validated `{ manifest; recipes; policyExtension; }`. It returns a Haskell extension that instantiates each generated function with `hself.callPackage` and applies the existing reviewed policy once in the established source/policy order. Integrate as an opt-in path through plan 9's generation layer and plan 16's runtime projection factory. Keep legacy `mkFirstPartyPackageSet` behavior, immutable historical selections, and channel aliases unchanged.

Treat an unsupported compiler/system/configuration as an explicit error for the selected generated layer; do not silently substitute a different configuration or fall back to live cabal2nix. Existing legacy consumers can keep their existing path. Audit conflicting source ownership through the existing consumer overlay audit. Add `generated-recipes-fresh`, `generated-recipes-no-ifd`, and `generated-recipes-parity` checks to `checks/default.nix`. The no-IFD check/query is scoped to the declared generated dependency roots; report first-party, application-owned, updater bootstrap, or base exceptions that still use IFD instead of claiming the whole flake is IFD-free.

Compare actual derivation identities and graph manifests with plan 9's comparator, not only package versions. An initial recipe representation change may legitimately alter a derivation; isolate and explain it, verify effective inputs, and keep the generated path opt-in until accepted. Unrelated selection/label changes must not alter generated dependency identities. Real version/source/metadata/flag/native dependency changes must invalidate affected dependents. M3 passes after fixture builds and supported native matrix comparisons establish these behaviors and existing cache-identity checks still pass.

### Milestone 4: Adopt one retained configuration and measure the result


Once plans 9 and 16 have delivered their required contracts and acceptance, generate one accepted default-compiler runtime configuration for Apple Silicon and x86 Linux as separately explicit artifacts. Store retained artifacts using their runtime-generation scheme, with content identities for package recipes; do not mutate an older generation. Update runtime projections to consume those artifacts and compare a representative application through the existing manifest API. Keep non-target compilers/configurations and source channels explicit and do not broaden support from one successful cell.

Measure wall time for the same evaluation query before/after with warm source inputs but no target output build; record repeated trials and spread, converter work moved to regeneration, and the exact roots/configuration. Run no-IFD evaluation for those roots, native builds, actual executable parity, and publication through plan 9's existing cache mechanism. Changed application compilation remains owned by the independent [plan 18](18-accelerate-application-code-compilation-in-nix-builds.md); no incremental compiler benefit is claimed here.

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

Build both targeted systems and preserve all existing first-party/channel/cache-identity checks. Record actual generated and legacy root identities and executable behavior using the shared comparator. Production publication and fresh-worker substitution use plan 9's machinery; no second publisher is introduced. Report the remaining IFD classes, and distinguish lower evaluation cost from unchanged whole-package recompilation. A positive toy fixture alone cannot complete production acceptance.

## Idempotence and Recovery


Generation writes only to a staging/output directory and promotes after verified context equality. Repeating generation/check is deterministic. A download, converter, unsupported-format, or concurrent-change failure leaves accepted artifacts untouched. Retained runtime generations are append-only. Restore the prior explicit recipe mode in a consumer if rollout fails; retain the failed candidate and evidence for diagnosis, without altering older runtime definitions. Do not update compiler pins, clear stores, rewrite snapshots, or remove user-generated files to obtain a passing comparison.

## Interfaces and Dependencies


`HaskellNix.Update.Cohort.Recipes` extends the existing `GenerationContext`, `ClassifiedPackage`, `GenerationMetadata`, and revision helpers with an explicit `RecipeGenerationContext` containing system/compiler/tool identities and effective configuration. Separate pure validation/rendering from downloading and converter execution. The generation CLI takes a serialized context and destination; there is no implicit latest/default selection. The manifest and extension describe one recursive scope and retain source/metadata/flag/policy/native identities.

`lib/mkGeneratedRecipeExtension.nix` instantiates full package functions in the final scope and preserves policy ordering. Plan 9 owns the generator context, classifications, comparator, manifests, and cache publication. Plan 16 owns retained-runtime schema and conflicts. This plan owns recipe conversion/artifacts, no-IFD guards, and evaluation measurements. It is not a prerequisite for finishing either existing plan; activation consumes their accepted outputs afterward. The system-independent toolchain metadata initiative in `mori://shinzui/haskell-nix-dev/masterplans/2-publish-verified-haskell-toolchain-capabilities-and-support-evidence` is an optional integration aid, not a hard dependency.

## Revision Notes


2026-10-14: Created from the Horizon comparison, reconciled existing cohort/runtime ownership, and checked native plan structure, canonical references, milestones, and intention bindings. This records planning, not implementation or independent review.

2026-10-14: Added umbrella membership and scoped Mori opt-in while preserving implementation boundaries and existing prerequisites.
