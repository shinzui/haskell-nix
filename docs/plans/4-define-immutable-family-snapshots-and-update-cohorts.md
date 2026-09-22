---
id: 4
slug: define-immutable-family-snapshots-and-update-cohorts
title: "Define immutable family snapshots and update cohorts"
kind: exec-plan
created_at: 2026-09-14T04:03:53Z
intention: "intention_01m2f17g4ye8qtz89rnbvndk5s"
master_plan: "docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md"
provenance:
  revisions:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-21T14:06:31Z
      mode: "update"
      note: "Review-driven corrections to snapshot retention, Nix composition, validation, and migration contracts."
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-21T14:26:45Z
      mode: "update"
      note: "Adopt flake-parts, treefmt-nix, nix-unit, and nix-diff; native checks pass with unchanged existing derivations."
    - model: "gpt-5.6-sol"
      harness: "codex-cli"
      at: 2026-09-22T14:50:28Z
      mode: "implement"
      note: "Implement immutable snapshot contracts, validation, projection, and migration."
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-21T14:06:32Z
      verdict: "approved"
      note: "Reviewed revised plan against repository and Nix semantics; implementation build and cache acceptance gates remain pending."
---

# Define immutable family snapshots and update cohorts

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan defines the durable model that lets one consumer select a new OKF family without
also selecting the newest Keiro family. It adds three plain concepts. A family snapshot is
an immutable observation of one repository revision and its GitHub/Hackage package records.
An update group is one or more families that are advanced atomically; Baikai and Shikumi are
the motivating multi-family group, while an unlisted family is its own implicit group. A
package set selects one update-group generation for every group.

At the end, Haskell and Nix fixture tests agree on a strict version-2 schema and can project
a selected package set back to the flat family list the current registry understands. A
pure migration turns the current version-1 family lock plus locked source descriptors into
one version-2 snapshot graph without changing package versions. Production remains on the
version-1 file during this plan, so the current refresh command and public channel outputs
continue to work until the later Nix and updater plans are ready.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [x] (2026-09-22 08:03 PDT) Add update-group and snapshot-domain types with plain-language invariants.
- [x] (2026-09-22 08:03 PDT) Implement strict version-2 JSON codecs, canonical ordering, and reference validation.
- [x] (2026-09-22 08:03 PDT) Add matching eager Nix validation and valid/invalid fixtures; 29 nix-unit cases pass.
- [x] (2026-09-22 08:03 PDT) Implement and test the pure version-1-to-version-2 migration and selected-set projection; all 50 Haskell tests pass.
- [ ] Keep the version-1 production reader, updater workflows, and flake outputs passing.
- [x] (2026-09-22 08:03 PDT) Prove retained snapshots survive current package-policy changes and reject unsupported catalog topology changes explicitly in Haskell and Nix.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

The version-1 registry checks locked package options and exclusions against current policy.
Reusing that check unchanged for historical generations would invalidate old snapshots when
policy changes. Version 2 must capture and validate the policy of each observation.

- Nix flake source snapshots omit untracked files. The first nix-unit run could not import
  the new validator until its path was staged; after staging the new source and fixture paths,
  all 29 cases passed. This affects local validation only and does not change the contract.


## Decision Log

Record every decision made while working on the plan.

- Decision: Capture discovery policy in each family snapshot and freeze family/group topology
  within the initial version-2 contract.
  Rationale: New package policy must not reinterpret old data; changing the group partition
  needs a separate explicit migration of complete consumer mappings.
  Date: 2026-09-21

- Decision: Keep version-1 production data active while adding the complete version-2 model
  and fixtures alongside it.
  Rationale: The Nix constructor and updater can then be developed against a stable contract
  without creating a commit where production evaluation or refresh is unusable.
  Date: 2026-09-13

- Decision: Store a positive integer generation scoped to a family or update group instead
  of treating a package version or Git revision as snapshot identity.
  Rationale: Monorepos contain multiple package versions, and Hackage state can advance
  without a Git revision change. A scoped generation identifies each immutable observation
  without adding a new hashing dependency.
  Date: 2026-09-13

