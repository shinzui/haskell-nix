---
id: 20
slug: build-project-development-shells-from-retained-runtime-package-sets
title: "Build project development shells from retained runtime package sets"
kind: exec-plan
created_at: 2026-10-14T15:21:55Z
intention: "intention_01m4xg1zg2e4wvbjgaagz3aqpz"
mori_publish: true
master_plan: "docs/masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex-cli"
    at: 2026-10-14T15:21:55Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-14T15:34:19Z
      mode: "other"
      note: "Flesh out retained-runtime project shell APIs with compiler and ownership validation."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-14T17:32:37Z
      mode: "update"
      note: "Add cross-repository umbrella coordination and scoped Mori publication without changing implementation ownership."
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-10-17T03:25:59Z
      mode: "update"
      note: "Reconcile delivered prerequisites and strengthen maintenance, real-consumer integration, and measured total-cost acceptance."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-17T06:50:58Z
      mode: "implement"
      note: "Prototype selected-scope project shells and native-library fixtures while preserving the DEV-4 production gate."
  reviews:
    - model: "gpt-6-astra"
      harness: "codex-cli"
      at: 2026-10-17T03:26:00Z
      verdict: "comments"
      note: "Reviewed against current repository contracts and applied maintenance/performance findings; new implementation and benchmark evidence remain pending."
---

# Build project development shells from retained runtime package sets

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective current. Distill durable implementation decisions into local ADRs.

## Purpose / Big Picture


A project should select its runtime generation once and use the resulting package scope for both its Nix build and development shell. Add a project-shell constructor that supplies that scope's compiler environment, compatible Cabal/HLS tools, and native dependencies, and rejects compiler/runtime mismatches. A developer can enter the shell, work with the same selected Nix dependencies, and change shell-only tools without rebuilding the shared runtime.

The existing bare toolchain shell remains available. This plan is an additive project-shell path, not a promise that arbitrary independent Cabal solving automatically reproduces Nix derivations. Cabal projects still use the retained constraints and source policy supplied by the runtime contract; verify their fresh plans separately.

This standalone plan requires [plan 16](16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md)'s retained runtime composition contract and the capability contract in `mori://shinzui/haskell-nix-dev/plans/4-publish-compiler-capabilities-and-an-explicit-platform-support-matrix` for production activation. Native fixtures and generic helper prototyping can start before those contracts are delivered. The full recipe-generation follow-on, [plan 19](19-pre-generate-complete-locked-nix-haskell-dependency-recipes.md), and behavioral toolchain plan are independent, not hard dependencies for this shell API.

## Progress

2026-10-17 M1 accepted on native Apple Silicon: the selected-scope compiler, direct executable, Nix production package and offline Cabal all resolve dependency 1.0 and print `42:1.3.2`. The deliberately wrong dependency prints `9000:1.3.2`. All four inherited input classes, three hooks exactly once, scoped compiler variables and shell-only identity changes pass. [Receipt](../evidence/ep20/project-shell-prototype.json). DEV-4 native Linux acceptance remains blocked; production helper/adoption work remains gated.


- [x] (2026-10-17) M1: Prototype one-scope shell construction with native and shell-input fixtures.
- [ ] M2: Add generic toolchain helper and guarded channel/runtime wrapper.
- [ ] M3: Validate real consumer shell/build/plan consistency on both supported systems.
- [ ] M4: Document adoption, preserve legacy consumers, and distill the ADR.

## Surprises & Discoveries


The native prototype passes. The pinned stdenv flattens `env` variables into derivation attributes, and `inputsFrom` does not preserve those arbitrary variables. Forward the scoped `NIX_GHC*` and locale values explicitly. Inherited native tools select development outputs, so compare derivation identity rather than entire multi-output values. No speed measurement is claimed. The existing toolchain helper only exposes extra native inputs and a shell hook; the retained runtime factory is now delivered under plan 16. The user restored the foreign DEV-4 plan and it is pulled locally; policy/capability fixtures pass on Apple Silicon, while native Linux acceptance is blocked by the configured builder authentication. Mori discovery remains unavailable.

