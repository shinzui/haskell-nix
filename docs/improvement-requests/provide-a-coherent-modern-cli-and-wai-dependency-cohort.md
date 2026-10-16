---
type: Improvement Request
title: Provide a coherent modern CLI and WAI dependency cohort
description: Add the mutually compatible Hackage releases needed by Hurl Workbench to
  the shared GHC 9.12/9.14 package-set extension, so consumers do not duplicate a
  fixed-hash override graph for current generic-lens and WAI/Warp APIs.
generated:
  by: openai-codex/gpt-6.1-sol
  at: "2026-10-16T18:54:57Z"
origin: mori://shinzui/hurl-workbench/plans/6-harden-document-and-package-the-workbench
requestId: IR-2
status: completed
completedAt: "2026-10-16T18:55:14Z"
resolution: >-
  The generated channel supplies the complete CLI/WAI cohort on both compilers
  and source channels. Published Seihou 0.31.0 supplies the managed pin;
  mori://shinzui/hurl-workbench commit 5f2cff2 removes eleven duplicate pins and
  passes its default Nix build and full native release gate.
reviews:
  - kind: model
    reviewer: openai-codex
    reviewed_at: "2026-09-21T04:27:41Z"
    document_timestamp: "2026-09-21T04:27:41Z"
    scope: content-and-metadata
    outcome: approved
    context: >-
      Reviewed against the successful Hurl Workbench macOS Nix build, the locked
      haskell-nix extension's evaluated versions, Hackage metadata, upstream release
      tags where published, and the checked-in improvement-request profile.
    provider: openai
    model: gpt-5
    effort: high
---

# Improvement Request: Provide a coherent modern CLI and WAI dependency cohort

## Status

- **Status:** completed
- **Origin:**
  `mori://shinzui/hurl-workbench/plans/6-harden-document-and-package-the-workbench`
  (the artifact-level URI is intended; current Mori plan resolution may require a
  refreshed registry)
- **Owner of the package set:** `mori://shinzui/haskell-nix`
- **Size:** medium — nine Hackage pins forming two tested dependency cohorts
- **Planning:** [ExecPlan 9](../plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md) under MasterPlan 3

## Implementation progress (2026-10-16)

The generated cohort now supplies this compatibility set instead of adding manual Hackage
pins to the policy registry. Both source channels evaluate all eleven requested package
names at the requested versions or newer compatible patch releases under GHC 9.12.4 and
9.14.1; HTTP/2 is 5.4.8. Receipt: `/tmp/mp3-ep9-ir2-evaluated-versions.json`. The complete
GHC 9.12 cohort builds and its 556 cache paths substitute into an empty isolated Darwin
store with zero builds. The full native compiler/channel matrix now passes.

The prepared change for `mori://shinzui/hurl-workbench/repos/hurl-workbench`, project-relative
`flake.module.nix` (source-file artifact URI pending), removes all eleven duplicate pins and
composes the shared extension before its two local packages. Its default Nix build and full
`just check` pass in an isolated checkout against immutable local channel commit
`aa45d216c0601e41757329bdd416708adcf34df8`: 65 core and 33 CLI tests, schema checks, examples,
the 100-case smoke, unpacked source distributions and Nix checks. Receipts:
`/tmp/mp3-ep9-hurl-review-build.log`, `/tmp/mp3-ep9-hurl-review-full-check.log`; module patch:
`/tmp/mp3-ep9-hurl-shared-extension.patch`.

Acceptance is complete: `mori://shinzui/seihou-modules/templates/nix-haskell-flake` 0.31.0 is published at commit `cc1b70c`, retaining the existing toolchain/nixpkgs inputs and pinning channel `58a2c26`. The primary consumer adopted it through Seihou at commit `5f2cff2` in `mori://shinzui/hurl-workbench`, removed all eleven Hackage replacements and passed its default Nix build and complete native `just check` (65 core tests, 33 CLI tests, schemas, examples, 100-case smoke, unpacked sdists and flake checks). Both commits are pushed. Receipts: `/tmp/mp3-ep9-hurl-adoption-build.log` and `/tmp/mp3-ep9-hurl-adoption-full-check.log`. EP-9 retains its separate Linux and fresh-CI cache gates. The
original proposal and observations below describe the request's starting point.

## Problem

