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
application's own code, 47 of them overrides of shared packages. Most of those duplicate
what the channel already supplies; a few supply something the channel lacks. Either way, two applications that
pin the same channel revision still build different derivations of the same library. On
2026-09-26 that is how mori-rei-app's `wai-app-static` 3.2.1 and `servant-server`
jailbreak changed the hash of everything above them up to `rei-core`.

After this plan:

- Every shared override has exactly one home, this repository's channel.
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


## Progress

- [ ] M1: Re-verify the inventory against each consumer's current HEAD (rei `880093cc`, mori `f3c5fa4b`, mori-rei-app `2acd4ed`, reiko `4f98ba9`, mina `6a4b3f9`) and record any drift in Surprises & Discoveries.
- [ ] M1: Re-evaluate the channel's current versions of the contested packages. If plan 9's generated version layer has landed, record which moved packages it already supplies.
- [ ] M2: Add policy-only registry entries for `link-canonical`, `hw-kafka-client` and `servant-server`.
- [ ] M2: Add version-pinned patches for `wai-app-static` 3.2.1, `servant-health` 0.1.0.0, `generic-lens-core` 2.3.0.0 and `generic-lens` 2.3.0.0. If plan 9's generated layer already supplies a version, add only the build policy.
- [ ] M2: Add `checks/shared-overrides.nix` and wire it into `checks/default.nix`.
- [ ] M2: `nix build .#checks.aarch64-darwin.shared-overrides` passes, and x86_64-linux passes where a builder is available.
- [ ] M2: Commit the channel entries.
- [ ] M3: Add `lib/consumerOverlayReport.nix` and expose `lib.consumerOverlayReport` and `lib.auditConsumerOverlay` from `flake.nix`.
- [ ] M3: Add nix-unit tests to `checks/unit.nix` and a fixture-backed `consumer-overlay-audit` flake check.
- [ ] M3: Run the audit against all five consumers' current overlays and record the reports. Each consumer's shadowing set must equal its deletion list.
- [ ] M3: Commit the audit.
- [ ] M4: Rehearse the deletions. Build `rei-cli` and `rei-api` (rei), `mori-cli` (mori) and `mori-rei-app` against the local channel with the deletion lists filtered out, then read the versions from the derivation closures.
- [ ] M4: Evaluate mina's filtered overlay (evaluation only; plan 13 owns its build).
- [ ] M5: Write the new ADR as `docs/adr/4-consumer-overlays-define-only-their-own-packages.md`.
- [ ] M5: Update `docs/user/consumer-integration.md`, `docs/user/adding-patches.md` and `docs/user/channels.md`, append to `docs/user/log.md`, and pass `just check-docs`.
- [ ] M5: `nix flake check` passes, and the final commit is made.
- [ ] M5: Fill in Outcomes & Retrospective and hand the deletion lists to plans 11, 12 and 13.


## Surprises & Discoveries

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
- **Observation:** Two private repositories are involved, and the channel is public.
  - `shinzui/haskell-nix` is public.
  - `topagentnetwork/typeid-hs` (source of `typeid-hs-sql` and `typeid-hs-pg-migrate`)
    and `topagentnetwork/tan-effectful` (source of `hasql-effectful`) are private.
  - Evidence from `gh repo view --json visibility`: `PUBLIC` for the channel and
    `PRIVATE` for both sources.
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
- **Decision:** `typeid-hs-sql`, `typeid-hs-pg-migrate` and `hasql-effectful` stay in
  consumer overlays as declared exceptions, each with a reason. They do not move into
  the channel.
  - Rationale: they build only from private `topagentnetwork` repositories. The channel
  is public. A flake input would force every consumer's lock to fetch them with
  credentials, and a lazy fetch inside a registry patch would make the public registry
  expose names that fail for anyone without access.
  - The MasterPlan's Integration Points list the `typeid-hs` sources among plan 10's
    additions. This is a deliberate divergence, recorded as an open question for the
    MasterPlan owner.
  - Date: 2026-09-26
- **Decision:** Do not touch `patches/shibuya-pgmq-adapter/0.16.nix`. Mori's local
  0.16.1.0 override is on mori's deletion list with a precondition: the channel must
  already supply at least 0.16.1.0.
  - Rationale: the MasterPlan decided not to ship a one-off 0.16.1.0 patch ahead of
    plan 9. Plan 9 owns retiring that hand-written pin.
  - Date: 2026-09-26
