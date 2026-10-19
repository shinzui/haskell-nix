---
type: Improvement Request
title: Provide a targeted Rei cohort for Kioku 0.10 and the Store error fix
description: Supply a generated Cabal and Nix cohort for released Kioku 0.10.0.0 and, once published, the structured Store error fix, without consumer-local source overrides or unrelated toolchain upgrades.
requestId: IR-3
status: proposed
origin: mori://shinzui/rei/masterplans/29-close-rei-cli-and-http-api-gaps-on-the-haskell-jitsurei-contract
generated:
  by: openai/gpt-6.1-sol
  at: "2026-10-19T22:55:57Z"
timestamp: "2026-10-19T22:55:57Z"
reviews:
  - kind: model
    reviewer: "codex (author self-review)"
    reviewed_at: "2026-10-19T22:58:18Z"
    document_timestamp: "2026-10-19T22:55:57Z"
    scope: technical-accuracy
    outcome: approved
    provider: openai
    model: gpt-6.1-sol
    effort: unspecified
    context: >-
      Checked the request against published Kioku 0.10.0.0 source and tags,
      current published Store versions and the selected cohort where relevant.
      This author self-review approves request accuracy only; it does not
      approve implementation, dependency adoption or publication.

---

# Provide a targeted Rei cohort for Kioku 0.10 and the Store error fix

## Consumer and verified gap

Rei's remaining Session, Memory and Today work is tracked by
`mori://shinzui/rei/plans/255-expose-agent-execution-sessions-memory-schedules-and-review-workflows`
and
`mori://shinzui/rei/plans/254-expose-saved-views-collections-dashboards-and-bounded-reporting-apis`.

Kioku 0.10.0.0 is published. Its bounded reads enforce `MemoryRead`, use the
flat `BoundedReadError`, and type the Session status filter. The published
`kioku-core` source archive and upstream tag were verified on 2026-10-19.
The package owner is `mori://shinzui/kioku`; its tag `v0.10.0.0` points to
commit `5f4afc872b09d615d1bb8c78369d6912161c550f`
(commit/tag artifact URIs pending).

The current `cabal/cohort.freeze` still selects Kioku API/Core/Migrations
0.9.0.2 and Store 0.11.0.0. Rei's retained runtime also fixes Store 0.11.0.0.
Merely raising the application's bounds cannot override those exact selections.
In `mori://shinzui/rei`, the selectors are project-relative `cabal.project`,
`cabal/runtime/keiro-runtime/1/cohort.freeze` and `flake.lock`
(source-artifact URIs pending).

The Store behavior needed by Rei is requested separately in
`mori://shinzui/kiroku/okf/improvement-requests/concepts/IR-19`.
It has no supported published successor at this request's verification date.
Further Kioku Memory APIs are requested in
`mori://shinzui/kioku/okf/improvement-requests/concepts/IR-6`
and
`mori://shinzui/kioku/okf/improvement-requests/concepts/IR-7`.
Their versions must be selected only after owner publication, not guessed now.

## Requested behavior

Use the existing targeted shared-cohort workflow to admit the published Kioku
0.10.0.0 family while keeping unrelated package, compiler and toolchain choices
fixed. Report any necessary transitive unlock before expanding scope.

When the Store fix is published, supply a compatible generated selection and a
new retained runtime generation if its runtime-owned inputs changed. Preserve
historical runtime generations. The Kioku-only update need not wait for an
unpublished Store or future Memory API release.

Provide immutable Cabal imports and matching Nix selectors with a consumer
migration procedure. Use the existing updater and runtime snapshot tooling;
do not hand-edit generated locks, insert local source paths, replace the
retained runtime with a look-alike graph, or update the compiler as a shortcut.

## Acceptance

1. A fresh consumer resolves published Kioku 0.10.0.0 using the generated cohort
   with no private dependency checkout or new `allow-newer` workaround.
2. Cabal and Nix select compatible versions and sources. The existing parity
   checks and focused consumer build pass; report the actual supported systems.
3. The targeted impact report accounts for transitive unlocks and retains
   unrelated pins. Any runtime generation change is justified by changed inputs.
4. Once IR-19 has a published fix, the selected Store release retains structured
   permanent versus retryable failures through its public API.
5. Publish the immutable channel/runtime artifacts and the relevant supported
   cache evidence before Rei changes its managed selectors.

This request does not authorize implementation, a broad family refresh,
dependency publication or application deployment.