- Decision: Require every package set to contain a fully expanded selection for every
  resolved update group.
  Rationale: Inheritance would make a selection's meaning depend on another mutable set.
  Complete mappings are slightly longer but deterministic, reviewable, and safe to export
  to consumers.
  Date: 2026-09-13

- Decision: Enforce global package-name uniqueness only within a projected package set, not
  across the whole snapshot catalog.
  Rationale: Historical generations necessarily repeat package names. A single selected
  Haskell scope must still contain only one provider for each package name.
  Date: 2026-09-13

- Decision: Keep the production version-1 data constructor named `PackageLock` and expose
  `LegacyPackageLock` as its transition alias while the new graph uses `PackageSetLock`.
  Rationale: Existing CLI, planner, and workflow call sites remain source-compatible, while
  migration APIs state explicitly that their flat input is legacy data. Renaming the active
  constructor would create broad mechanical churn without strengthening the version-2 boundary.
  Date: 2026-09-22


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

(To be filled during and after implementation.)


## Context and Orientation

The tooling foundation exposes named pure tests in `checks/unit.nix`, run with
`just nix-test` or `nix develop -c nix-unit --flake .#lib.tests`. Extend that suite with
version-2 contract fixtures and individual failure names. `nix/tooling.nix` wires the runner
and treefmt check; `checks/default.nix` owns build checks. Structural tests must remain free
of source fetching and Cabal2nix builds. Run `just fmt-check` with final validation.

The durable contract is recorded in
[docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md).
No pre-existing local ADR covered this design. Snapshot contents determine first-party inputs;
the consumer's Nixpkgs and transitive build inputs still determine the resulting derivations.

The completed initiative in
`docs/masterplans/1-automate-dual-channel-first-party-haskell-package-updates.md` introduced
two strict JSON files. `config/first-party-families.json` is hand-authored policy. Each
family names one registered repository, one mutable `flake = false` tracking input, optional
Cabal2nix arguments, and excluded packages. `packages/first-party-lock.json` is generated
state. It contains exactly one `LockedFamily` per configured family, so refreshing a family
replaces its only retained Git revision and package records.

`cli/haskell-nix-update/src/HaskellNix/Update/Types.hs` owns the current domain types.
`Catalog.hs` parses and validates the family config. `PackageLock.hs` parses and validates
the flat lock. `Plan.hs` creates replacement `LockedFamily` values, and `Workflow.hs` uses
those values for refresh and check. The offline tests in `PlannerTest.hs`, `WorkflowTest.hs`,
and `test/fixtures/` construct these records directly, so type changes must update all call
sites without weakening current coverage.

`lib/mkFirstPartyRegistries.nix` independently validates the same JSON contracts before
constructing package replacements. This validation is eager: malformed data fails when the
registry is constructed, not only when one package is forced. Nix fixtures live under
`checks/fixtures/first-party/` and are exercised by `checks/first-party-registry.nix`.

The following terms have precise meanings in this plan:

- A family remains the packages discovered from one source repository at one revision.
- A family snapshot is addressed by `(family name, generation)`. It stores a locked source
  descriptor and all package records observed together. Once committed, its content is never
  changed in place.
- A resolved update group partitions configured families. An explicit group contains two or
  more listed families. Every family absent from explicit groups becomes a singleton group
  whose name is the family name.
- A group snapshot is addressed by `(group name, generation)` and refers to exactly one
  family-snapshot generation for every member. It also names a compatibility profile;
  `default` means the cohort needs no additional dependency override.
- A package set is a named complete mapping from every resolved group to a group-snapshot
  generation. It is labelled `curated` or `historical`; `defaultPackageSet` names a curated
  set used by legacy output aliases.

Cross-repository research must use Mori. For example, the relevant project references are
`mori://shinzui/baikai`, `mori://shinzui/shikumi`, `mori://shinzui/okf`, and
`mori://shinzui/keiro`. Resolve them with `mori registry show <qualified-name> --full` or
`mori path <mori-uri>`; never search `/nix/store` or the filesystem root.


## Plan of Work

### Milestone 1: Define update groups and the version-2 snapshot graph

