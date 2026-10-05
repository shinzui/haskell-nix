---
id: 10
slug: own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays
title: "Own the shared third-party overrides in the channel instead of consumer overlays"
kind: exec-plan
created_at: 2026-09-26T22:16:13Z
intention: "intention_01m3fw8cpte9xtje3e5j7f2ng2"
master_plan: "docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md"
provenance:
  created_by:
    model: "claude-opus-5-5"
    harness: "claude-code"
    at: 2026-09-26T22:16:13Z
  revisions:
    - model: "claude-opus-5-5"
      harness: "claude-code"
      at: 2026-09-26T22:41:44Z
      mode: "update"
      note: "Reconcile cross-plan contracts after parallel drafting: freeze index-state, cohort-compare interface, ADR numbering, cabal-version correction"
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-04T13:51:42Z
      mode: "update"
      note: "Apply dependency-alignment review: routine update isolation, shared build evidence and applicable cache/ownership corrections; implementation pending."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-05T22:10:10Z
      mode: "implement"
      note: "Parallel EP-10 implementation: shared policy/source pins and consumer ownership audit"
  reviews:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-04T13:51:42Z
      verdict: "changes-requested"
      note: "Original review found incomplete shared-name audit and pre-adoption build dependency cycle; applied findings in update."
---

# Own the shared third-party overrides in the channel instead of consumer overlays

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Five Haskell applications (`mori://shinzui/rei`, `mori://shinzui/mori`,
`mori://shinzui/mori-rei-app`, `mori://shinzui/reiko` and `mori://shinzui/mina`) build
their Nix packages by layering this repository's channel under a local file,
`nix/haskell-overlay.nix`. The local file runs last, so every package it names silently
replaces the channel's copy. Today those five files carry 58 entries that are not the
application's own code, 53 of them overrides of shared packages (the count includes the
`typeid-hs-sql` and `typeid-hs-pg-migrate` source builds that rei, mori and mori-rei-app
each carry). Most of those duplicate what the channel already supplies; a few supply
something the channel lacks. Either way, two applications that
pin the same channel revision still build different derivations of the same library. On
2026-09-26 that is how mori-rei-app's `wai-app-static` 3.2.1 and `servant-server`
jailbreak changed the hash of everything above them up to `rei-core`.

After this plan:

- Every shared override has exactly one home, this repository's channel. That includes
  `typeid-hs-sql` and `typeid-hs-pg-migrate`, built from the now-public
  `topagentnetwork/typeid-hs` at `7164a74c`, so no consumer needs a `typeid-hs-src`
  flake input any more.
- The only declared exception left in any consumer overlay is mina's `mori-schema-pin`
  at mori `7af02c55`. Mori's `hasql-effectful`, the one other private source, is not a
  channel concern: plan 12 vendors it into `mori-core`, and the overlay entry goes with
  it.
- A check proves each moved package builds through the default package set.
- A second check, which consumers run, fails when a consumer overlay redefines a package
  the channel provides. It also fails when an overlay defines a package the consumer has
  not declared as its own.
- Each consumer has an exact list of overlay entries to delete. Plans 11, 12 and 13
  carry out those deletions; this plan edits no consumer.
- A new ADR in `docs/adr/` records the rule "consumer overlays define only their own
  packages". It extends `mori://shinzui/mori/okf/adrs/concepts/ADR-24` from first-party
  packages to every package.

You can see it working in three ways:

1. Run `nix build .#checks.aarch64-darwin.shared-overrides` in this repository. It
   builds every moved package from the default set and prints their versions.
2. Evaluate the audit against each consumer's current overlay. It names exactly the
   entries on that consumer's deletion list, and nothing else.
3. Build `rei-cli`, `mori-cli` and `mori-rei-app` against this repository's working tree,
   with those entries filtered out of their overlays. Each build succeeds.


## Review requirements (2026-10-04)

Plan 16 (`docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md`) will publish retained runtime ownership and source/policy records. Define the overlay audit so it can accept an explicit set of runtime-owned transitive packages/source components in addition to the existing registry/generated/freeze ownership. The baseline audit works before plan 16 exists; that later plan supplies the retained records and extends its fixtures. An application cannot declare a runtime-owned dependency as its own to evade the audit. Keep shared source/policy definitions centralized here; plan 16 captures immutable effective recipes for a generation, including Kafka forks/adapters outside the current family catalog, without copying them into consumer overlays.

Follow [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md): ordinary application edits retain the cohort and toolchain pins. Matching versions alone is insufficient evidence of reused builds. Historical input revisions, package counts and deletion lists below are starting observations; refresh them from recorded contributor revisions.

Audit consumer-owned names against the union of selected first-party packages, generated cohort entries, frozen shared names and declared source pins, not just `overlays/registry.nix`. Declaring a shared package as owned cannot hide shadowing. Re-inventory current overlays, including Rei's added API packages and shared instrumentation overrides. Keep only the already agreed mina `mori-schema-pin` exception; do not reopen that decision as part of this review.

Milestone 4's old-consumer builds are diagnostic rehearsals. A failure caused by the application source changes or bounds that plans 11–13 own does not block phase 1 or require those plans to run early. Record the failing component and hand it to its consumer plan. A registry/policy failure is still fixed here. Completion requires channel shared-override builds and ownership audits; all final consumer builds remain required before plan 14 deployment. Coordinate removal of temporary version pins with plan 9. ADR 4 is reserved; do not allocate by landing order.

## Progress

- [x] 2026-10-05: Audit accepts generated/frozen/source/runtime shared ownership names.
- [ ] Pre-adoption source failures are assigned to consumer plans after diagnostic rehearsals.

- [x] 2026-10-05: M1: Re-verify the inventory against each consumer's current HEAD (rei `25e4b492`, mori `62be8048`, mori-rei-app `453aaaef`, reiko `4f98ba91`, mina `8e0dcb80`) and record any drift in Surprises & Discoveries.
- [x] 2026-10-05: M1: Re-evaluate the channel's current versions of the contested packages. If plan 9's generated version layer has landed, record which moved packages it already supplies.
- [x] 2026-10-05: M2: Add policy-only registry entries for `link-canonical`, `hw-kafka-client` and `servant-server`.
- [x] 2026-10-05: M2: Add version-pinned patches for `wai-app-static` 3.2.1, `servant-health` 0.1.0.0, `generic-lens-core` 2.3.0.0 and `generic-lens` 2.3.0.0. If plan 9's generated layer already supplies a version, add only the build policy.
- [x] 2026-10-05: M2: Confirm anonymous access to `topagentnetwork/typeid-hs` at `7164a74c` and its fetch hash, then add the source-pinned registry entries `typeid-hs-sql` and `typeid-hs-pg-migrate` (`patches/typeid-hs/source.nix` plus one patch file per package).
- [x] 2026-10-05: M2: Add `checks/shared-overrides.nix` and wire it into `checks/default.nix`.
- [x] 2026-10-05: M2: `nix build --no-link --print-build-logs .#checks.aarch64-darwin.shared-overrides` passes. It builds all 34 selected shared package entries, with no below-minimum versions and redundant Kioku profiling policy.
- [ ] M2: x86_64-linux shared-overrides build finishes (started in session 74387).
- [x] 2026-10-05: M2: Commit the channel entries with the independently verified audit integration; Linux evidence remains open.
- [x] 2026-10-05: M3: Add `lib/consumerOverlayReport.nix` and expose `lib.consumerOverlayReport` and `lib.auditConsumerOverlay` from `flake.nix`.
- [x] 2026-10-05: M3: Add nix-unit tests to `checks/unit.nix` and a fixture-backed `consumer-overlay-audit` flake check.
- [x] 2026-10-05: M3: Run the audit against all five consumers' current overlays and record the reports. Each consumer's `shadowing` plus `undeclared` must equal its deletion list (mori's `hasql-effectful` and mina's `kdl-hs` are the two `undeclared` names).
- [x] 2026-10-05: M3: Commit the audit after the native fixture and 51-test Nix-unit checks pass.
- [ ] M4: Rehearse the deletions. Build `rei-cli` and `rei-api` (rei), `mori-cli` (mori) and `mori-rei-app` against the local channel with the deletion lists filtered out and `typeid-hs-src` replaced by a dummy, then read the versions from the derivation closures.
- [ ] M4: Evaluate mina's filtered overlay (evaluation only; plan 13 owns its build).
- [x] 2026-10-05: M5: Write the new ADR as `docs/adr/4-consumer-overlays-define-only-their-own-packages.md`.
- [x] 2026-10-05: M5: Update `docs/user/consumer-integration.md`, `docs/user/adding-patches.md` and `docs/user/channels.md`, append to `docs/user/log.md`, and pass `just check-docs`.
- [ ] M5: `nix flake check` passes, and the final commit is made.
- [ ] M5: Fill in Outcomes & Retrospective and hand the deletion lists to plans 11, 12 and 13.
- [x] 2026-09-26: Plan revised for the user's decisions: `typeid-hs` moves into the channel, `hasql-effectful` leaves the overlay through plan 12's vendoring, and mina's `mori-schema-pin` is the only declared exception. No implementation work has started.


## Surprises & Discoveries

- 2026-10-05: Removing servant-health from an in-memory copy of the registry makes
  shared-overrides evaluation fail with `attribute servant-health missing`, confirming
  the minimum-version/build check uses the centralized entry. No working-tree mutation
  was needed.
- 2026-10-05: Native shared-overrides completes successfully, building all shared policy
  entries including TypeID and Servant instrumentation. `consumer-overlay-audit` and
  `nix-unit` checks also finish successfully (51/51 unit tests). A negative report
  against the current mori-rei-app overlay rejects exactly its five shared names.

  ```text
  belowMinimum = []
  kiokuProfilingRedundant = true
  nix-unit: 51/51 successful
  mori-rei-app audit: shadows link-canonical, servant-server, typeid-hs-pg-migrate, typeid-hs-sql, wai-app-static
  ```

- 2026-10-05: Re-inventory at recorded Rei `25e4b492`, Mori `62be8048`, mori-rei-app
  `453aaaef`, Reiko `4f98ba91` and current Mina `8e0dcb80` finds 21/37/9/2/6 overlay
  attributes. Mina advanced from EP-8's recorded `5d4be2ef`; its overlay names are
  unchanged and EP-8's input record was not advanced. Rei adds two own API packages,
  shared instrumentation-servant and exporter-in-memory. The instrumentation source
  is centralized at the same `7a6f692e85295f965cd1827f9354c28af9e62742` pin as Cabal.
  Mori's local source corpus for this fork lags upstream; a fresh scratch clone
  confirms the retained revision admits hs-opentelemetry-api >=0.3 && <1.1.
- 2026-10-05: Source/version evaluation yields `belowMinimum=[]` and
  `kiokuProfilingRedundant=true`, including both TypeID packages 0.1.0.0 and
  instrumentation-servant 0.3.0.0. These are selection proofs, not build success.

These observations were made while drafting on 2026-09-26, with read-only evaluation of
this repository at `4cabd105` and of the consumer overlays at the HEADs named in Progress.

- **Observation:** Most consumer overrides duplicate packages the channel already
  supplies, at the same version.
  - `openapi-hs` 5.0.0 (source `06fc1171`), `servant-openapi-hs` 5.1.0 (source
    `181ca609`) and all four `relay-pagination` packages at 0.1.1.0 are first-party
    families in the default package set.
  - The whole `hs-opentelemetry` 1.0.0.0 line with `semantic-conventions` 1.40.0.0,
    `hasql-notifications` 0.2.5.0, `thread-utils-finalizers` and `thread-utils-context`,
    and the portable `blake3` build are already in `overlays/registry.nix`. The otel and
    `hasql-notifications` pins use the same Hackage hashes as mori's and rei's copies.
  - `link-canonical` 0.1.0.0 and `hw-kafka-client` 5.3.0 are already in the pinned
    nixpkgs, at exactly the versions the consumers pin.
  - Evidence (`nix eval`, channel vs. plain nixpkgs `ghc9124`):

    ```text
    link-canonical        nixpkgs 0.1.0.0   channel 0.1.0.0
    hw-kafka-client       nixpkgs 5.3.0     channel 5.3.0
    openapi-hs            nixpkgs absent    channel 5.0.0
    relay-pagination      nixpkgs absent    channel 0.1.1.0
    hs-opentelemetry-sdk  nixpkgs 0.1.0.1   channel 1.0.0.0
    hasql-notifications   nixpkgs 0.2.4.0   channel 0.2.5.0
    servant-health        nixpkgs absent    channel absent
    wai-app-static        nixpkgs 3.1.9.1   channel 3.1.9.1
    generic-lens          nixpkgs 2.2.2.0   channel 2.2.2.0
    kdl-hs                nixpkgs 1.1.0     channel 1.1.0
    typeid-hs-sql         nixpkgs absent    channel absent
    ```

  - Date: 2026-09-26
