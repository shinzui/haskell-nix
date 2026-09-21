---
id: 5
slug: compose-cache-stable-package-sets-in-nix
title: "Compose cache-stable package sets in Nix"
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
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-09-21T14:06:32Z
      verdict: "approved"
      note: "Reviewed revised plan against repository and Nix semantics; implementation build and cache acceptance gates remain pending."
---

# Compose cache-stable package sets in Nix

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan turns the snapshot graph from EP-4 into composable Nix values. A consumer can ask
for a retained package-set name or provide its own complete update-group selection, choose
GitHub or Hackage provenance, and receive a registry, a standard Haskell package-set
extension, and a Nixpkgs overlay. Two selections may differ in OKF while resolving the same
Keiro generation.

The central acceptance criterion is binary-cache identity. Under the same Nixpkgs, GHC,
system, channel, build settings, compatibility inputs, and transitive dependency derivations,
an unchanged family snapshot must have
the same derivation path in both package sets. Package-set names, group generations, and
unrelated selected families are evaluation metadata only; they must not be embedded in
package derivation names, sources, or environment variables. The plan proves this first
with local fixtures before production data moves to the new model.


## Progress

Use a checklist to summarize granular steps. Every stopping point must be documented here,
even if it requires splitting a partially completed task into two ("done" vs. "remaining").
This section must always reflect the actual current state of the work.

- [ ] Implement selected-set projection to lazy GitHub sources and exact Hackage pins.
- [ ] Compose selected first-party registries with common and compatibility-profile entries.
- [ ] Expose a generic consumer-owned package-set constructor without moving the public default.
- [ ] Prove set and channel isolation with valid and invalid Nix fixtures.
- [ ] Prove equal derivation paths for unchanged family snapshots across two package sets.
- [ ] Prove changed dependencies rebuild dependents, source fetching stays lazy, and downstream overrides survive composition.


## Surprises & Discoveries

Document unexpected behaviors, bugs, optimizations, or insights discovered during
implementation. Provide concise evidence.

The existing registry checks current discovery policy, so historical projections must carry
snapshot-specific policy. Also, `checks.<system>.<name>` must be a derivation: JSON assertion
results belong in a check derivation's `passthru.results`, not a sibling check attribute.

A minimal Nix 2.33.3 derivation probe during review returned `dependentChanges = true` when
only the dependency derivation changed, and confirmed `deepSeq` is needed to catch an error
inside a lazy record with `tryEval`. The Haskell-specific proof remains to be implemented.


## Decision Log

Record every decision made while working on the plan.

- Decision: Build one final Haskell scope using standard extensions and resolve dependencies
  through `hself`; promise cache identity only for unchanged transitive build inputs.
  Rationale: Independently constructing family derivations can mix incompatible dependency
  instances. Shared dependency changes legitimately rebuild every affected family.
  Date: 2026-09-21

- Decision: Make `lib.mkFirstPartyPackageSet` return a record containing `registry`,
  `haskellExtension`, and `overlay`.
  Rationale: Direct extension composition is the repository's recommended consumer path,
  while the other two values support inspection and simpler consumers without duplicating
  selection logic.
  Date: 2026-09-13

- Decision: Accept either one retained set name or one complete consumer selection, never
  both.
  Rationale: Curated sets need a concise stable interface, while downstream projects need
  combinations not centrally enumerated. Rejecting ambiguous calls keeps the selected graph
  explicit.
  Date: 2026-09-13

- Decision: Fetch historical GitHub snapshots from their stored locked descriptors with
  `builtins.fetchTree` and retain current flake inputs only as updater tracking inputs.
  Rationale: One flake input per historical revision would make `flake.lock` grow with every
  release. A revision plus NAR hash is already immutable and evaluates to the same source
  store path.
  Date: 2026-09-13

- Decision: Keep arbitrary-set overlays as returned constructor values and expose named
  top-level `overlays.github` and `overlays.hackage` only for the default set.
  Rationale: Flake overlay outputs are conventionally a flat attribute set of functions.
  Direct extensions also compose more safely with downstream overrides.
  Date: 2026-09-13


## Outcomes & Retrospective

Summarize outcomes, gaps, and lessons learned at major milestones or at completion.
Compare the result against the original purpose.

(To be filled during and after implementation.)


## Context and Orientation

Tooling is already adopted: `flake.nix` uses flake-parts, `checks/unit.nix` holds named
pure nix-unit tests, and `checks/default.nix` holds build checks. Extend those files rather
than adding another runner or inlining the matrix into `flake.nix`. Run `just nix-test`
and `just fmt-check`. On a cache-identity failure, retain both evaluated derivation paths
and run `just drv-diff '<before.drv>' '<after.drv>'`; diagnose the differing inputs before
changing assertions. Keep the constructor in `lib/` independent of flake-parts.

