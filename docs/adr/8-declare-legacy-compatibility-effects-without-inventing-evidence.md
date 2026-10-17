# Declare legacy compatibility effects without inventing evidence

Status: Accepted design; migration identity verification is pending.

Date: 2026-10-17

## Context

The executable registry combines source constructors, compiler repairs and package
test/bounds policy. Generated first-party and cohort constructors add their own
policy. Successful production builds cannot establish that skipped tests ran,
relaxed bounds were enforced or a workaround remains necessary. Internal compiler
and source guards also make an outer always-selected row an incomplete report.

[ADR 4](4-consumer-overlays-define-only-their-own-packages.md) reserves shared policy
for this channel. [ADR 7](7-compose-applications-on-retained-keiro-runtime-baselines.md)
protects historical recipes. The catalog must preserve both constraints.

## Decision

Keep descriptive exception records in `config/compatibility-exceptions.json` and
explicit construction profiles in `config/package-build-policies.json`. Stable IDs
join recipe bindings, waivers and future native evidence. Validate complete registry,
generated-constructor and profile coverage without evaluating package values.

Record migrated effects as unverified. Existing comments and upstream references
are investigation pointers; they do not become fresh validation receipts. Describe
source selection separately from temporary repair and durable build policy. Exact
sources remain owned by the existing locks and constructors. Keep compiler/version,
system and source assertions visible, including independent effects within one row:
unicode-data's unconditional test suppression differs from its guarded metadata repair.

Named legacy profiles preserve the exact order and semantics of existing wrappers.
Their test/bounds modes and legacy construction semantics cannot change under the same immutable name. A legacy layer that historically changed only bounds must not accidentally re-enable tests suppressed by an earlier layer. Its mode labels are not final behavioral evidence. Complete profiles explicitly set both modes; strict validation must still construct them before any bounds rewrite. A stricter
policy needs a new selected configuration and matching behavioral evidence. Apply
policy during construction; a later flag change cannot undo an earlier metadata
rewrite or prove that a dependency suite ran.

Keep catalog prose, IDs, evidence pointers and observation times outside production
derivation arguments. Source, metadata, flags, native inputs, compiler and effective
test/bounds policy remain real build inputs. Retained recipe directories remain
unchanged by the current catalog migration.

## Consequences and validation

Coverage validation catches missing owners/reasons, malformed guards, duplicate IDs,
orphan bindings and missing/wrong waiver references. It proves declaration consistency,
not that arbitrary patch functions have only their declared effects. Shared executable
selection/report predicates and strict native removal probes remain EP-21 work.
No entry is retired automatically, and ordinary builds do not run expensive probes.

Migration acceptance additionally compares actual production derivations before and
after the refactor. Native test/bounds claims require separately scoped receipts;
blocked services and unavailable platforms remain visibly unverified.
