---
type: Guide
title: Measure and remove avoidable application rebuilds
description: Measure source filtering and guarded compiler intermediate reuse with explicit inputs, native correctness and total-cost evidence.
docId: DOC-7
tags: [performance, consumers, nix, source-boundaries]
generated:
  by: process:codex
  at: 2026-10-17T04:45:02Z
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
