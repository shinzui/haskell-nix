---
id: 21
slug: manage-compatibility-exceptions-and-verify-their-continued-necessity
title: "Manage compatibility exceptions and verify their continued necessity"
kind: exec-plan
created_at: 2026-10-14T17:03:19Z
intention: "intention_01m4xnts6yewd84gx1ymajdzdv"
mori_publish: true
master_plan: "docs/masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-14T17:03:19Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-14T17:08:07Z
      mode: "other"
      note: "Define structured exception lifecycle, explicit dependency test/bounds policy, and evidence-backed removal probes."
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
      at: 2026-10-17T06:42:24Z
      mode: "implement"
      note: "Begin explicit legacy compatibility catalog and immutable build-policy migration."
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-10-17T03:26:00Z
      verdict: "comments"
      note: "Reviewed against current repository contracts and applied maintenance/performance findings; new implementation and benchmark evidence remain pending."
---

# Manage compatibility exceptions and verify their continued necessity

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective current. Distill lasting implementation decisions into local Architecture Decision Records (ADRs).

## Purpose / Big Picture


A maintainer should be able to explain every active compatibility exception, see where it applies, run the affected dependency tests, and establish when the exception can be retired. Add structured exception metadata, selected-configuration reports, explicit package test/bounds policies, and reproducible removal probes. After implementation, `nix run .#haskell-nix-update -- compatibility report --context FILE --json` lists applied, inactive, unverified, and retirement-candidate entries, with their owners, reasons, exact inputs, and test evidence. A separate validation configuration attempts applicable dependency tests with bounds enforced and names every remaining approved waiver.

The initial migration preserves existing production recipes. Stronger validation is a separately identified configuration, with its own derivations and truthful receipts. No report automatically removes a workaround, changes a source pin, advances a compiler, or modifies an immutable runtime generation. Successful removal requires the affected native checks and a reviewed normal policy update.

This is a standalone plan covering exception lifecycle and the validation necessary to retire exceptions. Existing cohort generation, shared ownership, and retained runtime work remain under [plan 9](9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md), [plan 10](10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md), and [plan 16](16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md). Pure fixtures and the current channel migration can start independently. Integration with generated/retained configurations consumes those delivered interfaces when available; it is not a new prerequisite for their existing acceptance.

## Progress

2026-10-17 M1 in progress: a schema-1 catalog covers 89 executable registry rows plus generated first-party/cohort constructors and named legacy profile waivers (98 entries). Every migrated entry remains unverified. Unicode-data's always-applied test waiver and compiler-guarded metadata repair have separate IDs. Construction helpers preserve their existing operation order and pin legacy profile modes. Validation and pure negative fixtures cover guards, ownership, duplicate IDs, coverage and waiver references. M2 groundwork extracts the lazy first-always/first-matching selector, and production compiler/version/system guards now consume the same catalog predicate. Exact inner package-version guards remain exact rather than being widened to outer registry ranges. All 192 pure expectations evaluate without failures. Four retained Apple Silicon generation/channel cells preserve compiler, fingerprint and package derivations. Current full-registry queries require an unrealized Codd source/translation and were left blocked while compilation is disabled during timings; Linux requires unavailable native translation. [Partial evidence](../evidence/ep21/catalog-migration-partial.json). Full matrix/focused native checks remain pending; no policy narrowing or native test claim is made.


- [ ] M1: Define the exception catalog and explicit build-policy profiles; migrate current entries without changing production derivations.
- [ ] M2: Share dispatch semantics with selected-configuration reports and retirement-candidate evaluation.
- [ ] M3: Add isolated strict validation and exception-removal probes with complete receipts and negative fixtures.
- [ ] M4: Verify a real dependency pilot, integrate retained policy evidence, and document the workflow and ADR.

## Surprises & Discoveries


2026-10-17: Cohort construction also suppresses tests before common registry repair dispatch. Coverage therefore includes that generated constructor as well as hand-written rows and first-party wrapping. A metadata catalog alone cannot establish the effects of an arbitrary patch function; selected-configuration reporting remains M2 acceptance. Reading the real functions found exact inner version guards narrower than their outer half-open registry range; the migrated shared predicates preserve both boundaries. Source-manifest/Cabal assertions remain in build hooks and are never treated as passed merely because a predicate matches.

No retirement decisions are recorded. The source baseline and already documented exceptions are described in Context and Orientation.

