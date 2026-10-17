---
type: Guide
title: Measure and remove avoidable application rebuilds
description: Measure source filtering and guarded compiler intermediate reuse with explicit inputs, native correctness and total-cost evidence.
docId: DOC-7
tags: [performance, consumers, nix, source-boundaries]
generated:
  by: process:codex
  at: 2026-10-17T20:46:00Z
---

[Guides](README.md)

# Measure and remove avoidable application rebuilds

Start with the application you actually build. Record its source revision, lock digest,
compiler, runtime selection, build flags, jobs, cores and available memory. Inspect its
Cabal components and compile-time file reads before changing a source boundary. A directory
named `test` may contain a public library or an installed executable. Markdown may supply
embedded help, prompts or templates. Keep all those inputs.

The first measured case is `mori://shinzui/rei`, starting at revision
`99b882ee6d9cdc77ee0e8dead8962736bd3c4d0a`. Its `rei-core/docs` directory contains planning
prose consumed by no Cabal component or compile-time file read. The original recipe included
that directory, so a prose edit rebuilt the entire application-owned closure: core and CLI.
The fix lives in that project's `nix/haskell-overlay.nix` (source-file artifact URI pending).
It excludes only that directory and preserves the source name and all other filtering.

## Run paired documentation trials

Prepare two **disposable** copies of the same tracked application tree outside this
repository. Keep the original recipe in the baseline and the changed recipe in the candidate.
Use identical `flake.lock` and runtime-selection bytes. Leave the prose file initially equal.
The measurement script modifies that file and restores it on exit. Never point it at a live
checkout. Store receipts outside both copies.

From this repository, set the path of the owning Rei checkout and run:

```bash
export MP4_REI_CHECKOUT=/path/to/rei
mkdir -p /path/to/disposable/baseline /path/to/disposable/candidate
git -C "$MP4_REI_CHECKOUT" archive 99b882ee6d9cdc77ee0e8dead8962736bd3c4d0a | tar -x -C /path/to/disposable/baseline
git -C "$MP4_REI_CHECKOUT" archive 4f209d3f | tar -x -C /path/to/disposable/candidate
python3 scripts/measure-application-nix-builds.py \
  --expression checks/fixtures/application-builds/rei.nix \
  --baseline-source /path/to/disposable/baseline \
  --candidate-source /path/to/disposable/candidate \
  --edit rei-core/docs/future-enhancements.md \
  --project-uri mori://shinzui/rei \
  --source-revision 99b882ee6d9cdc77ee0e8dead8962736bd3c4d0a \
  --output-dir /path/to/new/receipts
```

The expression retains the original application's locked inputs and invokes the checked
retained-runtime constructor. It pins the displayed revision to the original seven-character
stamp on both sides, isolating source filtering from repository revision changes. Verify
that its baseline identity equals the actual application output before interpreting timings.
A separate stamp-only check must preserve the core and update the CLI/version output.

Choose the practical threshold before running; the default is a 20% median saving. The script
runs five pairs in alternating order, appending a distinct prose comment for each pair.
It times the first `nix build` invocation for each variant, including evaluation and any
recipe translation, through a usable output. It does not run an evaluating dry-run first.
Unchanged warm lookup and the one-time candidate migration build are recorded separately.
Cache state is visible in raw logs and compiled-module counts. An unchanged candidate output
is the intended result for irrelevant prose; it does not prove faster changed-code compilation.

`summary.json` contains source/lock/expression identities, trial order, elapsed time, builder
phase events, compiler-work counts and output identities. Individual logs and receipts allow
failures to be inspected. Phase boundaries do not separately instrument linking, peak memory,
tests or transferred bytes. Report those limitations and measure them separately if they
could change adoption. Generation/IFD work remains included in the timed invocation.

For one-time migration cost C and median per-edit saving S, calculate `ceil(C/S)` relevant
edits to recover the cost. No positive S means no amortized performance claim. Keep required
tests and production optimization equivalent. No intermediate seed, new cache or dependency
update is needed for a source-filter fix.

## Verify preservation and invalidation

Compare recursive graphs with `nix derivation show --recursive` and the actual selected root.
All unchanged shared Haskell compiler/dependency/build-tool instances must retain both recipe
and output identities. Use the retained-runtime validator; matching package versions alone
cannot prove reuse.

Check that prose and an unrelated sibling edit leave the core/CLI unchanged; core Haskell,
embedded prompt/template, migration and public test-support edits invalidate the core and CLI;
and CLI source/help or revision-stamp edits invalidate only the CLI. Build the accepted
candidate and compare database-free version/help/completion commands with the baseline.
Keep positive invalidation checks alongside negative reuse checks. Source paths may resolve
through symlinks, so avoid filtering by equality against an uncanonicalized absolute prefix.