## Decision Log


2026-10-16: Consume the delivered retained runtime API with explicit selection mapping and checked scope reuse. Keep DEV-4 production activation gated until its actual contract is available; record shell startup/reuse evidence separately from application compilation improvements.

2026-10-14: Coordinate this workstream under [MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md). Scoped Mori publication records its production prerequisites and integration relationships; initial fixture work remains independent. Existing generator/runtime ownership and this plan's acceptance remain unchanged.


2026-10-14: Keep the dependency direction acyclic. The toolchain flake accepts a caller-supplied Haskell scope through a generic helper and gains no input on this repository. The channel owns runtime selection and conflict validation.

2026-10-14: Use the selected Haskell scope's `shellFor` environment rather than placing a second bare compiler alongside its compiler wrapper. HLS keeps its independently built dependency scope; changing runtime libraries must not rebuild the editor backend.

2026-10-14: Preserve `mkDevShell` and its existing unavailable-HLS behavior. The new project helper rejects an explicit `withHls = true` request when that cell has no HLS, and defaults to the declared availability. This makes new API requirements clear without breaking existing generated flakes.

2026-10-14: Require an explicit retained runtime/configuration and complete complementary application selections. Do not fill missing application groups from the mutable default or convert this into a workspace-wide pin update.

## Outcomes & Retrospective


M1 is accepted on native Apple Silicon. Production shell constructors, retained runtime integration, real-consumer native matrix and adoption documentation remain pending behind DEV-4 acceptance.

## Context and Orientation


`flake.nix` selects shared toolchain inputs through `haskell-nix-dev`, imports a common patch registry, and exposes `lib.mkFirstPartyPackageSet`. `lib/mkFirstPartyPackageSet.nix` composes selected first-party families with common compatibility policy in one Haskell scope. The flake now also exports `lib.mkRuntimePackageSet` from `lib/mkRuntimePackageSet.nix`. `docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md` owns that factory, including runtime name/generation/configuration, exact source policy, complete application complement, and conflict validation. Plan 16 is Complete locally, with generation-1/2 fingerprint-bound support evidence under `cabal/runtime-cache/keiro-runtime/`. Use its delivered factory and returned scope; do not implement an alternative runtime selector here. The factory accepts `runtime`, `generation`, `applicationSelections`, `channel`, `disableProfiling`, `disableHaddock`, and optional `applicationCohort`/`applicationRegistry`; it returns `mkApplicationScope`, `validateApplicationScope`, and `mkApplicationManifest`. Its compiler is currently fixed to the retained GHC 9.12.4 configuration. Map the proposed shell selection's `name` to `runtime` and validate its `configuration` against the retained record, translating supported build options explicitly. Do not pass a fictional free-form configuration argument or silently substitute the current default compiler.

A Haskell scope is the recursive package set in which dependency names resolve to one selected package instance. Nixpkgs `shellFor` derives a compiler package environment and development dependencies from packages in that scope. An `inputsFrom` shell inherits build dependencies from another derivation; extra native inputs are programs running on the development machine, while extra build inputs are libraries/header/pkg-config providers used by the project. A shell hook is code executed when entering the shell. These distinctions matter for PostgreSQL, OpenSSL, zlib, and other native libraries.

In `mori://shinzui/haskell-nix-dev`, project-relative `flake.nix` (file-level URI pending), `mkDevShell` currently takes `ghc`, `extraNativeBuildInputs`, `withHls`, and `shellHook`. It puts the bare compiler, Cabal, pkg-config, zlib, and optional HLS on PATH. It does not accept a project scope, library inputs, or inherited shell environments. The new generic helper will live there and consume its existing toolchain records and the capability contract from the canonical prerequisite plan URI. The channel already demonstrates `shellFor` in its updater dev shell, but that shell is its independent bootstrap scope, not a consumer runtime.

