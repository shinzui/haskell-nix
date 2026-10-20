---
type: Improvement Request
title: Provide a targeted Rei cohort for Kioku 0.11 and the Store error fix
description: Supply a generated Cabal and Nix cohort for published Kioku 0.11.0.0 and Store 0.11.0.1 without consumer-local source overrides or unrelated toolchain upgrades.
requestId: IR-3
status: completed
completedAt: "2026-10-20T04:15:10Z"
resolution: >-
  Generated the targeted published Kioku/Store/Metrics cohort and retained runtime
  generation 5, preserving 458 unrelated source identities and all historical
  snapshots. Native/Linux frozen parity and verifier builds pass; all 882 Darwin
  and 884 Linux dependency paths publish and substitute into empty stores with
  zero builds. Consumer selector adoption remains the consumer responsibility.
origin: mori://shinzui/rei/masterplans/29-close-rei-cli-and-http-api-gaps-on-the-haskell-jitsurei-contract
generated:
  by: openai/gpt-6.1-sol
  at: "2026-10-19T22:55:57Z"
timestamp: "2026-10-20T04:15:10Z"
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

# Provide a targeted Rei cohort for Kioku 0.11 and the Store error fix

## Consumer and requested behavior

Rei needs published bounded Session/Memory reads and truthful archive receipts
for `mori://shinzui/rei/plans/255-expose-agent-execution-sessions-memory-schedules-and-review-workflows`
and Today composition in
`mori://shinzui/rei/plans/254-expose-saved-views-collections-dashboards-and-bounded-reporting-apis`.
Its former generated cohort selects Kioku API/Core/Migrations 0.9.0.2 and Store
0.11.0.0; increasing application bounds cannot override these exact selections.

The original request named Kioku 0.10.0.0. The user subsequently released Kioku
0.11.0.0 and Kiroku Store 0.11.0.1, then explicitly authorized this implementation.
Hackage preferred-version records, source archives and upstream tags were checked.
Kioku supplies
`mori://shinzui/kioku/okf/improvement-requests/concepts/IR-6` and
`mori://shinzui/kioku/okf/improvement-requests/concepts/IR-7`;
Store supplies `mori://shinzui/kiroku/okf/improvement-requests/concepts/IR-19`.
No dependency source implementation or package release is part of this request.

Use the existing targeted updater and retained-runtime tooling. Preserve unrelated
package identities, compiler/toolchain choices and historical generations. Report
necessary unlocks before expanding scope. Publish immutable Cabal/Nix projections
and matching cache evidence before Rei changes its managed selectors. Do not use
consumer-local source overrides, hand-edited generated locks or new allow-newer.

## Delivered candidate

The scoped family refresh appends Kioku family/group generation 9 and Kiroku
family/group generation 4. All 55 previous family and 50 previous group snapshots
remain intact. Only those two source inputs move; their latest source commits
differ from the owner release commits only in documentation/evidence.

The combined solve advances the explicit index cutoff to
2026-10-20T01:31:03Z. Exactly seven of 465 source records change:

- Kioku API/Core/Migrations 0.9.0.2 to 0.11.0.0.
- Kiroku Store 0.11.0.0 to 0.11.0.1 and Metrics 0.3.0.0 to 0.3.0.1.
- crypton-connection 0.4.6 metadata revision 1 to 2, widening two X509 bounds
  from <1.10 to <1.11.
- streamly 0.11.1 metadata revision 1 to 2, widening streamly-core from
  <0.3.2 to <0.3.3.

The two metadata-only unlocks were reported and compared against the exact
previous Cabal hashes before promotion. Their source archives, versions, flags
and dependency names do not change. The other 458 complete source records are
identical; see [identity evidence](../evidence/ir3/dependency-identity-retention.json).
The 370 generated recipes are fresh and the freeze-only solve agrees exactly.

Retained runtime generation 5 owns 311 packages and has fingerprint
`dcfc3bd361804e14cb85a004b57792376da3282c09f7798cf630068e9cb968d1`.
Generations 1–4 are unchanged. Its four recipe contexts use the new cutoff;
the captured base64 recipe functions themselves are unchanged. The existing
verifier's exact Store/Metrics bounds are adapted only for generation 5 through
a fixture patch, without changing its owning repository.

## Validation and acceptance

The normal family refresh, five-generation runtime check, targeted cohort check,
365 pure Nix contracts, full native flake evaluation (119 outputs), current
generated/first-party freshness checks, and all
four generated-recipe checks pass. GHC remains 9.12.4 with profiling and Haddock
disabled. Native GitHub and Hackage frozen parity and verifier builds pass.
Eight distinct disposable PostgreSQL/queue/Kafka scenarios pass on both source
channels; [GitHub receipt](../evidence/ir3/integration-aarch64-darwin-github/receipt.json)
and [Hackage receipt](../evidence/ir3/integration-aarch64-darwin-hackage/receipt.json)
retain the actual results. They are eight scenarios across two configurations.

The native dependency cohort and both runtime closures are published to the
existing cache. An empty aarch64-darwin store substitutes all 882 paths with zero
builds; see [publication](../evidence/ir3/aarch64-darwin-publication.json) and
[substitution](../evidence/ir3/aarch64-darwin-substitution.json). This publication
contains dependencies, not a work-in-progress Rei executable.

The actual Rei Core/CLI/API compile against the published Hackage releases.
A separate Nix consumer uses generation 5 and Kioku 9 through the public
constructor; its real CLI and the HTTP handlers pass the same two AgentData
cases against disposable PostgreSQL. Final Rei acceptance still belongs to the
consumer after immutable selector adoption.

Both Linux frozen parity checks and both verifier builds pass; see the
[realized output evidence](../evidence/ir3/x86_64-linux-builds.json). Its dependency
cohort and two runtime closures are published and remotely verified, and all 884
paths substitute into an empty store with zero builds; see
[publication](../evidence/ir3/x86_64-linux-publication.json) and
[substitution](../evidence/ir3/x86_64-linux-substitution.json). Linux uses the
existing x86_64-linux Apple container with translated execution. This is
functional evidence, not physical-x86 performance or CI-worker acceptance.
Broad runtime support remains unverified; previous generations' support receipts
are never copied to the new fingerprint.

## Consumer migration

After this change is published, materialize generation 5's GitHub Cabal imports
with `scripts/runtime-import.py --revision <full-commit> --generation 5
--channel github --destination <new-retained-directory>`. Update the shared
cohort import, flake input/lock and runtime selection together. Select Kioku
application generation 9; preserve unrelated application selections and old
retained directories. Run the consumer's ordinary parity, build and behavior
gates without dependency source overrides.

Kioku 0.11 changes the bounded-read API, nullable tag parents and metadata/tag
fields. Consumers upgrading from 0.9.0.2 must apply owned migrations 0014/0015,
then explicitly preview/adopt changed catalog registrations through the public
owner recipe before normal startup. See `mori://shinzui/kioku`, project-relative
`docs/user/bounded-reads.md` (source-artifact URI pending).

## Registry access

The user identified the existing Mori tunnel in `mori://shinzui/dotfiles.nix`,
project-relative `hosts/yujin/home.nix` (source-artifact URI pending). Command-local
connection settings use that forwarded socket. No local registry database or
production runtime was created and dotfiles were not changed.
