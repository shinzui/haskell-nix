---
type: Reference
title: Maintainer tools
description: Find repository formatting, test, derivation-diff, and validation commands.
docId: DOC-6
tags: [maintainers, testing, nix]
timestamp: 2026-10-17T14:42:51Z
generated:
  by: human:nadeem
  at: 2026-09-21T14:33:46Z
---

# Maintainer tools

The flake uses flake-parts for system-specific output wiring. Shared package-selection and
overlay logic stays in `lib/`; existing build checks live in `checks/default.nix` and tool
checks live in `nix/tooling.nix`. Both flake-parts and treefmt-nix follow the existing inputs
of `mori://shinzui/haskell-nix-dev`. Nix-unit and nix-diff come from the same pinned Nixpkgs
as the development shell. Tool adoption does not update family sources or the compiler pin.

## Compatibility declaration reports

`lib.compatibilityReport` exports a read-only declaration context for an explicit
package set, compiler, channel, system and optional retained runtime configuration.
The caller supplies each package's version, source identity, Cabal metadata identity
and derivation **before its compatibility repair**, plus its selected construction
profiles and generated-source layer. Do not substitute a final repaired recipe or
stock Nixpkgs facts for those selected inputs. This low-level interface accepts
caller facts; use construction capture to collect actual current inputs.

Run the fixture and its native interchange check from this repository:

```bash
nix eval --impure --json .#lib.compatibilityReport \
  --apply 'report: report (import ./checks/fixtures/compatibility-policy/context.nix)' \
  > /tmp/compatibility-context.json
nix run .#haskell-nix-update -- compatibility report --context /tmp/compatibility-context.json --json
nix run .#haskell-nix-update -- compatibility check --context /tmp/compatibility-context.json
nix build --no-link .#checks.aarch64-darwin.compatibility-report
```

The report shares the executable registry's row selector and compiler/version
predicates. It distinguishes inactive rows, inactive scopes and selected unverified
entries. Entries outside the supplied package subset are listed separately.
Selected declarations remain unverified: a source assertion in a build hook has
not passed merely because its compiler/version predicate matches. Retirement
thresholds produce candidates with unmet checks, never automatic removals.

For a current selected scope, pass `captureCompatibility = true` to
`lib.mkFirstPartyPackageSet`, `lib.mkHaskellExtension`, or `lib.mkHaskellOverlay`.
Then pass that scope and an explicit package subset to
`lib.capturedCompatibilityReport`. The native representative check is:

```bash
nix build --no-link .#checks.aarch64-darwin.compatibility-capture
```

`checks/compatibility-capture.nix` shows the complete producer/consumer wiring.
Capture records the real input before each repair, including repairs applied after
first-party source selection, and the resulting recipe. Source constructors use a
separate stage with no invented stock input. The report checks declared test
suppression and bounds relaxation against captured Cabal arguments and lists changed
fields. Other function effects and build-time source assertions still need explicit
probes. Captured flags do not prove tests ran or original bounds admitted the compiler.

Some builder arguments, including metadata revisions and jailbreak policy, disappear
from final derivation attributes. Capture inspects the actual `overrideCabal` boundary
rather than substituting absent attributes with false values. It preserves the original
derivation and recursive dependency instances. Source and contextual hook identities use
metadata-only derivation projections so Nix canonicalizes lazy source aliases; these
projections are never built. Exported report strings discard build contexts so writing
a report does not require dependency outputs to be realized. Dependencies are identified
by derivation and output name. Disabled-test dependencies
are reserved for explicit strict-validation inventory.

Capture is opt-in and preserves production derivations. Older retained recipe bundles
lack capture hooks and fail explicitly in the captured adapter; their recipes are not
rewritten or silently reconstructed using current policy. Raw metadata equality is
insufficient for retirement: a repair can also change bounds in a build hook. An
already selected admitting-metadata repair becomes a candidate only when the complete
recipes also match, and still requires native validation before retirement.

