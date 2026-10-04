---
id: 16
slug: create-the-keiro-runtime-package-set-and-compose-applications-on-it
title: "Create the Keiro runtime package set and compose applications on it"
kind: exec-plan
created_at: 2026-10-04T14:38:53Z
intention: "intention_01m3fw8cpte9xtje3e5j7f2ng2"
master_plan: "docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-04T14:38:53Z
---

# Create the Keiro runtime package set and compose applications on it

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log,
and Outcomes & Retrospective current. Update relevant ADRs when durable context changes.


## Purpose / Big Picture

Projects using Keiro should select one tested runtime generation and add their own packages
and other library families to it. An application-only change must retain the runtime's
shared dependency builds. A runtime upgrade should identify the changed components and
consumers, rather than requiring every project to rediscover a compatible combination.

This plan delivers the named `keiro-runtime` baseline, immutable runtime generations,
matching Cabal imports, and `lib.mkRuntimePackageSet` for composing application selections
into one Haskell dependency scope. It includes Keiki, Keiro, Kiroku, Shibuya, pgmq-hs,
Settei, pg-migrate and the maintained hw-kafka-client fork, plus required adapters and
transitive dependencies. Available runtime components are not mandatory dependencies of
every application: Nix remains lazy and applications build only what they use.

The observable proof is two fixture applications with different application dependencies
using the same runtime generation. Their shared runtime packages have identical derivation
and output paths. Changing an unrelated application selection retains those identities;
trying to replace a runtime dependency fails with a named conflict. Fresh Cabal plans match
the selected runtime and complete application cohort. Real application adoption belongs to
plans 11–13, which now depend on this plan.


## Progress

- [ ] Prerequisites: plans 9 and 10 are Complete, including the shared solver/generator/comparator contracts inherited from plan 8.
- [ ] M1: Inventory runtime roots, adapters, source forks and dependency closure; define and validate runtime lock records without changing catalog topology.
- [ ] M2: Capture an immutable runtime generation and generate its Cabal/source/Nix projections using the existing cohort tools.
- [ ] M3: Export `lib.runtimePackageSets`, `lib.mkRuntimePackageSet` and runtime build outputs; prove application composition in one scope with conflict fixtures.
- [ ] M4: Verify supported builds, fresh-worker cache substitution and runtime integration evidence; hand the exact generation and APIs to consumer plans.
- [ ] Completion: update user guides, outcomes and ADR 7, and reconcile the MP-3 registry and affected consumer contracts.


## Surprises & Discoveries

At planning time, `lib.mkFirstPartyPackageSet` requires a complete group-to-generation map.
It cannot directly accept a runtime-only subset. The schema-2 first-party catalog also
rejects new family/group membership with a topology-migration error. A runtime wrapper must
normalize an explicit partial runtime selection plus a complete complementary application
selection before using that constructor; relaxing its existing completeness rule would
break retained consumers.

The catalog includes Keiki and the other requested first-party families except the
hw-kafka-client fork. Separate Shibuya adapters and Kafka integration projects are also not
all catalog families. This plan represents them as explicitly locked source components in
the runtime manifest. Adding them to the first-party catalog is separate catalog migration
work, not a hidden side effect of creating a runtime baseline.

The registered verification project `mori://shinzui/keiro-runtime-kenshou` already has
`cohort/released.json`, `cohort/head.json` and paired Cabal projects (artifact-level URIs
pending). Those describe historical, different runtime combinations. Reuse their component
inventory and verification machinery; do not copy their older versions into the new
upgrade-only cohort or claim that their evidence validates a new generation.


## Decision Log

Decision: put the reusable runtime in MP-3 as phase-1 plan 16, after plans 9 and 10 and before
application adoption. Rationale: the solver, generated package recipes, policy ownership and
shared comparison tools must exist before this plan can publish a usable generation. Read-only
inventory preparation may proceed earlier. Date: 2026-10-04.

Decision: retain the eight requested runtime families/components, with Keiki required, and
inventory adapters and transitive dependencies. Keep existing family/update-group boundaries.
Rationale: a shared compatibility baseline does not require every family to advance on every
patch. Date: 2026-10-04.