## Decision Log


2026-10-16: Use delivered generator/runtime evidence interfaces and report exact policy/evidence impact for targeted maintenance. Keep expensive strict probes out of routine evaluation/build/shell entry, while retaining all required explicit native checks and the independent policy pilot.

2026-10-14: Coordinate this workstream under [MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md). Scoped Mori publication records its production prerequisites and integration relationships; initial fixture work remains independent. Existing generator/runtime ownership and this plan's acceptance remain unchanged.


2026-10-14: Preserve existing production behavior during catalog migration, then narrow exceptions through explicit evidence-backed changes. New exceptions require scope, reason, owner, evidence requirements, and a retirement condition; old unverified behavior remains visibly unverified during migration rather than acquiring invented compatibility evidence.

2026-10-14: Distinguish deliberate source selection and durable build policy from temporary compatibility repairs. A source pin is not obsolete merely because it is always applied, and an inactive row may still be required by a retained historical configuration.

2026-10-14: Build reports from the same pure selector and effective recipe construction used by the registry. Never duplicate version dispatch, force package versions into attrset structure, or infer a function's arbitrary side effects solely from its declared metadata.

2026-10-14: A retirement condition identifies a candidate, not proof. Suppress the particular recipe entry before constructing the candidate, preserve other inputs, and verify the relevant behavior. Test and bounds waivers remain explicit in strict-validation receipts; waived or blocked checks cannot be labeled passed.

2026-10-14: Catalog prose and evidence locations are metadata. Changing a reason, owner description, or report timestamp must not rebuild production dependencies. Changing effective source, metadata, flags, patches, test policy, or dependency inputs legitimately changes build identity.

## Outcomes & Retrospective


M1 declaration and migration work is in progress; acceptance is pending. Structured exception metadata, policy migration, reports, strict-validation outputs, and retirement evidence remain pending.

## Context and Orientation


`overlays/registry.nix` declares package rows with `always` or version ranges and a `patch` function. `lib/fixPackageByVersion.nix` selects the first always row, otherwise the first matching half-open version range, and applies it lazily inside the package attribute value. A half-open range includes `min` and excludes `max`. Moving these conditions into attrset structure can force Nixpkgs' recursive package evaluation too early and cause infinite recursion. Preserve that design.

`checks/default.nix` currently validates only the executable row shape. Some compiler/source guards live inside patch functions, including `patches/metadata/admitting-revision-ghc914.nix` and `patches/kioku-core/0.8.0.2-ghc9141.nix`. A report that sees only an outer `always` row would incorrectly claim those guarded repairs apply everywhere. `patches/bytestring-lexing/0.5.nix` documents an admitting release and retirement threshold; the Kioku repair additionally requires a fixed compiler to build the unchanged source without its coercion-optimization flag. Preserve these protections and evidence while making scope machine-readable.

`lib/mkFirstPartyRegistries.nix`'s `wrapPackage` applies `dontCheck` and `doJailbreak` to every selected first-party recipe. `dontCheck` disables Nix dependency test execution; `doJailbreak` relaxes package dependency bounds. Many shared rows combine these operations too. A successful build therefore does not prove those package tests ran or their original bounds were respected. `cabal/common.config` already carries package-qualified `allow-newer` entries with reasons and retirement comments, but its broad union solve disables tests and benchmarks. Application inventories and acceptance tests provide separate evidence; do not claim the union solve itself tested dependencies.

`lib/mkHaskellExtension.nix` composes profiling/Haddock policy and selected registry functions. `lib/mkFirstPartyPackageSet.nix` preserves selected sources, applies explicitly declared `afterFirstParty` repairs afterward, and checks immutable compatibility-profile conflicts. `lib/mkConsumerOverlayAudit.nix` and `lib/consumerOverlayReport.nix` enforce shared recipe ownership. Existing selected family/group snapshots and compatibility profiles must keep their meanings; do not introduce an accidental global policy change for historical selections.

The existing updater command dispatch lives in `cli/haskell-nix-update/src/HaskellNix/Update/Cli.hs`; its tests are registered in `cli/haskell-nix-update/test/Main.hs` and the package's Cabal file. `Cohort/GenerationTypes.hs`, `Generate.hs`, `Render.hs`, and `Revision.hs` own generation context, exact metadata identities, and classification. Extend them through their existing owners for manifest/policy integration; do not write another freeze parser or dependency solver. [Plan 19](19-pre-generate-complete-locked-nix-haskell-dependency-recipes.md) consumes effective compatibility policy in generated full recipes and must retain the same policy identities. This plan covers the policy catalog and validation that those artifacts consume.

