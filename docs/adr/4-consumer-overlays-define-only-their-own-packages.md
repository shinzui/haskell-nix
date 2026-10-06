# Consumer overlays define only their own packages

Status: Accepted; native/Linux shared policy and audit checks pass. Consumer adoption is pending.

Date: 2026-10-05

## Context

Consumer Haskell extensions compose after the channel and silently replace duplicate names.
The September inventory found 53 shared override entries across applications, most already
supplied by the channel. The October inventory adds Rei's Servant instrumentation source pin
and in-memory exporter. Matching versions do not establish matching builds: the historical
thread-utils-context tarball override changed that dependency's derivation and its dependents
while retaining the same version. ADR 1 and ADR 5 require equal transitive build inputs.

The source exceptions have distinct resolutions. The TypeID source is public and three
applications use the same revision, so one channel source pin replaces their copies. Mori
alone uses the private hasql-effectful source; its consumer adoption vendors the effect into
mori-core rather than exposing an inaccessible channel source. Mina's mori-schema-pin is
deliberately retained because moving it changes Dhall written into other repositories.

This extends `mori://shinzui/mori/okf/adrs/concepts/ADR-24`, which prohibited first-party
shadowing but permitted local missing-version pins and chose review-only enforcement.

## Decision

Consumer overlays define application-owned packages, declared sibling application libraries
until those are consumed through their application outputs, and rare named exceptions with
non-empty reasons. They never redefine channel-owned names. Ownership includes selected
first-party registries, generated/frozen cohort names, source pins and retained runtime
transitive packages/components. Declaring a shared name as own, sibling or exception cannot
hide shadowing. Each consumer runs `lib.auditConsumerOverlay` with its selected ownership
records; the report evaluates names without fetching overlay values.

Required shared versions and build policies are added to this channel and then adopted by
relocking consumers. Public unpublished packages receive exact source revisions and hashes,
as with `mori://shinzui/typeid-hs` and
`mori://shinzui/hs-opentelemetry-instrumentation-servant`. Shared source exceptions remain
explicit under the Hackage first-party channel. Private sources are published or vendored
into their sole consumer rather than becoming permanent inaccessible shared entries.

The sole current declared exception is Mina's mori-schema-pin at `mori://shinzui/mori`
revision 7af02c55. Source/metadata/flags/policy of runtime-owned packages cannot change during
application-only composition; ADR 7's retained records supply their ownership. Nested source
input overrides remain possible under ADR-24, subject to retained snapshot and runtime
identity checks. They are not permission to replace a retained runtime recipe silently.

## Alternatives and consequences

Keeping local missing-version pins perpetuates silent divergence. Reversing extension order
would silently ignore local entries instead. Review alone failed to prevent existing copies,
so the audit supplies a failing check. Creating new catalog families for these packages is
separate topology work under ADR 1. The prior private-source exception approach was replaced
by public TypeID pins and Mori vendoring.

A consumer needing new shared policy first changes this repository, then relocks. Tests and
jailbreaks remain explicit compatibility policy, not evidence that Cabal bounds were enforced.
Opting back into profiling requires validating the known Kioku GHC 9.12.4 profiling problem.
Temporary version pins are converted to policy when the generated cohort takes ownership;
non-Hackage source pins retain their source identity.

## Validation

Pure audit fixtures cover shadowing despite ownership/exception declarations, missing and
unused declarations, duplicate declarations, invalid reasons, all shared ownership layers,
runtime ownership and deterministic reports. The `consumer-overlay-audit` check exposes a
clean fixture. `shared-overrides` evaluates minimum versions and profiling redundancy and
builds every listed shared dependency. Native aarch64-darwin and remote x86_64-linux
builds pass, as do all 51 Nix-unit cases including 11 ownership cases. The broad native
flake check remains blocked separately in cpio's security-patch phase by a
reproducible patch OOM. An isolated test confirms that the daemon's unlimited
NOFILE limit makes bootstrap GNU patch 2.7.6 fail; capping the test builder's
limit makes the identical patch succeed. A client-only cap does not reach the
daemon-created builder, so the required native environment gate remains open.
The earlier GHC 9.14
bytestring-lexing bounds failure is repaired with released 0.5.0.16, which passes
all 58 tests with bounds intact. These broad gate failures do not invalidate the
independently passing policy/audit checks.
Evaluation and build results are recorded in
[EP-10](../plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md).
Final application builds, exact executable manifests and deployments remain the consumer
plans' gates under [MasterPlan 3](../masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md).
