---
id: 6
slug: make-the-updater-manage-snapshots-and-package-set-selections
title: "Make the updater manage snapshots and package-set selections"
kind: exec-plan
created_at: 2026-09-14T04:03:54Z
intention: "intention_01m2f17g4ye8qtz89rnbvndk5s"
master_plan: "docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md"
provenance:
  revisions:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-21T14:06:32Z
      mode: "update"
      note: "Review-driven corrections to snapshot retention, Nix composition, validation, and migration contracts."
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-21T14:26:46Z
      mode: "update"
      note: "Adopt flake-parts, treefmt-nix, nix-unit, and nix-diff; native checks pass with unchanged existing derivations."
    - model: "gpt-5.6-sol"
      harness: "codex-cli"
      at: 2026-09-22T16:15:55Z
      mode: "implement"
      note: "Implement strict locked-source decoding and append-only package-set refresh planning."
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-21T14:06:32Z
      verdict: "approved"
      note: "Reviewed revised plan against repository and Nix semantics; implementation build and cache acceptance gates remain pending."
---

# Make the updater manage snapshots and package-set selections

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

After this plan, the refresh CLI advances one named package set without rewriting the
selections of any other set. Refreshing OKF appends a new immutable OKF family snapshot and
group snapshot, then moves only the requested set to that generation. Refreshing either
Baikai or Shikumi expands to their complete configured update group and commits both
observations together or neither.

The same CLI can migrate the current flat lock, import a flat lock and matching source
descriptors from repository history, clone a named set, and replace one group selection in
that clone. An operator can therefore construct an older-Keiro/newer-OKF set entirely through
validated commands. Dry runs leave both managed lock files byte-identical, failures restore
them byte-for-byte, and existing snapshots are never edited or pruned.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] Add target-set and update-group-aware CLI parsing while retaining the current default behavior.
- [x] Decode complete locked source descriptors and include them in family observations.
- [x] Plan append-only family/group snapshots and move only the requested package set.
- [ ] Make grouped refresh, validation, writes, and rollback atomic across both managed files.
- [ ] Add deterministic migration, historical import, clone, and group-selection commands.
- [ ] Cover no-op, Hackage-only, grouped failure, dry-run, rollback, and import workflows offline.
- [ ] Preserve schema-1 command dispatch until rollout and validate non-default historical targets independently of tracking inputs.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- The existing refresh already has a useful transaction boundary: it refuses dirty managed
  files, saves their original bytes, writes the package lock only after `flake.lock` updates,
  validates the flake, and restores both originals on failure. The version-2 workflow should
  extend this boundary rather than introduce a second writer.

- `HaskellNix.Update.Nix` currently extracts only `locked.rev` from a flake input. Historical
  GitHub evaluation also needs `type`, `owner`, `repo`, and `narHash`, all of which are already
  present in the direct `flake.lock` nodes.

- The existing workflow tests used deliberately minimal `flake.lock` nodes containing only
  `rev`. Making the revision compatibility wrapper delegate to strict descriptor decoding
  required the fixtures to model the real `type`, `owner`, `repo`, and `narHash` contract.

- The current `checkFamily` requires equality with moving tracking inputs and applies current
  exclusions. Version-2 historical checks must instead use selected source and policy. The
  current flake validator passes `--no-build`; successful evaluation is not build evidence.


## Decision Log

Record every decision made while working on the plan.

- Decision: Keep version-1 refresh/check dispatch operational through EP-6 and validate the
  actual version-2 target on every mutation, including historical sets.
  Rationale: EP-7 must be able to build the updater before migration; checking only the
  default would allow invalid retained selections to be written.
  Date: 2026-09-21

- Decision: Make `--package-set` select the one curated set a refresh is allowed to move; if
  omitted it resolves to `defaultPackageSet`.
  Rationale: This preserves today's convenient default while preventing a family bump from
  silently moving every named set.
  Date: 2026-09-13

- Decision: Resolve every `--family` through the catalog's update-group partition and report
  any expansion before network work begins.
  Rationale: Existing operator muscle memory remains useful, while `--family baikai` cannot
  accidentally leave Shikumi behind. Repeated family/group flags are normalized and deduped.
  Date: 2026-09-13

- Decision: Append a family or group generation only when its normalized content differs
  from an existing snapshot, and otherwise reuse the existing generation.
  Rationale: No-op refreshes and repeated historical imports must be idempotent, while a
  Hackage-only change at the same Git revision must still become selectable state.
  Date: 2026-09-13