[ADR 1](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md) requires one recursive dependency scope and actual transitive identity for cache reuse. [ADR 2](../adr/2-resolve-the-rei-family-cohort-upgrade-only.md) preserves floors and exact source/metadata/flag identities and requires scoped exceptions. [ADR 4](../adr/4-consumer-overlays-define-only-their-own-packages.md) keeps shared policy in the channel. [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md) distinguishes version parity, build identity, and behavioral evidence. [ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md) forbids silently changing retained runtime-owned policy. Carry these constraints into both production and validation configurations.

The repository has filesystem ADRs and `mori.dhall` does not declare a profiled ADR bundle. Preserve that convention. For dependency APIs and upstream evidence, first use `mori registry search`, `mori registry show --full`, and `mori registry docs`, then read the exact source/docs. Before proposing retirement based on a newer release, verify the authoritative package registry and upstream tags. Retirement reports use locked input facts; ordinary Nix evaluation never looks up latest upstream state. Do not traverse `/nix/store` or search the filesystem root; use build logs and Nix metadata APIs for evidence.

## Plan of Work


### Milestone 1: Describe existing behavior without changing it


Add `config/compatibility-exceptions.json`, `config/package-build-policies.json`, and `lib/validateCompatibilityPolicy.nix`. The exception catalog uses `schemaVersion = 1` and stable entry IDs referenced from registry rows and reusable build-policy profiles. Each entry records kind (`source-selection`, `compatibility-repair`, or `build-policy`), canonical Mori owner, nonempty reason, verified upstream references when available, declared effects, applicability, evidence requirements, and retirement/review conditions. Effects name source replacement, Cabal metadata repair, source patch, compiler flags, bound relaxation, test suppression, or unbreaking as applicable. Source selections retain exact source identities through the existing lock/generator; metadata must not become a second source lock.

Applicability records package names, channel, compiler range or exact compiler, system, version/source/metadata guards, and layer position such as `afterFirstParty`. Represent unknown or not-applicable values explicitly. A repair without a known upstream issue records that fact and a local verification requirement rather than an invented link. Retirement predicates include selected-version thresholds, selected metadata identity, or a successful no-workaround compiler probe. Durable policy/source choices use an explicit review trigger and reason rather than an arbitrary expiry date.

Build-policy profiles record package test mode (`run` or `skip`), bounds mode (`enforce` or `relax`), services required by tests, and exception IDs justifying every skip or relaxation. Separate test suppression from bounds relaxation. Reuse one documented versioned policy profile where appropriate instead of copying the same waiver prose into every package. Capture the packages/configurations affected by that profile in reports. Migrating the blanket first-party wrapper starts with a named legacy profile preserving its actual behavior; its evidence status is unverified until real checks exist. New or widened skips/relaxations require an explicit scoped record and verification requirements.

Refactor `wrapPackage` and shared registry helper construction to apply these explicit effective policies. Preserve current source selection and ordering, the schema-2 family/group topology, profiling/Haddock choices, and old public APIs. Old selections resolve the retained legacy profile rather than silently inheriting a changing current default. Any additional persistent policy reference uses a backward-compatible explicit migration whose legacy mapping is immutable; do not retrofit altered policy into older runtime/group records.

Add pure fixtures in `checks/unit.nix` and `checks/fixtures/compatibility-policy/` for missing IDs/reasons/owners, invalid guards, dangling evidence/waiver references, duplicate IDs, orphan recipe bindings, and invalid policy combinations. Registry coverage includes generated first-party wrapping and retained profile policy, not only hand-written common rows. Compare before/after production derivations with the current selected configurations. M1 passes when every current compatibility effect has a declared owner/reason/scope or an explicit unverified legacy record, malformed entries fail, and unchanged production recipes retain their identities. No package test or retirement is claimed yet.

### Milestone 2: Report exactly which entries apply


Extract the dispatch decision from `lib/fixPackageByVersion.nix` into `lib/selectCompatibilityEntry.nix`, preserving the first-always/first-matching semantics and lazy package-attribute behavior. The pure selector takes entry descriptors and explicit resolved facts; executable rows and reports consume the same decision. Move reportable compiler/source guards into shared predicates while preserving executable source-drift checks. Validate metadata against recipe bindings rather than letting declared scope disagree with an internal branch. Prohibit ambiguous new overlapping rows; migrate any existing overlap explicitly while preserving its selection semantics.

