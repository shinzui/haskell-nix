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
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-17T13:17:55Z
      mode: "implement"
      note: "Add declaration-only compatibility reports, read-only CLI checks and native interchange fixtures; keep production capture and strict evidence gates open."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-17T15:05:53Z
      mode: "implement"
      note: "Deliver explicit native removal plans, general verification and metadata/log receipt replay with strict false-pass and local-service fixtures."
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

Validation handoff (2026-10-17): the full Linux flake check for immutable implementation revision `823bf773e2e52b184a0fd262bf7f7166834b91f8` was last observed live in tool session `96756`. Its guest snapshot is `/tmp/ep21-check-823bf773e2e52b184a0fd262bf7f7166834b91f8`; the host log is `/tmp/ep21-linux-immutable-flake.log`, and `/tmp/ep21-linux-immutable-exit.txt` is written when the process terminates. Poll the same session or inspect authoritative terminal state before any retry. The earlier mutable-source attempt terminated with source-change rejection; it is not the running check. Focused Mac/Linux fixture, real-policy and receipt evidence is already retained independently. Do not turn the still-pending full Linux result into an accepted claim.

2026-10-17 M4 native pilot: `checks/bytestring-lexing-validation.nix` constructs the actual selected 0.5.0.16 source with `strict-v1` before policy application. Exact archive/Cabal hashes agree with the cohort. All 58 `test-all` cases, a 21-instance checked Haskell graph and three parser/serializer behavior cases pass on GHC 9.12.4 Apple Silicon and in the user-selected x86 Linux Apple guest. Source, metadata, flags, hooks, dependency instances and all other recorded effective inputs remain equal to production; only tests become enabled and bounds enforcement becomes explicit. [Evidence](../evidence/ep21/bytestring-lexing-native-policy-pilot.json). No standalone repair is retired. The configured remote builder still names unreadable `/etc/nix/builder_ed25519`; the user-selected Apple guest now supplies qualified Linux target execution instead. Production policy selection, retained evidence integration and update-impact reporting remain pending; no physical-x86 performance claim is made. No older recipe/policy record is changed.

2026-10-17 general native verification: updater `compatibility verify` and `verify-receipt` now consume explicit `lib.mkCompatibilityProbeContext` exports. Verification builds strict baseline/candidate packages and required graph/behavior/service checks; receipt replay checks exact context, complete outcomes, Nix output metadata and original complete suite logs without building. Stale/waived/incomplete receipts fail. Native fixed and bounded loopback-service fixtures pass both suites, graph and executable checks and receipt replay. The needed repair fails its actual suite with `EP21_REPAIR_REQUIRED` and retains a failed receipt. Configure flags cannot bypass enabled tests/enforced bounds. [Evidence](../evidence/ep21/general-native-verification.json) records twelve host CLI receipt/rejection checks plus Linux fixed/service verification/replay and expected needed-repair rejection, with cache conditions and elapsed replay cost. All 203 updater tests, 274 aggregate pure contracts and the native fixture check pass. M3's general fixture workflow is delivered on Apple Silicon and the user-selected translated x86 Linux Apple guest, including actual service-backed suites, metadata/log replay and needed-repair failure. The complete Darwin flake check passes; the full Linux check is being rerun from an immutable snapshot after the mutable-checkout attempt correctly rejected concurrent evidence edits. Production narrowing and M1/M2 matrix/effect acceptance remain open.

2026-10-17 strict-fixture continuation: `lib.mkPackageValidation` now requests the strict profile during recipe construction and suppresses one requested entry. It rejects disabled/jailbroken/custom/filtered suites and changed selected source, metadata, compiler or declared dependency instances; missing service probes block before package construction. Controlled native fixtures prove that a needed repair's removal fails the actual Cabal suite, while fixed input passes tests and executable behavior without it. Passing graph checks reuse `mkCohortManifest`. All 261 pure contracts and native fixture/capture checks pass. [The fixture receipt](../evidence/ep21/strict-native-fixtures.json) records an 18.42 s warm validation path, exact contexts, suite logs and graph/executable checks; uncontrolled caches preclude a performance claim. Requests and overall receipts remain unverified pending the general verifier and remaining coverage. Shared argument inspection now preserves unresolved null dependencies rather than falsely labeling compiler-provided inputs unavailable. M3 and M4 remain open.