- **Observation:** The duplicates outlived the reason they were added, and the
  composition order hid that.
  - Rei added its `openapi-hs`, `servant-openapi-hs` and `relay-pagination` pins in
    rei `ec9ce5bb` (2026-07-25). Its locked channel then was `2e1ee913`, which predates
    the families onboarded here in `d4bf7f9` and `6462993` (2026-07-21), so the pins
    were needed at the time.
  - They became dead weight the moment rei moved its lock forward. Because the consumer
    overlay composes second, nothing reported the overlap.
  - Rei's `hs-opentelemetry` pins were never needed: that rev already carried the 1.40
    family (`41f6423`). Rei's comment says the packages "ARE in the nixpkgs snapshot --
    at 0.1.x", which reasons from nixpkgs rather than from the channel.
  - Mori's otel pins date from 2026-06-03, the same day this repository added them.
- **Observation:** A same-version duplicate is still not the same derivation, and the
  difference spreads upward.
  - Mori's `thread-utils-context` 0.4.1.0 comes from a Hackage tarball through
    `callHackageDirect`. The channel's comes from nixpkgs' `all-cabal-hashes`, so the
    two derivations differ.
  - As a result, mori's `hs-opentelemetry-sdk` and `kioku-core` derivations differ from
    the channel's, although both sides pin identical versions.
  - Evidence: `channel.thread-utils-context.drvPath == withHackagePin.thread-utils-context.drvPath`
    evaluates to `false`. Composing mori's overlay makes `hs-opentelemetry-sdk` and
    `kioku-core` differ from the channel, while `hasql-notifications`, whose inputs are
    untouched, stays identical.
- **Observation:** The `kioku-core = disableLibraryProfiling prev.kioku-core` entry in
  rei and mori does nothing under the default channel extension.
  - The extension already disables library profiling for the whole set
    (`lib/disableProfilingOverride.nix`).
  - Evidence: in the channel scope, `kioku-core.drvPath` equals
    `(disableLibraryProfiling kioku-core).drvPath` (`true`).
  - The flag does not show up as `--disable-library-profiling` in
    `drvAttrs.configureFlags`, so a check must compare `drvPath`s instead of reading
    flags.
- **Observation:** `kdl-hs` is newer in the channel than in the only application that
  uses it.
  - nixpkgs ships 1.1.0. Mina pins 1.0.1 because `mina-core.cabal` requires
    `kdl-hs ^>=1.0` (so `<1.1`), and its Cabal plan also selects 1.0.1.
- **Observation (superseded later the same day, see the next entry):** At first
  drafting, two private repositories were involved, and the channel is public.
  - `shinzui/haskell-nix` is public.
  - `topagentnetwork/typeid-hs` (source of `typeid-hs-sql` and `typeid-hs-pg-migrate`)
    and `topagentnetwork/tan-effectful` (source of `hasql-effectful`) were private.
  - Evidence from `gh repo view --json visibility`: `PUBLIC` for the channel and
    `PRIVATE` for both sources.
- **Observation:** `topagentnetwork/typeid-hs` is now public, so the public channel can
  fetch it without credentials.
  - Evidence: an anonymous `git ls-remote https://github.com/topagentnetwork/typeid-hs`
    returns `HEAD` at `7164a74c490cc92ffe73a315d827c9515de125d3`, and the GitHub API
    answers the repository request with HTTP 200 without credentials.
  - That revision is the one rei, mori and mori-rei-app all lock as `typeid-hs-src`.
    All three `flake.lock` files record the same
    `narHash = "sha256-XCq5GXlOK8ZxbR4ZKIEi99rQdJ6vxX1c6/C3nRGvcrA="`, which is the NAR
    hash of the unpacked tree, the same quantity `pkgs.fetchFromGitHub`'s `hash` checks.
  - At that revision both packages are version 0.1.0.0. `typeid-hs-pg-migrate` depends
    on `pg-migrate` (a first-party family in this channel) and `hasql >=1.10 && <1.11`.
    Neither package depends on `effectful`, so the family's move to `effectful` 2.7
    (plan 15) does not touch them.
  - Date: 2026-09-26
- **Observation:** `hasql-effectful` is used by mori alone.
  - 59 `mori-core` modules (library and tests) import `Effectful.Hasql`. Rei,
    mori-rei-app and mori-app mention the package only in comments. Rei stopped
    depending on it by vendoring the module as `rei-core/src/Rei/Infrastructure/Hasql/Effect.hs`
    in `mori://shinzui/rei`.
  - Its `hasql-effectful.cabal` caps `effectful` below 2.6 (mori's `cabal.project`
    carries `allow-newer: hasql-effectful:effectful, hasql-effectful:effectful-core`),
    and the whole family moves to `effectful` 2.7 under plan 15, so a channel entry
    would be a jailbreak of a private source for one consumer.
  - Date: 2026-09-26
- **Observation:** Some Cabal and Nix differences in the same packages are outside this
  plan's reach. They are recorded for plans 8, 9, 11 and 13.
  - Rei's and mori-rei-app's `cabal.project` set `dhall -use-http-client-tls`, while the
    channel deliberately keeps that flag on (`patches/dhall/keep-http-client-tls.nix`).
  - `thread-utils-context` is 0.4.1.1 under Cabal and 0.4.1.0 under Nix.
  - Mina's `cabal.project` source-pins `streamly` and `streamly-core`, and nothing
    reflects that in Nix.
  - Mori's `cabal.project` source-pins `dhall` at `03b40e85`. Nix builds the same
    1.42.3 with this repository's bound patch.


## Decision Log

- 2026-10-05: Classify shared names as shadowing only and unknown undeclared names
  separately. The earlier literal undeclared formula duplicated every undeclared
  shared name, contradicting the real-report acceptance examples. Disjoint diagnostics
  retain rejection of every offending name and make deletion lists unambiguous.

- 2026-10-05: Retain the exact current Servant instrumentation fork in shared policy
  because the current Rei overlay and cohort source manifest require it. Add its name
  to Rei's deletion list and include the existing in-memory exporter copy. The report
  accepts explicit generated/frozen/source/runtime ownership lists so later EP-9/16
  records extend one audit rather than introducing another implementation. Shared
  ownership always wins over application declarations.

- Decision (runtime plan, 2026-10-04): adopt the plan-16 integration contract above. It owns retained runtime selection/composition, while this plan retains its existing solver/generation/policy/consumer/deployment responsibility. Consumer plans 11–13 require runtime delivery before adoption; preparatory shared tools do not depend on consumers.

- Decision (2026-10-04 review update): adopt the Review requirements above and ADR 5's update-isolation/build-evidence contract. Historical closure-only acceptance, fixed package counts and duplicated comparison implementations are superseded where noted. Preserve the agreed advisory fleet guard and effectful migration policy. Implementation evidence remains pending.

- **Decision:** Add no new first-party families. Each shared override that needs a
  channel entry goes into `overlays/registry.nix` (with a `patches/<package>/` file for
  version pins), even when the package is shinzui-owned (`servant-health`,
  `link-canonical`).
  - Rationale: `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` fixes
    the schema-version-2 family inventory. Adding a family needs an explicit catalog
    migration that must not silently add a group to existing complete package-set
    mappings (`docs/user/package-sets.md`, "Retention and topology"). That migration is
    separate work. A registry entry is also where plan 9's generated version layer
    expects third-party packages to live.
  - Date: 2026-09-26
- **Decision:** `openapi-hs`, `servant-openapi-hs`, the four `relay-pagination`
  packages, the `hs-opentelemetry` family, `hasql-notifications`,
  `thread-utils-finalizers`, `thread-utils-context` and `blake3` need no channel change.
  Consumers simply delete their copies.
  - For the one apparent conflict, `openapi-hs` (rei: Hackage 5.0.0; mori: source
    `06fc1171`), the versions are equal. Mori's revision is the channel family's locked
    revision. The channel's GitHub-sourced copy wins, and rei's provenance changes from
    tarball to tag, with no version movement.
  - Rationale: the channel already supplies each of these at a version at least as high
    as any application selects, so upgrade-only is satisfied with no edit here.
  - Date: 2026-09-26
- **Decision:** `link-canonical`, `hw-kafka-client` and `servant-server` get
  policy-only entries (`always dontCheckDoJailbreak`) on the nixpkgs version.
  - Rationale: nixpkgs already has the version every application selects. What the
    consumers add is build policy: tests off, bounds relaxed. Rei's `cabal.project`
    `allow-newer` for `link-canonical:http-client-tls` and `link-canonical:generic-lens`
    shows the jailbreak is required. `servant-server` 0.20.3.0's nixpkgs cabal file caps
    `wai-app-static <3.2`.
  - Date: 2026-09-26
- **Decision:** `wai-app-static` 3.2.1, `servant-health` 0.1.0.0 and
  `generic-lens`/`generic-lens-core` 2.3.0.0 get version-pinned patches, each marked as
  a pin plan 9 converts to policy.
  - Rationale: for each, the highest version any application selects (Cabal for all
    five; Nix for mori-rei-app and mina) is above what nixpkgs offers, or nixpkgs lacks
    the package. Upgrade-only therefore requires the channel to carry the higher
    version.
  - If plan 9's generated layer has already landed and supplies the version, add only
    the policy and skip the pin. If this plan lands first, plan 9 turns these pins into
    policy entries.
  - Date: 2026-09-26
- **Decision:** Add no channel entry for `kioku-core`. Consumers delete their
  `disableLibraryProfiling` line, and `shared-overrides` asserts it would be a no-op.
  - Rationale: the default extension already disables profiling for the whole set
    (proved by equal `drvPath`s). A common-registry entry could not target it anyway,
    because the generated first-party registry wins the merge
    (`commonRegistry // profileRegistry // firstPartyRegistry` in
    `lib/mkFirstPartyPackageSet.nix`).
  - A consumer that passes `disableProfiling = false` would meet the GHC 9.12.4
    profiling panic again. The ADR and the docs say so.
  - Date: 2026-09-26
- **Decision (superseded by the three user decisions dated 2026-09-26 below):**
  `typeid-hs-sql`, `typeid-hs-pg-migrate` and `hasql-effectful` stay in consumer
  overlays as declared exceptions, each with a reason. They do not move into the
  channel.
  - Rationale at the time: they built only from private `topagentnetwork`
    repositories, and the channel is public. A flake input would force every
    consumer's lock to fetch them with credentials, and a lazy fetch inside a registry
    patch would make the public registry expose names that fail for anyone without
    access.
  - Date: 2026-09-26
- **Decision (user decision):** `typeid-hs-sql` and `typeid-hs-pg-migrate` move into the
  channel as source-pinned entries in `overlays/registry.nix`, built from
  `topagentnetwork/typeid-hs` at `7164a74c490cc92ffe73a315d827c9515de125d3`. Rei, mori
  and mori-rei-app delete both overlay entries and their `typeid-hs-src` flake input.
  - Rationale: the repository is now public (see Surprises & Discoveries), which removes
    the only reason they stayed local. Three consumers carry identical copies, the
    definition of a shared override.
  - Shape: a registry entry, not a first-party family. A new family needs the explicit
    catalog migration that
    `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` requires, and the
    first decision above defers all such migrations. The entry follows the existing
    `patches/codd/0.1.nix` precedent, a `pkgs.fetchFromGitHub` source with a fixed
    revision and hash built by `callCabal2nix`. One shared `patches/typeid-hs/source.nix`
    holds the fetch so both packages always build from the same revision.
  - It is a source pin, not a version pin. `typeid-hs` is not on Hackage, so plan 8's
    `cabal/cohort.freeze` does not list it and plan 9's generated layer does not own it.
    The applications' `cabal.project` files keep their `source-repository-package`
    stanza at the same tag; the two must name the same revision.
  - Build policy stays what the consumers used: tests off, jailbroken.
  - Date: 2026-09-26