Hurl Workbench uses the GHC 9.12.4 package set pinned through the shared Nix toolchain. Its
released Cabal bounds require Aeson 2.2.5.1, generic-lens 2.3, optparse-applicative 0.19,
WAI 3.2.5, and Warp 3.4.16. The current `haskell-nix` extension already supplies
optparse-applicative 0.19.0.0, but the rest of the package set remains behind those bounds.

Enabling the shared extension therefore does not make this consumer buildable. Hurl Workbench
must duplicate fixed-output Hackage pins in its local `flake.module.nix`, including the
transitive cohort required to keep Warp internally consistent. That duplicates policy which
belongs in the version-scoped shared package registry and makes the next consumer rediscover the
same dependency graph.

## Evidence

Evaluating the current extension at the revision locked by Hurl Workbench produced:

| Package | Shared set | Required and built |
|---|---:|---:|
| `aeson` | 2.2.4.1 | 2.2.5.1 |
| `generic-lens-core` | 2.2.1.0 | 2.3.0.0 |
| `generic-lens` | 2.2.2.0 | 2.3.0.0 |
| `optparse-applicative` | 0.19.0.0 | 0.19.0.0 |
| `wai` | 3.2.4 | 3.2.5 |
| `warp` | 3.4.9 | 3.4.16 |
| `http2` | 5.3.10 | 5.4.4 |
| `http-semantics` | 0.3.0 | 0.4.1 |
| `time-manager` | 0.2.4 | 0.3.2 |
| `recv` | 0.1.1 | 0.1.2 |
| `network` | 3.2.8.0 | 3.2.9.0 |

The direct upgrades are not independent. Warp 3.4.16 requires WAI 3.2.5, HTTP/2 5.4,
HTTP Semantics 0.4, and recv 0.1.2. HTTP/2 5.4 requires time-manager 0.3, while recv 0.1.2
requires network 3.2.9. The Nix build exposed each incompatibility at Cabal configure time
until the entire cohort was present.

The final fixed-hash graph built `packages.aarch64-darwin.default`, passed `nix flake check`,
and passed the consumer's full `nix develop --accept-flake-config -c just check`: 65 core
tests, 33 CLI tests, live Hurl 8.0.1 examples, the 100-case concurrency smoke, and unpacked
source-distribution builds. The consumer-local hashes and exact graph remain available in
`mori://shinzui/hurl-workbench/repos/hurl-workbench`, project-relative
`flake.module.nix`; artifact-level source-file URIs are not yet defined.

## Proposal

Add fixed-output, `dontCheck` Hackage replacements to the common compatibility registry for:

- Aeson 2.2.5.1;
- generic-lens-core and generic-lens 2.3.0.0;
- WAI 3.2.5 and Warp 3.4.16;
- HTTP/2 5.4.4, HTTP Semantics 0.4.1, time-manager 0.3.2, recv 0.1.2, and network 3.2.9.0.

Keep the existing optparse-applicative 0.19.0.0 replacement. Treat the WAI/Warp entries as
one compatibility cohort in implementation and review even if each remains a separate registry
attribute: partial upgrades are known to be non-buildable.

Aeson must remain below 2.3 because Dhall 1.42.3 caps it there. Version 2.2.5.1 is the newest
release satisfying both Hurl Workbench's lower bound and Dhall's upper bound. The other versions
are the newest releases within the consumer's declared major/minor ranges at the time of this
request.

## Acceptance

1. Both shared source channels evaluate the new registry entries under every supported GHC.
2. Focused builds prove Aeson/generic-lens and the complete WAI/Warp cohort, not only overlay
   evaluation.
3. Existing first-party package-set checks remain green, with any incompatible fleet consumer
   identified before the default extension advances.
4. Hurl Workbench composes the shared extension, deletes these duplicate Hackage replacements
   from its local module, and still passes its default Nix build and full `just check` gate.
5. User documentation calls out the cohort and the reason its transitive releases move together.

## Scope boundary

This request does not ask `haskell-nix` to infer Cabal bounds or to become a general package
solver. It records a concrete, tested compatibility set for the GHC versions the repository
already supports.

It also does not cover the generated single-root `callCabal2nix` assumption found in the same
consumer. That behavior is owned by the Seihou `nix-haskell-flake` template at
`mori://shinzui/seihou-modules`; Hurl Workbench resolved it through the template's supported
`nix.builtin-package = false` configuration and a project-local multi-package output.