- Decision: Read the complete GitHub descriptor from `flake.lock` after each target input is
  updated; do not calculate or trust a NAR hash from Git metadata.
  Rationale: Nix owns the canonical fetch descriptor and content hash that
  `builtins.fetchTree` will later consume.
  Date: 2026-09-13

- Decision: Provide explicit `package-set clone` and `package-set select` operations rather
  than making operators edit generated JSON.
  Rationale: A complete named mapping remains reviewable and strictly validated, and the
  commands are enough to construct a deliberate mixed-generation set without a solver.
  Date: 2026-09-13

- Decision: Import historical version-1 locks only from commits in this repository and pair
  each with `flake.lock` from the same commit.
  Rationale: That pairing contains the provenance needed to verify every legacy Git revision
  and avoids accepting an untraceable source descriptor supplied on the command line.
  Date: 2026-09-13

- Decision: Keep the schema-1 planner and revision-reading wrappers while adding the
  version-2 planner and locked-source decoder beside them.
  Rationale: Production remains on schema 1 until EP-7, so EP-6 can be developed and tested
  without making intermediate commits unable to refresh the current lock.
  Date: 2026-09-22


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

(To be filled during and after implementation.)


## Context and Orientation

The shared tooling foundation is implemented. `flake.nix` uses flake-parts, imports the
existing build checks from `checks/default.nix`, and imports tool checks from
`nix/tooling.nix`. `nix fmt` uses pinned treefmt; `just fmt-check` checks without writing.
Run `just nix-test` alongside the updater tests when changing the shared JSON boundary.
Do not mistake successful pure Nix tests for the selected-set evaluation or build gates.

Follow [docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md).
Snapshot discovery policy and compatibility-profile names are immutable inputs; current
tracking inputs are observation aids, not an equality constraint on retained selections.

This plan has a hard dependency on
`docs/plans/4-define-immutable-family-snapshots-and-update-cohorts.md`. Do not implement it
until EP-4 is marked Complete in
`docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md`. EP-4 owns
the catalog resolver, version-2 codecs, append/import primitives, and selection validation.
EP-5 is a soft dependency: development can proceed against EP-4's fixtures, but the final
workflow must validate the same graph that `lib/mkFirstPartyPackageSet` consumes.

The executable is parsed in `cli/haskell-nix-update/src/HaskellNix/Update/Cli.hs`.
`Workflow.hs` loads the catalog, package lock, and `flake.lock`; selects families; observes
Git and Hackage; updates tracking inputs; writes; validates; and rolls back. `Plan.hs`
currently replaces one `LockedFamily` by name. `Nix.hs` updates inputs and extracts one Git
revision. `PackageLock.hs` is the JSON boundary. Offline behavior is exercised by
`cli/haskell-nix-update/test/PlannerTest.hs`, `WorkflowTest.hs`, and `AdapterTest.hs` using
injected process and HTTP clients.

In the version-2 model, a refresh target is a resolved update group, not a raw family. A
family snapshot captures one observation. A group snapshot atomically binds one generation
of every member plus its compatibility profile. A named package set is a complete mapping
from groups to group generations. The tracking inputs in `flake.nix` continue to point at
current upstream heads for observation; historical snapshots are fetched later from their
stored locked descriptors and do not become new flake inputs.


## Plan of Work

### Milestone 1: Parse package-set and group refresh intent

Dispatch by lock schema. Keep the existing version-1 refresh/check paths and tests until
EP-7 changes production; version-2-only commands report "migrate-lock required" on version 1.
Develop the new path against fixtures without replacing the only working production updater.

Extend `HaskellNix.Update.Cli` so `refresh` and `check` accept `--package-set SET`, repeated
`--family FAMILY`, and repeated `--group GROUP`. Omitting all family/group flags selects all
resolved groups; omitting `--package-set` selects the lock's `defaultPackageSet`. Reject an
unknown set, family, or group before doing network work. Resolve each family to its containing
group, dedupe the result, sort it by group name, and include expansions such as
`baikai -> shikumi-baikai [baikai, shikumi]` in dry-run and normal summaries.
Refresh must reject a set labelled `historical`; such a set is retained evidence, not a
moving release target.

Add an optional `--compatibility-profile PROFILE` to `refresh`. It is valid only when the
normalized target is one group. When omitted, a new group snapshot inherits the profile of
that set's currently selected group snapshot; the first generation uses `default`. When
provided, require a non-empty syntactically valid name and store it as an explicit input.
EP-5's flake validation is authoritative for whether the Nix profile exists.

Update offline parser and selection tests. This milestone ends when command parsing and pure
target normalization are deterministic and no observation or files are involved.