Extend `HaskellNix.Update.Types` with `UpdateGroupName`, `SnapshotGeneration`,
`UpdateGroup`, `LockedSource`, `FamilySnapshot`, `GroupSnapshot`, `GroupSelection`,
`PackageSet`, and `PackageSetLock`. Preserve the existing flat lock as
`LegacyPackageLock` during the transition and update current planner/workflow type
signatures mechanically. A positive `SnapshotGeneration` is scoped by its family or group;
there is no repository-global counter.

Extend `FamilyCatalog` with explicit update groups. `Catalog.decodeFamilyCatalog` must
accept current schema version 1 with no explicit groups and version 2 with a required,
sorted `updateGroups` list. Add `resolveUpdateGroups`, which rejects duplicate group names,
duplicate family membership, unknown members, empty groups, and one-member explicit groups;
then add one implicit singleton group for each remaining family. Group names and family
names share a namespace so an explicit group cannot shadow a singleton family name.

Define version 2 of `packages/first-party-lock.json` in `PackageLock.hs`. Its conceptual JSON
shape is:

```json
{
  "schemaVersion": 2,
  "familySnapshots": [
    {
      "family": "okf",
      "generation": 1,
      "discoveryPolicy": {
        "packageOverrides": {},
        "excludedPackages": []
      },
      "source": {
        "type": "github",
        "owner": "shinzui",
        "repo": "okf",
        "rev": "0123456789abcdef0123456789abcdef01234567",
        "narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
      },
      "packages": []
    }
  ],
  "groupSnapshots": [
    {
      "group": "okf",
      "generation": 1,
      "families": [{ "family": "okf", "generation": 1 }],
      "compatibilityProfile": "default"
    }
  ],
  "packageSets": [
    {
      "name": "default",
      "supportLevel": "curated",
      "groups": [{ "group": "okf", "generation": 1 }]
    }
  ],
  "defaultPackageSet": "default"
}
```

The real fixture must contain multiple families, an explicit two-family group, at least two
family generations for one family, two group generations, and two package sets that mix
old and new selections. Lists are sorted by their composite key. JSON decoding rejects
unknown fields. `LockedSource` initially accepts only exact GitHub records with `type`,
`owner`, `repo`, `rev`, and `narHash`; it does not store `lastModified`, because that field
does not determine fetched content. A package-set `supportLevel` is exactly `curated` or
`historical`.

The milestone is complete when codec round trips are byte-stable, version-1 current tests
still pass, and focused tests demonstrate the resolved group partition.

### Milestone 2: Validate references and project one selected set

Implement `validatePackageSetLock` and `selectPackageSet` in `PackageLock.hs`. Validation
must prove positive generations, unique composite keys, canonical sorting, configured family
coverage, source owner/repository agreement with family config, and exact references among
package sets, group snapshots, and family snapshots. Each group snapshot must contain the
resolved group's exact sorted membership and a non-empty compatibility-profile name. Each
package set must select every resolved group exactly once. `defaultPackageSet` must name one
declared curated set. Nix validates that profile names exist when it composes a set in EP-5.

Projection follows package-set groups to group snapshots and then to family snapshots. It
returns a sorted flat list with one snapshot per configured family. Validate package-name
uniqueness across that projected list. Reuse existing package-path, version, hash,
`cabal2nixOptions`, override, and exclusion checks for every family snapshot; historical
generations are not exempt from schema integrity. Validate options and exclusions against
the snapshot's required `discoveryPolicy`, never against today's family policy. This record
contains the normalized `packageOverrides` map and sorted `excludedPackages` list applied
when discovering the snapshot. Include it in content deduplication. The current catalog
policy is used only for new observations. A policy-only change may allocate a new snapshot
but must not change a derivation if its projected build inputs are identical.

Version 2 fixes family identities, source owner/repository identity, and resolved group
membership after migration. Reject additions, removals, or regrouping against retained
coverage with a contextual "catalog topology migration required" error. Do not silently
extend consumer selections from the default set. A future schema migration can relax this
boundary; ordinary package inventory and discovery-policy changes remain supported now.

Add invalid Haskell fixtures for an unknown group, missing group selection, wrong group
membership, missing family generation, duplicate composite key, non-positive generation,
mutable-looking source record with unknown fields, unknown support level, historical default
set, default set not found, and duplicate package provider inside one selected set. Add direct
projection tests showing two sets can select different OKF generations while selecting the
same Keiro generation.

