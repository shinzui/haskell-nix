# Compose first-party snapshots in one Haskell scope

Status: Accepted for implementation; production migration is pending.

Date: 2026-09-21

## Context

The current first-party lock keeps one observation per repository. Updating the default
therefore replaces the only selectable version. Consumers need to advance one independent
family while retaining another, and unchanged dependency closures should remain cacheable.
The repository already builds packages through Nixpkgs Haskell extensions and exact GitHub
or Hackage sources. No existing local ADR corpus or ADR profile was present at review time.

## Decision

Retain immutable family snapshots and atomic update-group snapshots as data. Named sets and
complete consumer mappings select those snapshots. Fetch GitHub trees from locked revision
and NAR-hash descriptors; keep tracking flake inputs for refresh observation. Hackage pins
remain an orthogonal channel. Do not allocate one permanent flake input per old revision.

Compose the selected registry into one Nixpkgs Haskell fixed point: the final recursive
package scope resolves all dependencies. Use ordinary Haskell extensions, preserve existing
overrides, and permit later consumer overrides. Do not merge derivations built separately
for each family; the scope still has one instance of each package name.

Cache reuse requires equal transitive build inputs, including platform, Nixpkgs, GHC, source,
dependency derivations, patches, and build settings. Names, generation numbers, support
labels, and unrelated selections are metadata and must not enter derivation inputs.
An unchanged source can legitimately rebuild when one of its dependencies changes. Retaining
first-party snapshots does not freeze future Nixpkgs or common-registry behavior; consumers
requiring the whole environment unchanged must also retain their flake/toolchain pins.

Capture discovery policy (package overrides and exclusions) inside each family snapshot.
Apply current policy only to new observations. Validate historical records against their
captured policy so a package-policy change cannot reinterpret a published generation.
Compatibility profile definitions are retained under immutable names; revised definitions
receive new names. Deduplicate profile names, reject overlaps between distinct profiles, and
reject profiles overriding selected first-party packages. A shared workaround can be expressed
as one profile referenced by several groups. These profiles affect the whole Haskell scope,
so all dependents of a changed shared dependency must be checked.

The initial version-2 schema fixes family identities and the update-group partition. Adding,
removing, or regrouping families requires an explicit future catalog migration. This is a
deliberate limit of complete consumer mappings; never fill missing selections from a mutable
default. Package inventory and discovery-policy changes inside existing families are supported.

Every mutation validates its selected target, including historical sets. Tracking inputs
need not equal historical selections. Evaluation and compilation are distinct gates: only
full supported system/channel/compiler builds justify promoting a new curated combination.
Retain the clean-managed-file guard and commit validated rollout mutations before subsequent
mutations. Keep schema-1 CLI dispatch usable until the production migration.

## Alternatives and consequences

Consumer flake input overrides are simpler for a one-off source substitution, but do not
provide this repository's dual-channel snapshots, retained package policy, atomic multi-family
updates, or curated support evidence. Multiple independent Haskell scopes complicate shared
dependency identity and linking. An automatic dependency solver is unnecessary for the initial
explicit supported combinations and would not establish source compatibility by itself.

The four child plans remain contracts, composition, updater, and rollout. This keeps schema
ownership central and permits Nix/updater work after that contract exists. The additional
catalog is justified by the retention requirement; the package constructor continues to use
ordinary Nixpkgs extensions. Historical sets remain selectable without promising they build forever
on future toolchains. Existing jailbreak and disabled-test behavior limits support claims to
the builds actually performed.

## Validation

Tooling adopted on 2026-09-21 uses flake-parts for output organization, with build checks in
`checks/default.nix` and tooling in `nix/tooling.nix`. Both flake-parts and treefmt-nix follow
the existing pins in `mori://shinzui/haskell-nix-dev`. Nix-unit and nix-diff come from the
existing Nixpkgs pin. Pure named tests live in `checks/unit.nix`; treefmt uses the fleet's
nixpkgs-fmt style and contributes a flake check. Nix-diff provides diagnostics for changed
derivation inputs. The package constructor remains independent of the module framework.
Git-hook installation is optional and not performed; nix-eval-jobs remains deferred until
evaluation performance provides a reason to adopt it.

Require identical derivations when only an unrelated selection or label changes, and changed
derivations when an actual dependency changes. Exercise downstream override composition,
historical-policy retention, profile conflicts, and lazy source fetching. All flake `checks`
entries are derivations; diagnostic JSON belongs in `passthru.results`. Record native or
remote build evidence for each supported system; a single host check is insufficient.

The implementation is coordinated by
[MasterPlan 2](../masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md).
Relevant primary references are the
[Nixpkgs fixed-point implementation](https://github.com/NixOS/nixpkgs/blob/master/lib/fixed-points.nix),
[Haskell package-set implementation](https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/haskell-modules/make-package-set.nix),
and [Nix flake check contract](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake-check.html).
These explain the composition and output rules; the implementation must use the repository's
pinned Nixpkgs and verify behavior on its supported Nix runtime.