- **Decision:** Add no channel entry for `kdl-hs`. Mina's override is deleted only after
  plan 13 lets mina accept the channel's 1.1.0 (by lifting `kdl-hs ^>=1.0`). Until then
  it is a declared exception in mina's audit.
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
- **Decision:** Sibling-application libraries (`rei-core`, `mori-types`, `mori-app` and
  `mori-schema-pin` in the overlays that consume them) are permitted as declared
  siblings, not as own packages.
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
  (`docs/adr/<N>-<slug>.md`, no OKF frontmatter). Allocate `<N>` when you write it by
  listing `docs/adr/`.
  - Rationale: `docs/adr` is not a profile-governed OKF bundle here; `mori.dhall`
    declares only `docs/improvement-requests`, `docs/user` and `docs/guides`. Plans 8
    and 9 each also add one ADR, so the number depends on landing order.
  - Date: 2026-09-26


## Outcomes & Retrospective

(To be filled during and after implementation.)


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

Every attribute defined in the five overlays falls into one of four classes:

- **(a) Own:** the application's own packages.
- **(b) Sibling:** another application's library, which stays until plans 11 and 12
  change how it is consumed.
- **(c) Shared:** a third-party or first-party override the channel must own.
- **(d) Exception:** a package that stays local for a stated reason.

The destination of each class-(c) entry is given with it.

**Rei** defines 17 attributes.

- Own (a): `rei-core`, `rei-api`, `rei-cli`.
- Exception (d): `typeid-hs-sql` and `typeid-hs-pg-migrate`, built from private
  `topagentnetwork/typeid-hs` at `7164a74c`.
- Shared (c), 12 entries:
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
- Exception (d):
  - `hasql-effectful`, from private `topagentnetwork/tan-effectful` at `5e081ad8`;
  - `typeid-hs-sql` and `typeid-hs-pg-migrate`, as in rei.
- Shared (c), 29 entries:
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
- Exception (d): `typeid-hs-sql` and `typeid-hs-pg-migrate`.
- Shared (c), 3 entries:
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
- Sibling (b): `mori-schema-pin`, from mori `7af02c55`.
- Shared (c):
  - `generic-lens-core` and `generic-lens`, both 2.3.0.0, fetched with
    `builtins.fetchTarball` and built with tests off. Destination: new pins in
    `patches/generic-lens-core/2.3.nix` and `patches/generic-lens/2.3.nix`.
  - `kdl-hs` 1.0.1. Destination: none. It is a temporary exception until plan 13
    accepts nixpkgs' 1.1.0.

Mori's `dhall-haskell` source pin and mina's `streamly` source pins live only in
`cabal.project`, not in any overlay, so they are not overlay overrides. Plans 8, 12 and
13 handle them. The same is true of nested flake-input overrides such as mina's
`haskell-nix.inputs.okf-src.follows`, which ADR-24's 2026-09-13 amendment permits.

The resulting per-repository deletion lists, which plans 11 to 13 apply, are:

- **Rei (12):**
  - `link-canonical`, `kioku-core`, `openapi-hs`, `servant-openapi-hs`,
    `servant-health`;
  - `hs-opentelemetry-instrumentation-wai`, `hs-opentelemetry-sdk`,
    `hs-opentelemetry-exporter-otlp`;
  - `relay-pagination`, `relay-pagination-servant`, `relay-pagination-hasql`,
    `relay-pagination-conformance`.
- **Mori (29):**
  - `openapi-hs`, `servant-openapi-hs`, `servant-health`, `blake3`, `link-canonical`,
    `hasql-notifications`;
  - the 14 `hs-opentelemetry-*` names listed above;
  - `thread-utils-finalizers`, `thread-utils-context`, `hw-kafka-client`, `kioku-core`;
  - `shibuya-pgmq-adapter`, only once the channel supplies at least 0.16.1.0;
  - `relay-pagination`, `relay-pagination-conformance`, `relay-pagination-hasql`,
    `relay-pagination-servant`.

  With these gone, the flake inputs `openapi-hs-src`, `servant-openapi-hs-src` and
  `servant-health-src`, their overlay arguments, and the `callHackageNoCheck` helper
  become unused. Plan 12 deletes them too.
