---
id: 7
slug: migrate-the-default-set-and-prove-independent-upgrades
title: "Migrate the default set and prove independent upgrades"
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
      at: 2026-09-22T17:17:05Z
      mode: "implement"
      note: "Begin production package-set migration and compatibility rollout."
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-21T14:06:32Z
      verdict: "approved"
      note: "Reviewed revised plan against repository and Nix semantics; implementation build and cache acceptance gates remain pending."
---

# Migrate the default set and prove independent upgrades

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan activates composable package sets for the real first-party catalog. Existing
consumers continue to receive the current GitHub or Hackage default with no source changes.
New consumers can choose a named set or supply a complete selection that keeps Keiro 0.14
while taking the current OKF generation.

The rollout imports the repository state immediately before the Keiro 0.15 update as a
historical baseline, then creates a curated set that differs from that baseline only in OKF.
Executable checks prove the older Keiro derivation path is identical before and after the OKF
selection moves, while the OKF path changes. The curated sets build under both provenance
channels and every supported GHC, turning cache reuse and compatibility into measured
properties rather than expectations.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] (2026-09-22) Convert production family policy to schema version 2 with the Baikai/Shikumi update group.
- [x] (2026-09-22) Migrate the current lock and import the pre-Keiro-0.15 historical baseline reproducibly.
- [ ] Create and validate the curated Keiro-0.14/OKF-0.9 set using updater commands only.
- [x] (2026-09-22) Bind package-set selection into public flake outputs while preserving every legacy alias.
- [ ] Add cache-identity, selected-version, and full curated matrix build checks.
- [ ] Document consumer selection, update-group maintenance, support levels, and cache behavior.
- [ ] Preserve clean-lock transaction boundaries and record per-system build coverage separately from evaluation.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

- The current repository history contains a suitable complete legacy pair at commit
  `1f3efedb04d71d066043f42cfb8017c122d9a351`, the parent of the Keiro 0.15 update. Its flat
  lock selects Keiro 0.14.0.0 and OKF 0.8.0.0. At the 2026-09-21 review the current lock
  selects Keiro 0.18.0.0 and OKF 0.9.0.0; capture the actual current lock at implementation
  time rather than restoring a stale planned version. Changing only the imported baseline's OKF group is a real skewed-family
  scenario rather than a synthetic fixture.

- That historical commit's family catalog is byte-identical to the current schema-version-1
  catalog, and every matching `-src` node contains `type`, `owner`, `repo`, `rev`, and
  `narHash`. Its state can therefore be imported without catalog projection or an unverified
  source fallback.

- Current Cabal manifests under the Mori-resolved `mori://shinzui/keiro` and
  `mori://shinzui/okf` repositories contain no direct dependency on one another. An OKF-only
  selection should therefore leave Keiro derivations unchanged when the rest of the selected
  graph and build inputs remain equal.

- The current generated registry wraps every first-party package in `doJailbreak` and
  `dontCheck`. A full Nix build proves source compatibility in this repository's supported
  construction, but it does not prove upstream Cabal bounds or test suites. Documentation and
  support language must retain that distinction.

- This repository has no hosted CI workflow and does not upload to a binary cache. Flake
  checks can prove identical derivation paths and realise closures from configured
  substituters, but cache publication remains the responsibility of the surrounding fleet.

- `flake.nix` defaults `disableProfiling` and `disableHaddock` to true, but the current
  consumer guide says the same arguments default to false. Preserve the implemented true
  defaults and correct the documentation during this migration; do not mix a build-setting
  policy change into the package-set rollout.

- The migration command's selected-set validation had only been exercised through a mocked
  workflow boundary. A real run showed that `nix eval --argstr` did not apply its function
  expression, and that `builtins.getFlake (toString ./.)` requires `--impure` to inspect the
  just-written working tree. The adapter now uses `--apply`, enables that local-path access,
  and has a command-shape regression test; all 65 updater tests pass.

- The migrated default preserves the captured GHC 9.12.4 derivation paths exactly: GitHub
  Keiro/OKF remain `4s8vapr...`/`vdnaj22...`, and Hackage Keiro/OKF remain
  `hr2n5mb...`/`gdfc3r3...`. The current versions remain Keiro 0.18.0.0 and OKF 0.9.0.0.


## Decision Log

Record every decision made while working on the plan.

