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
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-17T15:27:45Z
      mode: "implement"
      note: "Reconcile accepted DEV-4 capability prerequisite and qualified Apple Linux executor before production shell implementation."
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

Complete (2026-10-17). DEV-4's whole-child prerequisite is accepted. The generic helper is delivered in `mori://shinzui/haskell-nix-dev` at `cb005e5b049b6b43be3cf473afb99409e508e800`; the optional unmanaged consumer module is committed in `mori://shinzui/mori` at `ab5c11278c0bc7ce2597e2b44209148561548c56`. Channel/toolchain/consumer pins and the old default shells stay unchanged. Old input pins retain their existing outputs; the new optional consumer shell is exercised with matching local input overrides.

[Final consumer receipt](../evidence/ep20/mori-project-shell.json) supersedes the historical partial handoff. Apple Silicon and the user-selected translated x86 Linux Apple guest pass normal production CLI execution, source-complete Cabal comparison for 392 non-local dependencies, actual executable-manifest comparison for 340 frozen Haskell instances, 79 owned-package tests and a private implementation edit/test rerun. Three shell-only variants preserve all 311 runtime identities, five owned recipes and independent HLS; the owned-source probe invalidates only the expected application dependents. First/warm entry, substitutions and Cabal edit costs are retained separately without claiming a speedup. An empty Linux worker substitutes 907 existing published compiler/runtime/HLS paths with zero builds (1.383 GB archive payload, 10.154 GB NAR bytes). Both full platform flake checks pass; final literal-PATH/HLS fixtures, 25 generic contracts, 295 pure channel contracts, 37 native manifest tests per system, documentation profiles and formatting pass. All EP-20 runs are terminal; no live validation handoff remains.

- [x] (2026-10-17) M1: Prototype one-scope shell construction with native and shell-input fixtures; public two-system coverage retains the selected/wrong dependency and offline Cabal checks.
- [x] (2026-10-17) M2: Add generic toolchain helper and guarded channel/runtime wrapper; preserve exact legacy outputs and runtime identities.
- [x] (2026-10-17) M3: Validate real consumer shell/build/plan/manifest consistency, source edits and shared-output reuse on both declared execution systems, with explicit translation/cache qualifications.
- [x] (2026-10-17) M4: Publish copyable optional adoption guidance, preserve legacy consumers, pass documentation/format checks and distill ADR 9.

## Surprises & Discoveries

2026-10-17 final integration: lazy fetchTree aliases for the same Baikai source compare unequal as raw strings on the host, although JSON serialization resolves both to the exact same path/NAR. Executable-manifest guards now reuse the existing metadata-only source projection; it is never built or added to production inputs. Different repositories/subdirectories still fail, and all 37 native manifest regressions pass per system. Linux retains the exact pre-fix actual-manifest derivation; both real 340-instance comparisons pass. Ordinary scoped Cabal plans omit hashes for installed non-boot packages, so separate fresh same-compiler bare solves provide the source/metadata/flag evidence. A new guest also requires a Cabal index; initializing it preserved all retained project selections. Large streamed container I/O stalled; bounded transfers and guest-file logs produced terminal successful reruns. Neither interrupted attempts nor translated timings establish physical-x86 performance.

2026-10-17 real-consumer follow-up: HLS-enabled Mori entry found a transitive bare GHC before the scoped wrapper. The wrapper database contained retained libraries, but ordinary `ghc-pkg` selected the bare database. Normalize PATH after inherited hooks and before the caller hook while keeping HLS/compiler recipes unchanged. The public native fixture now defaults to available HLS and asserts ordinary compiler/database resolution and no bare compiler bin; it passes on Apple Silicon and the translated Linux guest, alongside all 25/295 contracts and retained identity checks. [Regression receipt](../evidence/ep20/hls-enabled-shell-entry.json). This corrects a case the original HLS-disabled M2 native fixture did not exercise.

2026-10-17 constructor delivery: equal Nixpkgs revision/NAR inputs can have different materialized path aliases. Verify declared package-set version/system plus operative native/compiler/tool identities rather than rejecting equivalent inputs by path strings. Nix derivation-path observations carry output contexts; strip contexts from diagnostic JSON so an identity-only check does not build the observed production/runtime packages. The real retained check now has only its shell builder as direct build input. Old toolchain pins lack the additive API, so local integration checks are conditional on its presence and are exercised with an explicit override; default consumers retain their current locks and outputs.


The native prototype passes. The pinned stdenv flattens `env` variables into derivation attributes, and `inputsFrom` does not preserve those arbitrary variables. Forward the scoped `NIX_GHC*` and locale values explicitly. Inherited native tools select development outputs, so compare derivation identity rather than entire multi-output values. No speed measurement is claimed. The existing toolchain helper only exposes extra native inputs and a shell hook; the retained runtime factory is now delivered under plan 16. The user restored the foreign DEV-4 plan and it is pulled locally; policy/capability fixtures pass on Apple Silicon, and its native Linux acceptance subsequently passed in the user-selected Apple guest. Mori discovery remains unavailable.

## Decision Log

2026-10-17: Bind the generic helper's compiler cell by actual supplied-scope compiler identity, validate its operative pinned native universe, and reject extra/inherited bare or wrapped compilers. The channel wrapper constructs and audits the retained scope once, exposes it for production, and attaches context-free diagnostic identities. Keep legacy APIs/locks and the dependency direction unchanged. See ADR 9 for the durable contract.


