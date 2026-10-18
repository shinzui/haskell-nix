---
type: Reference
title: Maintainer tools
description: Find repository formatting, test, derivation-diff, and validation commands.
docId: DOC-6
tags: [maintainers, testing, nix]
timestamp: 2026-10-18T01:41:26Z
generated:
  by: process:codex
  at: 2026-10-18T01:41:26Z
---

# Maintainer tools

The flake uses flake-parts for system-specific output wiring. Shared package-selection and
overlay logic stays in `lib/`; existing build checks live in `checks/default.nix` and tool
checks live in `nix/tooling.nix`. Both flake-parts and treefmt-nix follow the existing inputs
of `mori://shinzui/haskell-nix-dev`. Nix-unit and nix-diff come from the same pinned Nixpkgs
as the development shell. Tool adoption does not update family sources or the compiler pin.

## Exporting cohort generation inputs

The existing `cohort generate` command can export its validated generation context
alongside the version and compiler-boot tables:

```bash
nix run .#haskell-nix-update -- cohort generate \
  --output /tmp/cohort-context/cohort-versions.nix \
  --boot-output /tmp/cohort-context/ghc-boot-packages.nix \
  --context-output /tmp/cohort-context/generation-context.json
```

The versioned JSON preserves the frozen versions, flags and index-state, complete
solved source/component identities, shipped compiler packages, first-party and
source-policy ownership, and available base/policy comparison inputs. Its reader
uses the existing freeze parser and classifier. Paths, generation labels and
creation timestamps are absent from the context. A retained runtime caller can
serialize its own explicit `GenerationContext` through the same library interface.

Repeat with `--check` to compare all three outputs without rewriting them. The
existing generator still resolves metadata and source inputs through its normal
workflow. All selected outputs are staged before publication, and a changed
freeze, source manifest, ownership policy or lock rejects publication. Complete
recipe artifacts are available for explicitly scoped generated Hackage inputs
through the commands below. Declared GitHub source pins also require verified
archive metadata and a pinned extractor.

## Staging complete dependency recipes

`cohort recipes generate --context FILE --out DIR` converts every generated
Hackage selection and each explicitly declared GitHub source pin in a versioned
recipe context. The context wraps the
exported generation inputs with compiler/system/channel, Nixpkgs and reviewed
policy identities, the pinned builder converter's derivation/output/version, and
one input record per generated package. Each record supplies relative paths to a
local source archive and exact selected Cabal file, unpacked hash, revision and
native argument mapping. The existing classifier owns coverage and ownership.

```bash
nix run .#haskell-nix-update -- cohort recipes generate \
  --context /tmp/recipe-inputs/context.json --out /tmp/recipe-artifacts
nix run .#haskell-nix-update -- cohort recipes check \
  --context /tmp/recipe-inputs/context.json --out /tmp/recipe-artifacts
```

Generation verifies the archive's solved raw hash, its unpacked NAR hash through
Nix's local-file path, and the selected metadata before and after conversion.
The converter must already be realized from the pinned builder's
`buildPackages.haskellPackages.cabal2nix-unstable` scope (its `bin` output); its derivation output and
reported version must match the context. `check` reconverts the supplied local
inputs with offline Nix calls and compares all artifact bytes without rewriting
the output. Invalid arguments exit 2; drift or unverified identities exit 1.

The public `RecipeGenerationContext`, `RecipeConfiguration`, package/source and
pinned-tool records serialize through `recipeContextValue` and
`decodeRecipeContext`; the existing generation-context codec owns solved inputs.
Set the outer `schemaVersion` to 2 to record `convertedMetadata` and
`dependenciesByComponent` for each converted function. Inspection evaluates the
exact callable Nix function with symbolic dependency arguments and IFD disabled;
it verifies the selected package name, version and metadata revision. The inventory
keeps library, test, benchmark, Setup, native and tool dependency fields separate.
Names describe converter arguments before reviewed policy; the final recursive
scope still owns actual dependency resolution. Unsupported expressions reject
publication. Format 1 remains byte-compatible and omits this inventory.

The [component-role receipt](../evidence/ep19/recipe-component-roles.json) covers
all 11 converter fixtures, mixed Hackage/fixed-source generation, stale-role and
revision-label rejection, relocation, and unchanged format-1 artifacts. The
[native matrix](../evidence/ep19/recipe-component-roles-native-matrix.json) passes
all 223 updater tests on both systems and the same mixed format-2 pipeline in the
translated Linux guest. Both generated dependency roots and the actual
Rei CLI retain their previous derivations. The opt-in factory interface below adds selected-context binding; retained-runtime
capture and production performance acceptance remain open.