- Decision: Commit each validated lock mutation before the next mutating CLI command and
  keep temporary compatibility candidates historical until builds pass.
  Rationale: The clean-lock guard intentionally rejects uncommitted prior writes. Explicit
  commit boundaries preserve rollback semantics and make the documented rollout executable.
  Date: 2026-09-21

- Decision: Add exactly one explicit production update group,
  `shikumi-baikai = [baikai, shikumi]`; keep every other family an implicit singleton.
  Rationale: It records the release coupling stated by maintainers without inventing broader
  runtime trains. All packages within the Keiro repository already move as one family.
  Date: 2026-09-13

- Decision: Keep the migrated current state as curated `default`, retain the imported old
  global state as historical `keiro-0-14-okf-0-8`, and create curated
  `keiro-0-14-okf-0-9` from it.
  Rationale: The historical set provides one side of the cache comparison. The curated mixed
  set is the user-facing compatibility promise. Their only selected-group difference is OKF.
  Date: 2026-09-13

- Decision: Build every curated named set across both channels and all supported GHCs, but do
  not claim that historical named sets or arbitrary consumer selections are supported.
  Rationale: Retaining old snapshots ensures reproducibility; support requires a continuing
  build obligation. The explicit support level separates those promises.
  Date: 2026-09-13

- Decision: Add a compatibility profile for Keiro 0.14 only if the real build demonstrates a
  transitive incompatibility, and apply the same profile to the baseline and mixed proof set.
  Rationale: Compatibility pins should be evidence-driven. Applying the same profile to both
  comparison sets keeps the Keiro derivation identity assertion meaningful.
  Date: 2026-09-13

- Decision: Keep all legacy registries, Haskell extensions, overlays, and singular aliases as
  exact views of `default`.
  Rationale: Package-set adoption must be opt-in. Existing consumers should see neither an API
  break nor an unintended version change during migration.
  Date: 2026-09-13


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

Milestone 1 is complete. The production catalog and lock now use schema version 2, the
Baikai/Shikumi release boundary is explicit, the current default remains curated, and the
pre-Keiro-0.15 state is retained as historical `keiro-0-14-okf-0-8`. Public legacy aliases
now delegate to the bound package-set constructor without changing representative versions
or derivation paths. Offline default checking and no-build flake evaluation pass.


## Context and Orientation

The flake-parts tooling foundation is implemented. Add production matrix checks to
`checks/default.nix`; `nix/tooling.nix` already contributes formatting and nix-unit checks.
Run `just nix-test` and `just fmt-check` before the matrix. Preserve both derivation paths
on a failed identity assertion and use `just drv-diff '<before.drv>' '<after.drv>'` to
identify the actual changed input. Source selection remains ordinary Nix code in `lib/`.

Follow [docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md).
It limits cache reuse to equal transitive inputs and retains immutable snapshot policy and
profile names. Version-2 family/group topology migration is deliberately outside this rollout.

This plan has hard dependencies on
`docs/plans/5-compose-cache-stable-package-sets-in-nix.md` and
`docs/plans/6-make-the-updater-manage-snapshots-and-package-set-selections.md`. Do not begin
production mutation until both are marked Complete in
`docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md`. EP-5
provides the Nix selector and derivation-identity fixture. EP-6 provides the only allowed
writer and historical importer. EP-4's contract remains authoritative for every record.

`config/first-party-families.json` is currently schema version 1 and contains fourteen
families. `packages/first-party-lock.json` is a flat schema-version-1 snapshot. `flake.nix`
reads both, maps each family to one mutable tracking input, constructs global GitHub and
Hackage registries, and publishes these interfaces:

- `lib.registries.{github,hackage}` and singular `lib.registry`;
- `lib.haskellExtensions.{github,hackage}` and singular `lib.haskellExtension`;
- `overlays.{github,hackage,default,haskell}`; and
- `lib.mkChannelExtension` for build-setting choices.

The package-set constructor from EP-5 can project any valid version-2 selection and fetch a
historical GitHub source by its stored NAR hash. The tracking inputs remain in `flake.nix`
because the updater needs them to observe new upstream heads; they no longer determine which
historical source a consumer receives.

A curated named set is tested on the full supported matrix. A historical named set is
retained and selectable but is not a continuing full-matrix support promise. An explicit
consumer selection has no central support status; the consumer validates it in its own build.
Channel remains independent: the same group selection can use GitHub revisions or Hackage
archives.