2026-10-16: Consume the delivered retained runtime API with explicit selection mapping and checked scope reuse. Keep DEV-4 production activation gated until its actual contract is available; record shell startup/reuse evidence separately from application compilation improvements.

2026-10-14: Coordinate this workstream under [MasterPlan 4](../masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md). Scoped Mori publication records its production prerequisites and integration relationships; initial fixture work remains independent. Existing generator/runtime ownership and this plan's acceptance remain unchanged.


2026-10-14: Keep the dependency direction acyclic. The toolchain flake accepts a caller-supplied Haskell scope through a generic helper and gains no input on this repository. The channel owns runtime selection and conflict validation.

2026-10-14: Use the selected Haskell scope's `shellFor` environment rather than placing a second bare compiler alongside its compiler wrapper. HLS keeps its independently built dependency scope; changing runtime libraries must not rebuild the editor backend.

2026-10-14: Preserve `mkDevShell` and its existing unavailable-HLS behavior. The new project helper rejects an explicit `withHls = true` request when that cell has no HLS, and defaults to the declared availability. This makes new API requirements clear without breaking existing generated flakes.

2026-10-14: Require an explicit retained runtime/configuration and complete complementary application selections. Do not fill missing application groups from the mutable default or convert this into a workspace-wide pin update.

## Outcomes & Retrospective


All four milestones are accepted. One audited retained scope now supplies production and development, with explicit compiler/configuration/complement checks, stable shared recipes, independent HLS, correct scoped compiler precedence and native input/hook behavior. The optional Mori adoption preserves its default shell and pins and is available through matching input overrides. The final receipt retains two-system real production/Cabal/graph/test evidence, separate entry/edit costs and empty-worker substitution. [The adoption guide](../guides/develop-against-a-retained-runtime.md) and [ADR 9](../adr/9-build-project-shells-from-the-checked-retained-scope.md) record the durable contract. No template, runtime generation, solver, publisher or HLS dependency set was replaced. This is a consistency/maintenance result; HLS protocol behavior, the broader toolchain matrix and the MasterPlan's performance outcomes remain with their owning plans.

## Context and Orientation


`flake.nix` selects shared toolchain inputs through `haskell-nix-dev`, imports a common patch registry, and exposes `lib.mkFirstPartyPackageSet`. `lib/mkFirstPartyPackageSet.nix` composes selected first-party families with common compatibility policy in one Haskell scope. The flake now also exports `lib.mkRuntimePackageSet` from `lib/mkRuntimePackageSet.nix`. `docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md` owns that factory, including runtime name/generation/configuration, exact source policy, complete application complement, and conflict validation. Plan 16 is Complete locally, with generation-1/2 fingerprint-bound support evidence under `cabal/runtime-cache/keiro-runtime/`. Use its delivered factory and returned scope; do not implement an alternative runtime selector here. The factory accepts `runtime`, `generation`, `applicationSelections`, `channel`, `disableProfiling`, `disableHaddock`, and optional `applicationCohort`/`applicationRegistry`; it returns `mkApplicationScope`, `validateApplicationScope`, and `mkApplicationManifest`. Its compiler is currently fixed to the retained GHC 9.12.4 configuration. Map the proposed shell selection's `name` to `runtime` and validate its `configuration` against the retained record, translating supported build options explicitly. Do not pass a fictional free-form configuration argument or silently substitute the current default compiler.

A Haskell scope is the recursive package set in which dependency names resolve to one selected package instance. Nixpkgs `shellFor` derives a compiler package environment and development dependencies from packages in that scope. An `inputsFrom` shell inherits build dependencies from another derivation; extra native inputs are programs running on the development machine, while extra build inputs are libraries/header/pkg-config providers used by the project. A shell hook is code executed when entering the shell. These distinctions matter for PostgreSQL, OpenSSL, zlib, and other native libraries.

In `mori://shinzui/haskell-nix-dev`, project-relative `flake.nix` (file-level URI pending), `mkDevShell` currently takes `ghc`, `extraNativeBuildInputs`, `withHls`, and `shellHook`. It puts the bare compiler, Cabal, pkg-config, zlib, and optional HLS on PATH. It does not accept a project scope, library inputs, or inherited shell environments. The additive generic helper now lives there and consumes its existing toolchain records and the accepted capability contract from the canonical prerequisite plan URI. The channel already demonstrates `shellFor` in its updater dev shell, but that shell is its independent bootstrap scope, not a consumer runtime.

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

From the selected consumer checkout, use the opt-in shell with matching local inputs while preserving the current lock:

```bash
channel_checkout=/path/to/haskell-nix
toolchain_checkout=/path/to/haskell-nix-dev
override_inputs=(--override-input haskell-nix "path:$channel_checkout"
  --override-input haskell-nix/haskell-nix-dev "path:$toolchain_checkout"
  --no-write-lock-file)
nix develop .#runtime "${override_inputs[@]}" -c ghc --numeric-version
nix develop .#runtime "${override_inputs[@]}" -c ghc-pkg list
nix build --no-link --print-build-logs .#default "${override_inputs[@]}"
```

The completed commands and exact inputs are retained in the final receipt. Follow the adoption guide for the separate same-compiler bare Cabal solve: installed non-boot rows in a normal scoped plan cannot prove source hashes. Plan 9's delivered comparator verifies that source-complete plan and the actual Nix executable manifest independently. Compiler/ownership mismatches still fail before shell realization; Linux execution retains the Apple-translation qualification.

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