### Milestone 2: Observe exact sources and plan append-only refreshes

Replace `decodeLockedRevision`/`readLockedRevision` internals in `HaskellNix.Update.Nix` with
`decodeLockedSource`/`readLockedSource`, retaining revision wrappers if existing callers need
them. Parse the direct node's locked `type`, `owner`, `repo`, `rev`, and `narHash`, reject
indirect/follows nodes and unexpected source types, and verify owner/repository against the
catalog. Extend `ObservedFamily` to carry the locked source descriptor as well as package
observations. A preview can report a remote revision and prospective package changes without
inventing a NAR hash; only a real post-lock observation may enter persistent state.

Replace the flat replacement planner in `HaskellNix.Update.Plan` with a version-2 planner.
For each target group, compare every normalized observed family with all retained family
snapshots. Reuse a byte-identical snapshot or allocate `max generation + 1`. Construct the
candidate group snapshot from those family references and the chosen compatibility profile;
again reuse identical content or append the next generation. Change only the target package
set's corresponding group selection. Non-target package sets and all older snapshots remain
byte-for-byte equal, and all output lists use EP-4's canonical ordering.

Capture the normalized current discovery policy in each observation, include it in snapshot
deduplication, and validate retained records against their captured policy. Family identity
and group-partition changes require an explicit future catalog migration; reject them before
observation instead of rewriting retained generations or silently extending selections.

Model the operation as one `RefreshPlan` and validate the complete candidate lock before
returning it. Add planner tests for source-only changes, Hackage-only changes at an unchanged
revision, no-op reuse, two independent targets, multi-family groups, and an unchanged second
package set. This milestone ends when pure tests prove append-only allocation and isolation.

### Milestone 3: Apply one atomic group-aware workflow

Refactor `HaskellNix.Update.Workflow` around normalized groups. During a real refresh, query
all target remote heads, update only their tracking inputs, verify every resulting locked
source, observe every group member, create one candidate plan, write the version-2 package
lock, and run flake validation. A failure in any Baikai/Shikumi observation, source lock,
package query, write, or check restores the original `flake.lock` and
`packages/first-party-lock.json`; it must never publish half a group snapshot.

Keep the current dirty-file guard over both managed files. Dry-run records the original bytes
and performs no `nix flake update` or write. Improve the summary so it names the target set,
resolved groups, reused/appended family and group generations, selection changes, and the
fact that retained sets were untouched. Extend `check` to project and verify one named set;
offline mode checks locked Git objects and package discovery, while `--online` also compares
the selected groups with current upstream state.

For version 2, offline `check` reads source revisions from selected snapshots, never requires
them to equal `flake.lock` tracking nodes, and applies captured discovery policy. Require the
selected Git object in the Mori checkout; report a missing object with instructions to fetch
that exact revision, without checking out or modifying the worktree. A stale tracking input
is not a historical-set error. Online checks report upstream drift without mutating selection.

Add an injectable `validateSelectedPackageSet` process boundary. In production, evaluate both
channels of the target with EP-5's constructor, forcing normalized selections, profile checks,
and available selected package `drvPath`s for supported GHCs on the current system. Then run
the existing flake validation. This must include historical targets even though they are
excluded from the curated build matrix. Offline workflow tests inject this boundary until
EP-5 integration is available; EP-7 verifies the real combined path. Evaluation validates
construction, not compilation: do not report `--no-build` validation as a successful build.

Extend `WorkflowTest.hs` with fake multi-family observations and injected failures at each
mutation boundary. This milestone ends when rollback tests compare exact original bytes and
the full offline suite passes.

### Milestone 4: Migrate and compose named selections safely

Add a `migrate-lock` command with `--package-set NAME` (default `default`), repeatable
`--import-set NAME=GIT_COMMIT`, and `--dry-run`. It requires schema version 2 of the family
catalog and a schema version 1 production lock. For the current state, read source descriptors
from the working `flake.lock`. For each import, use the injected Git process boundary to read
`config/first-party-families.json`, `packages/first-party-lock.json`, and `flake.lock` from the same commit, decode them strictly,
and merge them through EP-4's pure idempotent import. Never execute a file from history.
Reject duplicate names, malformed commits, a version-2 historical lock in this first
implementation, family identity/coverage drift, and source revision mismatches. Validate
historical package policy against the historical catalog and capture it, rather than requiring
all current policy fields to match. Expand groups using the current version-2 partition.