Create `lib/validateFirstPartyPackageSetLock.nix` and matching fixtures under
`checks/fixtures/package-sets/`. It must implement the same eager structural and referential
checks using Nix primitives and return a normalized projection or throw. Add a focused check
file, but do not feed its data into the production registries yet.

The milestone is complete when Haskell and Nix accept the same valid fixture, reject the
same invalid cases, and emit the same selected family/generation pairs for both fixture
package sets.

### Milestone 3: Define deterministic migration without activating it

Add a pure `migrateLegacyPackageLock` function. It takes a version-2 family catalog, a map
of family names to `LockedSource` values read from a matching version-1 `flake.lock`, a
legacy flat lock, its matching version-1 family catalog, and a target set name. Validate the
legacy pair against that catalog and capture its discovery policy. It creates generation 1 for each family, generation
1 for every resolved group with compatibility profile `default`, a complete target package
set labelled `curated`, and that target as `defaultPackageSet`. It preserves every package
record exactly and fails if a source descriptor's revision disagrees with the legacy family
revision.

Add a pure import function that can merge another migrated historical flat lock into an
existing version-2 catalog. It reuses a byte-identical family snapshot, otherwise allocates
the next family generation; it does the same for group snapshots and creates or replaces
only the named package-set selection, labelled `historical` by default. This function enables
the later workflow to import an old Keiro selection and a new OKF selection from repository
history without hand-writing generated records.

Do not rewrite production JSON in this plan. Keep current CLI behavior pointed at
`LegacyPackageLock`, and add tests proving migration is deterministic, importing the same
legacy state twice is idempotent, and source/Hackage changes allocate a new generation even
when only one side changes. Run the entire offline test suite and `nix flake check`.


## Concrete Steps

Run all commands from `/Users/shinzui/Keikaku/bokuno/haskell-nix`. Begin by preserving user
changes and confirming the registered projects:

```bash
git status --short --branch
mori registry show shinzui/haskell-nix --full
mori registry show shinzui/baikai --full
mori registry show shinzui/shikumi --full
```

After adding the new Haskell types and fixtures, run the focused suite through the existing
development shell:

```bash
nix develop -c cabal test haskell-nix-update-test
```

Expected output ends with a successful test suite and includes new package-set codec,
validation, projection, and migration cases:

```text
Test suite haskell-nix-update-test: PASS
```

Parse and evaluate the new Nix validator before integrating its check:

```bash
nix-instantiate --parse lib/validateFirstPartyPackageSetLock.nix >/dev/null
nix eval --json .#checks.aarch64-darwin.package-set-contract.drvPath
```

Use the current system attribute instead of `aarch64-darwin` on another platform. Finish
with the complete repository checks:

```bash
jq empty config/first-party-families.json packages/first-party-lock.json
nix flake check --print-build-logs
git diff --check
```

Do not run the migration against production files in this plan. Commits made during
implementation include both plan trailers and the intention:

```text
feat(package-sets): define immutable snapshot contracts

MasterPlan: docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md
ExecPlan: docs/plans/4-define-immutable-family-snapshots-and-update-cohorts.md
Intention: intention_01m2f17g4ye8qtz89rnbvndk5s
```


## Validation and Acceptance

The Haskell test suite must round-trip the valid version-2 fixture with stable sorted JSON
and reject each malformed fixture with a contextual error. The Nix fixture check must reject
the equivalent malformed records eagerly with `builtins.tryEval`. Both implementations must
project identical family/generation pairs from a set where OKF moves and Keiro stays fixed.

Add fixtures where current policy changes Cabal2nix flags or excludes a formerly included
package: the old snapshot must still project its original packages and options. A malformed
snapshot-policy pairing must fail in both languages. Adding a family or changing group
membership must fail with the explicit migration-required diagnostic. For eager validation,
use `builtins.tryEval (builtins.deepSeq structuralResult true)` on data only, never on fetched
sources or derivations; a shallow successful `tryEval` of a lazy record is insufficient.

