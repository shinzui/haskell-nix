---
id: 22
slug: add-hinagata-shoko-heni-and-typesafe-hs-support
title: "Add hinagata, shoko, heni, and typesafe-hs support"
kind: exec-plan
created_at: 2026-10-27T13:46:16Z
intention: "intention_01m5ysptxpewys9zbt0nsbch5w"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-27T13:46:16Z
---

# Add hinagata, shoko, heni, and typesafe-hs support

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log,
and Outcomes & Retrospective current during implementation. Record material implementation
friction using the exec-plan skill's friction workflow and distill durable decisions into
local ADRs before completion.


## Purpose / Big Picture


Make Hinagata, Shoko, Heni, and typesafe-hs available through the repository's locked
first-party package sets. Consumers will select these libraries and command-line programs
from the same composed Haskell scope as existing packages, and maintainers will refresh
each family with `haskell-nix-update refresh --family NAME`. A family means the supported
Cabal packages in one source repository; a scope means the recursive Nix package collection
in which their dependencies resolve.

The requested spelling “hinagate” refers to `mori://shinzui/hinagata`. Support covers eleven
packages: three Hinagata packages, three Shoko packages, four Heni packages including its
optional test-framework adapters, and typesafe-hs. Eight currently have Hackage releases;
Shoko is GitHub-only. Deliver an explicit recoverable catalog migration, retained package
selection, real builds, and offline consumer checks. Implementation has not started.


## Progress


- [ ] Provide explicit additive catalog migration and retained extra-directory discovery, with offline contracts proving preservation, rejection, no-op, dry-run, and rollback behavior.
- [ ] Prove Heni's JSON/mutation behavior and Shoko's native Kafka dependency against the actual shared scope before activating the new inventory.
- [ ] Generate four family snapshots and complete selections, preserving existing records and old group choices; public constructors and repository-owned runtime complements evaluate.
- [ ] Pass the supported system/compiler/channel build matrix and offline consumer checks, document support and migration, and retain acceptance evidence.


## Surprises & Discoveries


## Decision Log


2026-10-27: Treat “hinagate” as Hinagata, the matching Mori project and actual repository.
Include its three top-level packages; keep its nested examples outside ordinary family
discovery. Include Heni's two published nested adapters through explicit retained paths,
without recursively discovering fixtures in every repository.

2026-10-27: Implement an explicit additive migration within schema 2. Extend every named
set with four singleton groups while preserving all old snapshot records and existing
selection entries. Normal refresh continues to reject topology changes. Removal,
regrouping, and repository renaming remain outside this plan. This is the explicit
migration required by ADR 1, rather than a relaxed ordinary refresh decoder.

2026-10-27: Keep the shared dependency freeze and retained runtime generations. Existing
first-party construction applies the declared `legacy-first-party-v1` policy, which relaxes
dependency bounds and skips package tests. Heni's newer declared bounds therefore require
independent compile and behavior evidence against the actual scope. Do not infer compatibility
from relaxed bounds or silently upgrade the cohort if the experiment fails.

2026-10-27: Pin rdkafka-hs 1.0.0.1 as an owned dependency source for Shoko. Its current
Hackage release, 1.1.0.0, is outside Shoko's `<1.1` bound. This dependency is additional to
the four requested families and does not become a fifth independently refreshed family.


## Outcomes & Retrospective


## Context and Orientation


`config/first-party-families.json` is hand-authored policy. It currently contains fourteen
families and thirteen update groups; Baikai and Shikumi share one group.
`packages/first-party-lock.json` retains immutable family snapshots (source, package paths,
versions, discovery policy, and Hackage pins), immutable group snapshots (family generation
references and compatibility profile), and three complete named sets. `default` is curated,
meaning the supported build matrix is required. `keiro-0-14-okf-0-8` and
`keiro-0-14-okf-0-9` are historical. All three currently select thirteen groups.
`flake.nix` declares moving non-flake source inputs; retained GitHub sources instead use
locked revision and content-hash descriptors.