For the current migration, derive the legacy policy catalog by projecting the version-2
catalog's unchanged family records to schema version 1 (omit `updateGroups`). This supplies
EP-4's pure migration with matching policy without needing to recover a pre-edit config file.
Validate every imported named set explicitly before accepting the migration transaction.

Add `package-set clone --from SOURCE --to TARGET --support-level
curated|historical [--dry-run]` and `package-set select --package-set SET --group GROUP`
with exactly one of `--generation N` or `--from-package-set SOURCE`. Clone rejects an
existing target, and its support level defaults to `historical`; use `curated` only for a
combination that EP-7 adds to the full build matrix. Select replaces exactly one entry in an
existing complete set and then validates the entire graph. Neither command changes
`defaultPackageSet`, deletes snapshots, or touches `flake.lock`. Both use the package-lock
dirty guard, atomic writer, and flake validation.

Add `package-set profile --package-set SET --group GROUP --profile PROFILE [--dry-run]` for a
rare historical compatibility exception. It reuses the selected group snapshot's family
references, appends or reuses a group snapshot with the requested profile, and moves only
that set. This is the only non-refresh path that creates a group snapshot. It lets EP-7
associate an old runtime cohort with a narrow dependency pin without editing immutable data
or changing the default set.

Add `package-set support --package-set SET --support-level curated|historical [--dry-run]`.
This changes only the set's support label and refuses to demote the set named by
`defaultPackageSet` (which need not be spelled `default`). It lets rollout
create a candidate as historical, prove it across the full matrix, and promote it only after
the support claim is true.

Test migration and import using checked-in fixture repositories or a temporary Git repository
created by the test suite. Resolve import commit expressions to commit IDs before use; use
argument-vector Git calls and reject option-like revisions. Within one migration batch,
sort imports by target name then resolved commit before allocation, so reordering flags
does not change output. Separate sequential imports may allocate different numeric generations:
append-only `max + 1` IDs cannot be order-independent across separate histories. Never
renumber published generations. Importing the same state twice must be a no-op. The milestone is complete when EP-7 can perform production
migration and create its compatibility set without editing generated JSON.


## Concrete Steps

Run from `/Users/shinzui/Keikaku/bokuno/haskell-nix`. Confirm EP-4 is complete and inspect the
current CLI contract before editing:

```bash
sed -n '1,420p' docs/plans/4-define-immutable-family-snapshots-and-update-cohorts.md
nix develop -c haskell-nix-update --help
nix develop -c haskell-nix-update refresh --help
```

Run the focused offline tests after each milestone:

```bash
nix develop -c cabal test haskell-nix-update-test
```

Expected output ends with:

```text
Test suite haskell-nix-update-test: PASS
```

Exercise a non-mutating preview against fixture or production state only after production is
version 2; before EP-7, the equivalent behavior is covered by version-2 workflow fixtures:

```bash
nix develop -c haskell-nix-update refresh --package-set default --family okf --dry-run
```

The summary must contain the normalized singleton group, current/candidate generations, and:

```text
Dry run; flake.lock and packages/first-party-lock.json were not changed.
```

Validate formatting, the CLI build, and repository evaluation:

```bash
just fmt-check
nix develop -c cabal build haskell-nix-update
nix flake check --print-build-logs
git diff --check
```

Use Conventional Commits and all active trailers:

```text
feat(updater): manage package-set snapshot generations

MasterPlan: docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md
ExecPlan: docs/plans/6-make-the-updater-manage-snapshots-and-package-set-selections.md
Intention: intention_01m2f17g4ye8qtz89rnbvndk5s
```


## Validation and Acceptance

Refreshing `--package-set default --family okf` must append or reuse only OKF's family/group
snapshots and may change only the `default` set's OKF selection. A second named set that had
the same pre-refresh selection remains unchanged. Repeating the refresh with unchanged Git
and Hackage observations produces byte-identical JSON and reports a no-op.

Refreshing `--family baikai` with the production update-group fixture must report expansion
to Baikai plus Shikumi. If either member fails, no new family snapshot, group snapshot, or set
selection remains, and both managed files equal their original bytes. A successful refresh
selects one new group generation containing both observed family generations.

A Hackage-only release at an unchanged Git revision must append a family generation. A
source revision change must persist the complete descriptor from the corresponding locked
flake node. A descriptor with the wrong repository, revision, missing NAR hash, or non-GitHub
type must fail before the package lock is written.