## Native Rei result, 2026-10-17 UTC

The [retained receipt](../evidence/ep18/rei-documentation-rebuild.json) records the full
trial/input/output/phase data, shared graph identities, boundary probes and behavior hashes.
The local raw-log directory and log digests are also recorded there.

| Pair | Original recipe, seconds | Filtered recipe, seconds |
|---|---:|---:|
| 1 | 157.36 | 3.37 |
| 2 | 153.23 | 3.39 |
| 3 | 151.07 | 3.38 |
| 4 | 153.83 | 3.35 |
| 5 | 153.33 | 3.55 |

Median time fell from **153.33 to 3.38 seconds (97.8%)**; observed ranges were
151.07–157.36 and 3.35–3.55 seconds. All five baselines compiled 893 core and 301 CLI
GHC events, including Setup/component repetitions; candidates compiled none. In the first
baseline, the core and CLI build phases took 80.90 and 29.22 seconds, including linking.
Every baseline requested a distinct previously unbuilt root. All 2,048 shared graph nodes,
including 474 Haskell dependency/build-tool instances, retained exact recipes and outputs.

The filter migration took 153.51 seconds and produced 1,303,069,896 NAR bytes across its
ordinary core/CLI outputs. At the median 149.96-second saving, two relevant prose edits
repay that cost. Final default-build, overlay and cohort-parity acceptance adds 122.68 seconds,
so the combined one-time migration/validation cost is 276.19 seconds. Two relevant edits
still repay it; five such edits save about 474 seconds after both costs. No seed is created
or refreshed, and no dependency download occurred in the timed builds. Builder peak memory
and network bytes were not separately instrumented. The Mac had 256 GiB RAM and 36 logical
CPUs; every measured build used one Nix job and 16 requested cores with unchanged production
settings. The benchmark campaign itself took approximately 943 seconds of timed build
invocations; it is a one-time experiment, separate from recurring production cost.

The accepted fix is `mori://shinzui/rei`, revision `4f209d3f`, project-relative
`nix/haskell-overlay.nix` (source-file URI pending). Eleven positive/negative identity
probes and the symlink-path comparison pass. Version output, top-level help, embedded time
help and Zsh completions agree byte for byte with the baseline at the fixed stamp.

A real new Git commit still changes the CLI's provenance stamp and rebuilds that component.
This fix removes the expensive core invalidation; the fixed-stamp timing does not measure
per-commit delivery or faster changed-Haskell compilation. EP-18 remains In Progress for
its intermediate-reuse, changed-code, second-application and deployment acceptance.


## Verify native intermediate reuse

The pinned builder supports explicit saved intermediates. The native fixture proves the
mechanism before application adoption:

```bash
nix build .#checks.aarch64-darwin.application-incremental --no-link
python3 scripts/check-application-intermediates.py --output-dir /tmp/new-intermediate-receipt
```

The second command compares executable behavior, retrieves original build logs through Nix,
and builds expected source failures explicitly. A missing service or download cannot satisfy
an expected type error. It never reads store files directly. The
[retained native receipt](../evidence/ep18/native-intermediate-fixture.json) records:

| Variant | Clean library modules compiled | Seeded library modules compiled |
|---|---|---|
| Unchanged | All four | None |
| Leaf implementation | All four | Leaf, Combined |
| Exported type and adapted consumer | All four | Leaf, Combined |
| Embedded data | All four | Embedded |
| Incompatible exported type | Type error | Same type error |
| Removed module | Missing-source error | Same missing-source error |

Setup compilation and executable relinking remain. These fixture results establish selective
reuse and correct invalidation, without establishing an application speedup.

`lib.mkApplicationIncrementalBuild` takes `pkgs`, `package`, `seedPackage`,
`currentCompatibility`, `seedCompatibility`, and optional `enabled` (default true). It returns
`package`, `seed`, and `compatibilityReport`. Disabled or incompatible inputs return the
original clean recipe and no seed. Accepted seeds are reconstructed with no predecessor,
saved intermediates and a separate intermediates output. The candidate consumes that explicit
seed. No cache directory or historical-seed search participates.