Follow [docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md).
It records the single-scope composition boundary, immutable snapshot policy and profile
definitions, and the conditional cache guarantee; no older local ADR covered this work.

This plan has a hard dependency on
`docs/plans/4-define-immutable-family-snapshots-and-update-cohorts.md`. Do not implement it
until EP-4 is marked Complete in
`docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md`. EP-4
provides strict Nix validation and a selector that projects a package set to one family
snapshot per configured family.

The current Nix path begins in `flake.nix`. It reads
`config/first-party-families.json`, `packages/first-party-lock.json`, and one named source
input per family. It calls `lib/mkFirstPartyRegistries.nix`, which validates a flat family
lock and generates two registry attribute sets. A registry maps a Haskell package name to a
list of version-dispatch entries. `flake.nix` merges the generated registry over
`overlays/registry.nix`, the common compatibility registry, and turns the result into a
Haskell extension with `fixPackageByVersion`.

`lib/mkHaskellOverlay.nix` and `overlays/haskell-overlay.nix` apply one registry to every
compiler in `lib.supportedGhcs`. The preferred downstream interface is a direct extension,
because a consumer can compose it with local Haskell overrides. Current public values are
`lib.registries.{github,hackage}`, `lib.haskellExtensions.{github,hackage}`, and
`overlays.{github,hackage}`. Singular names and default overlays alias GitHub.

EP-4's selected projection still has enough information to create the flat input expected by
`mkFirstPartyRegistries.nix`: family name, configured `githubInput`, locked revision, and
package records. For a GitHub channel, the corresponding source value comes from
`builtins.fetchTree familySnapshot.source`. For a Hackage channel, each published package
already carries the exact version and archive hash used by `callHackageDirect`; no GitHub
source is required by the resulting package.

A compatibility profile is a retained Nix registry fragment needed by an older update-group
generation when the global common registry has moved. Profiles live in
`overlays/compatibility-profiles.nix` and are referred to by name from group snapshots. The
empty profile is `default`. Profile names are append-only identifiers: changes to a retained
fragment require a new name. Selected profiles are merged after `overlays/registry.nix` and
before selected first-party packages. Deduplicate names first, so several groups may refer
to one consolidated profile. Reject package-key overlap between distinct selected profiles
and reject profile keys naming any selected first-party package, including GitHub-only
packages on the Hackage channel. Do not silently resolve these conflicts with merge order;
Nix functions cannot be safely compared for equality.


## Plan of Work

### Milestone 1: Construct one selected registry without extra flake inputs

Create `lib/mkFirstPartyPackageSet.nix`. Import and use EP-4's validator; do not reimplement
its reference checks. The function takes `lib`, `config`, the version-2 lock, the common
registry, compatibility profiles, supported compiler names, and the existing registry and
overlay constructors. Its exported `mkFirstPartyPackageSet` accepts exactly one of a retained
`packageSet` name or a `selections` attribute set mapping resolved group names to positive
generations. It also accepts `channel`, `disableProfiling`, and `disableHaddock` with the same
defaults as the current channel constructor.

Project the selected graph to a version-1-shaped family list and a matching version-1-shaped
catalog using each snapshot's discovery policy only at the existing registry boundary.
Keep stable family identity/tracking-input names from config but never apply current options
or exclusions to retained package records. Build the source attribute set lazily from each selected family snapshot's locked
descriptor. The descriptor passed to `builtins.fetchTree` contains only `type`, `owner`,
`repo`, `rev`, and `narHash`. Assert that the resulting revision equals the stored revision.
Do not put the package-set name, family generation, or group generation into a package name,
source name, derivation attribute, or Cabal2nix option.

Keep fetching separate from structural validation. Inject `fetchSource ? builtins.fetchTree`
only into the internal factory so local fixture descriptors can resolve to checked-in source
trees. The public bound constructor must use the real fetcher. Add throwing fetcher cases:
evaluating selection metadata, using Hackage, or selecting a different GitHub snapshot must
not force an unneeded fetch. Test one real locked GitHub descriptor in pure evaluation as a
separate integration check. Document the required `nix-command`/`flakes` features and verify
on the installed Nix; do not weaken the strict production descriptor schema for fixtures.

Refactor `lib/mkFirstPartyRegistries.nix` only where necessary to accept the selected flat
projection or to construct one requested channel lazily. Preserve its symlink staging,
GitHub-only handling, exact package versions, and existing version-1 callers until EP-7.
Add a fixture containing two versions of an OKF-like family and one shared runtime family.
Evaluate both GitHub and Hackage registries and verify that each exposes the selected
versions.