Updater modules live under `cli/haskell-nix-update/src/HaskellNix/Update/`. `Catalog.hs`
reads family policy and resolves groups; `Git.hs:discoverPackages` reads committed Cabal
files at the root or one directory down. `Types.hs` defines `FamilyConfig`,
`DiscoveryPolicy`, and `PackageSetLock`. `PackageLock.hs:validatePackageSetLock` requires
exact catalog/snapshot family and group agreement. `Plan.hs` plans append-only refreshes.
`Workflow.hs` owns dirty-file checks, writes, Nix validation, and restoration of the two
managed locks. `Cli.hs` exposes commands. `migrate-lock` migrates schema 1 to schema 2;
it cannot add a family to an existing schema-2 catalog.

`lib/validateFirstPartyPackageSetLock.nix` independently enforces the complete graph.
`lib/mkFirstPartyPackageSet.nix` projects a named set or complete explicit mapping into
`lib/mkFirstPartyRegistries.nix`, then composes recipes in one Haskell scope.
`lib/applyPackageBuildPolicy.nix` applies existing first-party bounds/test policy.
`checks/package-set-matrix.nix`, wired from `checks/default.nix`, builds every available
selected package for every curated set and channel with every `lib.supportedGhcs`
compiler. Systems in `flake.nix` are `aarch64-darwin` and `x86_64-linux`; discover compiler
names from the pinned toolchain instead of copying old plans.

`lib/mkRuntimePackageSet.nix` combines retained runtime selections with explicit application
complements through `lib/composeRuntimeSelections.nix`. The four new groups become required
complements in the live catalog. `flake.nix:runtimeApplicationSelections` and live-catalog
checks must provide them. Captured directories under `packages/runtimes/` remain immutable.
Consumers adopting the new channel revision must extend explicit mappings; consumers
retaining their old channel pin keep the previous catalog.

Relevant ADRs consulted are
[ADR 1](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md), requiring explicit
catalog migration, complete selections, retained discovery policy, and one scope;
[ADR 3](../adr/3-generate-the-channels-package-versions-from-the-cohort-freeze.md), making
`cabal/cohort.freeze` authoritative for shared dependencies;
[ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md), protecting
retained runtime identities and explicit complements; and
[ADR 10](../adr/10-retain-verified-generated-dependency-recipes-in-the-existing-scope.md),
keeping recipe choices and retained factories explicit. The local ADR corpus uses plain
filesystem records; this work does not introduce a profile or unrelated MasterPlan link.

Discovery on 2026-10-27 used Mori registry list/search/show/docs, local source, upstream Git
HEAD/tags, and Hackage JSON plus released Cabal metadata. Mori is a locator, not release
authority. Recheck all observations during execution.

`mori://shinzui/hinagata` contains `hinagata-core`, `hinagata-postgres`, and `hinagata-cli`
in their same-named top-level directories, all 0.1.0.0 and published on Hackage. HEAD and
dereferenced tag `v0.1.0.0` are `a0c1059743e5957e66e4b8cee9e485ad89471937`. Mori also
lists nested examples at `examples/workbench` and `examples/keiro-service`; these remain
outside the requested supported inventory. See `mori://shinzui/hinagata/docs/guides`.

`mori://shinzui/shoko` contains `shoko-core` 0.3.0.0, `shoko-adapters` 0.2.0.0, and
`shoko-cli` 0.2.0.0 in same-named top-level directories. HEAD is
`58adca36ef5f65ae78a4fa15626dba1ff967fcaf`; no tags or Hackage packages were observed.
See `mori://shinzui/shoko/docs/development`. The adapters require rdkafka-hs
`>=1.0.0.1 && <1.1`, native librdkafka, and c2hs. The binding's immutable release commit
is `45d9e21ad3c72b56c482173e17ca3fa2bd8b1bc7`, the dereferenced `v1.0.0.1` tag of
`mori://shinzui/rdkafka-hs/packages/rdkafka-hs`. Shoko's own build module records source
hash `sha256-lno5sy1FDVLTzHeunuUmnbqNAMGGrFymWyJg/5KgwuM=`; independently verify that
unpacked hash before retaining it. Current Hackage lists only rdkafka-hs 1.1.0.0, so it is
not a substitute for the version Shoko uses. Linked executables require `-threaded`.