The local historical baseline is a repository-local Git artifact, so it may be identified by
commit. External project references in the documentation must use canonical Mori URIs such
as `mori://shinzui/keiro`, `mori://shinzui/okf`, `mori://shinzui/baikai`, and
`mori://shinzui/shikumi`.


## Plan of Work

### Milestone 1: Make one coherent production migration

Capture the pre-migration selected versions and representative derivation paths on the same
Nixpkgs/system/GHC/settings before editing. Compare the post-migration aliases to this saved
baseline; comparing new aliases only with each other cannot prove no behavior changed.

Before editing production policy, build the completed EP-6 updater from the still-valid
version-1 tree and retain its output path for the migration command. Update
`config/first-party-families.json` to schema version 2 and add one sorted `updateGroups`
entry named `shikumi-baikai` with exactly `baikai` and `shikumi`. Do not group Keiro with OKF
or unrelated runtime repositories.

Refactor the production section of `flake.nix` to use EP-5's package-set constructor when the
lock is version 2. Make the edit before invoking the prebuilt updater, but do not evaluate the
transient state where the catalog is version 2 and the lock is version 1. The final retained
state must have both files at version 2; there is no requirement to support that transient
schema mismatch in normal evaluation.

Run `migrate-lock` with current state named `default` and import
`keiro-0-14-okf-0-8=1f3efedb04d71d066043f42cfb8017c122d9a351`. The command reads the
historical package lock and `flake.lock` from that exact commit. Review the generated graph:
the default projection must equal the old production flat lock field-for-field, the historical
projection must equal the imported flat lock, every source descriptor must match its paired
flake node, the historical set is labelled `historical`, and no top-level input is added.

Run the offline updater check and flake evaluation immediately. If migration fails, restore
only the generated lock through the updater's rollback, fix code or policy, and rerun from the
version-1 baseline. The milestone is complete when the working tree contains one coherent
version-2 catalog/lock and all legacy default package names and versions are unchanged.

Review and commit the coherent migration before running `package-set clone`. Every later
successful lock mutation must likewise be committed before the next command that writes the
lock. Use only task-owned files and include the MasterPlan, ExecPlan, and Intention trailers
shown below. Do not disable the dirty guard to make the sequence work.

### Milestone 2: Construct and compile the real skewed set

Use `package-set clone` to create historical candidate `keiro-0-14-okf-0-9` from
`keiro-0-14-okf-0-8`. Use `package-set select --from-package-set default` to replace only its
OKF group. Verify by normalized JSON/Nix projection that every other group generation,
especially Keiro, is identical between baseline and mixed sets, while OKF matches default.
Do not hand-edit a generated snapshot or selection.

Commit the clone before `select`, and commit the selected candidate before further lock
operations. Name `keiro-0-14-okf-0-9` is valid only if the captured default still selects
OKF 0.9; otherwise choose a name reflecting the actual version and propagate it through
commands and checks. Do not refresh unrelated families to fit this document's old baseline.

Build all first-party packages selected by `keiro-0-14-okf-0-9` under GitHub and Hackage
for `ghc9124` and `ghc9141`. If old Keiro needs a transitive pin, add the smallest registry
fragment to `overlays/compatibility-profiles.nix`, use `package-set profile` to associate it
with the Keiro group in both `keiro-0-14-okf-0-8` and `keiro-0-14-okf-0-9`, and rerun the
full builds. Record the failure evidence and rationale in this plan's living Decision Log.
Do not add a global common-registry override or weaken another set to make the build pass.

Commit a newly defined profile before assigning it; commit each `package-set profile`
mutation before assigning the other set. Do not enable the final pairwise identity assertion
until both sets select that profile: the intermediate state is intentionally unequal.
Once enabled, the assertion is a release gate and must remain active.

Add an end-to-end fixture package under `checks/fixtures/package-sets/consumer/` whose Cabal
dependencies include `keiro-core` and `okf-core`. It need not exercise their APIs; the
acceptance goal is dependency resolution and closure composition. Add a focused candidate
check that builds it and the complete mixed inventory across both channels and supported
GHCs. Obtain builds on every supported system using native or configured remote builders and
record the system/channel/compiler results. One host's `nix flake check` does not prove the
other systems build. If a required builder is unavailable, record incomplete validation and
leave the candidate historical. Once that matrix passes, use `package-set support` to promote the mixed set to `curated`.
The milestone is complete when the mixed set is a real buildable combination and its support
level is `curated` only after validation.

