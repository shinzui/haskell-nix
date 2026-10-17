---
type: Reference
title: Maintainer tools
description: Find repository formatting, test, derivation-diff, and validation commands.
docId: DOC-6
tags: [maintainers, testing, nix]
timestamp: 2026-10-17T21:10:00Z
generated:
  by: process:codex
  at: 2026-10-17T21:10:00Z
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

## Compatibility impact after an update

Export selected declaration contexts before and after a targeted update using
matching construction capture scopes, then compare them explicitly:

```bash
nix run .#haskell-nix-update -- compatibility impact \
  --before /tmp/compatibility-before.json \
  --after /tmp/compatibility-after.json --json
```

The report lists added/removed instances and changes to applicability, exact
source/Cabal metadata/derivation, compiler/platform/configuration, captured
construction effects, semantic entry policy and required evidence. Affected
active entries name their required native probes. Unaffected entries retain
`declarationInputsUnchanged: true` and their unverified evidence status.
Per-entry semantic identities keep an unrelated policy edit from invalidating
unchanged declarations. Older reports without those identities conservatively
require revalidation after a global policy change. Reasons and timestamps do not
change semantic identities.

This read-only comparison does not authenticate caller facts, rebind receipts or
turn a declaration into a native pass. Export the new selected native probe
context and run `compatibility verify` for affected claims; use the exact
`verify-receipt` workflow below before accepting existing evidence. A declaration
context cannot substitute for that executable native plan. No lock, recipe or
exception is changed by the report.

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

The general updater workflow uses `lib.mkCompatibilityProbeContext` to export an
explicit native plan. Supply the selected `validation`, baseline/candidate `graphs`
from `mkCohortManifest`, the complete `requiredSuites`, named baseline/candidate
`behaviorProbes`, `channel`, and a semantic `policyIdentity`. Behavior and service
checks are sandboxed Nix derivations; the updater accepts no shell command strings.
The graph must describe the exact strict package, compiler and system. Null Cabal
dependency values remain unresolved until the cohort producer checks compiler
packages and the exported derivation graph.

Export and run the fixed native fixture from the repository root:

```bash
nix eval --impure --json --expr '
  let f = builtins.getFlake (toString ./.);
      p = import f.inputs.nixpkgs { system = builtins.currentSystem; };
      fixture = import ./checks/package-validation.nix {
        lib = p.lib; pkgs = p;
        scope = p.haskell.packages.${f.lib.defaultGhc};
      };
  in fixture.contexts.fixed' > /tmp/compatibility-probe-context.json
nix run .#haskell-nix-update -- compatibility verify \
  --context /tmp/compatibility-probe-context.json \
  --entry fixture-compatibility-repair --out /tmp/compatibility-probe
nix run .#haskell-nix-update -- compatibility verify-receipt \
  --context /tmp/compatibility-probe-context.json \
  --receipt /tmp/compatibility-probe/receipt.json
```

Use a fresh output directory. `verify` builds both strict packages, checks the
complete named Cabal suite results, and builds the graph, executable and required
service probes. It writes a receipt and bounded logs, with a 900-second build
limit. A failed required check exits 1 and retains a failed receipt. Neither
command edits recipes, locks or exception entries.

`verify-receipt` requires exact context equality, no remaining waivers and complete
passing results. It then checks current Nix output metadata and original native
suite logs without building. An asserted pass cannot replace missing outputs,
missing logs, skipped suites or service evidence. Rechecking on another native
system fails. Existing cached outputs with their native logs are acceptable;
record cache state separately when measuring maintenance cost. Expected contexts
must come from the trusted selected constructors: receipts are local evidence,
not signed attestations of arbitrary caller-supplied JSON.

Select `fixture.contexts.service` to exercise the provided-service path. Both
strict suites contact a bounded, one-request loopback service; no external service
is contacted. `fixture.contexts.needed` produces a failed removal receipt with the
actual `EP21_REPAIR_REQUIRED` test failure. Missing service declarations block
construction. The complete constructible migration matrix and native report interchange pass on both
systems. Real policy selection/retained-history acceptance remains separate. Ordinary
builds and shell entry do not run these removal probes.

The real `bytestring-lexing` checks compare the current named run/enforce selection
with the independently constructed `strict-v1` recipe at the exact cohort source and
metadata. `pilot.legacy` retains the former waived recipe for comparison. Run them explicitly:

```bash
nix build --impure --no-link --print-build-logs --timeout 900 --expr '
  let channel = builtins.getFlake (toString ./.);
      pilot = import ./checks/bytestring-lexing-validation.nix {
        inherit channel; system = builtins.currentSystem;
      };
  in [ pilot.strict pilot.manifest pilot.behavior ]'
```

This builds the complete `test-all` suite, checked dependency graph and parser/serializer
behavior. No standalone repair is retired. The earlier strict pilot passes 58 tests on
Apple Silicon and the user-selected translated Linux guest. The named current selection passes the actual channel-overlay suites on Apple Silicon
and the user-selected Linux guest. Generation 3 captures it separately; its focused
checks and broad runtime support have distinct acceptance evidence.

Use `checks.aarch64-darwin.bytestring-lexing-policy-github` and
`checks.aarch64-darwin.bytestring-lexing-policy-hackage` for the normal channel-overlay
checks, with `x86_64-linux` on the Linux worker. Factory-scope and channel-overlay
receipts can have different test dependency identities; validate each declared context
instead of rebinding a successful receipt. Query `pilot.context` to inspect the selected
profile, previous/current recipe facts and exact graph. Current reports keep all native
source/repair-necessity labels unverified until their own receipt checks succeed.

The existing Apple guest can run the same Linux behavior checks:

```bash
container exec --workdir /workspace mp3-linux-builder \
  nix --extra-experimental-features 'nix-command flakes' \
  --option filter-syscalls false build --impure --no-link \
  --print-build-logs --timeout 900 --max-jobs 1 --cores 8 --expr '
    let channel = builtins.getFlake (toString ./.);
        pilot = import ./checks/bytestring-lexing-validation.nix {
          inherit channel; system = builtins.currentSystem;
        };
    in [ pilot.strict pilot.manifest pilot.behavior ]'
```

This reuses MP-3's read-only `/workspace` mount and independent store. The amd64
image runs through Apple translation; the guest has `sandbox=false`, and its
seccomp limitation requires `filter-syscalls=false`. Record those facts in Linux
receipts. These results establish the checked Linux behavior; they do not establish
performance on physical x86 hardware. Host builder configuration stays unchanged.

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