`mori://shinzui/heni` has stale registration: its local checkout is absent and its registry
lists two planned packages. Inspection of actual HEAD
`81696f8a2b1263312497e703bae7ac7f2139cd8b` found four packages, all 0.1.0.0: `heni` at
`.`, `heni-cli` at `heni-cli`, and `heni-hspec` / `heni-tasty` at `adapters/heni-hspec` /
`adapters/heni-tasty`. All four have normal Hackage releases. Tag `v0.1.0.0` dereferences
to `3a7978d2e67bf78a8137658f8c27bac93ffc5eaf`. The README still says “unreleased”; the
registry, README, tags, and registry publication therefore must be distinguished. Planning
inspected a disposable clone; implementation must establish a usable Mori checkout.
Canonical adapter package URIs belong under `mori://shinzui/heni/packages/` even while
registry coverage lags.

Heni's released metadata requires Aeson `>=2.3.2 && <2.4` and Crypton `>=2.2.5 && <2.3`.
The shared freeze selects Aeson 2.2.5.1 and Crypton 1.1.5. Heni's strict JSON decoder uses
Aeson's token-stream API, so compilation alone after bounds relaxation is insufficient.
Mori locates Aeson at `mori://haskell/aeson`; inspect the selected version's source and
actual Heni call sites before adding any adapter or workaround.

`mori://shinzui/typesafe-hs/packages/typesafe-hs` is a repository-root package at `.`,
version 0.1.0.0, also on Hackage. HEAD is `c4b56a01dd23f8844d44440887692f6ac64ef564`;
`v0.1.0.0` dereferences to `f79344b9bb48ac49626b1065d7de255bea4b5464`. Source now
includes a servant client; Mori's transport-free description is stale. Read the README
and exports at the selected revision instead of designing a consumer from registry prose.