Decision: add an immutable runtime manifest and a composition wrapper while preserving the
schema-2 first-party catalog and the complete-selection API. Store non-catalog forks/adapters
as locked runtime source components. Rationale: this delivers source identity and reusable
selection without rewriting historical family topology or silently extending old mappings.
Date: 2026-10-04.

Decision: derive runtime version constraints and Nix recipes from the existing Cabal solve;
use a retained runtime projection as constraints during subsequent application-only updates.
Rationale: independent solvers would recreate version drift, while metadata labels alone do
not preserve a dependency build. Date: 2026-10-04.

Decision: compose package recipes into one recursive Haskell scope, and reject application
changes to runtime-owned dependency inputs. Rationale: combining separately built scopes
could create duplicate package instances and invalidate runtime reuse. Date: 2026-10-04.


## Outcomes & Retrospective

Planning complete; implementation and all runtime/cache evidence are pending. This plan is
not authorization to deploy applications, migrate databases or publish first-party releases.
At completion, record the actual supported configurations, retained generations, cache paths,
consumer hand-off and remaining limitations, then distill them into ADR 7.


## Context and Orientation

Work in the repository root. Its canonical project is `mori://shinzui/haskell-nix`.
`config/first-party-families.json` declares fourteen source-repository families. Most are
independent update groups; `shikumi-baikai` is an existing atomic group.
`packages/first-party-lock.json` retains family snapshots, group snapshots and complete named
sets. A snapshot captures exact source revision/hash, package inventory and discovery policy.
A group generation selects family snapshots and a compatibility profile. Generation numbers
are opaque identities, not package versions.

`lib/mkFirstPartyPackageSet.nix` exports a constructor taking exactly one of `packageSet` or
`selections`, plus channel/profiling/Haddock options. The GitHub channel uses locked source
revisions; Hackage uses recorded released sources. Its factory merges common registry,
compatibility profile and selected first-party recipes into one extension. A recipe describes
how to build a package using the final recursive scope, so all users resolve the same named
dependency. `lib/mkHaskellExtension.nix` and `lib/mkHaskellOverlay.nix` construct those outputs.
`flake.nix` binds the factory, supported compilers and public `lib` outputs.

`lib/validateFirstPartyPackageSetLock.nix` and the updater's
`cli/haskell-nix-update/src/HaskellNix/Update/{Catalog,PackageLock,Plan,Workflow,Types}.hs`
validate immutable first-party data and implement snapshot operations. `Cli.hs` dispatches
commands. Extend these through a new `HaskellNix.Update.Runtime` module and focused tests;
reuse existing version, source, hash, error and workflow helpers. Do not add a parallel updater.

Hard prerequisites are
`docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md`
and `docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md`.
Plan 8, `docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`,
owns the Cabal solver inputs, version parser, upgrade report and targeted update machinery.
Plan 9 owns generated Hackage recipes, structured build manifests, lock resolution and
`cohort-compare`; plan 10 owns shared policy and consumer overlay audits. Consume these
artifacts and extend their declared inputs. This plan owns runtime membership, retained
runtime records, the composition API and its proof; it does not duplicate their algorithms.

A build manifest identifies the actual executable derivation, compiler/system, package roles,
versions, source/metadata/flag/policy inputs and dependency drv/output paths. A derivation is
Nix's build description. Equal relevant transitive inputs allow the same build to be reused.
Runtime output closures can omit static Haskell libraries, so version strings in executable
closure names do not establish this claim. Use plan 9's verified derivation-graph manifests.

Relevant local decisions are [ADR 1](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md),
which requires immutable snapshots, one scope, complete selections and unchanged-input cache
identity; [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md),
which separates application, dependency and toolchain updates and requires cache evidence;
and [ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md), which records
this runtime boundary. ADRs are plain Markdown here. Numbers 2–4 are reserved for plans 8–10
and number 6 for plan 14; do not take them. Cross-repository adoption retains
`mori://shinzui/rei/okf/adrs/concepts/ADR-18`: Cabal and Nix selectors move and pass together.


## Plan of Work

### Milestone 1: inventory and the retained-runtime contract

