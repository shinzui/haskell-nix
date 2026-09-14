---
id: 2
slug: decouple-first-party-upgrades-with-composable-package-sets
title: "Decouple first-party upgrades with composable package sets"
kind: master-plan
created_at: 2026-09-14T04:03:47Z
intention: "intention_01m2f17g4ye8qtz89rnbvndk5s"
---

# Decouple first-party upgrades with composable package sets

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Vision & Scope

After this initiative, a downstream project can update this `haskell-nix` flake to obtain a
new OKF family snapshot while continuing to build an older Keiro family snapshot. The
consumer chooses an explicit package set: a reproducible mapping from independently moving
update groups to immutable family snapshots. Updating one selection does not silently move
the others. The existing GitHub and Hackage channels remain available as an orthogonal
choice of source provenance, rather than acting as the only choice a consumer can make.

The design follows the release boundaries that actually exist. Every package discovered in
one repository remains a family and therefore shares one source revision. Families that
must move together across repositories can form an update group; the first production
multi-family group is Baikai plus Shikumi, while an ungrouped family such as OKF or Keiro is
an implicit single-family group. A package set selects one immutable generation of every
resolved update group. The selected snapshot identities, not the package-set name, determine
the resulting Nix derivations, so two package sets that select the same Keiro generation
must produce the same Keiro derivation path and reuse the same binary-cache entry.

`haskell-nix` owns an append-only catalog of released family and update-group snapshots, a
small set of curated named package sets, and a constructor for consumer-owned selections.
The updater appends new snapshots, moves only the requested named set, validates group
atomicity, and retains old snapshots as public selectable inputs. Existing outputs such as
`lib.haskellExtensions.github`, `lib.haskellExtensions.hackage`, and the corresponding
overlays remain exact aliases of the designated default package set throughout migration.

The initiative includes the JSON contracts, Nix composition API, source fetching from
locked GitHub descriptors, updater and migration workflows, cache-identity proofs, supported
package-set build checks, and consumer/operator documentation. It excludes an automatic
dependency solver, installing two versions of the same package name in one nixpkgs Haskell
scope, changing upstream release cadences, and provisioning or publishing to a remote binary
cache. A project package that directly depends on changed OKF will still rebuild; the goal is
to keep its unchanged Keiro closure identical and cacheable.


## Decomposition Strategy

The work is divided into four functional streams. EP-4 defines the durable domain model and
strict JSON contracts without changing production selection. EP-5 consumes that contract to
prove Nix can compose two different sets while preserving derivation identity for unchanged
families. EP-6 makes the Haskell updater create and move snapshots safely. EP-7 activates the
new model in production, imports a historical mixed-version baseline, runs the expensive
compatibility and cache proofs, and updates public documentation.

The contract plan comes first because both Nix and Haskell must agree on snapshot keys,
group expansion, reference integrity, sorting, and the default-set designation. After it is
complete, Nix composition and updater orchestration can proceed in parallel: they share the
contract but touch mostly separate code. Production migration remains last so every retained
commit evaluates and the current updater remains usable until its replacement path and Nix
reader are both ready.

A single large ExecPlan was rejected because schema evolution, Nix fixed-point behavior,
stateful refresh/rollback, and a real multi-family migration have different failure modes
and validation costs. A named global release train was rejected because it recreates the
current all-families cadence. Per-project source forks and one flake input per historical
family revision were rejected because they multiply lock inputs and make cache identity
harder to reason about. An automatic Cabal constraint solver was rejected for the first
version because the user needs explicit supported combinations, not every theoretically
solvable combination.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 4 | Define immutable family snapshots and update cohorts | docs/plans/4-define-immutable-family-snapshots-and-update-cohorts.md | None | None | Not Started |
| 5 | Compose cache-stable package sets in Nix | docs/plans/5-compose-cache-stable-package-sets-in-nix.md | EP-4 | None | Not Started |
| 6 | Make the updater manage snapshots and package-set selections | docs/plans/6-make-the-updater-manage-snapshots-and-package-set-selections.md | EP-4 | EP-5 | Not Started |
| 7 | Migrate the default set and prove independent upgrades | docs/plans/7-migrate-the-default-set-and-prove-independent-upgrades.md | EP-5, EP-6 | None | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-1, EP-3).


## Dependency Graph

EP-4 is the foundation. It defines update-group resolution, family and group snapshot
generations, package-set selections, locked source descriptors, and the validation rules
that every later plan consumes. EP-5 cannot safely build a Nix constructor against an
assumed record shape, and EP-6 cannot implement deterministic planning or codecs until
those types are fixed.