[ADR 1](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md) requires one dependency scope and stable identities for unchanged inputs. [ADR 4](../adr/4-consumer-overlays-define-only-their-own-packages.md) reserves shared recipe ownership for the channel. [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md) preserves toolchain/runtime pins during routine application edits. [ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md) requires explicit runtime selection and rejects application overrides of runtime-owned recipes. Summarize these rules in the implementation guides and apply them to the shell wrapper.

Before using Nixpkgs APIs, search Mori and read the exact pinned sources. The inspected upstream `mori://NixOS/nixpkgs`, project-relative `pkgs/development/haskell-modules/make-package-set.nix` and `pkgs/build-support/mkshell/default.nix` at `d5dfd8e6716dde34398bc14bc87c10dece9c8c68` (registry/file-level URI coverage pending), provide `shellFor` and `inputsFrom` behavior. Recheck the actual input revision. Acquire a scoped checkout when Mori lacks it; never inspect `/nix/store` or traverse the filesystem root. This work selects no new dependency releases.

## Plan of Work


### Milestone 1: Prove shell/compiler and native dependency behavior


Add `checks/fixtures/project-shell/` with a small library, executable, and a native-library fixture using zlib through pkg-config. Supply a pure local fixture package set and define a legacy production package plus a candidate shell using the same scope. Build a `checks/project-shell.nix` probe that enters the candidate's environment through Nix and demonstrates that its compiler resolves the selected fixture dependency, the native build succeeds, and the executable prints the expected result. Include a fixture with a second version of the shared library so accidentally using the stock scope visibly fails.

Use the selected scope's `shellFor` for owned project packages, then a `pkgs.mkShell` wrapper with `inputsFrom` for that environment and caller-supplied shell inputs. Verify the pinned builder's merge behavior: preserve inherited native/build/propagated inputs and shell hooks once, and add Cabal/HLS without another bare GHC. The shell compiler wrapper may have a different path from the bare compiler; compare its underlying compiler and dependency registrations, not wrapper-path equality. Run `ghc --numeric-version`, `ghc-pkg` queries, a direct compiler fixture, and an offline Cabal fixture under explicit retained constraints. M1 passes when the selected dependency and native library are visible and the wrong-scope fixture fails.

### Milestone 2: Implement generic and runtime-specific constructors


In `mori://shinzui/haskell-nix-dev`, add project-relative `lib/mkProjectShell.nix` and export `lib.<system>.mkProjectShell` (file-level URI pending). The generic helper accepts `{ pkgs; haskellPackages; packages; withHls ? policyCell.hlsAvailable; extraNativeBuildInputs ? []; extraBuildInputs ? []; inputsFrom ? []; shellHook ? ""; }`; `packages` is a function from the supplied scope to project-owned package derivations. Bind toolchain/policy internally to that per-system API. Require `pkgs` to match the toolchain's pinned package universe and system, using explicit metadata plus actual native tool/compiler identities where needed. Require the scope's underlying compiler to match the toolchain compiler's derivation. If available HLS has a different compiler key/version, reject it. Use the existing HLS component unchanged rather than rebuilding HLS against project dependencies.

Leave `mkDevShell` unchanged. An explicitly requested unavailable HLS fails in the new helper with a clear compiler/system reason. Empty packages, wrong system, incompatible scope/compiler, unknown compiler cell, and invalid shell arguments also fail before shell realization. Keep caller-supplied libraries in build inputs, executable tools in native inputs, and inherited shells in `inputsFrom`. Locale behavior must preserve the existing developer default; verify shell hooks execute exactly once.