At the end, the runtime's membership and its retained record schema are explicit and validated.
Create `config/runtime-package-sets.json` with schema version 1 and a `keiro-runtime` definition.
The required project identities are `mori://shinzui/keiki`, `mori://shinzui/keiro`,
`mori://shinzui/kiroku`, `mori://shinzui/shibuya`, `mori://shinzui/pgmq-hs`,
`mori://shinzui/settei`, `mori://shinzui/pg-migrate` and `mori://shinzui/hw-kafka-client`.
Resolve their sources with Mori and inventory actual Cabal components. Include separate
PGMQ/Kiroku/Kafka adapters and Kafka effect/stream integration when required by the declared
runtime capabilities. Record transport-specific roots so every application need not link Kafka.

Add `packages/runtime-lock.json`, schema version 1, with append-only runtime generation records.
Each record identifies name/generation, exact first-party group selections, non-catalog source
components, compiler/system/channel configurations, the complete transitive package inventory,
cohort/index-state identity, immutable version/source/policy projection files and their hashes.
Records distinguish build tools, compiler packages, libraries and test dependencies. Source
components carry canonical project identity, package name/subdirectory, exact Hackage archive
and metadata revision or Git revision/NAR hash, patches and policy. Required flags are recorded
in a separate configuration projection, not silently added to the version-only freeze.

A runtime dependency is owned by its generation even when it is a third-party transitive
library. The runtime member list is only the roots; the ownership closure is computed from
solved component dependency edges. Reject duplicate package ownership, conflicting source
records, missing/unknown group generations, broken projection hashes and undeclared support
configurations. A generation's support is an explicit tested matrix, not an unconditional
reuse of the existing catalog's `curated` label.

Implement matching Haskell and Nix validators with fixtures in
`cli/haskell-nix-update/test/RuntimeTest.hs` and `checks/fixtures/runtime-package-sets/`.
Wire the Haskell test through the Cabal test suite and `test/Main.hs`, and Nix cases through
`checks/unit.nix`. Preserve exact schema-2 validation, all retained sets and the existing
production cache-identity check. Milestone acceptance is fixtures rejecting the omissions
and conflicts above, including omission of Keiki/its required JSON codec, while current
first-party selections still validate unchanged.

### Milestone 2: produce one coherent runtime generation

At the end, a generation has reproducible Cabal and Nix projections and can be checked without
mutating files. Add `runtime snapshot`, `runtime check` and `runtime describe` commands to the
existing updater, implemented in `HaskellNix.Update.Runtime`. Snapshot takes a declared name
and the recorded cohort input, supports `--dry-run`, and appends rather than overwrites a
changed generation. Unchanged effective input returns the existing generation with no diff.
Check validates records and projections; describe prints machine-readable membership,
configuration, source and ownership metadata. Preserve clean-managed-file checks and recover
all managed files together on failure; do not advance toolchain/default selections implicitly.

Extend plan 8's solver input with the declared runtime roots and source policies. If an
adapter/Kafka package is absent from the original application union, feed its actual bounds
into the same solver and upgrade-only report. Request any necessary extra unlocks explicitly;
never resolve a second unbounded runtime cohort. Use the solver/generator commands to refresh
`cabal/cohort.freeze`, `cabal/cohort-sources.json` and the version layer together when necessary.
Create missing first-party observations with the existing immutable snapshot helpers, retaining
all former records and named sets; do not edit their meaning or implicitly regroup families.

Write the runtime-owned projection under `cabal/runtimes/keiro-runtime/<generation>/`:
`cohort.freeze` carries the recorded index-state and exact versions for the runtime closure;
`github.project` and `hackage.project` select the corresponding captured sources/configuration.
Write the associated Nix recipes under `generated/runtimes/keiro-runtime/<generation>.nix`
using plan 9's generator and metadata/hash cache. All shared package entries must agree with
the complete application cohort at publication. Projection is deterministic extraction of
one resolved plan, not another solver. Source-only components may be omitted from Hackage
constraints but must remain checked in the source manifest.

Pin the maintained hw-kafka-client fork consistently in Cabal and Nix when its fixes are
required. Verify current Hackage releases and upstream/fork tags before selecting sources;
local Mori data may lag. Hackage provenance for other first-party libraries does not erase
this declared fork exception. If pure released provenance cannot provide the fixes, describe
that configuration honestly as Hackage libraries plus the retained fork, with exact source
records. Do not publish a weaker unpatched profile under the same runtime identity.