EP-5 and EP-6 can proceed in parallel after EP-4. EP-5 owns evaluation and composition;
EP-6 owns online observation, snapshot planning, managed-file mutation, and rollback. They
have an integration dependency around the exact projected selected-family record passed to
the existing registry builder, but neither needs the other's completed implementation to
make progress once EP-4's fixtures exist.

EP-7 has hard dependencies on both EP-5 and EP-6. It changes the production lock and public
default only after the new Nix reader and the new updater can both consume and reproduce the
state. The intended execution graph is:

```text
EP-4 (contracts)
  |---> EP-5 (Nix composition and cache proof) --|
  `---> EP-6 (updater and migration workflow) ---|---> EP-7 (production migration)
```


## Integration Points

EP-4 owns schema version 2 of `config/first-party-families.json`. Its `updateGroups` field
lists only cross-family atomic groups; families not named there resolve to implicit
single-family groups. EP-6 must use the same resolver when expanding refresh targets, EP-5
must use it when validating consumer selections, and EP-7 owns the production Baikai plus
Shikumi group entry.

EP-4 also owns schema version 2 of `packages/first-party-lock.json`. A family snapshot is
addressed by `(family, generation)` and contains a locked GitHub fetch descriptor plus the
existing package metadata for both channels. An update-group snapshot is addressed by
`(group, generation)` and refers to exactly one family generation for every group member. It
also names the compatibility profile required by that historical cohort. A package set is a
sorted, complete mapping from every resolved update group to one group generation with an
explicit `curated` or `historical` support level, and `defaultPackageSet` names the curated
set behind compatibility aliases.
EP-5 reads and projects this graph; EP-6 is its only production writer; EP-7 migrates real
data into it.

EP-4 owns the shared Haskell types in
`cli/haskell-nix-update/src/HaskellNix/Update/Types.hs`, codecs and validators in `Catalog.hs`
and `PackageLock.hs`, and matching Nix fixture validation. EP-6 extends planning and workflow
code but must not redefine the contract. EP-5 consumes the Nix fixtures and must return the
same selected family/package order as the Haskell projection tests.

EP-5 owns `lib/mkFirstPartyPackageSet.nix` and the public constructor contract. Given a
retained package-set name or a complete consumer selection plus a channel, it returns a
registry, a composable Haskell extension, and an overlay. The constructor must keep the set
name and generation labels out of derivation inputs. EP-7 wires the designated default into
`flake.nix` and preserves all current output aliases.

EP-6 owns the CLI behavior in `HaskellNix.Update.Cli`, `Plan`, `Nix`, and `Workflow`. Normal
refresh updates one implicit family group or an explicit multi-family group, appends family
and group generations, and moves only the requested curated package set. EP-7 uses the
migration command to convert the production version-1 lock and to import a historical
mixed-version set without hand-editing generated records.

EP-5 and EP-7 share the cache acceptance invariant: if two package sets differ only in OKF,
an unchanged Keiro package must have equal `drvPath` values under the same channel, GHC, and
common compatibility registry. EP-7 additionally builds the supported sets under every
`lib.supportedGhcs` compiler and records which set combinations are curated rather than
claiming arbitrary compatibility.


## Progress

- [ ] EP-4: Define update groups, immutable snapshot generations, package sets, and strict version-2 codecs.
- [ ] EP-4: Prove cross-reference, sorting, coverage, and selected-package uniqueness validation in Haskell and Nix fixtures.
- [ ] EP-4: Add a deterministic version-1-to-version-2 projection/migration model while leaving production on version 1.
- [ ] EP-5: Build the package-set selector and per-channel registry projection from locked snapshot sources.
- [ ] EP-5: Expose a consumer-owned package-set constructor while preserving the current default interfaces.
- [ ] EP-5: Prove two sets with unchanged runtime selections evaluate to identical runtime derivation paths.
- [ ] EP-6: Extend refresh planning to append immutable family and group generations and move one named set.
- [ ] EP-6: Enforce atomic multi-family updates, dry-run behavior, dirty-file refusal, and byte-for-byte rollback.
- [ ] EP-6: Add repeatable migration and historical-set import commands with offline workflow tests.
- [ ] EP-7: Migrate production configuration and lock data, including the Baikai plus Shikumi update group.
- [ ] EP-7: Demonstrate an OKF-only upgrade with an older Keiro selection and run all supported set/channel/GHC checks.
- [ ] EP-7: Finalize consumer, cache, maintenance, and compatibility documentation.


## Surprises & Discoveries

- The current lock retains only one `LockedFamily` per family and `planRefresh` replaces it
  by family name. Historical locks and matching `flake.lock` nodes nevertheless contain the
  Git revisions, Hackage hashes, and NAR hashes needed to seed older selectable snapshots.

- The Cabal manifests in the Mori-located `mori://shinzui/keiro` and
  `mori://shinzui/okf` repositories contain no direct dependency on one another. That makes
  Keiro derivation identity across an OKF-only selection change a feasible acceptance test;
  the full build still covers shared transitive dependencies.