In this repository, add `lib/mkProjectDevShell.nix` and export `lib.mkProjectDevShell`. It accepts an explicit `runtimeSelection = { name; generation; configuration; channel; }`, complete `applicationSelections`, optional application-owned overrides, `ownPackages`, `pkgs`, and the matching `toolchainLib`, plus shell options. Invoke `lib.mkRuntimePackageSet` with the mapped selection and use its `mkApplicationScope pkgs applicationOverrides` to create the one scope used by production and the shell. Pass that checked scope to the generic helper; do not independently reconstruct it. Apply the existing ownership audit to application overrides; reject runtime recipe/source/flag/policy replacement and incomplete complements. Do not reconstruct recipes from package versions. Return a shell with `passthru.packageSetIdentity` recording selection/compiler/system/configuration and actual scoped dependency identities for diagnostics. Metadata and shell-only options must not alter runtime recipes.

M2 passes when both helpers evaluate through local input overrides, mismatches fail clearly, the old toolchain APIs still evaluate, and two otherwise identical shells differing only in an extra development tool preserve production/runtime derivation identities.

### Milestone 3: Validate one real consumer through the retained contract


Choose the smallest already adopted runtime consumer from the delivered plan 16/consumer evidence, initially `mori://shinzui/mori` if its retained runtime adoption is complete. Resolve its checkout with Mori; project-relative `flake.module.nix` and `nix/haskell-overlay.nix` are file-level references pending. Use an isolated checkout or unmanaged module edit, respecting its local instructions. Select its existing runtime generation/configuration and toolchain pins unchanged, and add an opt-in `devShells.<system>.runtime` using this helper. Preserve its current default shell until acceptance.

Obtain the fresh Cabal plan through the existing retained runtime constraints/source projection with supported test and benchmark configurations. Compare source/metadata/flags and declared exceptions using plan 9's comparator, and build the actual production package from the same composed scope. The shell can expose Nix-built libraries without making Cabal unit IDs identical; verify declared selection parity and actual Nix dependency identities as separate facts. Do not force a broad dependency update to resolve an application conflict.

Run Apple Silicon and x86 Linux native probes. Change an extra shell tool, a shell hook, and inherited shell metadata separately: each changes the shell as appropriate while runtime package derivations remain unchanged. A real project-owned package edit affects that package and its dependents, retaining unrelated runtime inputs. An explicit runtime flag/source change requires a new configuration/generation or is rejected. Record first entry and warm re-entry time, substituted bytes and any compiler/runtime/HLS builds. A shell-only edit must reuse existing compiler/runtime/HLS outputs when present, and a fresh worker must use available published outputs. Also measure a representative Cabal source edit separately: Nix-built package exposure does not prove Cabal avoided compilation. M3 passes after a real consumer builds and works in the candidate shell with truthful dependency evidence, and negative ownership/compiler fixtures still fail. This plan claims easier consistent development; claim speed only for separately measured paths.

### Milestone 4: Document the optional adoption path


Update `docs/user/consumer-integration.md`, `docs/user/package-sets.md`, and an adoption guide under `docs/guides/`, maintaining their reserved logs/profile checks. Show explicit runtime and application selection, native libraries, shell-only tools, inherited environments, optional HLS, and local input override verification. In `mori://shinzui/haskell-nix-dev`, update project-relative `README.md` (file-level URI pending) with the generic helper; preserve bare toolchain examples and its current `mkDevShell` contract.

Do not modify generated Seihou templates as a side effect. The opt-in consumer implementation uses unmanaged files; a future template update can be separately scoped if requested. Add the next unused filesystem ADR for project shells derived from retained scopes, after scanning `docs/adr/`; plan 19 may have allocated ADR 8 already. Record no second compiler on PATH, independent HLS closure, exact runtime ownership, and Cabal/Nix evidence limits. M4 passes when copyable examples evaluate, the legacy consumer fixture remains compatible, and both repositories' documentation/format checks succeed.

## Concrete Steps


Resolve checkout paths before executing cross-project commands:

```bash
mori registry show shinzui/haskell-nix --full
mori registry show shinzui/haskell-nix-dev --full
mori registry show shinzui/mori --full
```