- **Mori-rei-app (3):** `link-canonical`, `wai-app-static`, `servant-server`.
- **Reiko:** none.
- **Mina (2, then a third):** `generic-lens-core` and `generic-lens`. `kdl-hs` follows
  once mina's bound accepts 1.1.


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

Create four patch files. Each opens with a comment that says what it pins and why, and
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
exactly.

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
{ channelPackages, overlayPackages, ownPackages, siblingPackages ? [ ], exceptions ? { } }:
```

It computes the following, each a sorted list:

- `shadowing`: overlay names that are also channel names. Declaring such a name in any
  list does not excuse it; shadowing is never allowed.
- `undeclared`: overlay names in none of `ownPackages`, `siblingPackages` or
  `attrNames exceptions`.
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
consumer's `shadowing` must equal its deletion list from Context and Orientation,
except these parts of the lists:

- mori's `shibuya-pgmq-adapter` does shadow; its deletion list keeps the plan 9
  precondition;
- mina's `kdl-hs` is reported as `undeclared` unless you pass it as an exception;
- mori's `hw-kafka-client` and the `link-canonical` entries appear only once M2's
  entries exist;
- the class-(d) exceptions must not appear anywhere once declared.

Acceptance:

- `just nix-test` passes.
- `nix build .#checks.aarch64-darwin.consumer-overlay-audit` succeeds.
- The five reports match the deletion lists as described above.

Commit.

**Milestone 4: rehearse the consumer deletions without editing any consumer.** At the
end you know each deletion list is safe, because each application's Nix build succeeds
against this repository's working tree with those entries filtered out. You also know
its derivation closure contains the expected versions. This is evidence for plans 11
and 12. Nothing is committed in any consumer.

For rei, mori and mori-rei-app, build the application's package from a scratch
expression (Concrete Steps). The expression:

1. imports the consumer's flake with `builtins.getFlake "git+file://<checkout>?rev=<HEAD>"`
   to obtain its source inputs;
2. imports the consumer's `nix/haskell-overlay.nix` with those inputs;
3. wraps it as `final: prev: builtins.removeAttrs (overlay final prev) deletions`;
4. composes it after this repository's `lib.haskellExtensions.github`, obtained with
   `builtins.getFlake "path:/Users/shinzui/Keikaku/bokuno/haskell-nix"` so uncommitted
   work is included;
5. builds the application's package.

For mori, keep `shibuya-pgmq-adapter` out of `deletions` unless plan 9 has already moved
the channel. After each build, list versions from the derivation closure. The runtime
closure of a Haskell executable does not reference static Haskell libraries, so do not
use it.

Mina is a cohort behind this channel (Baikai 0.6), so a build here would fail for
reasons plan 13 owns. For mina, only evaluate the filtered overlay and confirm that
`generic-lens` and `generic-lens-core` resolve to 2.3.0.0 from the channel. Reiko has
nothing to delete.

Acceptance:

- the three builds succeed;
- the rei and mori-rei-app closures contain `wai-app-static-3.2.1` and
  `generic-lens-2.3.0.0` derivations and no `wai-app-static-3.1.9.1`;
- `openapi-hs-5.0.0` in the rei closure is built from the channel's GitHub source;
- mina's evaluation prints 2.3.0.0 for both packages.

If a build fails, the deletion list or a channel entry is wrong. Fix the channel entry
(never by adding back a consumer entry), record the failure in Surprises & Discoveries,
and rerun.

**Milestone 5: record the rule and finish.**

Write the ADR as `docs/adr/4-consumer-overlays-define-only-their-own-packages.md` (the MasterPlan allocates 2 to plan 8 and 3 to plan 9; confirm with `ls docs/adr` that 4 is still free):

```bash
ls docs/adr/
```

Take the next integer after the highest existing prefix. Today only `1-…` exists, but
plans 8 and 9 each add one ADR, so expect 2, 3 or 4. Name it
`docs/adr/<N>-consumer-overlays-define-only-their-own-packages.md` and follow ADR 1's
shape exactly: a title line, then `Status:` and `Date:` lines, then `## Context`,
`## Decision`, `## Alternatives and consequences` and `## Validation`. Its content:

- **Context:**
  - the composition order that lets a consumer overlay win silently;
  - the 2026-09-26 inventory: 58 entries that are not the consumer's own code, 47 of them
    shared overrides, most of those duplicates;
  - the mori-rei-app hash divergence;
  - the thread-utils evidence that same-version duplicates still change derivations.