- **Decision (user decision):** `hasql-effectful` is neither a channel entry nor a
  declared exception. Plan 12
  (`docs/plans/12-adopt-the-shared-package-set-in-mori.md`) vendors the module into
  `mori-core`, as rei did, and deletes mori's `hasql-effectful` overlay entry, its
  `tan-effectful-src` flake input and its Cabal pin. This plan lists the overlay entry
  and the input on mori's deletion list, conditioned on that vendoring: the vendoring
  lands before, or in the same commit as, the overlay deletion.
  - Rationale: only mori uses it (see Surprises & Discoveries). Its `effectful <2.6` cap
    would need a jailbreak against the family's `effectful` 2.7 (plan 15), and a
    private source cannot live in a public channel. Vendoring removes the dependency
    rather than relocating it.
  - Consequence for the audit: until plan 12 vendors it, mori's report shows
    `hasql-effectful` as `undeclared`, which is the expected signal of a pending
    deletion, not a failure of this plan.
  - Date: 2026-09-26
- **Decision (user decision):** The only declared exception in any consumer overlay is
  mina's `mori-schema-pin` at mori `7af02c55`.
  - Rationale: moving it changes the Dhall mina writes into other repositories, so it
    stays pinned until mina deliberately adopts a newer schema. It is therefore declared
    as an exception with that reason, not as a sibling (a sibling is a library that will
    be consumed from its application's flake, which this pin deliberately is not).
  - Mina's `kdl-hs` is not an exception either. It is a conditional deletion (after
    plan 13 lifts mina's bound) and appears as `undeclared` in mina's report until then.
  - This matches the MasterPlan's Integration Points for `mori-schema-pin`. The
    MasterPlan still lists the `typeid-hs` and `hasql-effectful` sources as declared
    exceptions; its owner must update that text to these decisions.
  - Date: 2026-09-26
- **Decision:** Do not touch `patches/shibuya-pgmq-adapter/0.16.nix`. Mori's local
  0.16.1.0 override is on mori's deletion list with a precondition: the channel must
  already supply at least 0.16.1.0.
  - Rationale: the MasterPlan decided not to ship a one-off 0.16.1.0 patch ahead of
    plan 9. Plan 9 owns retiring that hand-written pin.
  - Date: 2026-09-26
- **Decision:** Add no channel entry for `kdl-hs`. Mina's override is deleted only after
  plan 13 lets mina accept the channel's 1.1.0 (by lifting `kdl-hs ^>=1.0`). Until then
  it is a conditional deletion that mina's report shows as `undeclared`; it is not a
  declared exception (see the user decision above).
  - Rationale: pinning 1.0.1 in the channel would move the channel down from the 1.1.0
    it already offers. Only mina uses `kdl-hs`, and only mina's bound holds it back.
  - Date: 2026-09-26
- **Decision:** Enforce the rule with a check that consumers run
  (`lib.auditConsumerOverlay`), rather than by review alone.
  - Rationale: `mori://shinzui/mori/okf/adrs/concepts/ADR-24` rejected such a check as
    "machinery for a rule better enforced by not writing the entry". The evidence above
    shows that discipline did not hold: mori alone carries 29 entries the channel
    provides, several written after ADR-24.
  - The new ADR records this reversal explicitly.
  - Date: 2026-09-26
- **Decision:** Sibling-application libraries (`rei-core`, `mori-types` and `mori-app` in
  mori-rei-app's overlay) are permitted as declared siblings, not as own packages.
  Mina's `mori-schema-pin` is declared as an exception instead (see the user decision
  above).
  - Rationale: plans 11 and 12 change how one application consumes another's library
    (through that application's flake output). The audit must keep them legible until
    then without letting them pass as the consumer's own code.
  - Date: 2026-09-26
- **Decision:** `shared-overrides` builds on the default GHC (`ghc9124`) only.
  - Rationale: all five applications build with GHC 9.12.4. The moved packages are
    application dependencies, not first-party families whose support matrix includes
    `ghc9141`.
  - Date: 2026-09-26
- **Decision:** Write the ADR in this repository's filesystem convention
  (`docs/adr/4-consumer-overlays-define-only-their-own-packages.md`, no OKF
  frontmatter). The MasterPlan reserves ADR 4 independently of landing order.
  - Rationale: `docs/adr` is not a profile-governed OKF bundle here; `mori.dhall`
    declares only `docs/improvement-requests`, `docs/user` and `docs/guides`. Plans 8
    and 9 have reserved ADRs 2 and 3; this plan uses reserved ADR 4.
  - Date: 2026-09-26


## Outcomes & Retrospective

Implementation checkpoint (2026-10-05): shared channel entries and source pins are implemented,
with 11 ownership tests; the fixture audit and Nix-unit check build successfully (51/51 overall). The real reports reproduce the refreshed deletion lists, and the negative mori-rei-app wrapper fails with its five shared names. Implemented and ADR 4/user documentation. Authoritative Hackage checks and upstream
tags confirm the four Hackage pins. Anonymous TypeID prefetch confirms the recorded NAR hash.
Channel evaluation reports no below-minimum versions and profiling redundancy; native shared-dependency compilation passes; Linux compilation remains
a separate pending gate. `just check-docs` passes (9 user, 5 guide, 1 research concepts).

The refreshed deletion lists are Rei 16 shared names (the historical 14 plus
`hs-opentelemetry-instrumentation-servant` and `hs-opentelemetry-exporter-in-memory`), Mori 32
(including the conditional retired effect), mori-rei-app 5, and Mina 3 conditional/shared names.
Rei now declares five own overlay packages including rei-api-contract and rei-api-client.
Mori retains shibuya-pgmq-adapter until plan 9 supplies at least 0.16.1.0 and hasql-effectful until
plan 12 vendors its imports. Mina retains kdl-hs until plan 13 lifts its bound. Mina's
mori-schema-pin remains the sole exception. TypeID deletions free typeid-hs-src in Rei/Mori/mori-rei-app;
Mori additionally frees tan-effectful-src and the three HTTP family source inputs in its adoption.
No consumer repositories were modified. Linux shared-dependency and full flake-check builds, plus diagnostic
consumer rehearsals remain pending; this checkpoint does not mark EP-10 complete.


## Context and Orientation

This repository, `mori://shinzui/haskell-nix`, is a Nix flake that other repositories
use to build Haskell programs with one consistent set of package versions. Several
terms recur below.

- **Channel.** The thing consumers import: a function that, applied to nixpkgs' Haskell
  helper library and nixpkgs itself, returns a Haskell package-set extension. The
  default is `lib.haskellExtensions.github`. It is built in
  `lib/mkFirstPartyPackageSet.nix`, which merges three registries in this order:
  1. the hand-written common registry, `overlays/registry.nix`;
  2. compatibility profiles, `overlays/compatibility-profiles.nix`, which today contain
     only `default = { }`;
  3. a generated first-party registry, built from `config/first-party-families.json`
     and `packages/first-party-lock.json` by `lib/mkFirstPartyRegistries.nix`.

  The merge is `commonRegistry // profileRegistry // firstPartyRegistry`, so a
  first-party name always beats a common entry of the same name. The extension also
  disables library profiling and Haddock for the whole set by overriding
  `mkDerivation` (`lib/disableProfilingOverride.nix`, `lib/disableHaddockOverride.nix`).
- **Registry entry.** An attribute in `overlays/registry.nix` whose value is a list of
  patches. `always patch` applies regardless of version. `patch` is a function of
  `{ pkg, lib, haskellLib, pkgs, hself, hsuper }` that returns a derivation.
  - The file defines helpers: `dontCheckDoJailbreak` (tests off, version bounds
    stripped), `dontCheckOnly`, `doJailbreakOnly`, and the `markUnbroken*` variants.
  - A version pin is a patch file under `patches/<package>/<version>.nix` that calls
    `hself.callHackageDirect { pkg; ver; sha256; } { }`. Its `sha256` must be the hash
    of the *unpacked* source (what `nix-prefetch-url --unpack` prints), because
    `callHackageDirect` fetches with `fetchzip`.
  - A source pin is a patch file that builds a package not published on Hackage from a
    fixed Git revision: `hself.callCabal2nix "<name>" (pkgs.fetchFromGitHub { owner; repo; rev; hash; }) { }`.
    `patches/codd/0.1.nix` is the existing example. Its `hash` is the NAR hash of the
    unpacked tree, the same value a `flake.lock` records as `narHash` for the same
    GitHub revision.
  - `lib/fixPackageByVersion.nix` turns each entry into a per-package override.
- **First-party family.** A shinzui-owned repository whose packages the updater
  (`nix run .#haskell-nix-update --`) snapshots into `packages/first-party-lock.json`.
  The default package set selects one generation of each. `openapi-hs`,
  `servant-openapi-hs` and `relay-pagination` are families. Their default generations
  are `openapi-hs` 5.0.0 at `06fc1171`, `servant-openapi-hs` 5.1.0 at `181ca609`, and
  `relay-pagination` 0.1.1.0 (four packages) at `224163d1`. Adding a family is not
  routine (see the Decision Log).
- **Consumer overlay.** Each application's `nix/haskell-overlay.nix`, a
  `final: prev: { ... }` function. The application's `flake.module.nix` composes it
  after the channel:

  ```nix
  haskellPackages = pkgs.haskell.packages.ghc9124.override {
    overrides = pkgs.lib.composeExtensions
      (inputs.haskell-nix.lib.haskellExtensions.github pkgs.haskell.lib.compose pkgs)
      (import ./nix/haskell-overlay.nix { inherit pkgs gitRev; /* sources */ });
  };
  ```

  `composeExtensions first second` lets `second` win. Any package the overlay names
  replaces the channel's, silently.
- **Shadowing.** An overlay entry for a name the channel's registry also defines. The
  audit this plan adds reports shadowing by name.
- **Upgrade-only.** When two builds disagree on a package version, the lower one moves
  up. No package may move below the highest version any of the five applications
  selects today under Cabal or Nix.

Relevant ADRs:

- [`docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md`](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md):
  - one Nixpkgs fixed point with one version per package name;
  - later consumer overrides are permitted by the composition mechanism;
  - adding a family requires an explicit catalog migration;
  - `callHackageDirect` hashes are unpacked-tree hashes.

  This plan keeps all of these. It adds a rule about *what* consumers may override,
  not a change in *how* composition works.
- `mori://shinzui/mori/okf/adrs/concepts/ADR-24` ("Source first-party Haskell packages
  from the shared overlay"). Mori's overlay must not pin a first-party package the
  shared overlay provides, because a local entry silently shadows the shared one.
  - Its 2026-08-14 amendment allows a documented local pin when the shared overlay
    cannot supply a required version.
  - Its 2026-09-13 amendment allows overriding a family's nested `*-src` input instead
    of adding a package entry.
  - It explicitly left third-party packages in local overlays, and rejected a detection
    check.

  This plan extends the rule to every package. It replaces the "pin locally when the
  shared overlay can't" escape hatch with "add it to the channel". It keeps the
  nested-input amendment, because a nested input override is not an overlay entry. It
  adopts the check ADR-24 rejected.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort
  adoption") explains why the Cabal and Nix selections must be changed and proved
  together.

There is no local ADR yet about consumer overlays; this plan writes it.

The consumer overlays referenced below are at these project-relative paths.
Artifact-level `mori://` URIs for files are pending, so each is named by project URI
plus path.

- `mori://shinzui/rei`: `nix/haskell-overlay.nix` at `880093cc`, composed by
  `flake.module.nix` with `lib.haskellExtensions.github`.
- `mori://shinzui/mori`: `nix/haskell-overlay.nix` at `f3c5fa4b`. This commit is local
  and unpushed; another session owns mori's Keiro 0.19 adoption. It is composed with
  `lib.haskellExtension`, the same default.
- `mori://shinzui/mori-rei-app`: `nix/haskell-overlay.nix` at `2acd4ed`.
- `mori://shinzui/reiko`: `nix/haskell-overlay.nix` at `4f98ba9`.
- `mori://shinzui/mina`: `nix/haskell-overlay.nix` at `6a4b3f9`. Mina is on the older
  channel `b88d3173` and a cohort behind; plan 13 moves it.

### The inventory

Every attribute defined in the five overlays falls into one of five classes:

- **(a) Own:** the application's own packages.
- **(b) Sibling:** another application's library, which stays until plans 11 and 12
  change how it is consumed.
- **(c) Shared:** a third-party or first-party override the channel must own.
- **(d) Exception:** a package that stays local for a stated reason. There is exactly
  one: mina's `mori-schema-pin`.
- **(e) Retired by the consumer:** a dependency the consumer stops using, so the entry
  goes away without the channel gaining anything. There is exactly one: mori's
  `hasql-effectful`, which plan 12 vendors into `mori-core`.

The destination of each class-(c) entry is given with it.

**Rei** originally defined 17 attributes; the 2026-10-05 inventory defines 21.
Its own packages also include `rei-api-contract` and `rei-api-client`, and its shared
entries also include `hs-opentelemetry-instrumentation-servant` (retained fork) and
`hs-opentelemetry-exporter-in-memory` (already supplied by the channel).

- Own (a): `rei-core`, `rei-api`, `rei-cli`.
- Shared (c), 14 entries:
  - `typeid-hs-sql` and `typeid-hs-pg-migrate`, both 0.1.0.0, built with `callCabal2nix`
    from the `typeid-hs-src` flake input (`topagentnetwork/typeid-hs` at `7164a74c`,
    now public), tests off, jailbroken. Destination: new source-pinned registry entries
    backed by `patches/typeid-hs/source.nix`.
  - `link-canonical`: Hackage 0.1.0.0, tests off, jailbroken. Destination: a
    policy-only registry entry on nixpkgs' 0.1.0.0.
  - `kioku-core`: `disableLibraryProfiling`. Destination: none; already a no-op.
  - `openapi-hs` (Hackage 5.0.0), `servant-openapi-hs` (Hackage 5.1.0), and the four
    `relay-pagination` packages (Hackage 0.1.1.0). Destination: none; these are
    channel families at those versions.
  - `servant-health`: Hackage 0.1.0.0. Destination: a new pin in
    `patches/servant-health/0.1.nix`.
  - `hs-opentelemetry-instrumentation-wai`, `hs-opentelemetry-sdk` and
    `hs-opentelemetry-exporter-otlp`, all 1.0.0.0. Destination: none; already in
    `patches/hs-opentelemetry/1.40.nix` with the same hashes.

**Mori** defines 37 attributes.

- Own (a): `mori-types`, `mori-schema-pin`, `mori-core`, `mori-api`, `mori-cli`.
- Retired by the consumer (e): `hasql-effectful`, built from the `tan-effectful-src` flake
  input (private `topagentnetwork/tan-effectful` at `5e081ad8`). Destination: none in
  the channel. Plan 12 vendors the module into `mori-core` and then deletes the entry
  and the input.
- Shared (c), 31 entries:
  - `typeid-hs-sql` and `typeid-hs-pg-migrate`, identical to rei's entries (same input
    revision, same policy). Destination: the new source-pinned entries.
  - Already channel families, needing no change: `openapi-hs` (source `06fc1171`),
    `servant-openapi-hs` (source `181ca609`), and the four `relay-pagination` packages
    at 0.1.1.0.
  - `servant-health`: source `c70bffdd`, which is tag `v0.1.0.0` and so identical in
    version to Hackage 0.1.0.0. Destination: the new pin.
  - `blake3`: flags plus `-DBLAKE3_USE_NEON=0`. Destination: none;
    `patches/blake3/portable.nix` already does this.
  - `link-canonical`: Hackage 0.1.0.0. Destination: the new policy entry.
  - `hasql-notifications` 0.2.5.0. Destination: none; already in the channel.
  - The 14 `hs-opentelemetry-*` packages (`api-types`, `api`, `exporter-handle`,
    `exporter-in-memory`, `exporter-otlp`, `instrumentation-wai`, `otlp`,
    `propagator-w3c`, `propagator-b3`, `propagator-datadog`, `propagator-jaeger`,
    `propagator-xray`, `sdk`, and `semantic-conventions` 1.40.0.0). Destination: none;
    already in the channel.
  - `thread-utils-finalizers` 0.1.1.0 and `thread-utils-context` 0.4.1.0. Destination:
    none; the registry already applies `dontCheckDoJailbreak` to nixpkgs' copies at
    these versions.
  - `hw-kafka-client` 5.3.0. Destination: a new policy-only entry on nixpkgs' 5.3.0.
  - `kioku-core`. Destination: none, as in rei.
  - `shibuya-pgmq-adapter` 0.16.1.0. Destination: plan 9, which moves the channel's pin
    from 0.16.0.0.

**Mori-rei-app** defines 9 attributes.

- Own (a): `mori-rei-app`.
- Sibling (b): `mori-types` (from mori `32882f2d`), `mori-app` (from `mori-app`
  `30aca6e3`) and `rei-core` (from rei `880093cc`).
- Shared (c), 5 entries:
  - `typeid-hs-sql` and `typeid-hs-pg-migrate`, identical to rei's entries.
    Destination: the new source-pinned entries.
  - `link-canonical`. Destination: the policy entry.
  - `wai-app-static`: Hackage 3.2.1, tests off, jailbroken. Destination: a new pin in
    `patches/wai-app-static/3.2.nix`, replacing the registry's
    `wai-app-static = always dontCheckDoJailbreak` on nixpkgs' 3.1.9.1.
  - `servant-server`: `dontCheck (doJailbreak prev.servant-server)`. Destination: a new
    policy-only entry.

**Reiko** defines 2 attributes, `reiko-core` and `reiko-cli`, both own. It has nothing
to move.

**Mina** defines 6 attributes.

- Own (a): `mina-core`, `mina-cli`.
- Exception (d): `mori-schema-pin`, from mori `7af02c55`. It stays pinned because moving
  it changes the Dhall mina writes into other repositories. This is the only declared
  exception across the five overlays.
- Shared (c), 3 entries:
  - `generic-lens-core` and `generic-lens`, both 2.3.0.0, fetched with
    `builtins.fetchTarball` and built with tests off. Destination: new pins in
    `patches/generic-lens-core/2.3.nix` and `patches/generic-lens/2.3.nix`.
  - `kdl-hs` 1.0.1. Destination: none; the channel already offers nixpkgs' 1.1.0. It is
    a conditional deletion, not an exception: mina deletes it once plan 13 lifts
    `kdl-hs ^>=1.0`, and until then the audit reports it as `undeclared`.

Mori's `dhall-haskell` source pin and mina's `streamly` source pins live only in
`cabal.project`, not in any overlay, so they are not overlay overrides. Plans 8, 12 and
13 handle them. The same is true of nested flake-input overrides such as mina's
`haskell-nix.inputs.okf-src.follows`, which ADR-24's 2026-09-13 amendment permits.

The resulting per-repository deletion lists, which plans 11 to 13 apply, are:

- **Rei (16 after the October inventory):**
  - `typeid-hs-sql`, `typeid-hs-pg-migrate`;
  - `link-canonical`, `kioku-core`, `openapi-hs`, `servant-openapi-hs`,
    `servant-health`;
  - `hs-opentelemetry-instrumentation-wai`, `hs-opentelemetry-sdk`,
    `hs-opentelemetry-exporter-otlp`, `hs-opentelemetry-instrumentation-servant`,
    `hs-opentelemetry-exporter-in-memory`;
  - `relay-pagination`, `relay-pagination-servant`, `relay-pagination-hasql`,
    `relay-pagination-conformance`.

  With the two `typeid-hs` entries gone, the `typeid-hs-src` flake input and the
  overlay's `typeid-hs-src` argument become unused. Plan 11 deletes them too (the
  `source-repository-package` stanza in `cabal.project` stays, at the same tag).
- **Mori (32):**
  - `typeid-hs-sql`, `typeid-hs-pg-migrate`;
  - `openapi-hs`, `servant-openapi-hs`, `servant-health`, `blake3`, `link-canonical`,
    `hasql-notifications`;
  - the 14 `hs-opentelemetry-*` names listed above;
  - `thread-utils-finalizers`, `thread-utils-context`, `hw-kafka-client`, `kioku-core`;
  - `shibuya-pgmq-adapter`, only once the channel supplies at least 0.16.1.0;
  - `relay-pagination`, `relay-pagination-conformance`, `relay-pagination-hasql`,
    `relay-pagination-servant`;
  - `hasql-effectful`, only together with or after plan 12's vendoring of
    `Effectful.Hasql` into `mori-core`. Deleting the entry first breaks the build of
    every one of the 59 importing modules.

  With these gone, the flake inputs `typeid-hs-src`, `tan-effectful-src`,
  `openapi-hs-src`, `servant-openapi-hs-src` and `servant-health-src`, their overlay
  arguments, and the `callHackageNoCheck` helper become unused. Plan 12 deletes them
  too (`tan-effectful-src` in the vendoring change).
- **Mori-rei-app (5):** `typeid-hs-sql`, `typeid-hs-pg-migrate`, `link-canonical`,
  `wai-app-static`, `servant-server`. The `typeid-hs-src` flake input and overlay
  argument become unused; plan 11 deletes them.
- **Reiko:** none.
- **Mina (2, then a third):** `generic-lens-core` and `generic-lens`. `kdl-hs` follows
  once mina's bound accepts 1.1. `mori-schema-pin` stays as the one declared exception.


## Plan of Work

The work has five milestones. Only M2, M3 and M5 change files in this repository. M1
and M4 are verification against the consumers' checkouts, which are read, never
edited.

**Milestone 1: re-verify the inventory.** The consumers may have moved since
2026-09-26, so first re-derive the facts this plan relies on. At the end nothing has
changed on disk; you hold either a confirmed inventory or a list of differences, which
you record in Surprises & Discoveries and apply to the deletion lists above before you
continue.

1. For each consumer, list its overlay's attribute names by evaluating the overlay
   against the channel scope. The expression is under Concrete Steps.
2. Evaluate the channel's versions of the contested packages, also under Concrete
   Steps.
3. If plan 9 has landed, `packages/` or `lib/` will contain its generated version layer
   (the MasterPlan says it is loaded from `lib/mkFirstPartyPackageSet.nix`). Note which
   of `wai-app-static`, `servant-health`, `generic-lens` and `generic-lens-core` it
   already supplies at the target versions. For those, M2 adds only policy.

Acceptance: the attribute lists equal the inventory, or every difference is recorded.

**Milestone 2: add the channel entries and prove they build.** At the end the default
set supplies every class-(c) package at a version at least as high as any application
selects, with the build policy the consumers applied. A new flake check,
`shared-overrides`, builds them.

Edit `overlays/registry.nix`:

1. Next to the existing `wai-app-static` line under "Provider clients and
   generated-family dependencies", replace
   `wai-app-static = always dontCheckDoJailbreak;` with
   `wai-app-static = always (import ../patches/wai-app-static/3.2.nix);`. Rewrite its
   comment: 3.2.x drops cryptonite/crypton for `cryptohash-md5`, avoiding the
   `memory`/`ram` instance clash of the crypton 1.1 stack; every application's Cabal
   plan selects 3.2.1.
2. Add `servant-server = always dontCheckDoJailbreak;`, with a comment that
   `servant-server` 0.20.3.0's nixpkgs cabal file caps `wai-app-static <3.2`.
3. Add a new section headed `# ── Application HTTP and utility dependencies ──` that
   contains:
   - `link-canonical = always dontCheckDoJailbreak;`, commented that nixpkgs ships
     0.1.0.0 and its bounds cap `http-client-tls` and `generic-lens` below the stack
     pinned here, and that rei's `cabal.project` carries the matching `allow-newer`;
   - `hw-kafka-client = always dontCheckDoJailbreak;`, commented that nixpkgs ships
     5.3.0 and its test suite needs a Kafka broker;
   - `servant-health = always (import ../patches/servant-health/0.1.nix);`;
   - `generic-lens-core = always (import ../patches/generic-lens-core/2.3.nix);`;
   - `generic-lens = always (import ../patches/generic-lens/2.3.nix);`, commented that
     nixpkgs ships 2.2.x, Cabal selects 2.3.0.0 for every application, Baikai needs
     `>=2.3`, and IR-2 asks for it.
4. Add a section headed `# ── typeid-hs (public topagentnetwork source; not on Hackage) ──`
   that contains:
   - `typeid-hs-sql = always (import ../patches/typeid-hs/sql.nix);`
   - `typeid-hs-pg-migrate = always (import ../patches/typeid-hs/pg-migrate.nix);`

   commented that both packages build from `topagentnetwork/typeid-hs` at `7164a74c`,
   the revision the applications' `cabal.project` files pin with
   `source-repository-package`, and that the two must move together.

Create three files for the `typeid-hs` source pins, after confirming anonymous access
and the hash with the M2 command under Concrete Steps:

- `patches/typeid-hs/source.nix`, a function `{ pkgs, ... }:` returning
  `pkgs.fetchFromGitHub { owner = "topagentnetwork"; repo = "typeid-hs"; rev = "7164a74c490cc92ffe73a315d827c9515de125d3"; hash = "sha256-XCq5GXlOK8ZxbR4ZKIEi99rQdJ6vxX1c6/C3nRGvcrA="; }`.
  Its opening comment says the repository is public (anonymous access verified
  2026-09-26), is not on Hackage, and that this revision must equal the applications'
  Cabal tag.
- `patches/typeid-hs/sql.nix`:

  ```nix
  # typeid-hs-sql 0.1.0.0: source pin (not on Hackage). Plan 9's generated layer does not own it.
  { hself, haskellLib, pkgs, ... }@args:
  haskellLib.dontCheck (haskellLib.doJailbreak
    (hself.callCabal2nix "typeid-hs-sql" "${import ./source.nix args}/typeid-hs-sql" { }))
  ```

- `patches/typeid-hs/pg-migrate.nix`: the same shape for `typeid-hs-pg-migrate` and its
  subdirectory. Its `pg-migrate` dependency resolves to the channel's `pg-migrate`
  first-party family, and neither package depends on `effectful`, so the family's move
  to `effectful` 2.7 (plan 15) does not affect them.

Create four version-pin patch files. Each opens with a comment that says what it pins and why, and
includes this line, which plan 9 acts on:

```text
# Version pin: plan 9's generated layer owns this version once it exists; keep only the build policy then.
```

- `patches/wai-app-static/3.2.nix`: `dontCheck (doJailbreak (hself.callHackageDirect { pkg = "wai-app-static"; ver = "3.2.1"; sha256 = "sha256-HQP76brA2MwBVipRs2ZstY59nUMhzfJkw90Kaep2o9I="; } { }))`.
  That hash is the one mori-rei-app's deployed build already uses with
  `callHackageDirect`, so it is the unpacked hash.
- `patches/servant-health/0.1.nix`: the same shape, with `ver = "0.1.0.0"` and
  `sha256 = "sha256-new4jAeDaP1kzFkN0SB4FwVObZwV1zp3SlddGa2VRLw="` (rei's working
  `callHackageDirect` hash).
- `patches/generic-lens-core/2.3.nix`: `dontCheck (hself.callHackageDirect { pkg = "generic-lens-core"; ver = "2.3.0.0"; sha256 = <unpacked hash>; } { })`.
  Mina's `fetchTarball` hash was `sha256-Abntgf3UMhQed5gOc6sDoVilMc0FRRCh8VJCeoQfNRY=`.
  `fetchTarball` and `fetchzip` both hash the unpacked top directory, so the value
  should carry over; confirm it with the prefetch command under Concrete Steps.
- `patches/generic-lens/2.3.nix`: the same shape, with the expected hash
  `sha256-V8M8gkbrrLAsJ42IKa26HnU28sfljwUZuBiCJBV8ABs=`, confirmed the same way.

Mina applies no jailbreak to these two, so neither does the channel.

If M1 found that plan 9 already supplies one of these versions, write that entry as a
policy entry instead (for example `generic-lens = always dontCheckOnly;`) and create no
patch file.

Create `checks/shared-overrides.nix`. It takes
`{ lib, pkgs, defaultGhc, haskellExtension }`, where `pkgs` is the plain nixpkgs and
`haskellExtension` is `haskellExtensions.github`. It builds
`scope = pkgs.haskell.packages.${defaultGhc}.override { overrides = haskellExtension pkgs.haskell.lib.compose pkgs; }`
and declares a minimum-version table (the highest version any application selects
today):

- `link-canonical` 0.1.0.0, `servant-health` 0.1.0.0;
- `wai-app-static` 3.2.1, `servant-server` 0.20.3.0;
- `generic-lens` 2.3.0.0, `generic-lens-core` 2.3.0.0;
- `hw-kafka-client` 5.3.0, `blake3` 0.3.1;
- `openapi-hs` 5.0.0, `servant-openapi-hs` 5.1.0;
- `relay-pagination`, `relay-pagination-servant`, `relay-pagination-hasql` and
  `relay-pagination-conformance`, all 0.1.1.0;
- `hasql-notifications` 0.2.5.0;
- `thread-utils-finalizers` 0.1.1.0, `thread-utils-context` 0.4.1.0;
- `typeid-hs-sql` 0.1.0.0, `typeid-hs-pg-migrate` 0.1.0.0;
- every `hs-opentelemetry-*` name from mori's list at 1.0.0.0, except
  `hs-opentelemetry-semantic-conventions` at 1.40.0.0.

The check:

1. computes `belowMinimum = builtins.filter (n: !(lib.versionAtLeast scope.${n}.version table.${n})) (builtins.attrNames table)`;
2. computes `kiokuProfilingRedundant = scope.kioku-core.drvPath == (pkgs.haskell.lib.compose.disableLibraryProfiling scope.kioku-core).drvPath`;
3. asserts `belowMinimum == [ ] && kiokuProfilingRedundant`;
4. returns `pkgs.runCommand "shared-overrides" { buildInputs = map (n: scope.${n}) (builtins.attrNames table); passthru.results = { versions = ...; inherit belowMinimum kiokuProfilingRedundant; }; }`,
   which echoes the JSON results and touches `$out`.

Putting the packages in `buildInputs` is what forces each one to build, the same way
`checks/package-set-matrix.nix` forces first-party packages. `versionAtLeast` rather
than equality keeps the check green when plan 9 later moves a version up.

In `checks/default.nix`, add `haskellExtensions` to the argument set (and pass it from
`flake.nix` line ~229, where `checks` is imported). Then add
`shared-overrides = import ./shared-overrides.nix { inherit lib defaultGhc; pkgs = pkgsPlain; haskellExtension = haskellExtensions.github; };`.

Acceptance:

- `nix build .#checks.aarch64-darwin.shared-overrides` succeeds and prints versions at
  or above the table.
- `nix flake check` still passes.

Commit (see Concrete Steps for the message).

**Milestone 3: the consumer overlay audit.** At the end, two exist:

- a pure report function, unit-tested with nix-unit;
- a flake-library wrapper that consumers add to their own `checks`.

Running the report against the five current overlays reproduces the deletion lists
exactly: each list is that consumer's `shadowing` plus its `undeclared` names.

Create `lib/consumerOverlayReport.nix`:

```nix
# consumerOverlayReport ::
#   { channelPackages : [String]   # names the channel's registry defines
#   , overlayPackages : [String]   # names the consumer overlay defines
#   , ownPackages : [String]
#   , siblingPackages ? [String]   # other applications' libraries, until they are consumed from that application's flake
#   , exceptions ? { name = "non-empty reason"; }
#   } -> { shadowing; undeclared; unusedDeclarations; invalidDeclarations; ok; }
{ lib }:
{ channelPackages, overlayPackages, ownPackages, siblingPackages ? [ ], exceptions ? { },
  generatedPackages ? [ ], frozenPackages ? [ ], sourcePackages ? [ ], runtimePackages ? [ ] }:
```

It computes the following, each a sorted list:

- `shadowing`: overlay names that are also channel names. Declaring such a name in any
  list does not excuse it; shadowing is never allowed.
- `undeclared`: overlay names neither channel-owned nor declared in `ownPackages`,
  `siblingPackages` or `attrNames exceptions`. Channel-owned offenders are reported once
  as shadowing.
- `unusedDeclarations`: declared names the overlay no longer defines. These keep
  declarations honest after a deletion.
- `invalidDeclarations`: exceptions with an empty or non-string reason, and names that
  appear in more than one declaration list.

`ok` is true when all four lists are empty.

In `flake.nix`'s `let` block, import it and add two library outputs next to
`mkChannelExtension`:

- `consumerOverlayReport = { pkgs, overlay, ownPackages, siblingPackages ? [ ], exceptions ? { }, registry ? registries.github, ghc ? defaultGhc }: ...`.
  It builds `scope = pkgs.haskell.packages.${ghc}.override { overrides = haskellExtensions.github pkgs.haskell.lib.compose pkgs; }`,
  sets `overlayPackages = builtins.attrNames (overlay scope scope)` and
  `channelPackages = builtins.attrNames registry`, and returns the pure report.
  - Only the attribute *names* of `overlay scope scope` are forced. Taking `attrNames`
    of the overlay's result does not evaluate its values, so no consumer source is
    fetched and no package is built.
- `auditConsumerOverlay = args: let r = consumerOverlayReport args; in if r.ok then args.pkgs.runCommand "consumer-overlay-audit" { passthru.results = r; } "touch $out" else throw "<message>"`.
  The message has one line per non-empty list, for example:

  ```text
  consumer overlay audit failed:
    shadows channel packages (delete them; the channel owns them): link-canonical, wai-app-static
    defines undeclared packages (declare as own/sibling/exception or move to the channel): kdl-hs
  ```

Export both under `flake.lib`.

Add nix-unit tests to `checks/unit.nix`, each calling `lib/consumerOverlayReport.nix`
directly with literal lists:

- `testConsumerOverlayClean`: own names only, so `ok = true`.
- `testConsumerOverlayShadowing`: an overlay name in `channelPackages` appears in
  `shadowing`.
- `testConsumerOverlayShadowingNotExcused`: the same name, also declared as an
  exception, is still in `shadowing`.
- `testConsumerOverlayUndeclared`.
- `testConsumerOverlayUnusedDeclaration`.
- `testConsumerOverlayEmptyReason`: `exceptions = { x = ""; }` appears in
  `invalidDeclarations`.

Add a fixture overlay at `checks/fixtures/consumer-overlays/clean.nix`, a function
`{ pkgs }: final: prev: { consumer-overlay-example = final.callCabal2nix "package-set-consumer" ../package-sets/consumer { }; }`
that reuses the existing consumer fixture source. Then add a flake check to
`checks/default.nix`:
`consumer-overlay-audit = auditConsumerOverlay { pkgs = pkgsPlain; overlay = import ./fixtures/consumer-overlays/clean.nix { pkgs = pkgsPlain; }; ownPackages = [ "consumer-overlay-example" ]; }`.
Thread `auditConsumerOverlay` into `checks/default.nix`'s arguments from `flake.nix`.

Then run the report against the five real overlays with the scratch expression under
Concrete Steps, and record the five reports in Surprises & Discoveries. Each
consumer's `shadowing` plus `undeclared` must equal its deletion list from Context and
Orientation. Read the lists with these points in mind:

- mori's `shibuya-pgmq-adapter` does shadow; its deletion list keeps the plan 9
  precondition;
- mori's `hasql-effectful` and mina's `kdl-hs` are reported as `undeclared`, because
  the channel defines neither and neither is declared. That is correct: both are
  conditional deletions (plan 12's vendoring, plan 13's bound lift), not exceptions.
  Do not declare them to make the report green;
- mori's `hw-kafka-client`, the `link-canonical` entries and all `typeid-hs-*` entries
  appear in `shadowing` only once M2's entries exist;
- mina's `mori-schema-pin`, the one class-(d) exception, must not appear anywhere once
  declared.

Acceptance:

- `just nix-test` passes.
- `nix build .#checks.aarch64-darwin.consumer-overlay-audit` succeeds.
- The five reports match the deletion lists as described above, and only mina declares
  an exception.

Commit.

**Milestone 4: rehearse the consumer deletions without editing any consumer.** At the
end you have diagnosed the deletion lists against the existing consumer sources. Shared
registry builds prove channel policy; consumer source incompatibilities are recorded for
plans 11–13, whose final builds prove safe adoption. You also know
its derivation closure contains the expected versions. This is evidence for plans 11
and 12. Nothing is committed in any consumer.

For rei, mori and mori-rei-app, build the application's package from a scratch
expression (Concrete Steps). The expression:

1. imports the consumer's flake with `builtins.getFlake "git+file://<checkout>?rev=<HEAD>"`
   to obtain its remaining source inputs (rei needs none, because its only source
   argument is `typeid-hs-src`; its own packages are read from the checkout, which must
   be clean at the named HEAD);
2. imports the consumer's `nix/haskell-overlay.nix` with those inputs, except
   `typeid-hs-src`, which it replaces with the dummy string `"/dev/null"`. The filtered
   overlay never reads it, so a successful build proves the `typeid-hs` packages come
   from the channel's source pin and that the input really is unnecessary;
3. wraps it as `final: prev: builtins.removeAttrs (overlay final prev) deletions`;
4. composes it after this repository's `lib.haskellExtensions.github`, obtained with
   `builtins.getFlake "path:/Users/shinzui/Keikaku/bokuno/haskell-nix"` so uncommitted
   work is included;
5. builds the application's package.

For mori, keep `shibuya-pgmq-adapter` out of `deletions` unless plan 9 has already moved
the channel. Likewise keep `hasql-effectful` out of `deletions` unless the mori revision
you rehearse already contains plan 12's vendored `Effectful.Hasql` module; the channel
has no `hasql-effectful` of the right generation (nixpkgs' Hackage 0.1.0.0 is a
different, hasql-1.9-era source), so deleting the entry early fails `mori-core`'s build.
While it is kept, pass the real `tan-effectful-src`, which is still private and needs
your GitHub credentials. After each build, list versions from the derivation closure. The runtime
closure of a Haskell executable does not reference static Haskell libraries, so do not
use it.

Mina is a cohort behind this channel (Baikai 0.6), so a build here would fail for
reasons plan 13 owns. For mina, only evaluate the filtered overlay and confirm that
`generic-lens` and `generic-lens-core` resolve to 2.3.0.0 from the channel. Reiko has
nothing to delete.

Acceptance:

- the channel shared-override builds succeed; pre-adoption application rehearsal outcomes
  are recorded, and any source/bounds failures are assigned to plans 11–13;
- the rei and mori-rei-app closures contain `wai-app-static-3.2.1` and
  `generic-lens-2.3.0.0` derivations and no `wai-app-static-3.1.9.1`;
- `openapi-hs-5.0.0` in the rei closure is built from the channel's GitHub source;
- the rei, mori and mori-rei-app closures contain `typeid-hs-sql-0.1.0.0` and
  `typeid-hs-pg-migrate-0.1.0.0` derivations even though `typeid-hs-src` was a dummy;
- mina's evaluation prints 2.3.0.0 for both packages.

If a failure is in shared policy, fix it here and rerun. If the consumer source or bounds
require its planned port, record the failing component for plans 11–13 without making their
work a prerequisite for this plan. Do not add back shared overrides to mask the failure.

**Milestone 5: record the rule and finish.**

Write the ADR as `docs/adr/4-consumer-overlays-define-only-their-own-packages.md` (the MasterPlan allocates 2 to plan 8 and 3 to plan 9; confirm with `ls docs/adr` that 4 is still free):

```bash
ls docs/adr/
```

Take the next integer after the highest existing prefix. Today only `1-…` exists, but
plans 8 and 9 each add one ADR, so expect 2, 3 or 4. Name it
`docs/adr/4-consumer-overlays-define-only-their-own-packages.md` and follow ADR 1's
shape exactly: a title line, then `Status:` and `Date:` lines, then `## Context`,
`## Decision`, `## Alternatives and consequences` and `## Validation`. Its content:

- **Context:**
  - the composition order that lets a consumer overlay win silently;
  - the 2026-09-26 inventory: 58 entries that are not the consumer's own code, 53 of them
    shared overrides, most of those duplicates;
  - how the two private sources were resolved: `typeid-hs` was made public and moved
    into the channel, and `hasql-effectful` is vendored by its only user;
  - the mori-rei-app hash divergence;
  - the thread-utils evidence that same-version duplicates still change derivations.
- **Decision:**
  - A consumer overlay defines only its own packages, declared siblings (until the
    sibling is consumed from its application's flake), and named exceptions with
    reasons.
  - It never defines a name the channel's registry defines.
  - A package a consumer needs at a version or with a policy the channel lacks is
    added to this repository, not to the consumer. A package not on Hackage is added
    as a source pin (a fixed `fetchFromGitHub` revision), as `typeid-hs` is.
  - A source the public channel cannot fetch is not a standing exception. It is
    resolved by publishing the source (as `typeid-hs` was) or by vendoring it into the
    one consumer that uses it (as mori does with `hasql-effectful`).
  - Declared exceptions are rare and each carries a reason. The only one today is
    mina's `mori-schema-pin` at mori `7af02c55`, held because moving it changes the
    Dhall mina writes into other repositories.
  - Enforcement: each consumer's `checks` include `lib.auditConsumerOverlay`.
  - Nested `*-src` input overrides remain allowed, per
    `mori://shinzui/mori/okf/adrs/concepts/ADR-24`'s 2026-09-13 amendment.
- **Alternatives and consequences:**
  - The rejected alternatives: keeping ADR-24's local-pin escape hatch; making the
    channel win the composition, which ADR-24 already rejected; review-only
    enforcement, which ADR-24 chose and which the inventory shows did not hold;
    new families for `servant-health`, `link-canonical` and `typeid-hs`, deferred
    because of ADR 1's catalog-migration rule; and keeping private sources as declared
    exceptions, which this plan first chose and then reversed once `typeid-hs` became
    public.
  - Consequences: any consumer that needs a new override must first change this
    repository and relock. A consumer that opts back into profiling must handle
    `kioku-core` itself.
- **Validation:** the `shared-overrides` and `consumer-overlay-audit` checks, and the
  M4 rehearsal results.
- Cite `mori://shinzui/mori/okf/adrs/concepts/ADR-24` as the ADR it extends, and link
  the MasterPlan by repository-relative path.

Update the user documentation. `docs/user` is an OKF bundle validated by
`just check-docs`, so keep each file's frontmatter.

- `docs/user/consumer-integration.md`:
  - In "Ordering", replace the sentence "If your local overlay needs to further modify
    a package that haskell-nix already patches, your version wins because it runs
    second." with the rule and a pointer to the ADR.
  - Add a section "Audit your local overlay" that shows the `checks` wiring. The usual
    case, rei after plan 11, declares only its own packages:

    ```nix
    checks.consumer-overlay-audit = inputs.haskell-nix.lib.auditConsumerOverlay {
      inherit pkgs;
      overlay = import ./nix/haskell-overlay.nix { inherit pkgs gitRev; };
      ownPackages = [ "rei-core" "rei-api" "rei-api-contract" "rei-api-client" "rei-cli" ];
    };
    ```

    Then show the exception form with the one real exception, mina's:

    ```nix
    checks.consumer-overlay-audit = inputs.haskell-nix.lib.auditConsumerOverlay {
      inherit pkgs;
      overlay = import ./nix/haskell-overlay.nix { inherit pkgs gitRev; /* sources */ };
      ownPackages = [ "mina-core" "mina-cli" ];
      exceptions = {
        mori-schema-pin = "held at mori 7af02c55; moving it changes the Dhall mina writes into other repositories";
      };
    };
    ```

  - Say in the same section that a package missing from Hackage is not a reason for a
    local entry: ask for a source pin in the channel, as `typeid-hs` has.

  - Note in the same section that `disableProfiling = false` reintroduces the
    `kioku-core` profiling panic on GHC 9.12.4.
- `docs/user/adding-patches.md`: add a short paragraph saying that a consumer's need
  for a third-party override is satisfied here, with the new patch files as examples:
  a version pin (`patches/wai-app-static/3.2.nix`) and a source pin
  (`patches/typeid-hs/`).
- `docs/user/channels.md`: after the "Current inventory" family table, add a sentence
  naming the new common-registry entries.
- `docs/user/log.md`: add an entry under a new dated heading, in the file's existing
  format (`## YYYY-MM-DD`, then `* **Addition**: …`).

Run `just check-docs` and `nix flake check`, then commit.

Finally, fill in Outcomes & Retrospective. It must restate the four deletion lists
(rei, mori, mori-rei-app, mina), the three conditional deletions with their conditions
(mori's `shibuya-pgmq-adapter` after plan 9, mori's `hasql-effectful` with plan 12's
vendoring, mina's `kdl-hs` after plan 13's bound lift), the flake inputs each deletion
frees, and mina's one declared exception, so that plans 11, 12 and 13 can copy them.


## Concrete Steps

Every command runs in `/Users/shinzui/Keikaku/bokuno/haskell-nix` unless stated
otherwise. Put scratch files in a scratch directory outside every repository, for
example `$TMPDIR/plan10`. Never read or search `/nix/store` directly; use
`nix eval`, `nix path-info` and `nix-store --query` on known paths.

M1, listing a consumer overlay's names and the channel's versions. Write
`$TMPDIR/plan10/inventory.nix`:

```nix
let
  hn = builtins.getFlake "path:/Users/shinzui/Keikaku/bokuno/haskell-nix";
  pkgs = import hn.inputs.nixpkgs { system = "aarch64-darwin"; };
  scope = pkgs.haskell.packages.ghc9124.override {
    overrides = hn.lib.haskellExtensions.github pkgs.haskell.lib.compose pkgs;
  };
  dummy = "/dev/null"; # attribute names never force source arguments
  # These are the overlays' argument sets at the HEADs named in Progress. After plans 11
  # and 12 delete the typeid-hs and hasql-effectful entries, the `typeid-hs-src` and
  # `tan-effectful-src` arguments disappear; drop them here when that happens, or the
  # import fails with "called with unexpected argument".
  overlays = {
    rei = import /Users/shinzui/Keikaku/bokuno/rei-project/rei/nix/haskell-overlay.nix {
      inherit pkgs; gitRev = "0000000"; typeid-hs-src = dummy; };
    mori = import /Users/shinzui/Keikaku/bokuno/mori-project/mori/nix/haskell-overlay.nix {
      inherit pkgs; gitRev = "0000000"; tan-effectful-src = dummy; typeid-hs-src = dummy;
      mori-schema-src = dummy; openapi-hs-src = dummy; servant-openapi-hs-src = dummy;
      servant-health-src = dummy; };
    mori-rei-app = import /Users/shinzui/Keikaku/bokuno/mori-project/mori-rei-app/nix/haskell-overlay.nix {
      inherit pkgs; mori-src = dummy; mori-app-src = dummy; rei-src = dummy; typeid-hs-src = dummy; };
    reiko = import /Users/shinzui/Keikaku/bokuno/rei-project/reiko/nix/haskell-overlay.nix {
      inherit pkgs; gitRev = "0000000"; reiko-ui = dummy; };
    mina = import /Users/shinzui/Keikaku/bokuno/mina/nix/haskell-overlay.nix {
      inherit pkgs; gitRev = "0000000"; mina-ui = dummy; mori-src = dummy; };
  };
  version = n: let r = builtins.tryEval (scope.${n}.version or "absent"); in if r.success then r.value else "eval-error";
in {
  names = builtins.mapAttrs (_: o: builtins.attrNames (o scope scope)) overlays;
  channelVersions = pkgs.lib.genAttrs [ "link-canonical" "servant-health" "wai-app-static"
    "servant-server" "generic-lens" "generic-lens-core" "hw-kafka-client" "kdl-hs"
    "shibuya-pgmq-adapter" "thread-utils-context" "typeid-hs-sql" "typeid-hs-pg-migrate"
    ] version;
}
```

Run it:

```bash
nix eval --json --impure -f "$TMPDIR/plan10/inventory.nix" | jq .
```

Before M2, expect 17 names for rei, 37 for mori, 9 for mori-rei-app, 2 for reiko and 6
for mina, and channel versions like:

```text
"link-canonical": "0.1.0.0", "servant-health": "absent", "wai-app-static": "3.1.9.1",
"generic-lens": "2.2.2.0", "hw-kafka-client": "5.3.0", "kdl-hs": "1.1.0",
"shibuya-pgmq-adapter": "0.16.0.0", "typeid-hs-sql": "absent", "typeid-hs-pg-migrate": "absent"
```

After M2, the same run must print `servant-health` 0.1.0.0, `wai-app-static` 3.2.1,
`generic-lens` 2.3.0.0, and 0.1.0.0 for both `typeid-hs` packages.

M2, confirming that `typeid-hs` is fetchable without credentials and that its hash is
the one the consumers lock. Run it with GitHub tokens suppressed, so a success cannot
come from your own access:

```bash
env -u GITHUB_TOKEN -u GH_TOKEN nix --option access-tokens "" flake prefetch --json \
  github:topagentnetwork/typeid-hs/7164a74c490cc92ffe73a315d827c9515de125d3 | jq -r .hash
```

Expected output:

```text
sha256-XCq5GXlOK8ZxbR4ZKIEi99rQdJ6vxX1c6/C3nRGvcrA=
```

This is the `narHash` recorded for `typeid-hs-src` in the rei, mori and mori-rei-app
`flake.lock` files, and the value `patches/typeid-hs/source.nix` uses. If the command
fails with HTTP 404 or an authentication error, the repository is no longer public:
stop, record it in Surprises & Discoveries, and ask the user, because the decision to
move `typeid-hs` into the public channel depends on it.

M2, confirming the `generic-lens` hashes. The output of `nix-prefetch-url --unpack` is
base32; convert it to SRI form and compare it with the hash written in the patch:

```bash
for p in generic-lens-core generic-lens; do
  h=$(nix-prefetch-url --unpack "https://hackage.haskell.org/package/$p-2.3.0.0/$p-2.3.0.0.tar.gz")
  nix hash convert --hash-algo sha256 --to sri "$h"
done
```

Expected output:

```text
sha256-Abntgf3UMhQed5gOc6sDoVilMc0FRRCh8VJCeoQfNRY=
sha256-V8M8gkbrrLAsJ42IKa26HnU28sfljwUZuBiCJBV8ABs=
```

If either differs, use the printed value. A wrong hash fails at build time with
`hash mismatch in fixed-output derivation`, and that message names the correct value.

M2, building the new check:

```bash
nix build --print-build-logs .#checks.aarch64-darwin.shared-overrides
nix eval --json .#checks.aarch64-darwin.shared-overrides.passthru.results | jq '{belowMinimum, kiokuProfilingRedundant}'
```

Expected output:

```text
{ "belowMinimum": [], "kiokuProfilingRedundant": true }
```

If an x86_64-linux builder is configured (ADR 1 records one), also run:

```bash
nix build .#checks.x86_64-linux.shared-overrides
```

Otherwise, record in Progress that Linux evidence is pending.

M2 commit:

```text
feat(registry): own the shared application overrides in the channel

Add wai-app-static 3.2.1, servant-health 0.1.0.0 and generic-lens(-core)
2.3.0.0 pins, policy entries for link-canonical, hw-kafka-client and
servant-server, and source pins for typeid-hs-sql and typeid-hs-pg-migrate
from the now-public topagentnetwork/typeid-hs at 7164a74c, which the
consumer overlays each carried locally. The shared-overrides check builds
them through the default set.

MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

M3, running the report against the real overlays. Extend `inventory.nix` with a
`reports` attribute that calls `hn.lib.consumerOverlayReport` once per consumer, passing
`overlay`, `pkgs` and these declarations:

- **rei:** own `rei-core rei-api rei-api-contract rei-api-client rei-cli`; no siblings, no exceptions.
- **mori:** own `mori-types mori-schema-pin mori-core mori-api mori-cli`; no
  exceptions (`hasql-effectful` is deliberately left undeclared).
- **mori-rei-app:** own `mori-rei-app`; siblings `mori-types mori-app rei-core`; no
  exceptions.
- **reiko:** own `reiko-core reiko-cli`.
- **mina:** own `mina-core mina-cli`; exception
  `mori-schema-pin = "held at mori 7af02c55; moving it changes the Dhall mina writes into other repositories"`
  (`kdl-hs` is deliberately left undeclared).

Then run:

```bash
nix eval --json --impure -f "$TMPDIR/plan10/inventory.nix" --apply 'x: builtins.mapAttrs (_: r: { inherit (r) ok shadowing undeclared; }) x.reports' | jq .
```

Expected output, abbreviated:

```text
"mina":  { "ok": false, "shadowing": ["generic-lens","generic-lens-core"], "undeclared": ["kdl-hs"] }
"mori-rei-app": { "ok": false, "shadowing": ["link-canonical","servant-server","typeid-hs-pg-migrate","typeid-hs-sql","wai-app-static"], "undeclared": [] }
"reiko": { "ok": true, "shadowing": [], "undeclared": [] }
"rei":   { "ok": false, "shadowing": [ 14 names = rei's deletion list ], "undeclared": [] }
"mori":  { "ok": false, "shadowing": [ 31 names = mori's deletion list less hasql-effectful ], "undeclared": ["hasql-effectful"] }
```

No report may show `mori-schema-pin` anywhere, and `unusedDeclarations` and
`invalidDeclarations` must be empty for all five.

M3 checks and commit:

```bash
just nix-test
nix build .#checks.aarch64-darwin.consumer-overlay-audit
```

```text
feat(lib): audit consumer overlays against the channel

lib.auditConsumerOverlay fails when a consumer overlay redefines a package
the channel provides or defines one it has not declared as its own, a
sibling application's library, or a reasoned exception. The only exception
any consumer declares is mina's mori-schema-pin.

MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

M4, the rei rehearsal. `$TMPDIR/plan10/rehearse-rei.nix`:

```nix
let
  hn = builtins.getFlake "path:/Users/shinzui/Keikaku/bokuno/haskell-nix";
  pkgs = import hn.inputs.nixpkgs { system = "aarch64-darwin"; };
  deletions = [ "typeid-hs-sql" "typeid-hs-pg-migrate"
    "link-canonical" "kioku-core" "openapi-hs" "servant-openapi-hs" "servant-health"
    "hs-opentelemetry-instrumentation-wai" "hs-opentelemetry-sdk" "hs-opentelemetry-exporter-otlp"
    "relay-pagination" "relay-pagination-servant" "relay-pagination-hasql" "relay-pagination-conformance" ];
  # typeid-hs-src is a dummy: the filtered overlay never reads it, so the typeid-hs
  # packages can only come from the channel's source pin. Rei's overlay at 880093cc has
  # no other source argument, so rei's own flake inputs are not needed.
  overlay = import /Users/shinzui/Keikaku/bokuno/rei-project/rei/nix/haskell-overlay.nix {
    inherit pkgs; gitRev = "880093c"; typeid-hs-src = "/dev/null"; };
  filtered = final: prev: builtins.removeAttrs (overlay final prev) deletions;
  hp = pkgs.haskell.packages.ghc9124.override {
    overrides = pkgs.lib.composeExtensions
      (hn.lib.haskellExtensions.github pkgs.haskell.lib.compose pkgs) filtered;
  };
in { inherit (hp) rei-cli rei-api; }
```

Build it and read the versions:

```bash
nix build --impure --no-link --print-out-paths -f "$TMPDIR/plan10/rehearse-rei.nix" rei-cli rei-api
drv=$(nix eval --impure --raw -f "$TMPDIR/plan10/rehearse-rei.nix" rei-cli.drvPath)
nix-store --query --requisites "$drv" | grep -E -- '-(wai-app-static|generic-lens|openapi-hs|servant-health|link-canonical|typeid-hs-sql|typeid-hs-pg-migrate)-[0-9.]+\.drv$'
```

Expect `wai-app-static-3.2.1.drv`, `generic-lens-2.3.0.0.drv`, `openapi-hs-5.0.0.drv`,
`servant-health-0.1.0.0.drv`, `link-canonical-0.1.0.0.drv`,
`typeid-hs-sql-0.1.0.0.drv` and `typeid-hs-pg-migrate-0.1.0.0.drv` across the two
derivations (`rei-core` depends on both `typeid-hs` packages). `rei-cli` does not depend on `rei-api`, so the HTTP packages
(`servant-health`, `wai-app-static`) appear only in `rei-api`'s closure; run the same
query on `rei-api.drvPath`.

The mori and mori-rei-app rehearsals have the same shape:

- **mori:** `getFlake` of `git+file:///Users/shinzui/Keikaku/bokuno/mori-project/mori?rev=f3c5fa4b...`
  (full hash from `git -C … rev-parse HEAD`). Pass the five source inputs other than
  `typeid-hs-src` from the flake, and `typeid-hs-src = "/dev/null"`. Use mori's
  deletion list, keeping out `shibuya-pgmq-adapter` unless plan 9 has landed and
  `hasql-effectful` unless plan 12's vendoring is in the rehearsed revision (in which
  case the overlay no longer takes `tan-effectful-src` either). Build `mori-cli`. While
  `hasql-effectful` is kept, `tan-effectful-src` is the one private fetch, so it needs
  your GitHub credentials (netrc or `gh auth`), as mori's own build does.
- **mori-rei-app:** its three sibling source inputs (`mori-src`, `mori-app-src`,
  `rei-src`) from the flake, `typeid-hs-src = "/dev/null"`, and its 5-entry deletion
  list; build `mori-rei-app`.

Run these builds one at a time; each compiles a large closure from source.

M5 commit:

```text
docs(adr): consumer overlays define only their own packages

Record the rule that extends mori ADR-24 to every package, the audit that
enforces it, and the deletion lists plans 11 to 13 apply.

MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

Only the user pushes to `github:shinzui/haskell-nix`. Consumers (plans 11 to 13) need
the pushed revision in their `flake.lock` before they can delete entries, so ask for
the push when M5 is committed.


## Validation and Acceptance

The review requirements above are additional completion gates, including the assigned update-isolation, manifest and cache evidence. Historical runtime-closure/version tables are diagnostic evidence only; they cannot replace those gates.

The plan is complete when all of the following hold.

1. `nix build .#checks.aarch64-darwin.shared-overrides` succeeds. Its
   `passthru.results.belowMinimum` is `[]` and `kiokuProfilingRedundant` is `true`.
   - This proves every moved package builds through the default set, at or above the
     version any application selects.
   - Remove the `servant-health` registry entry temporarily and the check fails at
     evaluation with `attribute 'servant-health' missing` (nixpkgs has no such
     package). That demonstrates the check really depends on the new entry. Restore
     the entry afterwards.
2. `just nix-test` passes, including the six new `testConsumerOverlay*` cases.
   `nix build .#checks.aarch64-darwin.consumer-overlay-audit` succeeds.
3. The M3 report over the five real overlays gives each consumer `shadowing` plus
   `undeclared` equal to its deletion list in Context and Orientation. Reiko is `ok`.
   - This is the plan's central proof: the audit sees exactly what plans 11 to 13 must
     delete, and nothing more.
   - Calling `lib.auditConsumerOverlay` on mori-rei-app's current overlay fails with
     the `shadows channel packages … link-canonical, servant-server,
     typeid-hs-pg-migrate, typeid-hs-sql, wai-app-static` message.
   - Mori's `undeclared` is exactly `hasql-effectful` and mina's is exactly `kdl-hs`;
     mina's `mori-schema-pin` is the only declared exception in any report.
4. The M4 rehearsal builds of `rei-cli`, `rei-api`, `mori-cli` and `mori-rei-app`
   succeed with the deletion lists removed.
   - Their derivation closures show `wai-app-static-3.2.1` and
     `generic-lens-2.3.0.0` where those packages are used, and `typeid-hs-sql` and
     `typeid-hs-pg-migrate` 0.1.0.0 although `typeid-hs-src` was a dummy.
   - The anonymous `nix flake prefetch` of `topagentnetwork/typeid-hs` at `7164a74c`
     (Concrete Steps, M2) prints the locked hash, proving the public channel can fetch
     it.
   - Mina's filtered evaluation prints 2.3.0.0 for `generic-lens` and
     `generic-lens-core`.
5. `nix flake check` passes, including `registry-valid`, `overlay-eval` and the
   existing matrices.
6. `just check-docs` passes. The new ADR exists at `docs/adr/4-consumer-overlays-define-only-their-own-packages.md`.

Record each result, with the short transcript that proves it, in Progress and in
Outcomes & Retrospective.


## Idempotence and Recovery

Every step is additive or a scratch evaluation, and all can be rerun.

- The M1 and M3 evaluations and the M4 rehearsals write nothing outside the Nix store
  and the scratch directory. They never edit a consumer.
- Rerunning M2 or M3 after a partial edit is safe: the registry is a plain attribute
  set, and a duplicate attribute is a Nix evaluation error that names the line.
- To abandon a milestone before committing, run `git restore overlays/registry.nix checks/ lib/ flake.nix`
  and `git clean -n patches/` (then `-f` once the listing is only this plan's new
  directories).
- Never touch `flake.lock` or `packages/first-party-lock.json` in this plan. If a
  `haskell-nix-update refresh` is running in another session, wait for it to finish
  before committing, because the updater requires committed lock files and restores
  them on failure.
- If plan 9 lands while this plan is in progress, rebase onto it:
  - Where plan 9's generated layer supplies `wai-app-static`, `servant-health` or
    `generic-lens(-core)`, delete this plan's patch file and keep a policy entry
    (`dontCheckDoJailbreak` or `dontCheckOnly`).
  - `shared-overrides` uses `versionAtLeast`, so it stays valid.
- If this plan lands first, plan 9 owns converting those four patch files. The
  `# Version pin: plan 9's generated layer owns this version…` comment marks them.
- A rehearsal build failure in M4 means a channel entry is wrong. Fix the channel. Do
  not restore the consumer entry, because that is the shadowing this plan removes. The
  one exception is mori's `hasql-effectful`: a failure there means plan 12's vendoring
  has not landed, so keep that entry out of `deletions` and rerun.
- A `hash mismatch in fixed-output derivation` for `patches/typeid-hs/source.nix` means
  the revision or hash was mistyped; the message names the correct hash. The
  `typeid-hs` source pins are not Hackage versions, so plan 9 must leave them in place
  when it converts version pins to policy.


## Interfaces and Dependencies

Runtime integration: Plan 16 (`docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md`) will publish retained runtime ownership and source/policy records. Define the overlay audit so it can accept an explicit set of runtime-owned transitive packages/source components in addition to the existing registry/generated/freeze ownership. The baseline audit works before plan 16 exists; that later plan supplies the retained records and extends its fixtures. An application cannot declare a runtime-owned dependency as its own to evade the audit. Keep shared source/policy definitions centralized here; plan 16 captures immutable effective recipes for a generation, including Kafka forks/adapters outside the current family catalog, without copying them into consumer overlays.

At the end of this plan these exist in `mori://shinzui/haskell-nix`.

Registry entries in `overlays/registry.nix`:

- Version pins: `wai-app-static` (to `patches/wai-app-static/3.2.nix`), `servant-health`
  (`patches/servant-health/0.1.nix`), `generic-lens-core`
  (`patches/generic-lens-core/2.3.nix`) and `generic-lens`
  (`patches/generic-lens/2.3.nix`).
- Policy only: `link-canonical`, `hw-kafka-client` and `servant-server`, each
  `always dontCheckDoJailbreak`.
- Source pins also include `hs-opentelemetry-instrumentation-servant` at the retained
  Cabal revision `7a6f692e85295f965cd1827f9354c28af9e62742`, in
  `patches/hs-opentelemetry-instrumentation-servant/source.nix`.
- Source pins: `typeid-hs-sql` (to `patches/typeid-hs/sql.nix`) and
  `typeid-hs-pg-migrate` (to `patches/typeid-hs/pg-migrate.nix`), both built with tests
  off and jailbroken from `patches/typeid-hs/source.nix`, a `pkgs.fetchFromGitHub` of
  public `topagentnetwork/typeid-hs` at `7164a74c490cc92ffe73a315d827c9515de125d3`
  with `hash = "sha256-XCq5GXlOK8ZxbR4ZKIEi99rQdJ6vxX1c6/C3nRGvcrA="`.

Each patch file is a function of `{ hself, haskellLib, ... }` returning a derivation,
like `patches/claude/1.5.nix` (version pins) and `patches/codd/0.1.nix` (source pins).
`patches/typeid-hs/source.nix` is not a registry patch; it is a helper both
`typeid-hs` patch files import. None of these entries carries an `effectful` bound, so
the family's move to `effectful` 2.7 (plan 15) needs nothing from them.

`lib/consumerOverlayReport.nix`:

```nix
{ lib }:
{ channelPackages, overlayPackages, ownPackages, siblingPackages ? [ ], exceptions ? { },
  generatedPackages ? [ ], frozenPackages ? [ ], sourcePackages ? [ ], runtimePackages ? [ ] }:
{ shadowing = [ /* String */ ]; undeclared = [ ]; unusedDeclarations = [ ];
  invalidDeclarations = [ ]; ok = true; }
```

Flake library outputs (`flake.lib`):

```nix
consumerOverlayReport :: { pkgs, overlay, ownPackages, siblingPackages ? [], exceptions ? {},
                           registry ? registries.github, ghc ? defaultGhc, generatedPackages ? [],
                           frozenPackages ? [], sourcePackages ? [], runtimePackages ? [] } -> Report
auditConsumerOverlay  :: same arguments -> derivation "consumer-overlay-audit" (throws when not ok)
```

`overlay` is the consumer's already-applied `final: prev: { … }` function, the same
value it passes as the second argument of `composeExtensions`.

Flake checks, added to `checks/default.nix`:

- `shared-overrides`, from `checks/shared-overrides.nix`, taking
  `{ lib, pkgs, defaultGhc, haskellExtension }`;
- `consumer-overlay-audit`, over `checks/fixtures/consumer-overlays/clean.nix`.

Nix-unit tests are added in `checks/unit.nix`.

A new ADR, `docs/adr/4-consumer-overlays-define-only-their-own-packages.md`.

Dependencies and hand-offs:

- **Plan 9** must supply its generated/frozen/source ownership name records to the
  existing audit wrapper; **plan 16** supplies retained `runtimePackages`. Neither
  creates a second ownership audit.
- **Plan 9**
  (`docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md`)
  is a soft dependency.
  - Its generated layer supplies versions. After it lands, `overlays/registry.nix` and
    `patches/*` carry only build policy.
  - It must convert this plan's four version pins if this plan lands first. It must
    leave the two `typeid-hs` source pins alone: they are not Hackage versions and are
    not in `cabal/cohort.freeze`. Its parity guard should compare their revision with
    the applications' `source-repository-package` tag instead.
  - It must move `shibuya-pgmq-adapter` to at least 0.16.1.0 before mori's deletion of
    that entry.
  - Its parity script should consider reusing `lib/consumerOverlayReport.nix`'s idea of
    "names the channel owns".
- **Plan 8** should record two items in its report:
  - mina's `kdl-hs ^>=1.0` cap against nixpkgs' 1.1.0;
  - the Cabal `dhall -use-http-client-tls` flag in rei and mori-rei-app, which
    contradicts the channel's policy of keeping that flag on.
- **Plan 15**
  (`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`) releases
  `keiro`, `kioku-core`, `shikumi`, `shikumi-trace` and `shikumi-cache` admitting
  `effectful >=2.7.1.1`, and plan 8 hard-depends on it. This plan moves no package with
  an `effectful` bound. The move is one more reason `hasql-effectful`, which caps
  `effectful` below 2.6, is vendored by mori rather than carried by the channel.
- **Plan 11** applies:
  - rei's refreshed 16 deletions and mori-rei-app's 5;
  - removal of the `typeid-hs-src` flake input and overlay argument in both
    repositories, once their lock's channel revision contains this plan's `typeid-hs`
    entries at `7164a74c` (the same tag as `cabal.project`);
  - `checks.consumer-overlay-audit` in both repositories, with rei and mori-rei-app's
    declarations from Concrete Steps (no exceptions);
  - rei-core's move from a sibling entry to Rei's flake output, which then leaves
    mori-rei-app's sibling list.
- **Plan 12** applies:
  - mori's 32 deletions (with the `shibuya-pgmq-adapter` precondition, and
    `hasql-effectful` only in or after the change that vendors `Effectful.Hasql` into
    `mori-core`);
  - removal of the `typeid-hs-src`, `tan-effectful-src`, `openapi-hs-src`,
    `servant-openapi-hs-src` and `servant-health-src` flake inputs and overlay
    arguments, and of the `callHackageNoCheck` helper;
  - mori's audit check, with no exceptions.
- **Plan 13** applies:
  - mina's `generic-lens(-core)` deletions;
  - the `kdl-hs` bound lift followed by its deletion;
  - mina's and reiko's audit checks, mina's declaring `mori-schema-pin` as its one
    exception.
- **MasterPlan owner:** the MasterPlan's Integration Points and Decision Log still name
  the private `typeid-hs` and `hasql-effectful` sources as declared exceptions. They
  should be updated to the three user decisions of 2026-09-26 in this plan's Decision
  Log.
- **Tools:** Nix with flakes; `nix-unit` (already in the dev shell and in the
  `nix-unit` check); `jq`; `nix-prefetch-url`; `just`; `okf` for `just check-docs`.
  Nothing new is introduced.


## Revision Notes

- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The ADR is fixed as `docs/adr/4-consumer-overlays-define-only-their-own-packages.md` under the MasterPlan's allocation (plan 8 takes 2, plan 9 takes 3). The MasterPlan's Integration Points now match this plan's scope: most overrides are duplicates for consumers to delete, and the private `typeid-hs`/`hasql-effectful` sources and mina's `mori-schema-pin` are declared exceptions.
- 2026-09-26 (user decisions on the private sources): `topagentnetwork/typeid-hs` was made public (anonymous `git ls-remote` returns `HEAD` `7164a74c`; the GitHub API answers 200 without credentials), so `typeid-hs-sql` and `typeid-hs-pg-migrate` move into the channel as source-pinned registry entries (`patches/typeid-hs/`, a `fetchFromGitHub` at `7164a74c`, not a new first-party family because ADR 1 requires a catalog migration for that), and rei, mori and mori-rei-app delete both entries and their `typeid-hs-src` input. `hasql-effectful` is used only by mori, so plan 12 vendors it into `mori-core`; mori's deletion list now includes it and `tan-effectful-src`, conditioned on that vendoring landing first or in the same change. Mina's `mori-schema-pin` at mori `7af02c55` is now the only declared exception (reclassified from sibling), and mina's `kdl-hs` is a conditional deletion reported as `undeclared`, not an exception. Updated throughout: Purpose (53 shared overrides), Progress, Surprises (typeid-hs public, hasql-effectful mori-only), Decision Log (old exception decision marked superseded; three user decisions added), the inventory's classes and counts (rei 14, mori 32, mori-rei-app 5), the deletion lists and freed flake inputs, M2's registry and patch steps and the anonymous-prefetch step, the audit's declarations and expected report (deletion list = `shadowing` + `undeclared`), the M4 rehearsals (dummy `typeid-hs-src`), the ADR's decision text, the consumer-integration example, Validation, Idempotence, and the hand-offs to plans 9, 11, 12, 13 and 15 and to the MasterPlan owner. The family's move to `effectful` 2.7 (plan 15) is noted where it matters: no moved package has an `effectful` bound, and `hasql-effectful`'s `<2.6` cap is one more reason to vendor it.

- 2026-10-04: MasterPlan review for reducing change time: clarified shared ownership and acceptance, added the applicable targeted-update/build-identity/cache contracts, and corrected historical assumptions. No implementation completion is claimed.

- 2026-10-04 (runtime workstream): Added EP-16 integration, ownership and applicable acceptance; consumer adoption now requires the retained runtime set and composes application selections/packages onto it. Shared-tool preparation remains acyclic and the fleet advisory policy is preserved.

- 2026-10-05 (parallel implementation checkpoint): Added current shared policy/source pins,
  the ownership report and wrapper with runtime/cohort inputs, 11 unit tests, build/audit
  fixtures, ADR 4 and validated reader documentation. Refreshed Rei's inventory and
  recorded remaining compilation/integration gates explicitly. No completion is claimed.
