# Compose applications on retained Keiro runtime baselines

Status: Accepted; generations 1 and 2 and their declared GHC 9.12.4 platform/channel matrices are implemented and verified.

Date: 2026-10-04

Revised: 2026-10-27

## Context

Multiple projects use the same Keiro runtime. MP-3 aligns application dependency versions,
but a reusable runtime baseline needs explicit membership, source policy, retention and
composition behavior. The user requested a dedicated implementation plan and confirmed that
Keiki is essential alongside Keiro, Kiroku, Shibuya, pgmq-hs, Settei, pg-migrate and the
maintained hw-kafka-client fork.

ADR 1 retains first-party family/group snapshots and complete selections in one Haskell
scope. Its schema-2 catalog has fixed topology. The current constructor therefore cannot
directly accept only the runtime groups, and the Kafka fork and several adapter projects
are not catalog families. ADR 5 requires ordinary application edits to preserve unchanged
shared builds and requires evidence that CI can substitute them.

## Decision

Add a reusable `keiro-runtime` selection with append-only runtime generations. A generation
captures required root components, the resolved dependency closure, existing first-party
group selections, non-catalog source components, and the version/source/metadata/flag/policy
recipes for each declared build configuration. Keiki and its required JSON codec are part
of that closure. Inventory adapters and Kafka integration dependencies rather than treating
the eight root names as an exhaustive package list.

Keep existing family and update-group boundaries. Publish tested combinations as runtime
generations, and permit an individual family to advance when compatibility and impact checks
pass. This does not turn every runtime patch into an update of every runtime family.

Preserve the schema-2 catalog and its complete-selection API. The new runtime wrapper combines
retained runtime group selections with an explicit complementary application mapping before
calling the existing constructor. Missing selections and conflicting ownership fail; no
mutable default silently fills them. Non-catalog forks/adapters receive exact source records
in the runtime manifest. Admitting those projects as catalog families remains an explicit
future topology migration.

Derive runtime projections from the existing Cabal solve and generated Nix recipes. Retain
the selected runtime projection as exact constraints during application-only solving.
Compose runtime and application recipes into one recursive Haskell scope. Every package name
has one dependency instance; application changes to runtime-owned versions, sources, metadata,
flags or policy require an explicit new runtime generation/configuration. Applications build
only the runtime components they actually use.

Live catalog migrations may add discovery metadata unknown to an older captured constructor.
Validate the complete live graph with the current validator first, then project optional
`additionalPackagePaths` away only at the captured construction boundary; the older factory
already receives the immutable package paths and never discovers packages. Do not edit
captured recipe directories or rewrite runtime-owned snapshots. Extend repository-owned
application complements explicitly. New application-only source dependencies absent from
retained cohorts may use their live owned recipes, guarded against runtime ownership;
retained runtime recipes and derivation identities remain authoritative. Public selected-family
metadata comes from the unmodified live snapshot graph even when construction needed a
narrower internal metadata projection.

Retain the maintained Kafka fork where its fixes are required and identify it consistently
in Cabal and Nix. A source channel selecting Hackage first-party releases does not silently
erase a declared fork exception. Support evidence names the actual compiler/system/source
configuration, including native dependencies, rather than assuming that all combinations
are supported. Retained runtime labels and unrelated application metadata do not enter
dependency derivations.

Retain the recipe context itself: shared libraries, registries, patches, configuration,
full cohort data and both source/toolchain locks. A generation also captures its root
definition, resolved GitHub source descriptors with NAR hashes, and a recomputable identity
covering ownership and effective policy inputs. Old records use their captured definition
when the live definition grows. Store deterministic runtime version/flag projections and
fresh bounded GitHub/Hackage source profiles; both replay the shared cohort with no new
version choice. Checks verify hashes, recipe membership and source/freeze agreement without
rewriting managed files. Snapshot stages all outputs and restores every managed file if
publication fails. Append a changed generation; unchanged effective inputs select the
existing record. Cache and build evidence is retained outside immutable recipe directories.

Cabal import behavior was verified in `mori://haskell/cabal`, project-relative
`cabal/cabal-install-solver/src/Distribution/Solver/Types/ProjectConfigPath.hs` and
`cabal/cabal-install/src/Distribution/Client/ProjectConfig/Import.hs` (artifact-level
source URIs pending).