A source-pinned input uses `revision: null` and a `sourcePin` record containing
its solved Git repository/revision/subdirectory, archive SHA256 and verified
Cabal-file SHA256. Supply an `extractor` derivation/output/version in the
configuration. The pinned GNU tar reads the exact GitHub archive member; its
bytes must equal the supplied metadata. The manifest retains Cabal's solved Git
observations alongside archive, unpacked NAR and metadata identities. Original
solved observations remain unchanged.

The [fixed-source example](../evidence/ep19/source-pin-artifacts.json) converts
`mori://shinzui/cmark-gfm-hs` at its existing commit. Its raw function preserves
the solved `pkgconfig = false` flag. A metadata-hash-guarded constructor adapter
removes the redundant spelling of this default-false flag and reproduces the
legacy package and actual Rei CLI derivations. All 22 original package tests
pass with bounds enforced, and both selected roots evaluate with IFD disabled. The
[native supplement](../evidence/ep19/source-pin-native-matrix.json) repeats the
mixed pipeline and all 22 package tests on Linux, with 221 updater tests on each
system.
Broader selected Nix flag policy needs an explicit handoff before conversion;
Generation 1 Dhall records TLS false while its Nix policy enables it; generations
2 and 3 already record true.

A successful directory contains `manifest.json`, `extension.nix`, `packages/`
functions and the `.recipe-artifacts` ownership marker. Replacement is staged
and accepts only an existing directory owned by this generator. Changed context
or input bytes reject publication; unrelated files and directories are preserved.
Paths and creation times are absent from the manifest and generated recipes.
The raw extension requires an explicit reviewed `policyExtension`; the caller
must bind the declared configuration and retain normal runtime validation.

[The retained example](../evidence/ep19/recipe-artifacts-prototype.json) includes
a raw archive with its complete input context, source archive, selected metadata
and generated artifacts. It currently covers aarch64-darwin.

The bounded generation-1 `base64-bytestring` example preserves its dependency
and actual Rei CLI derivations through the existing runtime validator, regenerates
byte-identically after input relocation, and evaluates its scoped root with IFD
disabled. Other classifications remain explicit in the manifest and retain their
existing constructors. Additional source transports, an explicit effective-flag
policy handoff, wider retained recipe coverage, additional
native configurations and performance adoption remain EP-19 acceptance work. The earlier
one-root and five-root evaluation campaigns missed the declared speed target. The
[Linux supplement](../evidence/ep19/recipe-artifacts-native-matrix.json) passes the
same bounded root and all 218 updater tests in the translated Apple guest.

## Selecting generated recipes in a factory

The public `lib.mkGeneratedRecipeExtension` takes
`{ manifest; recipes; context; policyExtension; }`, followed by `haskellLib` and
`pkgs`. Supply the owning factory's independently captured, validated format-2
recipe context. The helper compares the manifest to that context, verifies the
selected builder's converter/extractor, requires exact package file coverage and
content hashes, and checks converted identity and component fields against the
actual callable functions. Compiler identity is checked inside each package to
preserve recursive-scope laziness. The reviewed extension runs once after raw
construction. The generated `extension.nix` remains portable; this stricter helper
constructs directly from the verified manifest and package functions.

The first configuration argument of `mkFirstPartyPackageSet` now accepts an
explicit option (default `null`):

```nix
generatedRecipes = {
  context = builtins.fromJSON (builtins.readFile ./captured-recipe-context.json);
  manifest = builtins.fromJSON (builtins.readFile ./recipes/manifest.json);
  recipes = ./recipes;
};
```

This path selects only the declared generated Hackage roots. It checks their
source observations, flags, revision, index-state, compiler/channel/Nixpkgs and
native arguments against the selected cohort. Existing construction policy and
compatibility capture wrap either constructor in the same place. A selected
mismatch fails explicitly. Undeclared roots retain their existing constructors;
source pins still require their existing registry owner or an explicit low-level
helper caller. Packages with unavailable test arguments cannot use this factory
option until their argument representation is explicitly supported.

The [factory integration receipt](../evidence/ep19/recipe-factory-binding.json)
uses generation 3 and an immutable Rei source on both systems. The selected
`base64-bytestring` root evaluates without IFD, and both scopes pass the existing
independent runtime validator with identical dependency and real CLI derivations.
This adds an opt-in factory interface. Generation 4 below captures both generated constructors. Its final native
checker matrix, update/rollback rehearsal and performance/cost adoption remain
EP-19 work. Existing generations and consumers
keep their selections.

## Retained recipe selection and freshness