The authoritative endpoints include
[Heni releases](https://hackage.haskell.org/package/heni.json),
[Hinagata releases](https://hackage.haskell.org/package/hinagata-core.json),
[typesafe-hs releases](https://hackage.haskell.org/package/typesafe-hs.json), and
[rdkafka-hs releases](https://hackage.haskell.org/package/rdkafka-hs.json).
Query each supported package individually. Genuine package-not-found responses become null
Hackage pins; transport or server errors must not be interpreted as unpublished packages.


## Plan of Work


### Milestone 1: Additive catalog migration and retained extra paths


Add `catalog add --from FILE [--dry-run]` in `Cli.hs`, pure planning in a new
`cli/haskell-nix-update/src/HaskellNix/Update/CatalogMigration.hs`, and transaction handling
in `Workflow.hs`. Register new modules in
`cli/haskell-nix-update/haskell-nix-update.cabal`. The input has the existing catalog
shape, `schemaVersion: 2`, `families`, and `updateGroups`, but contains additions only.
Initially accept singleton additions with empty `updateGroups`; reject regrouping,
removal, changed existing identities, conflicting package providers, missing source-input
declarations, and reusing a family name with different policy. Normal refresh remains strict.

First validate the existing lock against the existing catalog. Observe only new families
using the ordinary Mori/Git/Hackage adapters, then stage the enlarged catalog and lock.
Append generation 1 for each new family and singleton group, using profile `default`.
Extend every named set with those explicit selections, keeping all previous entries and
support labels. Compare every old family/group snapshot object for equality. Validate the
complete staged graph through ordinary Haskell and Nix validation, including every affected
named selection under both channels. Report every set's new mappings in the preview.

The transaction owns `config/first-party-families.json`, `flake.lock`, and
`packages/first-party-lock.json`. Require all three to be committed and clean; snapshot
original bytes, guard against concurrent changes before publication, and restore all three
on observation, write, or validation failure. Reuse existing source/hash and atomic-write
helpers. Dry-run publishes nothing. Identical accepted additions replay as a no-op; later
upstream changes are handled by refresh, not by catalog addition.

Extend `FamilyConfig` and `DiscoveryPolicy` with optional `additionalPackagePaths`, a
sorted list of clean repository-relative package directories. Absence means existing
root/top-level discovery; encode empty lists by omitting the field so old snapshots retain
their representation. Heni records exactly `["adapters/heni-hspec", "adapters/heni-tasty"]`.
In `Git.hs`, add `discoverPackagesWithPolicy` and preserve `discoverPackages` as the legacy
wrapper. Union the ordinary inventory with Cabal files directly inside the named extra
directories at the locked Git revision. Reject missing/ambiguous directories, traversal,
duplicate/default paths, and duplicate package names. Do not recursively scan all Cabal
files. Historical checks use captured policy rather than current policy.

Update exact-field decoders, canonical encoders, policy comparisons, refresh/check call
sites, and projections in `Catalog.hs`, `PackageLock.hs`, `Plan.hs`, `Workflow.hs`,
`lib/validateFirstPartyPackageSetLock.nix`, `lib/mkFirstPartyPackageSet.nix`, and where
needed the projected registry contract in `lib/mkFirstPartyRegistries.nix`. Never modify
captured runtime copies. Existing snapshot policy remains semantically and structurally
unchanged when the new field is absent.

Use `cli/haskell-nix-update/test/AdapterTest.hs`, `PackageSetTest.hs`, `PlannerTest.hs`,
`WorkflowTest.hs`, and `checks/unit.nix` for contracts covering nested adapters without
fixtures, historical policy, strict ordinary refresh rejection, deterministic/no-op addition,
unchanged old snapshots/selections, dry-run byte identity, dirty/concurrent-file refusal,
and injected failures at each write and selection validation. Acceptance is passing offline
Haskell/Nix tests while the production catalog still has fourteen families.


### Milestone 2: Prove the risky dependency interactions early


Before activating the inventory, exercise Heni and Shoko through proposed registries in the
actual existing cohort scope. Add `checks/new-first-party-support.nix` with a
`new-first-party-support` derivation in `checks/default.nix`; support injected proposed
registries before activation and the final selected registries afterward.

Introduce one source recipe, for example `patches/rdkafka-hs/source.nix`, dispatched from
`overlays/registry.nix`. Pin released 1.0.0.1 at the verified commit and unpacked hash,
identify its owner as `mori://shinzui/rdkafka-hs/packages/rdkafka-hs`, and follow existing
Kafka source-pin ownership/compatibility declaration conventions. Supply native `rdkafka`
from `pkgs.rdkafka`, retain c2hs, and use existing suppression policy for live broker tests.
Do not replace existing hw-kafka-client or runtime pins. Build a threaded Shoko executable
linked to `shoko-adapters` and invoke help, forcing the binding to link/load without a
broker. Building only `shoko-core` does not prove this interaction.

Compile all four Heni packages with actual frozen Aeson/Crypton and the existing
first-party policy. Enable upstream offline decoder, runner, and adapter tests in
validation-only recipes, since production skips tests. Demonstrate duplicate-key JSON
rejection and a caught/survived mutation pair through the packaged CLI using disposable
files. Check installed fixture data for the root package. Cover GitHub and released
Hackage sources, which need not be identical. Record actual dependency versions and
relaxed-bound limitations; add no new blanket jailbreak.

A narrow version/source-bound adaptation is permitted only when it preserves Heni's
strict validation and mutation semantics and passes direct regression checks. If the older
dependencies cannot implement those behaviors, record the failing API and leave this
milestone incomplete. A cohort upgrade or separate Heni scope needs an explicit scope
revision; do not remove behavior or claim compatibility to force activation. The uncertain
interaction is the reason this proof precedes production migration.


### Milestone 3: Generate locked inventory and complete live constructors


Create `config/catalog-additions/ep22.json` with four sorted records using canonical owners,
`github: shinzui/NAME`, `githubInput: NAME-src`, empty overrides/exclusions, and Heni's
extra paths. Declare corresponding `heni-src`, `hinagata-src`, `shoko-src`, and
`typesafe-hs-src` GitHub inputs with `flake = false` in `flake.nix`. Build the migration
CLI and commit a valid baseline containing code, declarations, and the addition request
while leaving the active catalog unchanged. This avoids bootstrapping through a catalog
that strict Nix evaluation cannot load.

Preview and run the explicit catalog command. Only the updater writes generated locks.
At the researched revisions expect eleven GitHub packages and eight Hackage packages:
Hinagata core/postgres/CLI, Heni core/CLI/two adapters, and typesafe-hs have releases;
Shoko's three records carry `hackage: null`. Never advertise GitHub fallbacks as Hackage
first-party packages. Keep rdkafka-hs dependency-source provenance separate from these
availability counts. Review generated sources, paths, versions, policy and hashes; do not
copy research SHAs into generated files manually.

Extend `flake.nix:runtimeApplicationSelections` and repository-owned live-catalog call
sites with explicit generation-1 complements for the four new groups. Locate them with
scoped searches for `applicationSelections` and `selections`; update completeness fixtures
only when they exercise the live catalog. Preserve standalone old-catalog fixtures and
captured runtime directories. External incomplete mappings should still fail rather than
receive defaults. Evaluate every retained public runtime generation with explicit new
complements and demonstrate unchanged runtime-owned derivation identities. Compare old
first-party derivations as well: adding unused names must not invalidate unrelated recipes.

Acceptance is successful four-family offline/online checks, correct registry availability,
seventeen complete group selections in each named set, equal old records and selections,
working runtime outputs, and a repeated addition preview reporting no changes. Commit the
validated transaction before any further mutating refresh.


### Milestone 4: Native builds, consumer behavior, and documentation


Complete `checks/new-first-party-support.nix` using fixtures under
`checks/fixtures/new-first-party/`. Inspect public exports at the locked revisions before
writing consumers. Hinagata must render CLI help and its pure planner must reject an invalid
identifier. typesafe-hs must encode/decode a representative request or response without API
credentials or external requests. Heni must reject duplicate JSON keys, produce `caught`
with exit 0 and `survived` with exit 1, and link both framework adapters. Shoko help must
execute from a binary linked to its adapters and native Kafka binding. Run package tests
through the selected scope where they provide this evidence; do not mistake the production
skipped-test setting for an upstream test pass.

Build every available new package through the final named-set factory on both systems and
both channels with the discovered supported compilers. Reuse
`checks/package-set-matrix.nix` for full curated-set regressions; all version-mismatch arrays
must be empty. Historical sets remain valid/selectable without being promoted to curated.
Record concise dated results in `docs/evidence/ep22/acceptance.md`: revisions, source channel,
system/compiler, actual inventory, behavior, policy limitations, and pending platforms.
One platform's success cannot stand in for another's build evidence.

Update `docs/user/channels.md`, `docs/user/updating-first-party-packages.md`,
`docs/user/package-sets.md`, and `docs/user/troubleshooting.md` for availability, optional
extra paths, explicit migration, its three-file dirty guard, and changed complete mappings.
Correct the catalog path in `README.md` while describing the four new families. Correct
`agents/skills/update-family/SKILL.md` where its discovery description or old schema workflow
is inaccurate. Maintain affected documentation timestamps/logs with the repository's OKF
tools and run `just check-docs`. Distill durable migration/discovery decisions into relevant
local ADRs, preserving their format. Triage implementation friction before completion.


## Concrete Steps


Run all commands from the haskell-nix repository root. The baseline/discovery commands
exist today; `catalog add` and `new-first-party-support` are interfaces to implement.

```bash
git status --short
mori registry list
mori registry search hinagata
mori registry search shoko
mori registry search heni
mori registry search typesafe-hs
mori registry show shinzui/heni --full
mori registry docs shinzui/heni
mori path mori://shinzui/heni
nix eval --json .#lib.supportedGhcs
nix eval --raw .#lib.defaultGhc
nix develop -c cabal test haskell-nix-update-test --test-show-details=direct
just nix-test
```

If Heni's registered checkout remains absent, inspect `mori register --help`, establish a
deliberate local clone of its canonical repository, and update registration using the
current CLI. Confirm `mori path` returns a usable checkout. Do not rely on the planning
session's temporary clone or search the filesystem root/Nix store. Repeat show/docs and
read selected source for all four projects. Verify release observations:

```bash
git ls-remote https://github.com/shinzui/hinagata.git HEAD 'refs/tags/*'
git ls-remote https://github.com/shinzui/shoko.git HEAD 'refs/tags/*'
git ls-remote https://github.com/shinzui/heni.git HEAD 'refs/tags/*'
git ls-remote https://github.com/shinzui/typesafe-hs.git HEAD 'refs/tags/*'
git ls-remote https://github.com/shinzui/rdkafka-hs.git HEAD 'refs/tags/*'
curl -fsSL https://hackage.haskell.org/package/heni.json
curl -fsSL https://hackage.haskell.org/package/heni-0.1.0.0/heni.cabal
```

Query all eleven package names individually. Current Shoko endpoints return 404; distinguish
that from request failure. After implementing milestones 1 and 2, rerun offline suites and
build the updater. Commit the valid baseline before production mutation. Every implementation
commit uses Conventional Commits and these trailers:

```text
ExecPlan: docs/plans/22-add-hinagata-shoko-heni-and-typesafe-hs-support.md
Intention: intention_01m5ysptxpewys9zbt0nsbch5w
```

Then run the new command and checks:

```bash
nix build .#haskell-nix-update --no-link --print-build-logs
nix run .#haskell-nix-update -- catalog add --from config/catalog-additions/ep22.json --dry-run
nix run .#haskell-nix-update -- catalog add --from config/catalog-additions/ep22.json
nix run .#haskell-nix-update -- check --package-set default --family heni --family hinagata --family shoko --family typesafe-hs
nix run .#haskell-nix-update -- check --package-set default --family heni --family hinagata --family shoko --family typesafe-hs --online
nix run .#haskell-nix-update -- catalog add --from config/catalog-additions/ep22.json --dry-run
```

The first preview describes four new families/groups and four additional mappings in each
of the three sets, without replacing old generations. The final preview reports no changes.
Commit the successful transaction and then use ordinary `refresh --family NAME --dry-run`
for each new family; Heni includes both adapters and no unrelated families. A newer upstream
HEAD is reported drift, not an idempotence failure at unchanged inputs.

```bash
nix eval --json .#lib.registries.github --apply builtins.attrNames
nix eval --json .#lib.registries.hackage --apply builtins.attrNames
nix eval --json .#lib.firstPartyPackageSets
just nix-test
just fmt-check
just check-docs
nix flake check --no-build
nix build .#checks.aarch64-darwin.new-first-party-support --no-link --print-build-logs
nix build .#checks.aarch64-darwin.package-set-default --no-link --print-build-logs
nix flake check --print-build-logs --keep-going
git diff --check
```

Run the corresponding `checks.x86_64-linux` builds on a native or configured remote builder
and the full flake check on Linux. The support check prints selected versions and a short
pass result per behavior. Record missing builders as pending acceptance, not success.


## Validation and Acceptance


All four milestones are required. Offline tests must prove deterministic addition, no-op
replay, strict normal-refresh rejection, unchanged snapshots/old selections, dry-run byte
identity, and restoration of all three managed files after injected publication/validation
failure. Historical policy checks must still work after current discovery policy changes.
The explicit addition yields seventeen groups in each set; Heni discovers four packages
while nested Hinagata examples and Heni fixtures remain excluded.

Through the final factory, the two registries expose eleven GitHub and eight published
Hackage packages at the researched revisions. Shoko's three names remain absent from the
Hackage first-party registry. Actual version comparisons are empty in every supported
compiler/channel cell. Every available package builds on both supported systems, all
specified consumer behaviors pass, and retained runtime construction works with explicit
new complements and equal runtime-owned identities. Evidence distinguishes bounds-relaxed
builds, tests actually executed, and unexecuted upstream suites.

Heni's JSON validation and Shoko's native-linked executable are early representative
integration gates before inventory activation. Compilation alone, successful Nix evaluation,
or removal of behavior cannot replace them. A broader cohort upgrade, new retained runtime
generations, cache publication, downstream repository migration, upstream release publication,
and live database/broker/API access are outside required acceptance.


## Idempotence and Recovery


Repeat discovery, dry-runs, and evaluation safely. Additions append generation 1 once;
subsequent refreshes reuse existing generation deduplication. Never hand-edit generated
locks, prune history, or use an all-family refresh to bootstrap the new catalog. Retain the
addition request as a reviewable artifact; identical accepted family definitions replay as
no-op even if upstream later moves.

Before each mutation, commit a valid baseline of the three managed files. The migration
restores their original bytes on failure. If restoration fails, report each affected path
and preserve saved originals; compare for concurrent edits before restoring transaction-owned
files, and preserve unrelated user changes. Failed early compatibility proofs leave production
selections intact. Record a specific dependency/API blocker before considering a wider scope.

The migration deliberately extends historical mappings, while retaining their old selections
and historical support level. Consumers adopting this channel revision must explicitly add
`heni = 1`, `hinagata = 1`, `shoko = 1`, and `typesafe-hs = 1` to their complement mappings.
Keeping the earlier channel pin is the rollback for consumers not making that transition.
Do not amend any captured runtime snapshot to hide a missing complement.


## Interfaces and Dependencies


This is a standalone ExecPlan. The required new interface is
`haskell-nix-update catalog add --from FILE [--dry-run]`, accepting additive singleton families
only. Existing `refresh`, `check`, `package-set`, and schema-1 `migrate-lock` retain their
meaning. `FamilyConfig` and `DiscoveryPolicy` gain optional `additionalPackagePaths`, omitted
when empty. Haskell and Nix agree on exact fields, path validation, and retained policy.

The four upstream owners are `mori://shinzui/hinagata`, `mori://shinzui/shoko`,
`mori://shinzui/heni`, and `mori://shinzui/typesafe-hs`. Use specific package/doc URIs for
durable cross-repository references. Nix evaluation consumes checked-in records and never
runs Mori or release discovery. Preserve repository-root package handling and family-root
symlink staging.

Shoko adds an owned immutable source recipe for
`mori://shinzui/rdkafka-hs/packages/rdkafka-hs`, native librdkafka, and c2hs. Their actual
native versions remain those of the pinned toolchain unless build evidence establishes a
blocking incompatibility. Heni uses disposable source copies and commands for mutations.
typesafe-hs checks require no API keys or external service. PostgreSQL and Kafka live
integration suites are not prerequisites for the new offline consumer checks.

The shared freeze, boot package selection, declared compatibility policy, and retained
runtime source/recipe records remain authoritative. New source policy participates in existing
ownership/audit checks. A successful legacy bounds-relaxed build remains weaker evidence
than an upstream bounds-valid Cabal solve; preserve that distinction in documentation.