Cabal does not resolve relative children against a remote project URL. Consumer adoption
therefore materializes the original runtime project, freeze and configuration bytes from an
explicit channel commit, verifies their retained SHA256 values and commits them with a source
selection receipt. The shared `runtime-import` tool refuses changed retained projections,
provides no-write checking and rolls back partial publication. The complete cohort freeze
continues to use the application's same pinned channel revision. This changes delivery of
projections, not their immutable contents or any dependency recipe. Import validates version
agreement with the selected current cohort; older generations whose Kiroku versions differ
remain retained but are rejected against that cohort. Tests must choose a matching generation
for successful imports and retain a deliberate conflict case for older generations.

The public constructor requires explicit runtime, generation and complementary selections.
It imports a content-addressed retained recipe subtree with a stable name, independently of
the current wrapper flake's source path. `mkApplicationScope` checks the final scope against
an independent scope from the retained compiler, native stdenv, recipes and original catalog
selection. `mkApplicationManifest` applies that check before building actual-root evidence;
manual extension users must invoke `validateApplicationScope`. Application cohort and policy
inputs cannot replace runtime-owned records. Non-runtime compatibility fragments cannot own
runtime names. Ordinary app documentation, leaf source and unrelated group changes preserve
runtime identities; a real runtime public-interface addition changes both fixture dependents.

Plan 16 owns membership, runtime records, the composition API and runtime-specific evidence.
Plans 8, 9 and 10 retain ownership of solving/reporting, generation/manifests/comparison and
shared policy/auditing respectively. Application-adoption plans 11–13 depend on plan 16;
plan 14 consumes the resulting runtime identity in its existing deploy guard. Other runtime
consumers can adopt the API independently.

## Preserving Cabal HTTPS imports

Mori requires Dhall remote HTTPS imports in its Cabal build. Generation 1's Cabal
projection disables that flag, although its admitted Nix policy already enables it.
Append generation 2 with the same versions, index and sources and Cabal TLS enabled;
never rewrite generation 1 or override a runtime-owned flag in an application.
The native comparison proves every one of the 273 non-Boot Nix derivations is unchanged.
A newly built Cabal executable successfully evaluates a published remote profile with a
fresh private cache. Generation 2 passes its declared matrix, actual application composition proofs, both
native integration sweeps and fresh-worker substitution with zero builds. Its fingerprint-bound
support evidence is retained in `cabal/runtime-cache/keiro-runtime/2/support.json`. Generation-qualified build outputs and a CI generation input let both
retained configurations be checked independently without moving existing output aliases.

## Alternatives and consequences

A complete named first-party set alone can select a compatible catalog combination, but
does not expose runtime-only ownership, retained third-party/fork policy, or guarded
application composition. Retained runtime records provide those contracts without changing
the meaning of existing catalog selections. A new atomic group spanning every runtime
family would increase coordination for otherwise independent patches.

The runtime dependency closure constrains application choices where the two share libraries.
A conflicting application update may need a runtime upgrade; reporting that conflict is
preferable to silently rebuilding the shared runtime under different inputs. Existing
first-party support matrices and historical-selection checks remain required. Runtime
support is an additional explicit matrix, initially targeting MP-3's GHC 9.12.4.

## Validation

Require matching Cabal/Nix runtime projections, source-policy verification and structured
derivation-graph manifests. Two applications with equal runtime inputs must share runtime
drv/output identities. Application-only edits preserve them; genuine runtime changes
invalidate affected dependents and leave unrelated selections unchanged. Reject missing
Keiki, missing complement mappings, conflicting duplicate ownership and source/metadata
drift at unchanged versions.

Build declared configurations on aarch64-darwin and x86_64-linux, publish outputs through
the existing trusted cache and prove substitution on fresh workers. Reuse disposable runtime
verification machinery from `mori://shinzui/keiro-runtime-kenshou` without changing its historical
profiles or touching production databases. Generation 1 passes both complete platform gates, actual application-manifest proofs,
both native source-channel integration sweeps and fresh-worker zero-build substitution for
all four configurations. Evidence is bound to the immutable fingerprint in
`cabal/runtime-cache/keiro-runtime/1/support.json`. Fleet update measurements remain owned
by plan 14; runtime delivery is accepted under
[plan 16](../plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md).