Add `lib/compatibilityReport.nix` and expose `lib.compatibilityReport` for a selected `{ packageSet; channel; ghc; system; runtimeConfiguration ? null; }`. Facts come from the selected constructed recipes after source selection and before the relevant repair, not from stock Nixpkgs when a generated/first-party source has replaced it. Report applied entries, inactive entries and why, retirement candidates and their unmet checks, unverified legacy effects, test/bounds waivers, and exact policy/source/compiler identities. An unmatched row needed by a historical selection is inactive in this context, not globally obsolete. Separate report-only metadata from inputs that affect recipes.

Add `HaskellNix.Update.Compatibility.Types`, `Report`, and `Cli` under `cli/haskell-nix-update/src/HaskellNix/Update/Compatibility/` and register a `compatibility` command group in `Update/Cli.hs`. `compatibility report --context FILE --json` consumes a deterministic context exported by the Nix report adapter or the existing generator/runtime manifest adapters. `compatibility check --context FILE` fails on missing policy coverage, mismatched effective effects, invalid references, and stale evidence for required claims. A valid report may contain explicitly labeled unverified legacy entries; a validation configuration requiring their evidence cannot call them passed. Exit codes are 0 for successful reporting/valid required checks, 1 for drift or unmet required evidence, and 2 for invalid arguments.

Add `compatibility-policy` and `compatibility-report` flake checks with fixture contexts for version thresholds, inactive compiler guards, exact metadata revisions, source mismatch, both source channels, and retained generations. M2 passes when a Kioku-style guard is reported inactive outside its exact compiler/source, a metadata repair matches only its declared revision scope, an admitting-release threshold becomes a candidate, and report/application decisions agree for every fixture without recursive evaluation.

### Milestone 3: Test strict policy and individual removal candidates


Add `lib/mkPackageValidation.nix`, `checks/package-validation.nix`, and native fixture packages under `checks/fixtures/package-validation/`. Produce a separate validation configuration from the same explicit source/compiler selections. Construct recipes under the intended validation policy before applying functions, so disabling a jailbreak flag afterward cannot pretend to undo an earlier source/metadata rewrite. Default validation requires applicable tests and enforced declared bounds; every retained waiver is named in the receipt. Do not append a blanket permissive overlay to force a green result.

When dependency tests introduce additional packages or tools, inventory those inputs, roles, hashes, and policies too. If the retained configuration lacks a required test dependency, report a configuration gap and route an explicit cohort/configuration update through its existing owner. Do not silently solve against live Hackage, change the production freeze, or drop a failing suite. A service requirement such as PostgreSQL or Kafka needs a declared isolated test environment; absent services produce blocked/unverified status, not success. Unit-only suites run natively without services. Fixtures must prove that both skipped-service and provisioned-service outcomes are recorded honestly and that a failing enabled suite fails the check.

Implement a removal probe that suppresses one compatibility entry ID during recipe construction while retaining all other source, metadata, compiler, flag, and policy inputs. A source-selection entry can be omitted only if another declared selected layer supplies the identical intended source; otherwise it is not a same-input retirement probe. Run a fixture that needs a workaround and fails without it, then a fixed-input fixture that succeeds without it. Candidate success includes relevant tests and exact executable behavior, not compilation alone. Fixture failures capture bounded logs and expected causes; a network or missing-service error is not evidence that the workaround is necessary.

Add `compatibility verify --context FILE --entry ID --out DIR` and `compatibility verify-receipt --context FILE --receipt FILE` to the updater. Verification creates staged receipts; it never edits registry files or locks. A schema-version-1 receipt names the entry, input context, policy/source/metadata hashes, compiler/system/channel, baseline/candidate derivations, effective bounds/test policy, dependency graph, required probes, native execution results, and remaining waivers. Use plan 9's manifest/identity helpers when available, with the same receipt facts in local fixtures beforehand. Labels include passed, failed, waived, blocked, and unverified. An all-required-passed outcome is the only successful validation claim; an explicitly waiver-qualified outcome is never described as bounds enforced or tests run for waived packages.

