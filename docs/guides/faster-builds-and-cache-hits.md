---
type: Guide
title: Get faster builds and reliable cache hits
description: Preserve shared dependency identities, configure cache delivery, shorten application rebuilds and choose performance features by measured cost.
docId: DOC-9
tags: [performance, cache, runtime, consumers]
generated:
  by: process:codex
  at: 2026-10-18T13:34:34Z
---

[Guides](README.md)

# Get faster builds and reliable cache hits

Keep routine application edits on a fixed toolchain and retained dependency scope, make
those exact dependency outputs available from the cache, and limit application sources to
files their packages actually use. These are the first steps toward shorter builds. Use
the project shell for the edit and test loop; reserve production Nix builds for checking
the deliverable. Try generated recipes or saved compiler intermediates when measurements
show that their particular phase is still expensive.

This workflow brings together the consumer features coordinated by
[MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md).
Its application-compilation and generated-recipe work remains in progress. The supported
runtime configurations, opt-in shell and experimental build paths have separate acceptance
evidence; a newer generation number alone is not a reason to upgrade.

## Choose the change that addresses your build time

| What takes time | First action | Expected effect |
|---|---|---|
| Shared libraries rebuild after routine application edits | Align inputs and use one checked retained scope | Unchanged dependency derivations remain reusable |
| Matching dependencies still compile on a new worker | Check cache publication, trust and private read access | Published outputs can substitute on that system |
| Documentation edits rebuild application libraries | Narrow each package's source boundary | Irrelevant edits preserve its derivation |
| Editing and testing repeatedly rebuilds the application | Use the retained-runtime project shell and Cabal | Cabal can perform incremental application compilation |
| Evaluation repeatedly invokes dependency recipe translation | Investigate generated recipes for the selected root | Covered recipes can evaluate without that translation |
| Changed Haskell code remains expensive in production Nix builds | Measure guarded intermediates or package boundaries | Adopt only when correctness and total cost pass |

## Keep one dependency identity across consumers

Follow [flake adoption](adopt-in-an-existing-flake.md) and
[runtime composition](compose-on-the-keiro-runtime.md) before tuning the application.
Use the Nixpkgs pin from `mori://shinzui/haskell-nix-dev` and make the channel follow that
same toolchain input:

```nix
inputs.nixpkgs.follows = "haskell-nix-dev/nixpkgs";
inputs.haskell-nix.inputs.haskell-nix-dev.follows = "haskell-nix-dev";
```

Commit `flake.lock`, the explicit runtime generation/channel/configuration and the complete
complementary application selections. Materialize the matching Cabal runtime imports and
retain the complete cohort freeze. Keep these inputs fixed during ordinary application
work. Move them together during an intentional dependency upgrade, then build and publish
the new configuration before rolling it out to other consumers.

When a deployment or dotfiles flake consumes an application, build the exact immutable
producer reference that it selects. A dirty checkout, local input override or different
revision stamp can produce a different application derivation despite matching dependency
pins. Compare the producer and deployment package identities before expecting reuse.

Construct production packages with `selected.mkApplicationScope`, or use the
`applicationScope` returned by `lib.mkProjectDevShell`. These constructors verify the
runtime-owned recipes against the retained reference. Declare application-owned packages
in the local overlay; put shared dependency repairs in the channel. Run the consumer
overlay audit and Cabal/Nix comparison from the adoption guide when changing composition.

Equal package versions are insufficient. Compiler, Nixpkgs, system, source revision,
selected Cabal metadata, flags, native tools, patches, dependency instances and build ways
all affect reuse. Keep profiling and Haddock disabled for the currently retained production
runtime configurations. Enabling either requires a separately accepted configuration and
its own outputs. Preserve required tests and production optimization when tuning.

Inspect retained choices from the channel checkout:

```bash
nix eval --json .#lib.runtimePackageSets.keiro-runtime
```