Generation 4 captures four explicit GHC 9.12.4 recipe cells under its immutable
`config/generated-recipes/` tree. Its captured
`config/runtime-generated-recipes.json` selects a context after the system is
known. Both public and independent reference factories use it. Earlier snapshots
lack that file and keep their original factory interface. The earlier policy
reference remains distinct from generation 4's own fingerprint
`c89b34a59b00cfbb8e08040beee3c540f61af8e7da8cc399a776817628183b76`.
Support remains unverified; ordinary consumer selections and aliases stay fixed.

Projection validation hashes file bytes directly so bundled binary archives need
no string decoding. The current checks cover all 356 pure contracts. All four
public constructor cells preserve the 273 non-boot runtime package derivations
and real immutable Rei CLI identity, and their declared generated root passes
no-IFD. The complete constructor still encounters unconverted `Diff` when IFD is
disabled; that limit is recorded separately.

`cohort recipes commands --context FILE` prints a validated JSON command model
without running conversion, querying Nix or publishing files. Build freshness
checks use those same compiler/system/flag arguments, exact local metadata and
the pinned converter. A private metadata-only directory avoids the converter's
unconditional home-cache creation; `--src-expression=src`, disabled hpack and
byte-identical ordinary-generator output remain required. Inputs, archives and
accepted recipes are read-only to the checker.

```bash
nix build --no-link --print-build-logs .#checks.aarch64-darwin.generated-recipes-fresh
nix build --no-link --print-build-logs .#checks.aarch64-darwin.generated-recipes-parity
nix eval --raw .#checks.aarch64-darwin.retained-generated-recipes-no-ifd.drvPath \
  --option allow-import-from-derivation false
```

Repeat on Linux with its corresponding check names. The installed updater's 225
tests pass on Darwin. The actual Linux Rei CLI also builds and its help matches
Darwin byte-for-byte; an eight-core compilation stalled under translation, while
the one-core retry completed. Retain those execution facts when using the guest.
The immutable final Linux checker matrix remains pending at this checkpoint.
[ADR 10](../adr/10-retain-verified-generated-dependency-recipes-in-the-existing-scope.md)
records ownership and acceptance boundaries. Retained capture does not establish
evaluation speed or production adoption.

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
behavior. The bytestring-lexing change narrows its test policy. The earlier strict pilot passes 58 tests on
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

Copy saved guest logs or archives directly to the host:

```bash
container copy mp3-linux-builder:/tmp/result.json /tmp/result.json
```

This also handles large artifacts without sending them through `container exec`
standard output. A direct archive copy was verified against the chunked transfer's
SHA256 in the factory checkpoint.

## A verified metadata retirement

The current cohort independently selects `servant-docs` 0.13.1 Cabal revision 3.
Its GHC 9.14.1 strict recipes agree with and without `legacy-servant-docs-v1`.
All 20 `spec` cases, the 88-package graph, shipped `greet-docs` behavior and exact
receipt replay pass on Darwin and the translated Linux guest in both source channels.
The live row and catalog entry are retired; source pins and historical records stay fixed.
See [the retirement receipt](../evidence/ep21/servant-docs-retirement.json).

Keep a historical probe's constructor, catalog and expected context together. Reproduce
this probe from its immutable pre-retirement commit in this repository's Git history:

```bash
nix eval --impure --json --expr '
  let frozen = builtins.getFlake
        "git+file://${toString ./.}?rev=ce51b8a504670d2847bce731d6c2d6ce71e02ca9";
  in (import (frozen.outPath + "/checks/servant-docs-retirement.nix") {
    channel = frozen;
    system = builtins.currentSystem;
    sourceChannel = "github";
  }).context' > /tmp/servant-docs-context.json
nix run .#haskell-nix-update -- compatibility verify \
  --context /tmp/servant-docs-context.json --entry legacy-servant-docs-v1 \
  --out /tmp/new-servant-docs-proof
nix run .#haskell-nix-update -- compatibility verify-receipt \
  --context /tmp/servant-docs-context.json \
  --receipt /tmp/new-servant-docs-proof/receipt.json
```

Use a fresh output directory and select `hackage` for the second channel. This verifies
the recorded historical candidate; it does not reconstruct a removed row from current
metadata. A changed source/compiler/policy requires a new expected context and its
applicable native checks. Other repairs and dependency-suite coverage remain unverified.
The first cold Linux build and graph take 2060.68 seconds; its second-channel verification
reuses the same physical package in 6.06 seconds, with 3.44/1.48-second receipt replays.
These are explicit maintenance costs under concurrent work. Ordinary builds and shell
entry do not run the removal matrix or query current upstream releases.

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