M3 passes when false-positive fixtures are rejected: tests disabled but marked passed, relaxed bounds presented as enforced, a correct and wrong dependency instance together, a receipt from another compiler/source/policy, an omitted transitive test dependency, and an absent service treated as a pass. A changed reason or report timestamp does not change production recipes; a genuine effective-policy change invalidates the affected validation recipe.

### Milestone 4: Prove a real pilot and preserve retained history


Inventory the currently selected matrix and pilot the real `bytestring-lexing` package, whose existing repair selects a released version admitting newer compiler bounds and whose prior plan records test execution. Reverify current facts: historical comments are not fresh results. Run its actual applicable suite with bounds enforced on native Apple Silicon and x86 Linux for an explicit declared compiler/channel configuration. If the selected metadata does not admit that compiler, retain the necessary exception and report the blocker; never lower floors or broaden unrelated versions. Demonstrate at least one real test/bounds-policy narrowing with fresh evidence before promoting the stronger policy, choosing another recorded applicable dependency explicitly if the pilot cannot establish that outcome.

For retirement reporting, use an actual selected source/metadata/compiler condition that satisfies a catalog predicate when one exists. Verify the no-entry candidate; if none currently satisfies retirement conditions, retain all repairs and record no eligible real retirement, alongside the successful controlled removal fixtures. A plan that tracks necessity must not invent an obsolete repair to complete its demonstration. Preserve legacy support as declared while marking waived/unverified coverage precisely.

Connect effective exception/policy identities to plan 9's delivered `lib/mkCohortManifest.nix` and comparator, plan 16's delivered `lib/mkRuntimePackageSet.nix` and immutable runtime records, and plan 19's recipe artifacts when delivered. Plans 9 and 16 are Complete locally as of 2026-10-16; consume their actual interfaces rather than waiting for replacement contracts. Retain older profile definitions under immutable names and introduce a new profile/generation for accepted effective-policy changes. Historical selections keep their previous recipes. The integration cannot become a dependency cycle: these existing plans do not wait for this plan's pilot; this plan consumes accepted contexts afterward and fixture acceptance remains independently runnable.

Update `docs/user/adding-patches.md`, `docs/user/maintainer-tools.md`, `docs/user/package-sets.md`, and their reserved log through the existing documentation profile workflow. Show catalog creation, reporting, strict validation, blocked-service handling, receipt checking, and reviewed retirement. Add the next unused filesystem ADR for evidence-backed compatibility exception lifecycle after inspecting `docs/adr/`; do not guess a number already reserved by another active plan. Preserve canonical Mori references to external owners and upstream issue artifacts. For a selected dependency update, report which exception IDs changed applicability, which evidence was invalidated, and the precise probe needed to regain each required claim. Include unaffected entries whose evidence remains valid. Pass this report and effective-policy identity into EP-19's targeted-update rehearsal once available; preserve standalone fixtures so EP-19 does not become a hard prerequisite. Document a short report/check/probe path that does not require manual edits to generated artifacts or duplicated policy records. Validation probes run explicitly or in designated CI; ordinary builds and shell entry must not rerun the strict matrix, query live upstream releases, or change inputs. Measure the cost of that maintenance path separately from production build latency.

M4 passes after the real policy-narrowing pilot, native receipts, unchanged historical identities, actionable update-impact reporting, existing channel/audit checks, and documentation validation. Completion does not imply every existing waiver has been retired.

## Concrete Steps


Run from this repository. New attributes/subcommands and fixture contexts below are implementation deliverables, not present at plan creation.

```bash
nix develop -c cabal test all --test-show-details=direct
just nix-test
nix build --no-link --print-build-logs .#checks.aarch64-darwin.compatibility-policy
nix build --no-link --print-build-logs .#checks.aarch64-darwin.compatibility-report
nix build --no-link --print-build-logs .#checks.aarch64-darwin.package-validation
nix run .#haskell-nix-update -- compatibility report --context checks/fixtures/compatibility-policy/context.json --json
nix run .#haskell-nix-update -- compatibility check --context checks/fixtures/compatibility-policy/context.json
nix run .#haskell-nix-update -- compatibility verify --context checks/fixtures/compatibility-policy/context.json --entry fixture-obsolete-repair --out /tmp/haskell-nix-compatibility-probe
nix run .#haskell-nix-update -- compatibility verify-receipt --context checks/fixtures/compatibility-policy/context.json --receipt /tmp/haskell-nix-compatibility-probe/receipt.json
nix flake check --print-build-logs
just check-docs
nix fmt -- --ci
```