Both compatibility records have `schemaVersion: 1` and nonempty string fields:
`packageName`, `packageVersion`, `compilerIdentity`, `recipeIdentity`, `metadataIdentity`,
`sourceLayoutIdentity`, and `generatedInputPolicy`. Unknown fields reject reuse. Package and
compiler fields must match the actual recipes. The caller owns the remaining evidence:
project the actual recipe onto a fixed dummy source, preserving compiler/native tools,
Setup/Cabal, flags, ways, hooks and dependency identities, and use its derivation identity
as `recipeIdentity`. Never build that dummy projection. Separately fingerprint Cabal/Setup
bytes and source-file layout. Only an explicitly audited generated-source transformation
may normalize its varying content; its normalized writer belongs in the policy fingerprint.
A version string alone cannot establish compatibility. An inaccurate caller-supplied record
cannot provide safe reuse.

## Measure real leaf edits

The [initial baselines](../evidence/ep18/application-leaf-baselines.json) use a real Haskell
implementation edit to an embedded help value in `mori://shinzui/rei` and
`mori://shinzui/mori`. One initial trial took 52.98 and 49.26 seconds respectively, compiling
301 and 92 events. Those are baseline observations, not repeated speedup statistics.

For paired Haskell trials, the measurement script also accepts
`--replace BEFORE AFTER`. BEFORE must occur exactly once in each disposable source file;
AFTER must include `{trial}` so each pair requests distinct changed source. Both policies
receive identical edited bytes, and the file is restored on exit. The
[experimental adapter](../../checks/fixtures/application-builds/pilot.nix) uses each
application's locked inputs and checked retained-runtime constructor. Its clean and seeded
paths move the revision literal into the one source module that consumes it, preserving
version output while removing the global CPP flag. It remains a prototype until its
application acceptance is recorded. Per-copy `.mp4-pilot.json` configuration is read by
[pair.nix](../../checks/fixtures/application-builds/pair.nix) outside owned package sources;
it names application, exact application revision, seed source and clean/incremental policy.

Keep the seed copy fixed and both edited copies disposable. Export
`MP4_APPLICATION_CHECKOUT` to the owning application checkout. Record full configuration and
commands with receipts. Predeclare the threshold and checkpoint budget: the current pilot
uses five alternating pairs, a 20% median saving threshold, and ten leaf edits per checkpoint.
Charge seed creation and first use, transfers, retained bytes and final validation before
adopting a default. Compare changed behavior, tests and exact shared graphs. Keep an opt-in
output when the total-cost budget or required correctness evidence does not pass.

New trials sample host compiler RSS every 250 milliseconds using process names, without
reading command arguments or store files. This can include unrelated concurrent compilers;
receipts identify processes already present at the first sample. Treat it as sampled host
memory, not exact isolated builder accounting. Phase events still do not separate linker,
network or test time. Keep all production settings fixed when comparing policies.


## Use the application-owned opt-in outputs

Both producing projects now expose `application-clean` as the ordinary build. When their
channel input provides `lib.mkApplicationIncrementalPackage`, they additionally expose
`application-incremental` and `application-seed-intermediates`, with the report under
`legacyPackages.<system>.applicationIncremental.compatibilityReport`. Existing input pins
are retained. During local integration, run from the owning application checkout:

```bash
nix build .#application-clean --no-link
nix build .#application-incremental --no-link \
  --override-input haskell-nix path:/path/to/haskell-nix --no-write-lock-file
nix eval --json .#legacyPackages.aarch64-darwin.applicationIncremental.compatibilityReport \
  --override-input haskell-nix path:/path/to/haskell-nix --no-write-lock-file
nix build .#application-seed-intermediates --out-link /path/to/explicit-seed-root \
  --override-input haskell-nix path:/path/to/haskell-nix --no-write-lock-file
```

For the independent core-library experiment, use `application-core-incremental` for the
library and `application-with-core-intermediates` for the full CLI consuming that guarded
library in one recursive scope. `application-core-seed-intermediates` roots its clean
checkpoint, and `legacyPackages.<system>.applicationCoreIncremental.compatibilityReport`
explains its guard decision. The producing checkouts bind their original checkpoint to an
explicit native declaration under a local channel override. Changed-core timing, behavior and total-cost acceptance
are separate gates; these outputs remain opt-in. Core data files have no permissive
embedded-help exception.

The seed source is a fixed published application revision. Its clean recipe is constructed
using the same reviewed owned overlay and retained dependency environment as the current
candidate. A checkpoint has no predecessor. Reuse additionally requires a `validatedCheckpoint`
declaration binding its exact successfully built derivation and compatibility record. Compare
the current context and raw old-source metadata with that recorded origin before constructing
an older package. A changed
compiler, dependency or recipe selects the ordinary clean package; reconstructing both records
in the new scope cannot validate an old checkpoint. Root only the checkpoint you intend to
retain. Runtime outputs do not retain intermediate products.

