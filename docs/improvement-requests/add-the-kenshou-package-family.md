---
type: Improvement Request
title: Add the kenshou package family
description: Add the nine packages of the first kenshou release to the shared first-party Haskell registry so consumers can select a managed Git or Hackage source.
requestId: IR-6
status: proposed
origin: mori://shinzui/kenshou/plans/7-publish-the-first-kenshou-release-and-prepare-the-consumer-adoption-path
generated:
  by: codex-cli/gpt-6.2-sol
  at: "2026-11-20T19:50:18Z"
reviews:
  - kind: model
    reviewer: codex-cli
    reviewed_at: "2026-11-20T19:50:18Z"
    document_timestamp: "2026-11-20T19:50:18Z"
    scope: content-and-metadata
    outcome: approved
    context: Author review against the release plan, nine Hackage candidates and installed Git pin, and the documented singleton-family workflow.
    provider: openai
    model: gpt-6.2-sol
    effort: high
---

# Add the kenshou package family

`mori://shinzui/kenshou` supplies the verification harness used by
`mori://shinzui/keiro-runtime-kenshou`. The consumer pins eight packages at one
Git revision and is preparing to switch to the published Hackage sources.

Once `v0.1.0.0` is published, add family `kenshou` using Mori project
`mori://shinzui/kenshou`, GitHub repository `shinzui/kenshou`, and the non-flake
GitHub input `kenshou-src`. Include all nine packages.

- `kenshou-core`
- `kenshou-measure`
- `kenshou-check`
- `kenshou-diagnose`
- `kenshou-telemetry`
- `kenshou-remote`
- `kenshou-evidence`
- `kenshou-cli`
- `kenshou-synthetic`

Use the [singleton family migration](../user/updating-first-party-packages.md#add-singleton-families-explicitly).
Acceptance is a validated catalog and lock with the new singleton family and nine
`0.1.0.0` Hackage pins, with the existing snapshots preserved. The originating
[release plan](mori://shinzui/kenshou/plans/7-publish-the-first-kenshou-release-and-prepare-the-consumer-adoption-path)
records publication and the consumer handoff.
