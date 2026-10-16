# Generate the channels' package versions from the cohort freeze

Status: Accepted

Date: 2026-10-16

## Context

Cabal solves the Rei-family applications together, while independently maintained Nix
pins previously selected different dependency releases. Matching a few visible versions
cannot establish agreement: metadata revisions, automatic flags, source pins and statically
linked libraries can differ without appearing in an executable's runtime closure.

[ADR 2](2-resolve-the-rei-family-cohort-upgrade-only.md) owns the upgrade-only solve.
[ADR 5](5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md)
requires source/configuration evidence and actual cache substitution, and keeps routine
application changes independent of dependency and toolchain updates.

## Decision

Generate Nix's shared version selection from `cabal/cohort.freeze` and its recorded source
manifest. The shared Haskell updater owns parsing, normalization, generation and freshness
checks. Retain `generated/cohort-versions.nix` and `generated/ghc-boot-packages.nix` in Git;
ordinary evaluation consumes these records without a new solve or registry lookup.

Choose Hackage metadata at the recorded index-state. Cache metadata lookup by package,
version and cutoff; retain tarball hashes independently. Supply the selected metadata to
cabal2nix before recipe translation, then apply the same revision during the build.
Normalize Apple's `arm64` spelling to Cabal's `aarch64` for the pinned translator so that
architecture-dependent dependencies match the actual host.

The pinned cabal2nix path already parses Cabal specifications 3.14 and 3.16 in both source channels; no parser overlay or compiler/nixpkgs update is needed for that purpose. The guard builds the 3.14 fixture and evaluates all four 3.14/3.16 translation paths. Parsing a specification does not imply the compiler-bundled Cabal setup driver can build it.

The generated layer owns shared Hackage versions. The registry owns explicit compatibility,
test and flag policies plus declared non-Hackage sources. Reject newly introduced Hackage
fetching in registry patches. Preserve compiler-provided packages, first-party snapshot
selection and supported historical constructors. Intentional source differences have a
canonical Mori owner and reason in the retained context; intentional flag and compatibility
hook differences are declared in `cabal/cohort-nix-policy.json`.

Construct manifests from the actual composed scope and executable derivation. Capture
generic-builder arguments and require them to reconstruct that exact derivation; reject
unrecorded lower-level overrides. Record all actual Haskell instances and dependency roles,
with native tools separated. Verify recorded edges against Nix's exported derivation graph,
including static libraries omitted from runtime closures.

Replay each actual recipe through configure with its compiler and dependencies to obtain
Cabal's resolved flag assignment, original/patched metadata hashes and configured compiler
tool identities. User-supplied flag arguments alone omit defaults and automatic choices.
Source-altering hooks require an owned content digest. Compiler-bundled hsc2hs requires an
owned exception, the frozen version, an exact compiler-provided path and a reachable provider
derivation.

The public comparator shares the updater's parser and fails on missing or unverifiable
evidence. It compares frozen Cabal plans or Nix manifests and can compare complete build
identities between two manifests. Consumers call these shared interfaces. Retained runtime
projections supply explicit immutable context to the same generation and manifest helpers,
as required by [ADR 7](7-compose-applications-on-retained-keiro-runtime-baselines.md).

Build and publish declared dependency roots to the trusted cache before adoption. Verify
every NAR identity/reference across the explicitly recorded private and upstream caches;
Cachix may omit paths already supplied by its upstream. Prove substitution with local and
remote builds disabled into an empty matching-system store. Host isolation is useful evidence
but does not replace the separate fresh-CI-worker gate. Deferred platforms remain pending.

## Alternatives and consequences

Keeping manual pins duplicates Cabal's version authority and permits silent drift. Parsing
runtime path basenames misses static dependencies and can confuse native homonyms. Comparing
only versions, command-line flags or successful uploads leaves source/configuration and cache
readiness unproven. Those approaches are insufficient acceptance evidence.

Using a moving `all-cabal-hashes` selection would lose the retained index-state metadata choice. Retained generated expressions avoid network solving during ordinary evaluation while retaining exact archive and metadata hashes. A nixpkgs bump or migration to haskell.nix would expand toolchain scope without resolving the ownership boundary; generating Cabal from Nix would reverse the accepted solver authority. Those remain separate explicit toolchain decisions.

Correcting metadata translation or platform interpretation can change dependency derivations
without changing any frozen version. Rebuild and republish affected outputs, preserving the
upgrade-only version contract. Ordinary application changes continue to reuse retained
dependency and toolchain identities.

## Validation

Plan 9 owns deterministic generation, registry lint, composed version parity, manifest and
comparison fixtures, compiler/channel builds and cache receipts. Fixtures reject missing
static edges, duplicate conflicting instances, unowned source/configuration differences,
wrong compiler-tool providers and unrecorded derivation overrides. Real pg-migrate-cli and
Dhall JSON manifests exercise the shared comparison path, including pinned sources and the
owned TLS difference. Retained receipts in `cabal/cohort-cache/` and [fresh hosted run 38967850038](https://github.com/shinzui/haskell-nix/actions/runs/38967850038) prove substitution of 556 Darwin and 561 Linux paths into empty stores with zero builds. Both complete platform flake checks and four-cell compiler/channel matrices pass. Full platform/CI acceptance and downstream adoption remain governed by
MasterPlan 3; this record does not mark those gates complete.