Capture effective source and policy recipes in the runtime record; a mutable reference to
current `overlays/registry.nix` alone cannot preserve an old generation. When a runtime
dependency policy changes, emit a new generation. Reuse plan 10's shared policy definitions
and verify no required policy is missing. Future application-only solves import the retained
runtime projection as exact constraints, preserve its configuration inputs, and solve only
additional application requirements. A conflict requests an explicit runtime update.

Milestone acceptance is a no-write check, byte-identical repeated projection, and fresh Cabal
plans matching both the runtime projection and full cohort. Tampering with an unchanged
package's source/metadata/policy must be detected even when its version stays equal.

### Milestone 3: compose applications on the runtime in one scope

At the end, the public API below works on fixture applications. Implement
`lib/validateRuntimePackageSetLock.nix`, `lib/composeRuntimeSelections.nix` and
`lib/mkRuntimePackageSet.nix`, then bind/export them through `flake.nix`.

`composeRuntimeSelections` accepts runtime group selections and the explicit complementary
application selections. Normalize them to the complete schema-2 group map before invoking
the existing first-party constructor. Every non-runtime group must be provided from a recorded
set or literal mapping; never fill it from a moving default. Identical duplicate selections
are allowed, conflicting duplicates fail and identify the owning runtime group. Preserve
existing atomic group boundaries. The wrapper defaults application selections to empty only
when the normalized runtime mapping is already complete; otherwise report missing groups.

The wrapper supplies retained runtime version/source/configuration recipes and application
recipes to one recursive Haskell scope. Internal factory wiring may accept an explicit
cohort/policy context, while existing public calls retain their behavior. Shared runtime
entries have matching source, metadata, flags, patches and transitive dependency selections;
an application entry with different inputs fails before building. Applications add their own
packages after that extension, and plan 10's overlay audit checks runtime ownership too.
Never union derivations created in two independently solved Haskell scopes.

The complete application cohort still owns application-only dependency constraints. The
runtime projection protects its dependency closure when applying that generated layer. Names
shared by runtime and application layers must agree; an application flag or transitive-version
change that invalidates the runtime requires an explicit new runtime generation/configuration.
Keep runtime generation names, labels, report timestamps and unrelated application selections
out of library derivation inputs. Capture system/compiler/channel identity in manifests.

Expose `lib.runtimePackageSets.keiro-runtime` as JSON-evaluable generation/support metadata.
The `runtime` argument names the set and `generation` selects an immutable record; no implicit
latest lookup exists in `mkRuntimePackageSet`. Return the normalized complete `selections`,
`runtimeSelections`, runtime/source metadata, `haskellExtension` and `overlay`. The extension
keeps the current `haskellLib -> pkgs -> hself -> hsuper` shape so consumer exports compose into
it. Publish `packages.<system>.keiro-runtime` as a build of runtime roots and
`packages.<system>.keiro-runtime-manifest` through plan 9's manifest helper for the selected
configuration. Building all roots is a cache/verification task, not a requirement for every
application build.

Prototype first with the existing small package-set fixtures: one runtime library and two
consumers with different unrelated libraries. Promote the wrapper after drv identity and
collision tests pass. Then use actual runtime packages. Milestone acceptance rejects missing
complementary groups, duplicate conflicting policies and application overrides of runtime-owned
packages; equal inputs compose to identical runtime dependency drv/output paths.

### Milestone 4: prove support, cache reuse and consumer hand-off

At the end, consumer plans can select an exact generation with real evidence. Build the runtime
roots and fixture consumer packages on aarch64-darwin and x86_64-linux with the MP-3 compiler
GHC 9.12.4 and each declared source configuration. Record configured flags, native Kafka
`librdkafka`, PostgreSQL fixture versions, source exceptions and build/test commands. The existing
first-party catalog's curated matrix still covers all its supported compilers/channels; do not
weaken it or claim runtime support for GHC 9.14.1 until its own configuration is tested.