From this repository, after implementing the new check outputs:

```bash
nix build --no-link --print-build-logs .#checks.aarch64-darwin.project-shell
nix build --no-link --print-build-logs .#checks.aarch64-darwin.project-shell-identity
nix flake check --print-build-logs
just check-docs
nix fmt -- --ci
```

From the selected consumer checkout, use its new opt-in shell:

```bash
nix develop .#runtime -c ghc --numeric-version
nix develop .#runtime -c ghc-pkg list
nix develop .#runtime -c cabal build all --offline --dry-run
nix build --no-link --print-build-logs .#default
```

The plan command uses the accepted retained constraints/project configuration, not an unconstrained default solve. Run plan 9's delivered `cohort-compare` on that fresh plan and the actual executable manifest. Expected observations are the retained compiler version, selected fixture/runtime dependencies, native library visibility, and no undeclared source/metadata/flag drift. A mismatched compiler or application override must fail before a shell is produced. Run the equivalent native x86 Linux checks and record both input revisions. These are future acceptance commands, not completed probes.

## Validation and Acceptance


Positive fixtures demonstrate a selected non-stock Haskell dependency, native pkg-config library, inherited shell input, one-time shell hook, and optional HLS. Negative fixtures cover a second compiler, wrong system/nixpkgs identity, unavailable explicitly requested HLS, missing complementary selections, and application shadowing of a runtime-owned recipe. Compare compiler identity beneath wrappers and retain the actual selected package graph; do not prove compatibility with version strings alone.

Two shells differing only in shell tools/hooks retain identical production/runtime dependency derivations. The generic helper introduces no `haskell-nix` input in the toolchain flake and does not replace legacy `mkDevShell`. The real consumer's Nix executable uses the same selected scope, while its fresh Cabal plan agrees with declared retained constraints/source policy and documented exceptions. Both production systems must have native behavioral evidence. No global pin update or generated template rewrite is necessary to finish.

## Idempotence and Recovery


Fixtures and opt-in shells are additive. Use isolated consumer checkouts or local input overrides with `--no-write-lock-file` until verification; keep unrelated working-tree edits. Retain the old default shell and restore it if the candidate fails. Cabal probes use temporary build/cache directories or the consumer's ordinary writable development area, never production databases. New shell options do not mutate runtime generations. Repeating a shell build must preserve dependency identities. Failed compiler/source/ownership validation leaves accepted runtime records untouched.

## Interfaces and Dependencies


The hard activation prerequisites are plan 16's explicit retained-runtime factory/ownership contract and the policy/capabilities delivered by `mori://shinzui/haskell-nix-dev/plans/4-publish-compiler-capabilities-and-an-explicit-platform-support-matrix` for production use. This plan owns the generic `mkProjectShell` extension in the toolchain project, channel `mkProjectDevShell` wrapper, native/identity fixtures, one optional consumer adoption, and guides. It must adapt to the delivered runtime factory, not change that factory's ownership or complete-selection semantics.

The generic helper receives a caller's scope and owned package function while choosing compatible existing tooling from its per-system environment. The channel wrapper constructs the exact runtime/application scope before invoking it and exports selection diagnostics in passthru. Plan 9 owns solver/manifest/parity tools, plan 16 owns runtime identity, and the separate behavioral toolchain plan owns its CI evidence. No new solver, runtime lock, compiler pin, cache publisher, or HLS dependency set is introduced here.

## Revision Notes


2026-10-14: Created from the Horizon comparison, reconciled existing cohort/runtime ownership, and checked native plan structure, canonical references, milestones, and intention bindings. This records planning, not implementation or independent review.

2026-10-14: Added umbrella membership and scoped Mori opt-in while preserving implementation boundaries and existing prerequisites.

2026-10-16: Reconciled the implemented runtime constructor and its real arguments, retained the unverified foreign capability gate, and added shell first-use/re-entry and Cabal reuse evidence without promising compiler speedups.