The report prints deterministic JSON with selected compiler/source/policy facts and entry statuses. The fixed fixture's removal probe produces a passed receipt; the still-needed fixture fails without its repair. A deliberately altered source/compiler or a falsified skipped-test result makes `verify-receipt` exit 1. Repeating report/probe at identical inputs reproduces the relevant identities; timestamps may differ only in observation metadata. Run equivalent native x86 Linux checks on the configured native builder and record its exact configuration. Use temporary evidence directories and Nix metadata APIs, never store traversal or production services.

## Validation and Acceptance


Catalog and report tests prove complete effect coverage, valid ownership/reasons/guards, matching executable dispatch, inactive historical rows, exact metadata/source guards, and no recursive evaluation. Build-policy tests distinguish test execution from suppression and declared-bound enforcement from relaxation. M1 migration retains current production derivations and channels; stricter configurations have separate identities and complete declared test dependencies.

Every required behavioral claim has a matching native receipt. Missing services, stale evidence, disabled tests, relaxed bounds, wrong dependency instances, and incomplete coverage cannot yield an unqualified pass. A real dependency demonstrates at least one evidence-backed narrowing, with bounds/test results scoped to its declared matrix. Retirement requires a verified candidate and a subsequent explicit policy update; reports and probes never auto-delete entries or update pins. Existing first-party selection, consumer audit, generated recipe freshness, and cache-identity checks continue to pass. Retained snapshots/configurations keep their prior effective policy and source identities.

## Idempotence and Recovery


Reports and checks are read-only; probes build explicit baseline/candidate recipes in disposable environments and stage their receipts. Failure leaves source pins, catalog recipes, runtime locks, and accepted evidence unchanged. Use a fresh output directory or verify its existing input context before reuse. Bound and terminate only test/service processes started by the probe; never connect to production databases or brokers. Keep the legacy production profile during migration and roll back a failed pilot by selecting that prior immutable profile rather than editing its contents. No compiler refresh, broad cohort solve, automatic retirement, store deletion, or historical rewrite is part of this plan.

## Interfaces and Dependencies


`lib/validateCompatibilityPolicy.nix` takes catalog, profile definitions, and recipe bindings and returns normalized data or field-specific errors. `lib/selectCompatibilityEntry.nix` takes descriptors and resolved input facts and returns the same selected ID/status used by lazy executable dispatch. `lib/compatibilityReport.nix` takes an explicit configuration plus effective facts and produces JSON-evaluable entry/test/bounds/retirement results. `lib/mkPackageValidation.nix` accepts a selected recipe-construction context, explicit validation profile, required packages/probes, and declared service environment; it returns validation derivations and their receipts without changing production constructors.

The updater's new Compatibility modules validate contexts, invoke explicit Nix check targets, and verify receipts. Share parsing of policy/profile/context data between report and verification; do not maintain a second dispatch or freeze parser. Catalog IDs join recipes and evidence; recipe-affecting identity excludes prose and observation timestamps. Capture actual effective policy and dependency graphs through existing generator/runtime manifest APIs when delivered, distinguishing validation dependency instances from production ones.

This plan owns structured exception metadata, package test/bounds policy, reports, removal probes, receipt rules, and a real narrowing pilot. Plans 9, 10, 16, and 19 keep generation/manifests, shared ownership, retained runtime, and full recipe conversion respectively. The coupled lifecycle/validation feature remains one four-milestone plan, now coordinated by [MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md) at the user's request for cross-repository progress tracking. The toolchain capability and smoke-check initiative at `mori://shinzui/haskell-nix-dev/masterplans/2-publish-verified-haskell-toolchain-capabilities-and-support-evidence` supplies optional identity/evidence integration and is not a hard prerequisite. Hoogle/documentation tooling is outside this plan's scope.

## Revision Notes


2026-10-14: Created from the compatibility lifecycle and dependency-test gaps identified after the Horizon comparison. Reconciled existing generator/runtime ownership, retained historical policy, and separate production/validation evidence. This records planning, not implementation or independent review.

2026-10-14: Added umbrella membership and scoped Mori opt-in while preserving implementation boundaries and existing prerequisites.

2026-10-16: Reconciled delivered generator/runtime interfaces and added actionable update/evidence impact plus the EP-19 rehearsal handoff; separated explicit validation cost from routine build latency.