Use the existing binary cache publication interface from plan 9 to publish this exact runtime
closure and demonstrate substitution on a fresh worker. Compare the verified manifests of
both fixture applications and a CLI/documentation-only edit. All used runtime dependencies
with equal inputs retain drv/output paths and incur zero avoidable recompilation. An actual
runtime-library/interface change invalidates that library and its dependent applications;
unrelated family selections remain unchanged. Compare meaningful identity sets from the build
graph, not an empty runtime output closure.

Reuse verification machinery from `mori://shinzui/keiro-runtime-kenshou` with a disposable
cohort descriptor generated from this exact runtime record. Keep its historical released/head
profiles untouched. Use its available smoke scenarios for append/replay, migrations, worker
acknowledgement and PGMQ; include Kafka fatal-error/shutdown checks for the Kafka configuration.
Record the exact scenario/spec identities and manifests. If required assembled verification
is not implemented there, add a small isolated integration fixture here instead of treating
that project's unfinished work as a completion prerequisite. Use disposable PostgreSQL/Kafka
fixtures; never apply migrations to the user's production databases.

Update `README.md`, `docs/user/package-sets.md` and a new
`docs/guides/compose-on-the-keiro-runtime.md`, following their existing OKF metadata/profile/log
requirements. Explain the eight roots, adapter closure, explicit source configuration,
non-runtime selection, conflict procedure and generation update workflow. Hand the exact
runtime generation and resolved source/cohort revision to plans 11, 12 and 13. They own real
application edits, tests and deployment. Plan 14 records this identity in the actual system
manifests and preserves its advisory fleet guard; it must not require every application to
link unused runtime components. Complete this plan only after the declared runtime build/cache
and integration evidence passes; live consumer deployment is not a prerequisite here.


## Concrete Steps

Start in this repository's root and establish the prerequisites with the MP-3 registry.
Inventory paths through Mori; commands below do not traverse the Nix store.

```bash
mori registry show shinzui/keiro --full
mori registry show shinzui/keiki --full
mori registry show shinzui/hw-kafka-client --full
mori registry docs shinzui/keiro-runtime-kenshou
mori path mori://shinzui/keiro-runtime-kenshou
nix eval --json .#lib.firstPartyPackageSets
nix eval --json .#lib.firstPartyGroupSnapshots
just validate
```

The runtime subcommands and outputs below are new contracts implemented by this plan; they
are not available before its milestones. Use actual recorded generations rather than inventing
one from a release version.

```bash
nix run .#haskell-nix-update -- runtime snapshot --name keiro-runtime --cohort-freeze cabal/cohort.freeze --dry-run
nix run .#haskell-nix-update -- runtime snapshot --name keiro-runtime --cohort-freeze cabal/cohort.freeze
nix run .#haskell-nix-update -- runtime check --name keiro-runtime
nix run .#haskell-nix-update -- runtime describe --name keiro-runtime --json
nix eval --json .#lib.runtimePackageSets.keiro-runtime
```

A second unchanged snapshot invocation reports `unchanged` and writes nothing. Check exits
nonzero for missing members, source/hash/policy drift or invalid generation references.

```bash
just nix-test
nix build .#checks.aarch64-darwin.haskell-nix-update --no-link
nix build .#checks.aarch64-darwin.runtime-package-set-composition --no-link
nix build .#checks.x86_64-linux.runtime-package-set-composition --no-link
nix build .#keiro-runtime .#keiro-runtime-manifest --no-link
just cohort-check
just fmt-check
just check-docs
```

Configure a native/remote builder before the Linux command. The new composition check must
print a concise evidence record like the following; path values come from actual manifests.

```text
runtime members: complete
application-a / application-b: shared runtime identities equal
application-only selection update: runtime unchanged
conflicting runtime dependency override: rejected
missing complementary selection: rejected
```

Run cache and disposable integration scenarios as M4 describes, record exact commands and
exit codes, and include a before/after identity table plus fresh-worker substitution log in
Outcomes. Do not claim cache publication solely from an already populated local store.


## Validation and Acceptance

The runtime manifest includes all eight requested roots, Keiki's required codec and the
resolved adapter/transitive closure. Cabal and Nix source configuration and frozen versions
agree for every runtime-owned package, with declared fork provenance preserved. Fresh Cabal
plans for supported tests/benchmarks pass the shared comparator.