Both `mori://shinzui/rei` and `mori://shinzui/mori` store native declarations in project-relative
`nix/application-checkpoints.json` (file-level URIs pending). Missing declarations, including
systems without native validation, select clean builds. To refresh one, deliberately build
`legacyPackages.<system>.applicationIncremental.checkpoint` (or `applicationCoreIncremental`),
then capture its `checkpointDeclaration`. Review and store that declaration only after the
exact build succeeds; repeat behavioral and budget checks before adopting a new checkpoint.
`checkpointDeclaration` describes a candidate and is not itself evidence of a successful build.
The [origin fixture](../evidence/ep18/application-checkpoint-binding.json) exercises a same-version
dependency that removes an API: current clean code works, reconstruction of old code fails,
and the guard rejects it before adding that invalid checkpoint to the current build graph.

The shared constructor takes `pkgs`, `mkScope`, `overlayFor`, `source`, `seedSource`,
`packageName`, `revision` and `seedRevision`, plus optional `validatedCheckpoint`, `enabled` and `trackedDataFile`.
The optional `retainCurrentIntermediates` defaults to true. Setting it to false
consumes the fixed checkpoint while exporting only the current runtime output.
The native fixtures and [Mori paired pilot](../evidence/ep18/mori-consume-only-core-pilot.json)
prove selective reuse and changed behavior. The [fresh-checkpoint cost screen](../evidence/ep18/mori-consume-only-full-cost.json)
measures 1,055.88 seconds of gross startup/validation, requiring eleven edits
against the declared budget of ten before final rollout. Keep the policy opt-in.
`overlayFor` uses the supplied source and revision; `mkScope` is the actual retained-runtime
constructor. Only the revision literal and root source are normalized in the recipe projection.
All other recipe inputs remain intact. Cabal/Setup and every non-Haskell file are hashed unless
explicitly declared to be audited GHC-tracked data. The two CLI pilots allow embedded Markdown
under `help/`, whose embedding registers GHC dependencies. Native sources, generator scripts
and untracked resources reject reuse by default. Source layout changes reject conservatively,
even when an added file would be ignored by the package filter. A rejection returns the exact
clean recipe; explicitly requesting the checkpoint output remains possible independently.

The [native application checks](../evidence/ep18/application-native-guards.json) prove current
embedded help, revision stamps and type-error rejection through the owned factory. The normal
application pins and their cohort checks are tested separately from local channel overrides.
Retained-runtime parity must compare the selected generation's captured freeze, rather than
an unrelated newer channel default; the reference validator remains enabled.

To replay guards against a particular successfully built checkpoint, pass
`--seed-source`, `--seed-revision` and `--validated-checkpoint-file` to
`scripts/check-application-source-guards.py` with the producing-project
`--expression`. Add `--no-retain-current-intermediates` to validate the consume-only
policy. The receipt records these inputs. Omitting them preserves the original
same-source, export-enabled guard behavior. A declaration must name the actual
successful checkpoint; these options do not validate or rebuild its origin for you.

Use `--require-idle-compilers` for changed-code timing. It waits up to 60 seconds for other
compiler processes, recording that wait separately from build latency. If interrupted before
a trial, rerun the **same command** with `--resume`. Resume verifies tool/platform/settings,
source directories, locks, expression and complete original warmup identities, then continues
the ordered trial prefix. Changed source, recipe or seed inputs require a new campaign. A
previously completed changed target is retained as historical evidence; a pending target that
is already cached is rejected. Check memory receipts for overlapping host work during trials.
A cached warmup cannot establish checkpoint cost; include fresh creation, migration, final
validation, transfer and retention before adopting defaults.


## Native CLI pilot results, 2026-10-17 UTC

The [paired receipt](../evidence/ep18/application-intermediate-pilots.json) retains all five
pairs, phases, waits, source/settings checks, graph proofs and storage metadata.

| Application | Clean median | Seeded median | Saving | GHC events clean → seeded |
|---|---:|---:|---:|---:|
| Rei | 54.66 s | 42.84 s | 21.6% | 301 → 7 |
| Mori | 50.92 s | 36.02 s | 29.3% | 92 → 5 |

Rei ranges are 53.26–57.50 s and 41.26–43.54 s; Mori ranges are 50.02–51.94 s and
33.36–37.45 s. No trial starts with other sampled compiler processes. Both CLI policies use
the same complete filtered source, production build ways and unchanged non-CLI dependency
graph. Earlier trials with concurrent compilers or cached targets are excluded.