`migrate-lock` must preserve the selected flat package projection exactly. Importing a
historical commit twice must be idempotent. Cloning a set and selecting one valid old group
generation, directly or from another set, must leave every other selection equal to the
source set; incomplete, unknown, or non-positive selections must fail. Reprofiling a group
must preserve its family references and isolate the change to one set. Every successful
mutating command must finish with flake validation. Refreshing a historical set and demoting
the default must fail. The full `nix flake check` must pass.

Test a historical set whose selected revision differs from its tracking input: offline check
must succeed using its recorded source and policy. A missing profile on a non-default
historical target must roll back even when the default evaluates. Test a default named
`stable` to ensure support demotion uses `defaultPackageSet`, and permute import flags within
one migration to prove deterministic allocation without claiming order-independent histories.


## Idempotence and Recovery

Snapshot content is immutable and deduplicated, so a repeated observation/import reuses its
existing generation. Canonical batch ordering makes flag order irrelevant within one migration;
separate mutation histories can allocate different generation numbers. Dry runs do not invoke
mutating Nix commands and do not write. Clone never overwrites an existing set; selection
replacement is safe to repeat.

For refresh, retain the existing byte snapshots of both managed files until validation
succeeds. For migration and set operations, retain the original package-lock bytes until
validation succeeds. An asynchronous exception or write/check failure uses the same rollback
path. Atomic writes stay in the destination directory so rename is filesystem-atomic. Do not
recover by deleting a generation or editing a committed source hash; fix the observation or
profile and append/select valid state.


## Interfaces and Dependencies

Use only the repository's existing Aeson, `containers`, `optparse-applicative`, process, Git,
Nix, and HTTP abstractions. If a new library seems necessary, locate its source and docs with
Mori and verify its released version before choosing bounds. Historical state is local Git
data; no GitHub API is required.

`HaskellNix.Update.Cli` must represent normalized command intent equivalent to:

```haskell
data RefreshTarget = TargetFamily FamilyName | TargetGroup UpdateGroupName

data RefreshOptions = RefreshOptions
  { packageSet :: Maybe PackageSetName
  , targets :: [RefreshTarget]
  , compatibilityProfile :: Maybe CompatibilityProfileName
  , dryRun :: Bool
  }

data Command
  = Refresh RefreshOptions
  | Check CheckOptions
  | MigrateLock MigrateOptions
  | PackageSet PackageSetCommand
```

`HaskellNix.Update.Nix` must expose a strict decoder and file reader equivalent to:

```haskell
decodeLockedSource :: Text -> ByteString -> Either UpdateError LockedSource
readLockedSource :: FilePath -> Text -> IO (Either UpdateError LockedSource)
```

`HaskellNix.Update.Plan` must expose pure functions equivalent to:

```haskell
planRefresh
  :: FamilyCatalog
  -> PackageSetLock
  -> PackageSetName
  -> [(UpdateGroup, CompatibilityProfileName, [ObservedFamily])]
  -> Either UpdateError RefreshPlan

clonePackageSet
  :: PackageSetName -> PackageSetName -> PackageSetLock
  -> Either UpdateError PackageSetLock

selectGroupGeneration
  :: PackageSetName -> UpdateGroupName -> SnapshotGeneration -> PackageSetLock
  -> Either UpdateError PackageSetLock

selectGroupFromPackageSet
  :: PackageSetName -> UpdateGroupName -> PackageSetName -> PackageSetLock
  -> Either UpdateError PackageSetLock

selectGroupCompatibilityProfile
  :: PackageSetName -> UpdateGroupName -> CompatibilityProfileName -> PackageSetLock
  -> Either UpdateError PackageSetLock

setPackageSetSupportLevel
  :: PackageSetName -> PackageSetSupportLevel -> PackageSetLock
  -> Either UpdateError PackageSetLock
```

Field ordering and exact currying may follow repository style, but target-set isolation,
content deduplication, group atomicity, and immutable retained snapshots are required. EP-5's
Nix selector is the final validation boundary after writes; this plan must not introduce a
second package-set interpretation.

`ObservedFamily` includes `DiscoveryPolicy`, and the historical import primitive takes the
historical catalog alongside its lock and source descriptors. The selected-set validation
process boundary must be represented in the existing injected workflow environment.

Revision 2026-09-21: preserve legacy dispatch, validate historical targets explicitly, check
selected sources independently of tracking inputs, capture historical policy, and bound import
ordering guarantees. Implementation remains unstarted; full builds remain a separate support gate.

Tooling update 2026-09-21: use the implemented flake-parts, treefmt-nix, nix-unit, and
nix-diff foundation for this plan's checks and diagnostics. Package-set milestones remain
unstarted; tooling adoption does not count as completing the schema or migration work.
