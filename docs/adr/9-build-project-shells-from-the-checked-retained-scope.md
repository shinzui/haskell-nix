# Build project shells from the checked retained scope

Status: Accepted.

Date: 2026-10-17

## Context

[ADR 1](1-compose-first-party-snapshots-in-one-haskell-scope.md) requires one recursive
Haskell scope. [ADR 4](4-consumer-overlays-define-only-their-own-packages.md) reserves
shared policy for the channel, and [ADR 7](7-compose-applications-on-retained-keiro-runtime-baselines.md)
retains exact runtime recipes and explicit complementary application selections.
A bare toolchain shell does not expose that selected scope's dependency database.
Adding a second bare compiler can also hide the compiler wrapper made by `shellFor`.

## Decision

The generic project-shell helper belongs to `mori://shinzui/haskell-nix-dev`,
project-relative `lib/mkProjectShell.nix` (artifact-level URI pending). It consumes a
caller-supplied Haskell scope and project-package selector, while binding tooling
to its own declared system/compiler cells. The toolchain flake gains no channel or
application input. The existing bare `mkDevShell` API remains compatible.

Infer the compiler cell from its actual derivation identity. Require selected
packages to be members of that scope with the same compiler. Match the declared
package-set version/system and actual stdenv, Cabal, pkg-config and zlib identities;
compiler matching supplies the Haskell side. Equal pinned revision/NAR metadata can
materialize under different path aliases, so path-string equality is insufficient.
Reject unknown compilers, unavailable explicitly requested HLS and extra/inherited
bare or wrapped GHC inputs. HLS remains the toolchain's existing independent component,
with its compiler identity checked; project libraries do not reconstruct its backend.

The channel's `lib.mkProjectDevShell` owns selection mapping. Require explicit
runtime name/generation/channel and compiler/profiling/Haddock configuration, plus
a complete application complement. Construct the scope once through the delivered
`mkRuntimePackageSet.mkApplicationScope` validator. Audit the application overlay
against that actual checked scope and all selected channel/frozen/runtime ownership.
Expose the same scope as `applicationScope` for production packages. Runtime source,
flag and policy changes require a new accepted generation/configuration.

Use that scope's `shellFor`, then `mkShell.inputsFrom` for the compiler environment
and caller shells. Preserve all four dependency classes and hooks once. Forward the
scoped `NIX_GHC*` and locale archive explicitly because `inputsFrom` omits arbitrary
environment variables. Add compatible Cabal/pkg-config/HLS tools and preserve the
legacy locale default. Keep libraries in build inputs and tools in native inputs.
A real HLS-enabled consumer exposed a transitive bare GHC earlier on PATH. After
inherited hooks, remove the selected bare compiler's bin entry and any duplicate
scoped-wrapper bin entry, then prepend the scoped wrapper before the caller hook.
This keeps the independent HLS closure intact and makes ordinary `ghc`/`ghc-pkg`
use the selected package database. The two-system native fixture now enables HLS
and asserts compiler resolution and absence of the bare compiler bin.
[Regression evidence](../evidence/ep20/hls-enabled-shell-entry.json) records the case.

Attach selection, fingerprint and actual dependency identities in passthru.
Executable manifests compare the existing metadata-only source identity projection
when lazy source aliases have different strings. Literal path equality remains a
fast path; changed repositories and subdirectories still fail. The projection is
never built or added to a production closure. Keep declaration paths contextual
until Nix materializes them, and retain the complete selected graph and source policy.

Discard Nix output string contexts in diagnostic JSON: exporting a derivation path
must not request that package's output build. Diagnostic metadata does not alter
shell or production recipes. Selected package/environment values retain their
normal contexts when actually used to build or enter a shell.

Keep the helper additive. Consumers supply a toolchain library exporting the new
API; old source pins retain existing outputs. The integration check attributes are
available when that input exports the project-shell API, including explicit local
input overrides. Do not silently change locks or generated consumer templates.

## Consequences and validation

The public helper passes selected-dependency, native-library, hook and offline Cabal
fixtures on Apple Silicon and in the user-selected translated x86 Linux guest.
Twenty-five toolchain contracts and 295 channel contracts pass. Real retained-scope
identity checks preserve production and every recorded runtime dependency across
tool, hook and inherited-shell edits. The identity check's direct build inputs are
only its shell builder, and all legacy tools/bundles/shells keep their identities on
all three declared toolchain systems. [M2 evidence](../evidence/ep20/project-shell-constructors.json)
records exact inputs and qualifications.

The optional `mori://shinzui/mori` adoption is delivered in its unmanaged
`flake.module.nix` (artifact-level URI pending), preserving pins and the default
shell. [Final consumer evidence](../evidence/ep20/mori-project-shell.json) retains
normal production execution, 392-dependency fresh Cabal comparisons, 340-instance
actual executable manifests, 79 owned-package tests, source-edit behavior and
shared identities on both declared execution systems. Entry/edit costs are separate
observations. An empty Linux worker substitutes 907 existing compiler/runtime/HLS
paths with zero builds; this does not claim zero construction for a fresh shell wrapper.

Normal scoped Cabal plans contain installed non-boot packages without source/metadata
hashes; the existing comparator must reject those rows as source evidence. Obtain a
separate fresh plan through the same bare compiler and retained imports. Compare the
complete cohort freeze against the complete source manifest, then verify actual Nix
identities separately. This preserves the existing parser and package authority.
Nix-built library exposure does not imply equal Cabal unit IDs or no application
recompilation. HLS protocol behavior remains the toolchain smoke plan's separate
responsibility. Linux results retain translation and guest sandbox/syscall-filter
limits; no physical-x86 performance or general compiler speedup is claimed.