2026-10-17 construction continuation: opt-in `captureCompatibility` now observes the real recursive repair boundary and source-constructor stages; `lib.capturedCompatibilityReport` exports actual selected inputs, hidden Cabal arguments, production dependency identities, hook identities and changed fields. Represented test/bounds declaration mismatches fail the report check, and CLI validation rejects inconsistent capture boundaries or omitted mismatch diagnostics. Four representative packages preserve all ordinary derivations across both current compilers and both channels on Apple Silicon; all four reports repeat identically and pass the CLI check. The native capture/report and nix-unit checks pass, with 243 aggregate pure expectations and 184 updater tests. [Evidence](../evidence/ep21/construction-capture.json). Source assertions, arbitrary patch effects, historical constructors without capture hooks and the Linux matrix remain acceptance gaps; no strict test/bounds or retirement result is claimed.

2026-10-17 report continuation: `lib.compatibilityReport` and updater `compatibility report/check` now exchange a schema-1, explicitly declaration-only context. Reports share row/applicability selection, preserve exact caller-supplied pre-repair inputs and immutable profile waivers, distinguish inactive rows/scopes, and keep source guards/native evidence unverified. Required absent/unverified evidence fails; JSON validation rejects forged pass statuses and inconsistent diagnostics. Pure tests cover channel/compiler/version guards, lazy patch functions, candidate-only retirement, source/metadata identity changes, and descriptive-text stability. All 229 aggregate pure expectations and 181 updater tests pass, as do native Nix-to-CLI, policy and nix-unit checks, documentation profiles and formatting. [Evidence](../evidence/ep21/declaration-report.json). Automatic fact capture from production recipe construction, effective-effect comparison, actual source/metadata mismatch probes, and strict validation receipts remain unimplemented; this is M2 groundwork, not M2 acceptance. The configured Linux builder key is still unreadable on this host.

2026-10-17 M1 in progress: a schema-1 catalog covers 89 executable registry rows plus generated first-party/cohort constructors and named legacy profile waivers (98 entries). Every migrated entry remains unverified. Unicode-data's always-applied test waiver and compiler-guarded metadata repair have separate IDs. Construction helpers preserve their existing operation order and pin legacy profile modes. Validation and pure negative fixtures cover guards, ownership, duplicate IDs, coverage and waiver references. M2 groundwork extracts the lazy first-always/first-matching selector, and production compiler/version/system guards now consume the same catalog predicate. Exact inner package-version guards remain exact rather than being widened to outer registry ranges. All 209 aggregate pure expectations evaluate without failures, including channel ordering and checkpoint-origin regression cases. Four retained Apple Silicon generation/channel cells preserve compiler, fingerprint and package derivations. Current Apple Silicon translation sources were realized after timings. All constructible registry entries preserve exact derivations in four compiler/channel cells. Unfiltered queries encounter the existing retrie broken-package guard in both versions; per-entry queries retain that guard and explicitly exclude blocked entries from identity acceptance. Linux requires unavailable native translation. [Partial evidence](../evidence/ep21/catalog-migration-partial.json). Full matrix/focused native checks remain pending; no policy narrowing or native test claim is made.


- [x] (2026-10-17) M1 declaration groundwork: bind all 98 unverified catalog entries and immutable legacy construction profiles; preserve four retained Apple Silicon identities and pass pure validation. Full current/native matrix acceptance remains open below.
- [ ] M1: Define the exception catalog and explicit build-policy profiles; migrate current entries without changing production derivations.
- [ ] M2: Share dispatch semantics with selected-configuration reports and retirement-candidate evaluation.
- [x] (2026-10-17) M2 declaration interchange: implement the pure report adapter, report/check CLI, required-evidence diagnostics and native fixture handoff without claiming verified package behavior.
- [x] (2026-10-17) M2 current construction capture: observe real source/repair stages, inspect hidden Cabal arguments, check represented policy effects and verify repeatable four-cell producer/consumer identity parity without modifying retained recipes.
- [x] (2026-10-17) M3: Deliver isolated strict/removal constructors, explicit native plans, general verification/receipt CLI, complete native suites/graph/behavior/service evidence and false-pass fixtures for the declared Apple Silicon and user-selected translated x86 Linux guest fixture configurations. Production policy and full current/historical matrix claims remain unverified under the real-pilot/integration gates.
- [x] (2026-10-17) M3 construction/native foundation: strict constructor guards, isolated needed/fixed removal fixtures, blocked-service construction, enabled suite/executable checks and existing cohort graph-producer integration. General verify/receipt commands, provided-service native coverage and false-positive receipt checks are delivered by the subsequent general native workflow.
- [ ] M4: Verify a real dependency pilot, integrate retained policy evidence, and document the workflow and ADR.