Two independently constructed application fixtures using the same runtime generation and
configuration have identical shared runtime drv/output identities. App-only source or
unrelated family changes retain them. Conflicting runtime package versions, sources, metadata,
flags or policies fail by name even when another correct instance is present. Missing ownership
records fail. Native build tools do not produce false package-name collisions.

Existing complete-selection APIs, historical snapshots, default outputs and production
Keiro/OKF independence checks remain valid. Runtime metadata-only edits do not alter dependency
build inputs. Changed runtime inputs append a generation; old runtime records remain selectable
under their declared toolchain and source configuration without consulting a moving default.

Declared aarch64-darwin and x86_64-linux configurations build, disposable runtime smoke checks
pass, and fresh workers substitute published outputs. Runtime support claims name the matrix
actually tested. Plans 11–13 receive a usable exact generation/API without requiring their
application ports to happen first. Documentation checks pass and ADR 7 records the final
contract. No implementation milestone is satisfied merely by adding this plan.


## Idempotence and Recovery

Snapshot construction stages managed files and validates them before publication. Preserve
backups through solver/generator failures and interruption; restore the entire staged set,
including the first-party lock if new observations were appended. `--dry-run`, check and describe
write nothing. Repeated effective input selects the same existing runtime generation.

Published generation records and projection files are immutable. If a generation is wrong,
retain it with honest evidence status and append a corrected one; do not recycle its identity.
Application rollback selects a prior runtime generation/cohort/toolchain pair only when its
binary is compatible with the actual database schema. A runtime set cannot undo a Kiroku
migration. This plan deploys no application and operates only disposable integration fixtures.

Keep new wrappers additive until conflict, identity and historical-selection tests pass.
Rollback an unfinished API by reverting its authored files while retaining user edits; never
rewrite unrelated locks or snapshots. User-guide OKF timestamp changes require log entries.


## Interfaces and Dependencies

The public construction contract is:

```nix
selected = inputs.haskell-nix.lib.mkRuntimePackageSet {
  runtime = "keiro-runtime";
  generation = recordedGeneration;
  channel = "github"; # or the explicitly supported Hackage configuration
  applicationSelections = completeComplementaryGroupMapping;
  disableProfiling = true;
  disableHaddock = true;
};

hs = pkgs.haskell.packages.ghc9124.override {
  overrides = pkgs.lib.composeExtensions
    (selected.haskellExtension pkgs.haskell.lib.compose pkgs)
    applicationOwnPackages;
};
```

Both variables identifying generations/mappings come from recorded metadata. The selected
runtime and all application recipes resolve dependencies through the same final `hs` scope.
The wrapper uses the pinned toolchain; it must reject configurations not supported by the
selected record. Profiling/Haddock choices are build configurations and affect cache identity.

This plan owns `config/runtime-package-sets.json`, `packages/runtime-lock.json`,
`lib/{validateRuntimePackageSetLock,composeRuntimeSelections,mkRuntimePackageSet}.nix`,
`HaskellNix.Update.Runtime`, runtime-specific projection orchestration, API exports and
composition checks. It extends `Cli.hs`, test wiring and `flake.nix` after their predecessor
changes. Plan 8 still owns solving/parsing/reporting; plan 9 owns generation and manifest/
comparison helpers; plan 10 owns shared policy and overlay auditing. Source recipes may be
captured in retained runtime records, with registry definitions reconciled rather than copied
into consumer overlays. No additional third-party solver or dependency library is required.

Consumer plans 11–13 depend on this plan and export actual executable manifests containing
runtime name/generation/configuration plus verified dependency identities. Plan 14 consumes
those fields in its existing guard/reporting contract. Other projects can use the public API;
migrating every reverse dependent is separate work and does not block MP-3.


## Revision Notes

2026-10-04: Created as MP-3's explicit runtime-set and composition workstream after the user
requested a dedicated plan. Membership includes essential Keiki. The plan preserves current
catalog topology, represents non-catalog sources explicitly, and makes runtime delivery a
prerequisite of the three application-adoption plans.