Given a catalog with explicit group `shikumi-baikai = [baikai, shikumi]`, resolved groups
must contain that group plus one singleton per remaining family. A package set omitting the
explicit group, selecting only Baikai, or referring to different group membership must fail.

Given one version-1 lock and matching locked sources, migration must produce generation 1
records whose selected flat package names, Git revisions, GitHub versions, Hackage versions,
hashes, paths, and Cabal2nix options equal the legacy lock. Running the import twice must
produce byte-identical version-2 output. Changing a Hackage pin while keeping the Git
revision fixed must allocate a new family generation.

The existing production `nix eval --json .#lib.registries.github --apply builtins.attrNames`,
offline `haskell-nix-update check`, and `nix flake check` commands must remain successful and
continue to read the version-1 production lock.


## Idempotence and Recovery

All work in this plan is additive or a mechanical internal type rename. Production config,
`flake.lock`, and `packages/first-party-lock.json` remain byte-identical. If a type migration
breaks current workflows, restore compilation by keeping legacy and version-2 types separate
rather than weakening validation or converting production early.

Fixture generation and pure migration are deterministic. Re-running tests or importing the
same legacy fixture cannot allocate further generations. Never delete existing user changes
from the working tree, and never regenerate a production lock to repair a fixture failure.


## Interfaces and Dependencies

Use the repository's existing Aeson, `containers`, Cabal `Version`, and pretty-JSON
dependencies; this plan needs no new package. If implementation appears to need an external
library, locate it with `mori registry search`, inspect its source and docs, and verify its
released version before adding a Cabal bound.

`HaskellNix.Update.Types` must expose records equivalent to:

```haskell
newtype UpdateGroupName = UpdateGroupName Text
newtype SnapshotGeneration = SnapshotGeneration Int

data PackageSetSupportLevel = Curated | Historical

data UpdateGroup = UpdateGroup
  { name :: UpdateGroupName
  , families :: [FamilyName]
  }

data LockedSource = LockedSource
  { sourceType :: Text
  , owner :: Text
  , repo :: Text
  , rev :: GitRevision
  , narHash :: SriHash
  }

data FamilySnapshot = FamilySnapshot
  { family :: FamilyName
  , generation :: SnapshotGeneration
  , discoveryPolicy :: DiscoveryPolicy
  , source :: LockedSource
  , packages :: [LockedPackage]
  }

data GroupSnapshot = GroupSnapshot
  { group :: UpdateGroupName
  , generation :: SnapshotGeneration
  , families :: [(FamilyName, SnapshotGeneration)]
  , compatibilityProfile :: Text
  }

data PackageSet = PackageSet
  { name :: Text
  , supportLevel :: PackageSetSupportLevel
  , groups :: [(UpdateGroupName, SnapshotGeneration)]
  }

data PackageSetLock = PackageSetLock
  { schemaVersion :: Int
  , familySnapshots :: [FamilySnapshot]
  , groupSnapshots :: [GroupSnapshot]
  , packageSets :: [PackageSet]
  , defaultPackageSet :: Text
  }
```

Field wrappers may replace tuples, and duplicate record fields may require qualified access,
but the serialized meanings must not change. `Catalog.hs` must expose
`resolveUpdateGroups :: FamilyCatalog -> Either Text [UpdateGroup]`. `PackageLock.hs` must
expose `validatePackageSetLock`, `selectPackageSet`, `migrateLegacyPackageLock`, and the
historical import function with typed errors. The new Nix validator accepts `{ lib, config,
lock }` and returns normalized resolved groups plus a `select` function; EP-5 consumes that
interface without duplicating validation.

`DiscoveryPolicy` contains the existing package-override map and excluded-package list;
its JSON keys are exactly `packageOverrides` and `excludedPackages`. The selected projection
must supply snapshot-specific policy to the legacy registry boundary.

Revision 2026-09-21: snapshot discovery policy, make topology migration an explicit boundary,
and require historical-policy and eager-validation regression fixtures. Implementation has
not started; these revisions correct the retention contract before dependent plans begin.

Tooling update 2026-09-21: use the implemented flake-parts, treefmt-nix, nix-unit, and
nix-diff foundation for this plan's checks and diagnostics. Package-set milestones remain
unstarted; tooling adoption does not count as completing the schema or migration work.
