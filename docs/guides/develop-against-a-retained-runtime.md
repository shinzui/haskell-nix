---
type: Guide
title: Develop against a retained runtime
description: Add an optional project shell that shares its checked dependency scope with production and verify shell, Nix and Cabal evidence separately.
docId: DOC-8
tags: [runtime, development, adoption]
generated:
  by: process:codex
  at: 2026-10-17T16:22:44Z
---

[Guides](README.md)

# Develop against a retained runtime

Start with an application that already uses the [retained runtime contract](compose-on-the-keiro-runtime.md).
Keep its channel/toolchain pins, runtime selection, complementary application selections and
Cabal source policy. Add `devShells.runtime` in an unmanaged consumer module. Preserve the
existing default shell while validating this optional path.

The generic API belongs to `mori://shinzui/haskell-nix-dev`, project-relative
`lib/mkProjectShell.nix` (artifact-level URI pending). The channel's `lib.mkProjectDevShell`
constructs and audits the retained scope, and then passes that exact scope to the generic API.
Use its returned `applicationScope` for production packages. The copyable Nix example and
complete argument contract are in [Package sets](../user/package-sets.md#project-shells-from-retained-scopes).
Declare every application-owned package; the ownership audit rejects shared recipe overrides.

Keep executable development tools in `extraNativeBuildInputs`, native libraries/headers in
`extraBuildInputs`, and additional environments in `inputsFrom`. For example, PostgreSQL tools
belong in native inputs while OpenSSL and librdkafka belong in library inputs. Shell hooks and
all four inherited dependency classes are preserved. An inherited shell containing bare GHC
or another GHC package wrapper is rejected. Reuse shared environment settings through a
compiler-free shell rather than inheriting a bare toolchain shell.

`withHls` defaults to the selected cell's declared availability. Explicitly requesting an
unavailable server fails. HLS retains its independent dependency scope and exact compiler
identity; project library edits do not reconstruct its backend. Transitive tools can propagate
bare GHC, so the helper selects the scoped wrapper after inherited hooks and before the caller
hook. A caller hook should preserve that compiler selection.

## Validate with local inputs

Older pins retain their existing outputs and may not expose the new helper. In the consumer
checkout, explicitly override both inputs for validation without writing the lock file:

```bash
channel_checkout=/path/to/haskell-nix
toolchain_checkout=/path/to/haskell-nix-dev
nix develop .#runtime \
  --override-input haskell-nix "path:$channel_checkout" \
  --override-input haskell-nix/haskell-nix-dev "path:$toolchain_checkout" \
  --no-write-lock-file \
  -c bash -c 'set -e; test "$(command -v ghc)" = "$NIX_GHC"; test "$(command -v ghc-pkg)" = "$NIX_GHCPKG"; ghc --numeric-version'
```

Use `set -e` when combining probes that must all pass. Query actual project dependencies with
`ghc-pkg` and native libraries with `pkg-config`; the compiler version alone cannot establish
which package database is selected. In the `mori://shinzui/mori` trial, ordinary `ghc-pkg latest
keiki` and `ghc-pkg latest kiroku-store` establish selected library visibility, and `pkg-config`
checks libpq, OpenSSL and librdkafka. That project's unmanaged `flake.module.nix` and
`nix/runtime-selection.json` are project-relative source artifacts with artifact-level URIs pending.

Inspect `shell.packageSetIdentity` through `nix eval --json`. It records selection,
configuration, compiler, runtime fingerprint, owned packages and retained dependency recipes.
Its diagnostic strings do not request output builds. Compare actual identities before and
after a development-tool, hook or inherited-environment edit: the shell changes while production
and runtime recipes stay equal. A project-owned source edit should affect its package and
dependents while preserving unrelated runtime recipes. Runtime source/flag changes require a
new accepted generation/configuration and cannot be hidden in an application overlay.

## Compare Cabal plans separately

A new worker also needs a Cabal package index. Run `cabal update` in the selected
project before its first solve if the index is absent. Its retained imports still
pin the index state, versions, sources and flags; initializing this local cache
does not change the project selection. Missing index data can make Cabal report
installed dependencies as unusable when the project selects their source packages.

A normal Cabal plan in this shell can reuse installed Nix packages. Such `pre-existing` plan
rows omit trustworthy source/metadata hashes. The shared comparator correctly rejects them as
source-parity evidence. Keep that diagnostic; never label these rows source-verified or invent
hashes from package names.

For source/metadata/flag verification, make a separate fresh plan with the same underlying bare
compiler, the retained imports, and supported tests/benchmarks enabled. Obtain that compiler
output from `shell.applicationScope.ghc.outPath` using Nix evaluation. Pass its `bin/ghc` and
`bin/ghc-pkg` explicitly to Cabal's `--with-compiler` and `--with-hc-pkg`, and use a new build
directory. This is a plan-only evidence step; ordinary development commands use the scoped
wrapper. Compare the result through the existing tool:

```bash
nix run "$channel_checkout#cohort-compare" -- \
  --freeze "$channel_checkout/cabal/cohort.freeze" \
  --sources cabal/runtime/keiro-runtime/2/comparison-sources.json \
  --contributors "$channel_checkout/cabal/contributors.json" \
  --plan-json /path/to/fresh-build/cache/plan.json
```

Use the complete cohort freeze with the complete comparison source manifest. The smaller
runtime-only freeze cannot validate unrelated cohort entries in that manifest. Bind the freeze,
contributors and runtime projection hashes to the consumer's selected immutable revision;
local input overrides do not authorize a dependency update.

## Record costs without implying a speedup

Measure first entry into a new shell recipe and warm re-entry separately. Record cache state,
substitutions, compiler/runtime/HLS builds and the execution system. Changing shell-only options
must reuse existing shared outputs. Check available published compiler/runtime/HLS roots in an
empty worker store with builds disabled before claiming fresh-worker substitution.

Also build and test a representative owned package with Cabal, then measure a real source edit.
Cabal may still compile application code and dependencies; selected Nix library visibility
alone does not prove saved compilation. Keep these timings separate from Nix production builds,
compiler performance and HLS protocol behavior. Apple Containers amd64 translation supplies
qualified Linux correctness results; retain that qualification for guest timings.

[Final real-consumer evidence](../evidence/ep20/mori-project-shell.json),
[constructor evidence](../evidence/ep20/project-shell-constructors.json),
[the HLS-enabled regression](../evidence/ep20/hls-enabled-shell-entry.json) and
[ADR 9](../adr/9-build-project-shells-from-the-checked-retained-scope.md) describe accepted
constructor behavior. [Plan 20](../plans/20-build-project-development-shells-from-retained-runtime-package-sets.md)
records completed real-consumer and optional adoption acceptance, with the declared evidence limits.