- **Decision:**
  - A consumer overlay defines only its own packages, declared siblings (until the
    sibling is consumed from its application's flake), and named exceptions with
    reasons.
  - It never defines a name the channel's registry defines.
  - A package a consumer needs at a version or with a policy the channel lacks is
    added to this repository, not to the consumer.
  - Private sources the public channel cannot fetch are the standing exception class.
  - Enforcement: each consumer's `checks` include `lib.auditConsumerOverlay`.
  - Nested `*-src` input overrides remain allowed, per
    `mori://shinzui/mori/okf/adrs/concepts/ADR-24`'s 2026-09-13 amendment.
- **Alternatives and consequences:**
  - The rejected alternatives: keeping ADR-24's local-pin escape hatch; making the
    channel win the composition, which ADR-24 already rejected; review-only
    enforcement, which ADR-24 chose and which the inventory shows did not hold; and
    new families for `servant-health` and `link-canonical`, deferred because of ADR 1's
    catalog-migration rule.
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
  - Add a section "Audit your local overlay" that shows the `checks` wiring:

    ```nix
    checks.consumer-overlay-audit = inputs.haskell-nix.lib.auditConsumerOverlay {
      inherit pkgs;
      overlay = import ./nix/haskell-overlay.nix { inherit pkgs gitRev; /* sources */ };
      ownPackages = [ "rei-core" "rei-api" "rei-cli" ];
      exceptions = {
        typeid-hs-sql = "private topagentnetwork source; the public channel cannot fetch it";
        typeid-hs-pg-migrate = "private topagentnetwork source; the public channel cannot fetch it";
      };
    };
    ```

  - Note in the same section that `disableProfiling = false` reintroduces the
    `kioku-core` profiling panic on GHC 9.12.4.
- `docs/user/adding-patches.md`: add a short paragraph saying that a consumer's need
  for a third-party override is satisfied here, with the new patch files as examples.
- `docs/user/channels.md`: after the "Current inventory" family table, add a sentence
  naming the new common-registry entries.
- `docs/user/log.md`: add an entry under a new dated heading, in the file's existing
  format (`## YYYY-MM-DD`, then `* **Addition**: …`).

Run `just check-docs` and `nix flake check`, then commit.

Finally, fill in Outcomes & Retrospective. It must restate the three deletion lists, and
the two conditional deletions with their conditions, so that plans 11, 12 and 13 can
copy them.


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
    "shibuya-pgmq-adapter" "thread-utils-context" ] version;
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
"shibuya-pgmq-adapter": "0.16.0.0"
```

After M2, the same run must print `servant-health` 0.1.0.0, `wai-app-static` 3.2.1
and `generic-lens` 2.3.0.0.

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
2.3.0.0 pins and policy entries for link-canonical, hw-kafka-client and
servant-server, which five consumer overlays each carried locally. The
shared-overrides check builds them through the default set.

MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

M3, running the report against the real overlays. Extend `inventory.nix` with a
`reports` attribute that calls `hn.lib.consumerOverlayReport` once per consumer, passing
`overlay`, `pkgs` and these declarations:

- **rei:** own `rei-core rei-api rei-cli`; exceptions for `typeid-hs-sql` and
  `typeid-hs-pg-migrate`.
- **mori:** own `mori-types mori-schema-pin mori-core mori-api mori-cli`; exceptions for
  `hasql-effectful`, `typeid-hs-sql` and `typeid-hs-pg-migrate`.
- **mori-rei-app:** own `mori-rei-app`; siblings `mori-types mori-app rei-core`;
  exceptions for the two typeid packages.
- **reiko:** own `reiko-core reiko-cli`.
- **mina:** own `mina-core mina-cli`; sibling `mori-schema-pin`; exception
  `kdl-hs = "held at 1.0.1 until mina accepts kdl-hs 1.1 (plan 13)"`.

Then run:

```bash
nix eval --json --impure -f "$TMPDIR/plan10/inventory.nix" --apply 'x: builtins.mapAttrs (_: r: { inherit (r) ok shadowing undeclared; }) x.reports' | jq .
```

Expected output, abbreviated:

```text
"mina":  { "ok": false, "shadowing": ["generic-lens","generic-lens-core"], "undeclared": [] }
"mori-rei-app": { "ok": false, "shadowing": ["link-canonical","servant-server","wai-app-static"], "undeclared": [] }
"reiko": { "ok": true, "shadowing": [], "undeclared": [] }
"rei":   { "ok": false, "shadowing": [ 12 names = rei's deletion list ], "undeclared": [] }
"mori":  { "ok": false, "shadowing": [ 29 names = mori's deletion list ], "undeclared": [] }
```

M3 checks and commit:

```bash
just nix-test
nix build .#checks.aarch64-darwin.consumer-overlay-audit
```

```text
feat(lib): audit consumer overlays against the channel

lib.auditConsumerOverlay fails when a consumer overlay redefines a package
the channel provides or defines one it has not declared as its own, a
sibling application's library, or a reasoned exception.

MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

M4, the rei rehearsal. `$TMPDIR/plan10/rehearse-rei.nix`:

```nix
let
  hn = builtins.getFlake "path:/Users/shinzui/Keikaku/bokuno/haskell-nix";
  rei = builtins.getFlake "git+file:///Users/shinzui/Keikaku/bokuno/rei-project/rei?rev=880093ccd90aefc90e7b5ee288f9dc6a5e5d1921";
  pkgs = import hn.inputs.nixpkgs { system = "aarch64-darwin"; };
  deletions = [ "link-canonical" "kioku-core" "openapi-hs" "servant-openapi-hs" "servant-health"
    "hs-opentelemetry-instrumentation-wai" "hs-opentelemetry-sdk" "hs-opentelemetry-exporter-otlp"
    "relay-pagination" "relay-pagination-servant" "relay-pagination-hasql" "relay-pagination-conformance" ];
  overlay = import /Users/shinzui/Keikaku/bokuno/rei-project/rei/nix/haskell-overlay.nix {
    inherit pkgs; gitRev = "880093c"; inherit (rei.inputs) typeid-hs-src; };
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
nix-store --query --requisites "$drv" | grep -E -- '-(wai-app-static|generic-lens|openapi-hs|servant-health|link-canonical)-[0-9.]+\.drv$'
```

Expect `wai-app-static-3.2.1.drv`, `generic-lens-2.3.0.0.drv`, `openapi-hs-5.0.0.drv`,
`servant-health-0.1.0.0.drv` and `link-canonical-0.1.0.0.drv` across the two
derivations. `rei-cli` does not depend on `rei-api`, so the HTTP packages
(`servant-health`, `wai-app-static`) appear only in `rei-api`'s closure; run the same
query on `rei-api.drvPath`.

The mori and mori-rei-app rehearsals have the same shape:

- **mori:** `getFlake` of `git+file:///Users/shinzui/Keikaku/bokuno/mori-project/mori?rev=f3c5fa4b...`
  (full hash from `git -C … rev-parse HEAD`). Pass all six source inputs. Use mori's
  deletion list, keeping out `shibuya-pgmq-adapter` unless plan 9 has landed, and build
  `mori-cli`. Mori's `tan-effectful-src` and `typeid-hs-src` are private, so the fetch
  needs your GitHub credentials (netrc or `gh auth`), as mori's own build does.
- **mori-rei-app:** its four source inputs and its 3-entry deletion list; build
  `mori-rei-app`.

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
3. The M3 report over the five real overlays gives each consumer a `shadowing` list
   equal to its deletion list in Context and Orientation. Reiko is `ok`.
   - This is the plan's central proof: the audit sees exactly what plans 11 to 13 must
     delete, and nothing more.
   - Calling `lib.auditConsumerOverlay` on mori-rei-app's current overlay fails with
     the `shadows channel packages … link-canonical, servant-server, wai-app-static`
     message.
4. The M4 rehearsal builds of `rei-cli`, `rei-api`, `mori-cli` and `mori-rei-app`
   succeed with the deletion lists removed.
   - Their derivation closures show `wai-app-static-3.2.1` and
     `generic-lens-2.3.0.0` where those packages are used.
   - Mina's filtered evaluation prints 2.3.0.0 for `generic-lens` and
     `generic-lens-core`.
5. `nix flake check` passes, including `registry-valid`, `overlay-eval` and the
   existing matrices.
6. `just check-docs` passes. The new ADR exists at `docs/adr/<N>-consumer-overlays-define-only-their-own-packages.md`.

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
  not restore the consumer entry, because that is the shadowing this plan removes.


## Interfaces and Dependencies

At the end of this plan these exist in `mori://shinzui/haskell-nix`.

Registry entries in `overlays/registry.nix`:

- Version pins: `wai-app-static` (to `patches/wai-app-static/3.2.nix`), `servant-health`
  (`patches/servant-health/0.1.nix`), `generic-lens-core`
  (`patches/generic-lens-core/2.3.nix`) and `generic-lens`
  (`patches/generic-lens/2.3.nix`).
- Policy only: `link-canonical`, `hw-kafka-client` and `servant-server`, each
  `always dontCheckDoJailbreak`.

Each patch file is a function of `{ hself, haskellLib, ... }` returning a derivation,
like `patches/claude/1.5.nix`.

`lib/consumerOverlayReport.nix`:

```nix
{ lib }:
{ channelPackages, overlayPackages, ownPackages, siblingPackages ? [ ], exceptions ? { } }:
{ shadowing = [ /* String */ ]; undeclared = [ ]; unusedDeclarations = [ ];
  invalidDeclarations = [ ]; ok = true; }
```

Flake library outputs (`flake.lib`):

```nix
consumerOverlayReport :: { pkgs, overlay, ownPackages, siblingPackages ? [], exceptions ? {},
                           registry ? registries.github, ghc ? defaultGhc } -> Report
auditConsumerOverlay  :: same arguments -> derivation "consumer-overlay-audit" (throws when not ok)
```

`overlay` is the consumer's already-applied `final: prev: { … }` function, the same
value it passes as the second argument of `composeExtensions`.

Flake checks, added to `checks/default.nix`:

- `shared-overrides`, from `checks/shared-overrides.nix`, taking
  `{ lib, pkgs, defaultGhc, haskellExtension }`;
- `consumer-overlay-audit`, over `checks/fixtures/consumer-overlays/clean.nix`.

Nix-unit tests are added in `checks/unit.nix`.

A new ADR, `docs/adr/<N>-consumer-overlays-define-only-their-own-packages.md`.

Dependencies and hand-offs:

- **Plan 9**
  (`docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md`)
  is a soft dependency.
  - Its generated layer supplies versions. After it lands, `overlays/registry.nix` and
    `patches/*` carry only build policy.
  - It must convert this plan's four version pins if this plan lands first.
  - It must move `shibuya-pgmq-adapter` to at least 0.16.1.0 before mori's deletion of
    that entry.
  - Its parity script should consider reusing `lib/consumerOverlayReport.nix`'s idea of
    "names the channel owns".
- **Plan 8** should record two items in its report:
  - mina's `kdl-hs ^>=1.0` cap against nixpkgs' 1.1.0;
  - the Cabal `dhall -use-http-client-tls` flag in rei and mori-rei-app, which
    contradicts the channel's policy of keeping that flag on.
- **Plan 11** applies:
  - rei's 12 deletions and mori-rei-app's 3;
  - `checks.consumer-overlay-audit` in both repositories, with rei and mori-rei-app's
    declarations from Concrete Steps;
  - rei-core's move from a sibling entry to Rei's flake output, which then leaves
    mori-rei-app's sibling list.
- **Plan 12** applies:
  - mori's 29 deletions (with the `shibuya-pgmq-adapter` precondition);
  - removal of the `openapi-hs-src`, `servant-openapi-hs-src` and `servant-health-src`
    flake inputs and overlay arguments, and of the `callHackageNoCheck` helper;
  - mori's audit check.
- **Plan 13** applies:
  - mina's `generic-lens(-core)` deletions;
  - the `kdl-hs` bound lift followed by its deletion;
  - mina's and reiko's audit checks.
- **Tools:** Nix with flakes; `nix-unit` (already in the dev shell and in the
  `nix-unit` check); `jq`; `nix-prefetch-url`; `just`; `okf` for `just check-docs`.
  Nothing new is introduced.


## Revision Notes

- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The ADR is fixed as `docs/adr/4-consumer-overlays-define-only-their-own-packages.md` under the MasterPlan's allocation (plan 8 takes 2, plan 9 takes 3). The MasterPlan's Integration Points now match this plan's scope: most overrides are duplicates for consumers to delete, and the private `typeid-hs`/`hasql-effectful` sources and mina's `mori-schema-pin` are declared exceptions.