The milestone is complete when a pure Nix expression constructs four combinations—two sets
times two channels—without modifying the production outputs or adding historical source
inputs to `flake.nix`.

### Milestone 2: Compose compatibility profiles and standard consumer values

Create `overlays/compatibility-profiles.nix` with an empty `default` profile and a documented
record shape. For every selected group snapshot, collect its profile name. Validate that the
profile exists, deduplicate names, and enforce the collision rules described above.
Compose registries in this order:

```text
common registry -> selected compatibility profiles -> selected first-party registry
```

The selected first-party entry wins over a common-registry entry; a profile collision is an
error. Reproduce the current Hackage null
placeholder behavior only for GitHub-only packages in the selected set, not for every
historical snapshot in the catalog.

Return this exact conceptual record from `mkFirstPartyPackageSet`:

```nix
{
  selections = { /* normalized group -> generation map */ };
  selectedFamilies = [ /* normalized family snapshot records */ ];
  registry = { /* selected channel registry */ };
  haskellExtension = haskellLib: pkgs: /* standard extension */;
  overlay = final: prev: /* supported-GHC overlay */;
}
```

Move reusable extension construction currently local to `flake.nix` into a library function
or parameterize it so current and package-set paths share one implementation. Preserve
`disableProfiling` and `disableHaddock` semantics, including per-package opt-back-in.

Use a single final scope (the recursive set containing all resulting packages), with
`hself.callCabal2nix`/`hself.callHackageDirect` resolving dependencies from that scope.
Preserve existing `old.overrides` using `lib.composeExtensions`; compose consumer extensions
after this extension in the documented example. Add a test with a pre-existing override and
a later consumer override, proving both survive and a selected package sees the overridden
dependency. Never assemble a scope by merging independently instantiated family packages.

Expose the generic constructor under `lib.mkFirstPartyPackageSet`. During this plan it takes
explicit `config` and `lock` inputs or is demonstrated only through fixtures; it must not
redirect the production default before EP-7. Document the provisional interface in the
function header and focused tests, not yet in the end-user guide.

### Milestone 3: Prove cache-stable composition

Add fixture sources under `checks/fixtures/package-sets/source/`. The runtime fixture must
have identical source and dependencies in both sets. The OKF-like fixture has two immutable
generations with different versions or source contents. Construct two otherwise identical
Nixpkgs Haskell scopes under `lib.defaultGhc`: set A selects runtime generation 1 plus OKF
generation 1, and set B selects runtime generation 1 plus OKF generation 2.

Force `.drvPath` for the unchanged runtime package and the changed OKF-like package. Assert
that the runtime derivation paths are equal and the OKF-like derivation paths differ. Repeat
the unchanged-runtime equality assertion for both GitHub and Hackage provenance. Also assert
that changing the GHC, channel, runtime generation, build settings, or a compatibility
profile is allowed to change the path; the cache guarantee applies only when actual package
inputs are equal.

Add a third fixture package that depends on the changing OKF-like package: its source stays
fixed but its `drvPath` must change. A shared-dependency override must similarly change the
runtime path. Renaming a set, appending an unselected snapshot, or changing irrelevant policy
metadata must preserve unaffected paths. For Hackage use two real, pinned published fixture
versions and hashes (verified during implementation through Mori and Hackage), not invented
local package names. Keep the pure graph/laziness fixtures independent of those downloads.

Add negative evaluation cases for incomplete selections, simultaneous curated and explicit
selection, unknown channels, missing compatibility profiles, profile key conflicts, and a
locked source whose returned revision disagrees with metadata. Integrate the focused checks
into `flake.nix` and run the entire flake check. The milestone is complete only when cache
identity is an executable assertion rather than a documentation claim.

Each check is a derivation with assertions and optional `passthru.results`. Keep structural
checks free of import-from-derivation (IFD, evaluation that first builds Cabal2nix output).
The derivation-identity tests may need IFD; retain the updater's warm-check path and document
that evaluation can build generators even when final Haskell packages are not built.


## Concrete Steps

Run from `/Users/shinzui/Keikaku/bokuno/haskell-nix`. Verify EP-4 and inspect current Nix
interfaces before editing:

```bash
sed -n '1,260p' docs/plans/4-define-immutable-family-snapshots-and-update-cohorts.md
nix eval --json .#lib.supportedGhcs
nix eval --json .#lib.registries.github --apply builtins.attrNames
nix eval --json .#lib.registries.hackage --apply builtins.attrNames
```

Parse every new or changed Nix file:

```bash
nix-instantiate --parse lib/mkFirstPartyPackageSet.nix >/dev/null
nix-instantiate --parse lib/mkFirstPartyRegistries.nix >/dev/null
nix-instantiate --parse overlays/compatibility-profiles.nix >/dev/null
```

Expose a focused result attribute from the package-set check and inspect it:

```bash
nix eval --json .#checks.aarch64-darwin.package-set-cache-identity.results
nix build --no-link .#checks.aarch64-darwin.package-set-cache-identity
```

Use the current system key on non-Apple systems. Expected result structure includes equal
runtime paths and unequal changed-family paths:

```json
{
  "githubRuntimeEqual": true,
  "hackageRuntimeEqual": true,
  "githubOkfDifferent": true,
  "hackageOkfDifferent": true
}
```

Finish with:

```bash
nix flake check --print-build-logs
git diff --check
```

Use Conventional Commits and all active trailers:

```text
feat(nix): compose cache-stable first-party package sets

MasterPlan: docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md
ExecPlan: docs/plans/5-compose-cache-stable-package-sets-in-nix.md
Intention: intention_01m2f17g4ye8qtz89rnbvndk5s
```


## Validation and Acceptance

A caller selecting a named set and a caller supplying the equivalent explicit map
must obtain the same normalized selections and package versions. Supplying both forms, an
incomplete map, or an unknown group/generation must fail before a registry package is forced.

For every selected family, GitHub uses the locked source revision in that generation and
Hackage uses the exact non-null version/hash in that same generation. An unpublished package
is absent only from the Hackage registry. Historical GitHub sources resolve without adding a
new top-level flake input.

The cache fixture must prove an unchanged runtime package has the same derivation path in two
package sets whose only difference is the selected OKF-like generation. The changed OKF-like
package must have a different path. A package-set label change alone must not change either
path.

Current `lib.registries`, `lib.haskellExtensions`, and `overlays` values must retain their
pre-plan package names and versions. `nix flake check` must pass on every supported system.

Repeated use of one profile name succeeds; two distinct overlapping profiles fail; a profile
overriding a selected family fails. Historical snapshot-policy fixtures must still evaluate
after current policy changes. Realise checks on each supported native system or configured
remote builder and record coverage: one host's `nix flake check` is not an all-system build.


## Idempotence and Recovery

All source fetching is content-addressed by revision and NAR hash, so repeated evaluation is
safe and cacheable. Fixture package sets do not mutate production locks or tracking inputs.
If the package-set constructor exposes recursion or derivation instability, keep it behind
the fixture check and adjust composition before exporting it; do not switch the public
default as a workaround.

If a historical descriptor is not already available locally, Nix may fetch it during the
first evaluation. A hash mismatch must fail rather than update metadata. Re-run through the
later updater workflow to create a new immutable snapshot; never edit an existing snapshot
hash merely to make evaluation succeed.


## Interfaces and Dependencies

Use Nixpkgs `lib`, `builtins.fetchTree`, the existing `fixPackageByVersion`,
`mkFirstPartyRegistries`, `mkHaskellOverlay`, and `haskell.lib.compose` interfaces. Nix 2.33.3
in the planning environment successfully fetched both current and historical GitHub locked
descriptors. If implementation targets a different Nix release, verify `fetchTree` against
that release's authoritative manual and behavior before adding compatibility code.

`lib/mkFirstPartyPackageSet.nix` must expose a function equivalent to:

```nix
{ lib
, config
, lock
, commonRegistry
, compatibilityProfiles
, supportedGhcs
, mkFirstPartyRegistries
, mkHaskellExtension
, mkHaskellOverlay
}:
{
  mkFirstPartyPackageSet =
    { packageSet ? null
    , selections ? null
    , channel ? "github"
    , disableProfiling ? true
    , disableHaddock ? true
    }:
    { selections = { }; selectedFamilies = [ ]; registry = { };
      haskellExtension = _: _: _: _: { }; overlay = _: _: { }; };
}
```

The exact currying may follow repository style, but input exclusivity and returned fields are
part of the acceptance contract. `overlays/compatibility-profiles.nix` is an attribute set
from profile name to registry fragment and must always define `default = { };`. EP-7 will
bind the constructor to production config/lock and make the curated default public.

Revision 2026-09-21: tighten fixed-point and transitive cache semantics, preserve historical
policy, define immutable conflict-checked profiles, and correct check output/fixture design.
Implementation remains unstarted; acceptance now includes dependency propagation and laziness.

Tooling update 2026-09-21: use the implemented flake-parts, treefmt-nix, nix-unit, and
nix-diff foundation for this plan's checks and diagnostics. Package-set milestones remain
unstarted; tooling adoption does not count as completing the schema or migration work.