`check` validates the declaration interchange contract and fails if any explicitly
required evidence is missing or unverified. A context with no required evidence
can pass that check while retaining unverified native coverage; this is not a
dependency-test, bounds-enforcement or retirement receipt. The CLI rejects forged
pass statuses, inconsistent captured boundaries and required-evidence diagnostics.
It also rejects omitted diagnostics for captured test/bounds policy mismatches. It does not rerun
Nix selection from JSON, validate arbitrary patch-function effects or authenticate
caller-supplied input facts. Invalid command arguments exit 2; malformed contexts
and unmet evidence exit 1. Reports and checks do not change locks or recipes.

## Isolated package validation fixtures

`lib.mkPackageValidation` stages a baseline and a one-entry removal candidate using
the same explicit recipe constructor. Its `mkRecipe` callback receives
`policyProfile = "strict-v1"`, `disabledEntryIds`, and declared service probes.
Apply that profile before applying compatibility entries, and omit exactly the
requested entry during construction. Selecting a stricter flag afterward cannot
undo a prior metadata/bounds rewrite.

The constructor checks actual consumed Cabal arguments: both packages must enable
the standard complete test run and disable jailbreak. Custom check phases, narrowed
test targets and test-filter flags are rejected by this initial helper. Selected
source, metadata, compiler and declared production/test dependency instances must
match. Missing declared service probes return a blocked request before either
recipe is constructed. A declared service probe alone remains unverified.

Run the controlled native fixtures explicitly:

```bash
nix build --no-link .#checks.aarch64-darwin.package-validation
python3 scripts/check-package-validation.py --output-dir /tmp/package-validation-evidence
```

Choose a fresh evidence directory for each run. The first fixture needs a CPP
repair: its strict baseline passes, and removing the repair must fail in the actual
Cabal test phase with the expected cause. A fixed source passes the same suite and
executable behavior without the repair. Passing graphs go through the existing
`mkCohortManifest` producer, including compiler-package and exported derivation
graph checks. The script uses Nix build/log APIs and records cache conditions and
elapsed fixture-validation time; it makes no performance claim.

These are staged fixture receipts. Constructor requests remain unverified until
their required execution and graph evidence exists. Null Cabal dependency values
are explicitly unresolved; they can denote compiler-provided packages and do not
by themselves prove missing dependencies. Production necessity/retirement, a native
provided-service probe, general receipt validation and updater `compatibility verify`
commands remain pending. Ordinary builds and shell entry do not run these probes.

## Formatting

Run these commands from the repository root:

```bash
just fmt
just fmt-check
```

`nix fmt` runs treefmt using `treefmt.nix`. The formatter is nixpkgs-fmt, matching the existing
fleet style. `nix fmt -- --ci` checks without writing. `checks.<system>.formatting` runs the
same policy during `nix flake check`. Managed skill directories are excluded.

## Fast Nix tests

```bash
just nix-test
```

This builds only `checks.<current-system>.nix-unit`. The named tests in `checks/unit.nix`
validate registry inventories, rejection of malformed data, and source-fetch laziness without
building Haskell packages or fetching family sources. Dependencies of the test runner may be
downloaded the first time. Add snapshot-selection contract tests here as schema version 2
is implemented; keep real compilation and derivation-identity checks separate.

For interactive test filtering, the shell provides the same runner:

```bash
nix develop -c nix-unit --flake .#lib.tests
nix develop -c nix-unit --flake .#lib.tests --attr testGithubInventoryWithoutFetching
```

Nix-unit embeds the Nix evaluator from its pinned package, which can differ from the installed
Nix executable. Run the ordinary flake checks as well to exercise the host's evaluator.

## Derivation differences

When two expected-equal derivation paths differ, preserve both paths printed by the failed
comparison and inspect them with nix-diff:

```bash
just drv-diff '<before.drv>' '<after.drv>'
```

Replace the placeholders with the actual `.drv` paths. The command runs nix-diff in the
development shell. Differences in source, compiler, dependency derivations, patches, or build
flags are real rebuild inputs; set labels and unrelated selections should not appear there.

## Full validation

```bash
just flake-check
git diff --check
```

The flake checks include formatting and pure Nix tests alongside the existing registry,
version, overlay, build-setting, and updater checks. Cabal2nix evaluation can require building
generators. Checks run on the current system; other supported systems require their own
native or configured remote builders. No Git hooks are installed automatically, and
nix-eval-jobs remains deferred until evaluation performance warrants it.