### Milestone 3: Publish stable selection and cache assertions

Bind `lib.mkFirstPartyPackageSet` to the production config, lock, common registry,
compatibility profiles, supported compilers, and constructors. Publish normalized discovery
data as `lib.firstPartyPackageSets` (name to support level and complete group selection) and
`lib.firstPartyGroupSnapshots` (group/generation/profile and family references). These
records contain no derivations and must be JSON-evaluable, so downstream consumers can copy a
named mapping and change one generation deliberately.

Reimplement current public channel registries and extensions by calling the constructor with
`packageSet = firstPartyLock.defaultPackageSet`. Keep `lib.mkChannelExtension` as a
compatibility wrapper around that default. Preserve `lib.registry`, `lib.haskellExtension`,
`overlays.default`, and `overlays.haskell` as GitHub-default aliases. Add equality checks over
selected package names, versions, and representative derivation paths so migration cannot
quietly change legacy behavior.

Add production cache checks comparing `keiro-0-14-okf-0-8` with
`keiro-0-14-okf-0-9`. Under the same channel, GHC, build settings, common registry, and
compatibility profiles, force every Keiro package's `drvPath` and assert equality. Force both
OKF packages and assert their paths differ. Repeat for GitHub and Hackage. A failure is a
release blocker: do not mask it by changing check inputs or substituting package-set names
into derivations.

Generate version and build checks only for named sets whose support level is `curated`.
For every curated set, both channels, and every `lib.supportedGhcs` compiler, verify the
projected versions and realise every available selected first-party package; Hackage omits
records whose pin is null. The historical baseline participates in focused Keiro cache and
consumer checks but not the continuing full matrix. The milestone is complete when
`nix flake check` realises the matrix and the discovery APIs evaluate as JSON.

Keep every `checks.<system>.<name>` value a derivation. Put the identity result record in
`checks.<system>.production-package-set-cache-identity.passthru.results`, accessible as
`.results`. Its assertions must force every compared path, while metadata-only discovery
must not fetch trees. Include an append-only-catalog test: adding an unselected generation
changes neither the selected versions nor unaffected derivations.

### Milestone 4: Document the operating and consumer model

Create `docs/user/package-sets.md` and link it from `docs/user/README.md`. Explain family,
update group, family/group generation, named set, support level, compatibility profile, and
channel in that order. Show both a curated named selection and a consumer-owned mapping based
on `lib.firstPartyPackageSets.default`. Explain that merging one override over the live
default deliberately tracks future default generations for every other group, while copying
the complete mapping as literals pins every group until the consumer edits it. State that
group selections are complete, Baikai and Shikumi move atomically, all packages in the Keiro
repository move as one family, and OKF can advance independently.

Explain that schema version 2 fixes the family inventory and group membership; topology
changes need a future explicit migration. Package discovery-policy changes within a family
are allowed and old snapshots retain their own options and exclusions. Profile definitions
are retained under immutable names; a revised workaround receives a new profile name.

Update `docs/user/consumer-integration.md` with the new constructor while retaining the
legacy default examples. Update `docs/user/updating-first-party-packages.md` for grouped
refresh, target-set isolation, migration/import, clone/select/profile, append-only retention,
and review commands. Correct its current blanket claim that evaluation never contacts
GitHub: a selected locked GitHub tree is content-addressed and may be downloaded when its
store path is absent, while unselected snapshots stay lazy and Hackage/Mori discovery remains
an updater concern. Update `docs/user/channels.md` to make provenance orthogonal to package
selection. Add troubleshooting entries for unknown generations, incomplete selections,
historical support expectations, profile conflicts, and unexpected cache misses.

Document the precise cache contract: two builds reuse a first-party derivation only when
compiler, channel, source/version, dependency graph, compatibility profile, and build settings
are equal. A package directly depending on changed OKF may rebuild even if Keiro itself does
not. The repository proves derivation identity but does not promise a particular external
cache contains the path.


## Concrete Steps

Run from `/Users/shinzui/Keikaku/bokuno/haskell-nix`. Confirm both hard dependencies are
complete and verify the known historical state:

```bash
sed -n '1,420p' docs/plans/5-compose-cache-stable-package-sets-in-nix.md
sed -n '1,460p' docs/plans/6-make-the-updater-manage-snapshots-and-package-set-selections.md
git show 1f3efedb04d71d066043f42cfb8017c122d9a351:packages/first-party-lock.json \
  | jq -r '.families[] | select(.name == "keiro" or .name == "okf") | .name as $family | .packages[] | select(.name == (if $family == "keiro" then "keiro" else "okf-core" end)) | [$family, .version] | @tsv'
```

The last command must show Keiro 0.14.0.0 and OKF 0.8.0.0. Build the migration-capable updater
before creating the transient schema mismatch:

```bash
updater_path="$(nix build --no-link --print-out-paths .#haskell-nix-update)"
```

After editing the catalog and production Nix wiring, migrate current and historical state:

```bash
"$updater_path/bin/haskell-nix-update" migrate-lock \
  --package-set default \
  --import-set keiro-0-14-okf-0-8=1f3efedb04d71d066043f42cfb8017c122d9a351
```

Review and commit the migration before continuing (also stage any newly introduced task-owned
Nix files before evaluating a Git-backed flake):

```bash
git add config/first-party-families.json packages/first-party-lock.json flake.nix
git commit -m 'feat(package-sets): migrate production snapshot catalog' \
  -m 'MasterPlan: docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md
ExecPlan: docs/plans/7-migrate-the-default-set-and-prove-independent-upgrades.md
Intention: intention_01m2f17g4ye8qtz89rnbvndk5s'
```

Create the skewed supported set without looking up a numeric generation:

```bash
nix run .#haskell-nix-update -- package-set clone \
  --from keiro-0-14-okf-0-8 \
  --to keiro-0-14-okf-0-9
git add packages/first-party-lock.json
git commit -m 'chore(package-sets): retain mixed-set candidate' \
  -m 'MasterPlan: docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md
ExecPlan: docs/plans/7-migrate-the-default-set-and-prove-independent-upgrades.md
Intention: intention_01m2f17g4ye8qtz89rnbvndk5s'
nix run .#haskell-nix-update -- package-set select \
  --package-set keiro-0-14-okf-0-9 \
  --group okf \
  --from-package-set default
git add packages/first-party-lock.json
git commit -m 'chore(package-sets): advance candidate OKF selection' \
  -m 'MasterPlan: docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md
ExecPlan: docs/plans/7-migrate-the-default-set-and-prove-independent-upgrades.md
Intention: intention_01m2f17g4ye8qtz89rnbvndk5s'
nix build --no-link --keep-going --print-build-logs \
  .#checks.aarch64-darwin.keiro-0-14-okf-0-9-candidate
```

After recording equivalent passing builds for every other supported system, promote:

```bash
nix run .#haskell-nix-update -- package-set support \
  --package-set keiro-0-14-okf-0-9 \
  --support-level curated
```

Inspect public selections and the focused identity result:

```bash
nix eval --json .#lib.firstPartyPackageSets
nix eval --json .#lib.firstPartyGroupSnapshots
nix eval --json .#checks.aarch64-darwin.production-package-set-cache-identity.results
```

Use the current system key instead of `aarch64-darwin` in both check attribute paths on
non-Apple systems. The identity result must contain equal Keiro paths and different OKF paths
for both channels:

```json
{
  "githubKeiroEqual": true,
  "hackageKeiroEqual": true,
  "githubOkfDifferent": true,
  "hackageOkfDifferent": true
}
```

Run the updater and complete build checks:

```bash
nix run .#haskell-nix-update -- check --package-set default
nix run .#haskell-nix-update -- check --package-set keiro-0-14-okf-0-9
nix flake check --print-build-logs --keep-going
git diff --check
```

Review the migration rather than its volume alone:

```bash
jq '{schemaVersion, defaultPackageSet, sets: [.packageSets[] | {name, supportLevel}], familySnapshotCount: (.familySnapshots | length), groupSnapshotCount: (.groupSnapshots | length)}' packages/first-party-lock.json
git diff -- config/first-party-families.json packages/first-party-lock.json flake.nix overlays/compatibility-profiles.nix docs/user
```

Use Conventional Commits and all active trailers:

```text
feat(package-sets): support independent first-party family upgrades

MasterPlan: docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md
ExecPlan: docs/plans/7-migrate-the-default-set-and-prove-independent-upgrades.md
Intention: intention_01m2f17g4ye8qtz89rnbvndk5s
```


## Validation and Acceptance

The version-2 default projection must match the pre-migration version-1 flat lock for every
family revision, package path, GitHub version, Hackage version/hash, publication null, and
Cabal2nix option. Existing `lib.registries`, `lib.haskellExtensions`, `overlays`, and singular
aliases must expose the same default packages and settings as before migration.

The catalog resolver must expose one `shikumi-baikai` group containing exactly Baikai and
Shikumi, plus singleton groups for all remaining families. The historical baseline must
project Keiro 0.14.0.0 and OKF 0.8.0.0. The mixed curated set must project Keiro 0.14.0.0 and
the default's current OKF generation, with every non-OKF selection identical to the baseline.

For both GitHub and Hackage under the same supported GHC, every Keiro derivation path in the
baseline and mixed set must be equal, and the available OKF derivation paths must differ. The
consumer fixture must build in the mixed set. All packages available in every curated
set/channel/GHC cell must build; null Hackage packages are deliberately absent rather than
failed.

`lib.mkFirstPartyPackageSet` must accept the curated mixed name and an equivalent explicit
selection and return the same normalized graph. `lib.firstPartyPackageSets` and
`lib.firstPartyGroupSnapshots` must evaluate without forcing package derivations. A consumer
using only existing default outputs must require no source change.

The updated user guide must distinguish curated, historical, and consumer-owned selections;
describe the cache identity conditions; and state the limitations from jailbreak, disabled
tests, and absent cache publication. All updater tests, Nix checks, formatting checks, and
documentation links must pass.


## Idempotence and Recovery

Migration and historical import deduplicate normalized snapshot content. Rerunning the same
import, clone preview, selection, or profile operation is either a no-op or an explicit
already-exists error; it never allocates another generation for identical content. All
generated lists remain canonically sorted.

Build the updater before changing schemas so a failed migration can be retried without
evaluating transient production state. The migration command holds original package-lock
bytes and restores them on validation failure. Until the migration commit is retained, the
catalog and Nix wiring can be reverted as ordinary text edits; do not delete user work or
rewrite Git history. After publication, old snapshots are public selectable inputs and must
not be pruned to recover space.

If the mixed set fails, leave it historical or remove only the newly created named selection
before publication; never relabel it curated without passing the matrix. If a compatibility
profile is necessary, append/reuse a profiled group snapshot through the CLI and apply it to
both sides of the cache comparison. A bad NAR hash is source-integrity evidence and must be
fixed through a verified import/refresh, not edited in place.


## Interfaces and Dependencies

No new external library or service is required. Use EP-5's Nix constructor, EP-6's updater,
Nixpkgs Haskell package scopes, the repository's Git history, and the configured substituters.
Use Mori for cross-repository source/docs inspection, and verify any new compatibility bound
against authoritative upstream releases before recording it.

`flake.nix` must expose these new values in addition to every existing output:

```nix
lib.mkFirstPartyPackageSet {
  packageSet = "keiro-0-14-okf-0-9";
  channel = "github";
  disableProfiling = true;
  disableHaddock = true;
}

lib.firstPartyPackageSets = {
  default = {
    supportLevel = "curated";
    selections = { /* complete group -> generation map */ };
  };
};

lib.firstPartyGroupSnapshots = [
  {
    group = "keiro";
    generation = 1;
    compatibilityProfile = "default";
    families = [ /* family/generation refs */ ];
  }
];
```

The constructor also accepts `selections` instead of `packageSet`, as defined by EP-5. It
returns `selections`, `selectedFamilies`, `registry`, `haskellExtension`, and `overlay`.
`lib.mkChannelExtension` delegates to the default selection and retains its existing
signature. Package-set names and support labels are inspection metadata only; neither may
enter a derivation.

Revision 2026-09-21: update the live Keiro baseline, add real before/after alias evidence,
repair clean-lock rollout sequencing, correct flake check result paths, and require explicit
system build coverage. No production migration or compilation was performed during review.

Tooling update 2026-09-21: use the implemented flake-parts, treefmt-nix, nix-unit, and
nix-diff foundation for this plan's checks and diagnostics. Package-set milestones remain
unstarted; tooling adoption does not count as completing the schema or migration work.