Check the selected generation's `support`, fingerprint and configuration. Generations 1
and 2 have verified configurations for GHC 9.12.4 on `aarch64-darwin` and `x86_64-linux`,
both source channels, with profiling/Haddock disabled. Generation 4 captures generated
recipes but retains an unverified broad support status. Unqualified `keiro-runtime`
outputs still select generation 1. Explicit selectors and support evidence are described
in [Package sets](../user/package-sets.md#retained-keiro-runtime-generations).

## Make cache delivery work on each machine

The existing cache is `tan`. On a developer machine with Nix and Cachix installed, configure
it using your existing private-cache credentials:

```bash
cachix use tan
cachix doctor
```

Keep `cache.nixos.org` available alongside the fleet cache. Use the cache's published
signing key and configure read authentication where the Nix daemon can use it. Cachix's
[setup instructions](https://docs.cachix.org/getting-started) cover configuration and
authentication. In CI, the existing
[runtime cache workflow](../../.github/workflows/runtime-cache.yml) configures `tan` with
`CACHIX_AUTH_TOKEN` and `skipPush: true`; use the same read setup in consumer jobs.

From the consumer checkout, replace `TARGET` with the package you actually need:

```bash
nix build .#TARGET --dry-run
nix build .#TARGET --no-link --print-build-logs
```

The [dry run](https://nix.dev/manual/nix/2.32/command-ref/new-cli/nix3-build) previews
planned work; inspect which dependencies would build or download. A changed application
may need compilation while all its shared libraries are reused. An unchanged local build
can finish immediately without consulting the remote cache. Neither observation proves
fresh-worker cache coverage. Recipe evaluation can itself trigger translation builds, so
run latency measurements separately without a preceding dry run.

If a shared library unexpectedly rebuilds, compare its derivation with the published or
previously accepted one. Different identities point to input drift. An equal identity
with no substitutable output points to publication, retention, read access, trust or
platform coverage. Check both before increasing parallelism or changing package versions.

## Publish reusable outputs and prove substitution

After validating a dependency update, a maintainer with cache write access can publish
the selected runtime closure from the channel checkout. For example, for generation 2's
GitHub channel on the current system:

```bash
nix run .#cohort-cache -- publish \
  --root .#keiro-runtime-2-closure \
  --cache tan --receipt /absolute/receipts/runtime-publication.json
```

Choose the root for the actual generation and channel. Repeat publication on each target
system; Darwin outputs do not supply Linux outputs. `cohort-cache` builds the declared
roots, pushes them and verifies remote hashes, sizes and references before writing its
receipt. Publish `cohort-closure` for the broader cohort. A runtime executable's installed
closure can omit Haskell libraries used only during compilation; dependency closure roots
retain those build inputs. Publish additional application, shell and HLS roots separately
when workers need them. A successful CLI build does not populate every sibling output
that a system configuration might later request.

On a matching worker with cache reads configured, verify the publication into a new empty
store. Replace the absolute paths below; the store path must have no symlink parents
(use `/private/tmp/...` rather than `/tmp/...` on macOS):

```bash
nix run .#cohort-cache -- verify \
  --receipt /absolute/receipts/runtime-publication.json \
  --store 'local?root=/absolute/new-empty-worker' \
  --evidence /absolute/receipts/runtime-substitution.json
```

Verification disables local and remote builds and fallback, rejects pre-existing expected
paths, and checks the complete recorded graph. Use an empty alternate store without
deleting the normal store. The
[existing CI workflow](../../.github/workflows/runtime-cache.yml) also binds its retained
receipt to the runtime fingerprint and channel; it currently accepts generations 1 and 2.
Running this check on a developer machine proves substitution there. Run it on the actual
CI worker to establish CI delivery. See the
[cache contract](../user/package-sets.md#build-manifests-and-cache-receipts) for manifest
comparison and publication details.

## Shorten the application edit loop

Adopt the optional shell through
[Develop against a retained runtime](develop-against-a-retained-runtime.md). Export it
as `devShells.runtime` using the copyable
[project-shell example](../user/package-sets.md#project-shells-from-retained-scopes),
then run from the consumer:

```bash
nix develop .#runtime
cabal build all
cabal test YOUR-TEST-TARGET
```

Initialize a missing Cabal index with `cabal update`. Keep the retained imports in place
and use the scoped compiler selected by the shell. Keep `dist-newstyle` between local
edits so Cabal can reuse application compilation. A normal plan can reuse installed Nix
packages, but source/flag policy may still require builds; inspect what Cabal actually
compiles. Source-parity comparison uses the separate fresh-plan procedure in the shell
guide because installed `pre-existing` entries lack complete source evidence.

Add development executables through `extraNativeBuildInputs`, libraries through
`extraBuildInputs` and a compatible HLS through `withHls`. Shell-only changes should
preserve production and runtime identities. Avoid inheriting a second bare GHC shell.
First shell entry, warm re-entry and changed-code Cabal builds are different costs;
measure them separately from production Nix builds.

For production builds, give each application package its own required sources. Inspect
Cabal components, Template Haskell, generated modules, embedded help/templates, schemas,
migrations and license files before excluding anything. A broad repository source can
make a planning-document edit invalidate a large library. An exclusion based only on a
file extension can also remove a real build input.

Verify both directions: an irrelevant prose or sibling edit preserves the package;
a Haskell, embedded-data or public-interface edit rebuilds it and the required dependents.
Keep revision stamps in the component that exposes them where practical. A new commit
can legitimately rebuild a CLI's version output while leaving its core library reusable.
The [application rebuild guide](faster-application-nix-builds.md) contains the measured
source-boundary example and validation procedure.

## Use experimental features when their costs pay off

Generated recipes move covered dependency translation out of evaluation. They do not
change GHC compilation speed or automatically publish binaries. Keep older consumers on
their selected generation; maintainers introduce reviewed artifacts through a new retained
snapshot. Follow [retained recipe selection](../user/maintainer-tools.md#retained-recipe-selection-and-freshness)
for context binding, regeneration checks and scoped evaluation with
`allow-import-from-derivation` disabled. Generation 4 converts a bounded root; the complete
constructor still encounters unconverted dependencies. Its native parity and bounded
cache checks do not establish a general evaluation speedup or broad production support.

Saved compiler intermediates are opt-in. Where the producing application exports them,
compare `application-clean`, `application-incremental` and its compatibility report using
the [application-owned output procedure](faster-application-nix-builds.md#use-the-application-owned-opt-in-outputs).
Reuse requires an explicit validated checkpoint with matching compiler, recipe, dependency,
metadata and source guards. Preserve clean fallback when the context changes and retain
only the checkpoint you intend to use. Intermediates add creation, validation, transfer,
storage and refresh costs even when a leaf edit compiles fewer modules.

The recorded application pilots retain clean production defaults because total cost or
acceptance remains unresolved. Before adopting either an intermediate cache or a package
split, measure at least five alternating baseline/candidate pairs with distinct changed
sources, fixed production settings and a declared improvement threshold. Include required
tests and compare behavior and shared dependency identities. If extra setup/refresh cost
is C and each eligible edit saves S, require enough edits to cover `ceil(C / S)`, including
transfers and retained storage in the adoption decision. Keep an experiment opt-in if the
expected work before its next refresh does not repay that cost.

## Diagnose the remaining time

Record the consumer revision, lock, runtime selection, system, compiler, jobs/cores and
cache state alongside the build logs. Distinguish evaluation/translation, substitution,
shared dependency compilation, application compilation, linking and tests. An unchanged
warm build, changed code with warm dependencies and first use on a new worker answer
different questions.

Capture graphs through Nix's metadata API, from the consumer checkout:

```bash
nix derivation show --recursive .#TARGET > /absolute/receipts/target-graph.json
```

The [derivation command](https://nix.dev/manual/nix/2.32/command-ref/new-cli/nix3-derivation-show)
exposes dependency recipes without searching the store. Export the actual consumer's
`cohort-manifest` when available and compare before/after manifests with `cohort-compare`.
Use `just drv-diff BEFORE.drv AFTER.drv` from the channel checkout to explain a changed
recipe. Compare the shared dependency instances as well as the application root: source
edits legitimately change the latter.

If dependencies already reuse and application compilation dominates, focus on source
boundaries, the Cabal loop or a measured compilation experiment. If evaluation dominates,
investigate recipe coverage. If downloads dominate, investigate cache delivery and closure
size. Change jobs and cores only after observing CPU and memory use; record those settings
so subsequent measurements remain comparable.