## Surprises & Discoveries

2026-10-17 strict fixtures: a true `doCheck` flag alone is insufficient: an empty target list, narrowed targets, filtering flags or a replaced check phase can avoid the required suites. The initial strict constructor rejects those cases. Null dependency values also cannot be classified as missing without compiler/selection evidence. The shared inspector records that uncertainty and strict graph checks consume the delivered cohort producer rather than introducing another graph parser. The former `patches/bytestring-lexing/0.5.nix` path is absent from the current tree; generated recipes select 0.5.0.16 and the cohort's legacy test profile. The real pilot must narrow the selected package's actual test policy, not pretend to remove an obsolete registry row.

2026-10-17 construction: final derivation attributes omit some consumed Cabal arguments, so reading `editedCabalFile` or `jailbreak` directly falsely reported unknown metadata/policy. An `overrideCabal` diagnostic projection reads the actual arguments without replacing the produced recipe. Current cborg-json has matching r4 metadata before/after its repair, but `postPatch` still changes the base bound; complete derivations differ, so it is not an automatic retirement candidate. Lazy fetch-tree paths also expose transient aliases if contexts are stripped prematurely. Metadata-only source/hook derivations canonicalize identities before diagnostic output contexts are discarded. Report materialization must not require production or disabled-test output realization. Dependencies retain exact derivation/output-name identities. These constraints are distilled in ADR 8.

2026-10-17: Source guards remain build-time assertions in several recipes. Reporting a matching compiler/version as a successful guard would fabricate evidence. The first report format therefore accepts explicit pre-repair input facts, labels itself declaration-only, and rejects all verified/native-pass statuses. Production fact capture and effective-effect comparison remain mandatory before full M2 acceptance. The report CLI checks its interchange contract rather than reimplementing version dispatch in Haskell.


2026-10-17: Cohort construction also suppresses tests before common registry repair dispatch. Coverage therefore includes that generated constructor as well as hand-written rows and first-party wrapping. A metadata catalog alone cannot establish the effects of an arbitrary patch function; selected-configuration reporting remains M2 acceptance. Reading the real functions found exact inner version guards narrower than their outer half-open registry range; the migrated shared predicates preserve both boundaries. Source-manifest/Cabal assertions remain in build hooks and are never treated as passed merely because a predicate matches.

Channel applicability now compares membership independently of list order. Pure fixtures cover reordered declarations and require an explicit selection for channel-restricted effects; native identities remain a separate gate. New catalog bindings now reject malformed version ranges, overlapping half-open ranges, duplicate always rows, and always/range ambiguity. The public selector independently preserves historical first-match behavior for legacy callers. Six negative/adjacent-range fixtures extend the pure suite to 198 expectations. No retirement decisions are recorded. The source baseline and already documented exceptions are described in Context and Orientation.

## Decision Log

2026-10-17: At the user's request, reuse MP-3's existing `mp3-linux-builder` Apple guest for Linux behavioral validation. Its amd64 binaries execute through Apple translation in an independent Linux store with a read-only source mount. Record `sandbox=false` and guest-only `filter-syscalls=false` explicitly; the latter avoids Rosetta's seccomp setup failure. Preserve default GHC settings. Translated target execution is qualified Linux behavior evidence, following the accepted producer precedent in plan 9; it is not physical-x86 performance evidence. No host builder or global configuration changes are needed.


2026-10-16: Use delivered generator/runtime evidence interfaces and report exact policy/evidence impact for targeted maintenance. Keep expensive strict probes out of routine evaluation/build/shell entry, while retaining all required explicit native checks and the independent policy pilot.