Fresh clean migration plus seeded first use costs 133.29 s for Rei and 125.04 s for Mori.
Adding native validation replay (86.85/91.50 s) gives observed break-even of at least 19/15
edits; initial validation work and transfers are additional. Both exceed the ten-edit budget,
so the clean builds remain defaults. Retaining both the checkpoint and current intermediates
adds about 4.59/3.55 GB of marginal NAR closure beyond the corresponding runtime closure;
each individual intermediates output is about 1.92/1.57 GB. Runtime outputs retain neither
intermediates nor the checkpoint executable, including first use.

These timings belong to the explicit pilot expression. Native identities and source guards
connect it to the owned factory, whose final evaluation latency and core-package rollout have
separate acceptance. The original Mori 49.26 s archive baseline had an alias-sensitive README
selection and a different core context; use the corrected canonical pilot evidence above.

The independent [core-library pilot](../evidence/ep18/application-core-intermediate-pilots.json)
measures full CLI builds after core leaf edits: Rei falls from median 155.343 to 93.245 seconds
and Mori from 224.621 to 115.045 seconds across five alternating pairs. Native changed-value
probes use the exact measured core libraries. CLI behavior, shared graphs, one-seed bounds,
source errors and runtime closure isolation pass. Including the later origin-binding work,
the conservative observed cost requires at least 15 Rei or 11 Mori edits to break even;
the declared budget is ten. Uninstrumented fixture time and fresh-worker transfer add further
uncertainty. These results retain opt-in outputs and keep production defaults clean.

For package-boundary investigation, inventory the chosen source component explicitly:

```bash
python3 scripts/application-module-graph.py \
  --package /path/to/rei/rei-cli --source-dir src \
  --project-uri mori://shinzui/rei \
  --group-prefix Rei.Cli.Commands.Help \
  --output /tmp/rei-cli-module-graph.json
```

The scanner records nested-comment-aware imports, conservative cycles, reverse dependents,
CPP/Template Haskell/resource hazards and Cabal/source hashes. An existing native log can
verify module-name coverage with `--compiler-log` and `--compiler-prefix`. It remains a source
inventory; conditional/generated edges and an actual package split require compiler validation.
The [Rei inventory](../evidence/ep18/rei-cli-boundary-inventory.json) covers 297 native source
modules and a proposed closed 91-module parser/type foundation. The disposable
`scripts/prepare-rei-package-split.py` archive tool preserves source bytes and original public
module names through Cabal reexports. Its [native five-pair pilot](../evidence/ep18/rei-cli-package-split-pilot.json)
passes all 91 public imports and clean behavior, but median elapsed saving is only 8.08%
(56.398 → 51.843 s), below the declared 20% target. Production layout adoption is rejected;
no producing package layout or retained ownership manifest has been changed.

The [Mori core/API pilot](../evidence/ep18/mori-core-split-pilot.json) moves a closed
573-module foundation while the original core reexports every public module. The API depends
on that foundation after an import audit. Five fresh pairs reduce full CLI medians from
229.847 to 84.733 s (63.13%), preserving 2,034 shared graph nodes and unchanged API outputs.
The real generator and conformance/API/CLI/diagram suites pass; five core tests still fail.
The receipt retains those failures and all raw measurements. Gross observed setup and
validation already cost 1,355.42 s, or ten edits, before final rollout and transfer.
Keep this disposable experiment separate from production adoption.

`scripts/prepare-mori-core-split.py` accepts an explicit closed module inventory and immutable
producer revision; `--api-foundation` audits API imports before narrowing its two dependency
names. `scripts/prepare-mori-core-split-workflow.py` stages the existing generator's merged
source view, original placement, Cabal reexports and formatter/push-gate routing. Its nine
controlled routing tests pass. A producer variant can use `--trim-unbuilt-foundation-sources`
to retain required fixtures/SQL while omitting copied test/executable Haskell sources without
a foundation component. That source differs from the measured pilot and requires fresh
realization, identity, complete suite and cost validation. No helper updates the production
checkout or overrides the retained cohort's owned-package validation.

The [matching-input dotfiles rehearsal](../evidence/ep18/dotfiles-package-identity.json) uses
immutable local Git references and normal producing pins. Build those exact references when
checking cache identity: an input override or a dirty working tree can change the truthful
version stamp and therefore the CLI derivation. Both current producer builds complete and
their dotfiles wrappers reuse the same CLI outputs with zero GHC compilations. The actual
Darwin graph includes both wrappers. The system build completes without activation and performs
zero CLI/shared-dependency GHC compilations. It builds the separately exported Rei API and
contract targets; building the project CLI default does not produce those additional artifacts.