- The current generated registry applies `dontCheck` and `doJailbreak` to every first-party
  package. Exact-version evaluation therefore proves selection but not full declared-bound
  or test-suite compatibility. EP-7 must state and test the support level honestly rather
  than treating registry evaluation alone as compatibility evidence.

- Determinate Nix 2.33.3 successfully evaluated both a current and a historical GitHub
  locked descriptor with `builtins.fetchTree`. Old snapshots therefore do not need one
  permanent flake input per revision; the existing named family inputs can remain mutable
  tracking inputs used only by refresh.

- The repository has no `.github` workflow and does not itself publish cache artifacts.
  This initiative can prove derivation identity and build the curated closures, but remote
  cache upload remains outside scope.

- `flake.nix` currently defaults both profiling and Haddock suppression to true, while
  `docs/user/consumer-integration.md` describes those constructor defaults as false. The
  package-set migration must preserve code behavior and correct the guide; changing the
  defaults would invalidate cache comparisons and broaden this initiative.


## Decision Log

- Decision: Decompose the initiative into contracts, Nix composition, updater workflow, and
  production migration.
  Rationale: These concerns have distinct artifacts and validation costs; the split permits
  Nix and updater work to proceed in parallel after one shared contract is fixed.
  Date: 2026-09-13

- Decision: Make package sets consumer-selectable mappings rather than centrally enumerating
  every project combination.
  Rationale: Central combinations grow combinatorially and would recreate coordinated fleet
  upgrades. Consumers need to advance OKF while retaining their own Keiro generation.
  Date: 2026-09-13

- Decision: Label retained named sets as `curated` or `historical` and require the default to
  be curated.
  Rationale: Retention and selectability do not imply that every old global combination is
  maintained across the full compiler/channel matrix. The support claim must be machine
  readable so checks can target it honestly.
  Date: 2026-09-13

- Decision: Represent cross-repository release coupling as update groups and treat every
  ungrouped family as an implicit singleton group.
  Rationale: Repository families already keep their internal packages atomic. Only Baikai
  plus Shikumi currently need an additional cross-repository boundary, so singleton inference
  avoids repetitive configuration.
  Date: 2026-09-13

- Decision: Address snapshots with positive monotonically increasing generations scoped to
  their family or update group.
  Rationale: A Git revision alone is insufficient because a Hackage release can change while
  source HEAD stays fixed. Scoped generations need no new hashing dependency, are stable
  public selectors, and can cover source-identical Hackage-only changes.
  Date: 2026-09-13

- Decision: Keep family and group snapshots append-only and never automatically prune a
  published generation.
  Rationale: Haskell-Nix cannot discover every downstream consumer-owned selection. Removing
  an old generation would make an otherwise valid consumer fail merely by updating the
  Haskell-Nix flake.
  Date: 2026-09-13

- Decision: Keep GitHub/Hackage provenance orthogonal to package-set selection.
  Rationale: A package set answers which compatible versions to use; a channel answers where
  their source comes from. Combining both concerns in set names would duplicate manifests.
  Date: 2026-09-13

- Decision: Preserve existing public channel outputs as aliases of the designated default
  package set.
  Rationale: Consumers that do not need independent selection should upgrade without source
  changes, while new consumers can opt into explicit selections.
  Date: 2026-09-13

- Decision: Attach compatibility workarounds to immutable group snapshots through named Nix
  registry profiles, with `default` meaning no extra overrides.
  Rationale: An older cohort can need an older transitive dependency even when its own source
  is unchanged. Associating the exception with the cohort keeps it out of unrelated sets and
  makes any cache-path difference an explicit input rather than hidden global state.
  Date: 2026-09-13

- Decision: Require derivation-path equality for unchanged family selections across package
  sets.
  Rationale: The motivating outcome is binary-cache reuse, not merely a more expressive
  manifest. Package-set names, generation labels, and unrelated selections must not enter an
  unchanged family's derivation.
  Date: 2026-09-13

- Decision: Do not implement automatic compatibility solving.
  Rationale: Named and consumer-owned sets are explicit support claims backed by builds. A
  solver would add dependency-range extraction and search complexity without proving source
  or runtime compatibility.
  Date: 2026-09-13


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original vision.

(To be filled during and after implementation.)
