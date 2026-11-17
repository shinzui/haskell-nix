---
type: Improvement Request
title: Document the application complement for retained Keiro HTTP services
description: Give HTTP service consumers a checked way to combine the published application dependencies with generation 9 while retaining every runtime-owned derivation.
requestId: IR-4
status: proposed
origin: mori://tan/tan-app-infrastructure/okf/friction-log/concepts/FRIC-12
generated:
  by: codex-cli/gpt-6.2-astra
  at: "2026-11-17T19:44:23Z"
reviews:
  - kind: model
    reviewer: codex (author self-review)
    reviewed_at: "2026-11-17T19:44:23Z"
    document_timestamp: "2026-11-17T19:44:23Z"
    scope: technical-accuracy
    outcome: approved
    effort: unspecified
    provider: openai
    model: gpt-6.2-astra
    context: Checked the missing recipe, service bounds and successful native build with the application complement.
---

# Document the application complement for retained Keiro HTTP services

At revision 7d874f6, generation 9 with its documented complementary group selections
can evaluate the Keiro runtime. A service using servant-health 0.1.0.0 encounters
`attribute 'servant-health' missing` when it builds the server. Supplying that one recipe
still leaves hasql-dynamic-statements on the base package set's 0.3 series when the
application requires 0.5.1.2.

Document or expose a supported composition of the published application recipes with the
generation's owned records. A small HTTP consumer should build on the Hackage channel,
select servant-health and hasql-dynamic-statements at the declared versions, and pass
the existing runtime derivation identity check. Show where a consumer supplies its own
immutable instrumentation source. This request leaves historical generation records intact.