2026-10-14: Coordinate this workstream under [MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md). Scoped Mori publication records its production prerequisites and integration relationships; initial fixture work remains independent. Existing generator/runtime ownership and this plan's acceptance remain unchanged.


2026-10-14: Preserve existing production behavior during catalog migration, then narrow exceptions through explicit evidence-backed changes. New exceptions require scope, reason, owner, evidence requirements, and a retirement condition; old unverified behavior remains visibly unverified during migration rather than acquiring invented compatibility evidence.

2026-10-14: Distinguish deliberate source selection and durable build policy from temporary compatibility repairs. A source pin is not obsolete merely because it is always applied, and an inactive row may still be required by a retained historical configuration.

2026-10-14: Build reports from the same pure selector and effective recipe construction used by the registry. Never duplicate version dispatch, force package versions into attrset structure, or infer a function's arbitrary side effects solely from its declared metadata.

2026-10-14: A retirement condition identifies a candidate, not proof. Suppress the particular recipe entry before constructing the candidate, preserve other inputs, and verify the relevant behavior. Test and bounds waivers remain explicit in strict-validation receipts; waived or blocked checks cannot be labeled passed.

2026-10-14: Catalog prose and evidence locations are metadata. Changing a reason, owner description, or report timestamp must not rebuild production dependencies. Changing effective source, metadata, flags, patches, test policy, or dependency inputs legitimately changes build identity.

## Outcomes & Retrospective


M1 declaration/migration, M2 declaration interchange/current-constructor capture and M3 native verification are implemented. Current capture preserves derivations in four compiler/channel cells. Strict fixtures run actual suites, isolated service-backed tests and executable checks, reject a necessary repair's removal for its expected test cause, and verify passing graphs through the existing producer. Full acceptance remains pending: arbitrary effective-effect comparison, exact source/metadata probes, historical constructor coverage, production receipt integration, the real narrowing pilot and full native matrix.

The M3 general workflow additionally delivers native receipt replay without builds,
strict false-pass rejection and actual isolated service-backed suites. It accepts
only the declared fixture configurations and does not retire any production exception.
Production package-policy narrowing, selected-policy update impact and the full
current/historical matrix remain mandatory work.

## Context and Orientation


`overlays/registry.nix` declares package rows with `always` or version ranges and a `patch` function. `lib/fixPackageByVersion.nix` selects the first always row, otherwise the first matching half-open version range, and applies it lazily inside the package attribute value. A half-open range includes `min` and excludes `max`. Moving these conditions into attrset structure can force Nixpkgs' recursive package evaluation too early and cause infinite recursion. Preserve that design.

`checks/default.nix` currently validates only the executable row shape. Some compiler/source guards live inside patch functions, including `patches/metadata/admitting-revision-ghc914.nix` and `patches/kioku-core/0.8.0.2-ghc9141.nix`. A report that sees only an outer `always` row would incorrectly claim those guarded repairs apply everywhere. The formerly documented `patches/bytestring-lexing/0.5.nix` is absent: `generated/cohort-versions.nix` selects 0.5.0.16 through the cohort constructor and its legacy test policy. Reverify that selected source and narrow an actual waiver rather than assuming the historical row exists; the Kioku repair additionally requires a fixed compiler to build the unchanged source without its coercion-optimization flag. Preserve these protections and evidence while making scope machine-readable.

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


Inventory the currently selected matrix and pilot the real `bytestring-lexing` package. The earlier standalone repair is absent in the current tree; the generated cohort selects 0.5.0.16 with its legacy test-suppression profile. Begin with that actual selection and an explicit package-scoped test-policy narrowing, not removal of a nonexistent registry entry. Reverify current facts: historical comments are not fresh results. Run its actual applicable suite with bounds enforced on native Apple Silicon and x86 Linux for an explicit declared compiler/channel configuration. If the selected metadata does not admit that compiler, retain the necessary exception and report the blocker; never lower floors or broaden unrelated versions. Demonstrate at least one real test/bounds-policy narrowing with fresh evidence before promoting the stronger policy, choosing another recorded applicable dependency explicitly if the pilot cannot establish that outcome.

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
