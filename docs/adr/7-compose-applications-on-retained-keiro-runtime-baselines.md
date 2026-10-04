# Compose applications on retained Keiro runtime baselines

Status: Accepted for implementation; runtime generations and validation evidence are pending.

Date: 2026-10-04

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

Retain the maintained Kafka fork where its fixes are required and identify it consistently
in Cabal and Nix. A source channel selecting Hackage first-party releases does not silently
erase a declared fork exception. Support evidence names the actual compiler/system/source
configuration, including native dependencies, rather than assuming that all combinations
are supported. Retained runtime labels and unrelated application metadata do not enter
dependency derivations.

Plan 16 owns membership, runtime records, the composition API and runtime-specific evidence.
Plans 8, 9 and 10 retain ownership of solving/reporting, generation/manifests/comparison and
shared policy/auditing respectively. Application-adoption plans 11–13 depend on plan 16;
plan 14 consumes the resulting runtime identity in its existing deploy guard. Other runtime
consumers can adopt the API independently.

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
profiles or touching production databases. All runtime delivery and timing evidence remains
pending under [plan 16](../plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md).
