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
Channel lists describe membership: reordering them must not change activation. Omitted
channel facts are accepted only for an exception declared in both source channels;
a restricted exception requires an explicit channel selection.

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

The first report interface is explicitly `declaration-only`. It shares executable
row and applicability selection, requires explicit pre-repair source/metadata facts,
and keeps source guards and native requirements unverified. Its interchange validator
rejects fabricated pass labels and inconsistent required-evidence diagnostics, but
does not authenticate caller facts or prove arbitrary patch effects. Input and policy
report identities exclude descriptive reason text; changed exact input facts or
semantic policy change their respective identities. A declaration check with no
required native evidence is not a strict validation receipt.

Opt-in capture observes the actual recursive construction boundary. Do not reconstruct
a separate unpatched scope: its dependency instances can differ from the real inputs.
Preserve source-constructor versus repair stages and lazy replacement of absent stock
packages. Inspect consumed Cabal arguments through `overrideCabal`; final derivation
attributes omit fields such as revision and jailbreak policy. Keep observations on
returned values, outside builder arguments, preserving ordinary derivation identities.

Lazy source trees can render transient path aliases. Canonicalize source and contextual
hook identities through metadata-only derivation projections, without building them.
Remove output string contexts from exported diagnostic JSON so report materialization
does not require dependency output realization. Record dependency derivations and output
names rather than output paths. Strict validation owns disabled-test input
inventory; ordinary reports must not force that closure. Older retained constructors
without capture hooks are explicitly unsupported rather than silently replayed through
new policy. Native source/metadata probes remain separate acceptance work.

Admitting-metadata candidates require equal complete recipes as well as selected
metadata identity. The cborg-json repair demonstrates why: identical revised metadata
can still require an additional guarded Cabal-bound rewrite in `postPatch`. Neither
metadata equality nor a matching declaration establishes successful native retirement.

Strict probe construction requests the immutable strict profile before compatibility
entries are applied and suppresses one requested entry during construction. Require
enabled standard Cabal suites, disabled jailbreak and matching selected source,
metadata, compiler and declared dependency instances. Reject custom/filtered test
execution until its coverage has an explicit probe contract. Missing service probes
block before constructing packages; supplied service metadata is not native evidence.
Staged requests stay unverified, with actual suite logs, executable checks and the
existing cohort graph producer supplying separate execution evidence.

A null Cabal dependency value is unresolved, not necessarily missing: compiler-provided
libraries can be represented that way. Resolve coverage against compiler-package and
graph evidence rather than inventing a missing package or silently solving a new one.

Migration acceptance additionally compares actual production derivations before and
after the refactor. Native test/bounds claims require separately scoped receipts;
blocked services and unavailable platforms remain visibly unverified.

Native probe contexts name the complete suite inventory and exact baseline/candidate
graph, behavior and service-check derivations. Use the existing cohort producer to
reconstruct/check dependency graphs; reject duplicate Haskell package instances and
omitted declared/transitive dependencies. The strict path also rejects explicit
configure flags that disable tests or relax bounds. Build native probes only on the
declared system and retain bounded execution logs.

A receipt's success label alone is insufficient. Recheck exact expected context,
complete required outcomes and absence of waivers, then query Nix's current output
metadata and original native suite logs without rebuilding. Missing metadata/logs
invalidate the claim. Cache substitution without available native test logs does not
establish test execution. These local receipts assume a trusted expected constructor
context; they are not signed attestations against a malicious context producer.
Supplied service probes require native evidence, and actual service-backed suites
must contact isolated bounded services rather than production endpoints.

The user-selected Apple Linux guest can supply qualified target-Linux behavioral
evidence, following the accepted cohort producer workflow. Record its amd64 image,
Apple translation, independent store and read-only source mount. Guest-only
`sandbox=false` and `filter-syscalls=false` are required by its seccomp limitation;
the guest's VM boundary and explicit loopback fixtures provide isolation, without a
claim that Nix sandboxing ran. Preserve ordinary GHC settings and host builder
configuration. This target execution does not establish performance on physical
x86 hardware or substitute for fresh-worker cache proofs.
