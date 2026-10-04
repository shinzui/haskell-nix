---
id: 11
slug: adopt-the-shared-package-set-in-rei-and-mori-rei-app
title: "Adopt the shared package set in rei and mori-rei-app"
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
  reviews:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-04T13:51:42Z
      verdict: "changes-requested"
      note: "Original review found whole-repository invalidation assumption, stale package inventory and split adoption; applied findings in update."
---

# Adopt the shared package set in rei and mori-rei-app

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Rei (`mori://shinzui/rei`) is a personal time-management system, and mori-rei-app
(`mori://shinzui/mori-rei-app`) is a small webhook daemon that turns commits into Rei actions
by linking Rei's `rei-core` library. Both are deployed as macOS launchd agents from the user's
dotfiles (`mori://shinzui/dotfiles.nix`), and both write to the same Kiroku event store (the
PostgreSQL database `host=/Users/shinzui/.local/state/postgresql dbname=rei`).

Today each is built twice, by two different package selectors that disagree. `cabal build`
resolves Hackage at an `index-state`; `nix build` takes whatever versions this repository's
channel (`mori://shinzui/haskell-nix`) and each repository's local overlay happen to supply. On
2026-09-26 Rei's deployed binary and Rei's own Cabal plan differed in 73 of 353 shared packages,
so the test suite, which runs under Cabal, has never run against the binary that ships.
mori-rei-app makes it worse: it rebuilds `rei-core` itself from a copy of Rei's source, in a
package scope its own overlay perturbs (`wai-app-static` 3.2.1, a jailbroken `servant-server`),
so the `rei-core` inside mori-rei-app is a different derivation from the one inside Rei.

After this plan:

- rei, mori-app (a library mori-rei-app links) and mori-rei-app all `import:` the one Cabal freeze
  file this repository publishes at `cabal/cohort.freeze`, pinned to the same haskell-nix commit
  their flakes lock. Their Cabal plans equal the freeze, which moves the whole family to
  `effectful` 2.7.1.0 / `effectful-core` 2.7.1.1 or later (a user decision of 2026-09-26), so all three
  compile against effectful 2.7 with no `allow-newer` on it.
- rei and mori-rei-app build under Nix from that same haskell-nix commit, with no shared-package
  overrides left in their overlays, so their Nix closures contain exactly the frozen versions.
- Rei's flake exports a Haskell extension that adds `rei-core`, and mori-rei-app composes it
  instead of rebuilding `rei-core`, so the two deployed programs contain the byte-identical
  `rei-core` store path.
- Both are deployed together, proven first against a fresh clone of the global database with the
  exact shipped binary.

How to see it working, at the end: the haskell-nix parity script reports zero differences for
each application's `dist-newstyle/cache/plan.json` and for each deployed closure; running
`nix-store -qR` on the deployed `rei` and on the deployed `mori-rei-app` shows the same
`rei-core-6.x` store path in both; `rei --version` reports the new commit; the Kiroku worker's
metrics endpoint on port 9091 lists live subscriptions; and a push carrying an `Intention:`
trailer is recorded as a Rei action by the new mori-rei-app.


## Review requirements (2026-10-04)

Follow [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md): ordinary application edits retain the cohort and toolchain pins. Matching versions alone is insufficient evidence of reused builds. Historical input revisions, package counts and deletion lists below are starting observations; refresh them from recorded contributor revisions.

Plan 9 owns the shared `cohort-compare` app. Use `--freeze FILE_OR_URL --plan-json FILE` for a freshly generated Cabal plan and `--freeze FILE_OR_URL --nix-manifest FILE` for the executable's build evidence. Use `--compare-manifests FILE FILE` to compare build identities and `--resolve-channel-lock FILE --input-path PATH` to obtain a channel's full locked revision. The resolver starts at the lock's declared root and handles recursive array `follows`, string nodes, missing nodes and cycles. Check the Cabal import revision against the application's own resolved lock, rather than assuming a node named `haskell-nix` exists. Return 0 on success, 1 on drift or missing/unverifiable evidence, and 2 on usage error.

Export `packages.<system>.cohort-manifest` through plan 9's construction helper. Its JSON schema records the system, compiler/toolchain/channel, actual executable root drv/output and Haskell packages with names, versions, component roles, source/metadata identities, flags/policy and drv/output paths. Generate records from the actual composed scope used to build the executable, then verify dependency edges against that root's derivation graph through Nix metadata APIs. Runtime closures may omit static Haskell libraries; basename parsing and unrelated channel evaluation cannot prove parity. All instances of a Haskell package must pass, including when one correct and one incorrect version coexist. Missing expected dependencies fail. Native build tools and compiler packages are distinguished by role.

Refresh `plan.json` with tests and benchmarks enabled for supported configurations; check all non-local packages. Record own packages and non-Hackage source pins in the channel's declared policy and `cabal/cohort-sources.json` (exact source revision/subdirectory plus reasons and owners for intentional Cabal/Nix source or flag differences). Do not use arbitrary `--ignore` lists. Keep exact-binary release rehearsals: version parity alone does not establish flag/source or behavioral equivalence. Consumer checks are thin calls to shared tooling, with no fallback comparator.

Re-inventory Rei's five owned packages (`rei-core`, `rei-api-contract`, `rei-api-client`, `rei-api`, `rei-cli`) and include their components. Stage Cabal import/bounds changes and Nix input/lock changes in one adoption commit after both paths pass, even if preparation spans milestones. Do not commit a half-adopted selector pair. Source-only preparatory ports may land independently while retaining the old selectors.

Export the Rei library extension into the consumer's single Haskell scope. Prove `rei-core` identity from relevant source and build inputs; do not require all later Rei commits to move mori-rei-app. Add source filtering if the current constructor includes unrelated files, retaining required licenses, schemas, vendor assets and data. Compare before/after manifests for a documentation-only edit and a Rei CLI-only edit: `rei-core` and unchanged third-party dependencies retain drv/output identities. A real `rei-core` source/interface change must invalidate it and its dependents. Inspect and measure current constructor behavior rather than assuming a whole-repository commit always invalidates the library. Retarget dependency audits to the channel's source manifest for pins supplied by registry constants; such pins need not exist as flake-lock input nodes.

## Progress

- [ ] Documentation/CLI-only edits preserve unchanged library and shared dependency identities

- [ ] Prerequisites: plans 9 and 10 are Complete and pushed (and therefore plans 8 and 15, which plan 9 depends on); record the haskell-nix revision `R`, plan 15's released versions of keiro, keiro-ops, keiro-pgmq, keiro-test-support and kioku-core, and plan 8's upgrade report entries for rei, mori-app and mori-rei-app in Surprises & Discoveries.
- [ ] Milestone 1 (rei, Cabal): baseline `plan.json` captured before any edit.
- [ ] Milestone 1: `import:` of the freeze at `R` added; `index-state`, `constraints:` and `allow-newer:` reconciled.
- [ ] Milestone 1: capping bounds lifted (expected `brick`, `vty` in `rei-cli/rei-cli.cabal`, and the keiro/kioku bounds if plan 15 released a new major); source fixed until `cabal build all` passes.
- [ ] Milestone 1: rei's effectful 2.7 breaks fixed, including the vendored `rei-core/src/Rei/Infrastructure/Hasql/` modules and `rei-core/src/Rei/Infrastructure/Trace.hs`; `plan.json` shows `effectful` >= 2.7.1.0 / `effectful-core` >= 2.7.1.1.
- [ ] Milestone 1: `cabal test all`, `just openapi-check`, `just keiro-check`, `just dependency-closure-audit` pass; plan-json parity reports zero differences; committed.
- [ ] Milestone 2 (rei, Nix): `flake.nix` haskell-nix pin moved to `R`; `typeid-hs-src` input deleted (the channel carries `typeid-hs-*`); `nix/haskell-overlay.nix` reduced per plan 10's deletion list.
- [ ] Milestone 2: `flake.lib.haskellExtension` and `packages.rei-core` exported from `flake.module.nix`; rei's own build uses the exported extension.
- [ ] Milestone 2: `nix build .#rei`, `.#rei-api`, `.#rei-core` succeed; closure parity reports zero differences; `nix flake check` passes; committed.
- [ ] Milestone 3 (rei, ADR): new ADR (allocated with `okf id next`, expected ADR-49) written; ADR-18 amended; `just adr-validate` and strict validation pass; committed. Record rei commit `C`.
- [ ] Milestone 3: user approves; rei pushed so `github:shinzui/rei/C` resolves.
- [ ] Milestone 4 (mori-app): freeze imported at `R`; bounds lifted (expected `ephemeral-pg`, and `effectful`/`effectful-core ^>=2.6` to `^>=2.7`); compiles against effectful 2.7; `cabal test all` passes; parity zero; committed; user approves push. Record mori-app commit `A`.
- [ ] Milestone 5 (mori-rei-app, Cabal): freeze imported at `R`; `rei-core` pin moved to `C`, `mori-app` pin moved to `A`; `effectful`/`effectful-core ^>=2.6` lifted to `^>=2.7` (and keiro bounds if plan 15 released a new major); redundant entries removed; `cabal test all` passes against Rei's repo-local dev database; parity zero.
- [ ] Milestone 5 (mori-rei-app, Nix): `rei` flake input added; `haskell-nix`, `haskell-nix-dev` and toolchain inputs follow rei; `rei-src` and `typeid-hs-src` removed; overlay reduced; `nix build` passes; closure parity zero; `rei-core` store path equals rei's.
- [ ] Milestone 5: dependency-closure audit updated and passing; ADR-1 amended; committed; user approves push. Record mori-rei-app commit `M`.
- [ ] Milestone 6 (deploy): read-only production baseline captured.
- [ ] Milestone 6: dotfiles lock moved for `rei` and `mori-rei-app` only; `./bin/build.sh` passes; built store paths equal the proven ones.
- [ ] Milestone 6: fresh-clone rehearsal with the shipped binaries passes (migration status pending 0; replay gate passes with the 13-stream / 89-event exclusion).
- [ ] Milestone 6: user runs `sudo ./bin/darwin-rebuild-sungkyung.sh`.
- [ ] Milestone 6: post-activation verification (real binaries by `lsof`, :9091 subscriptions, today's logs, migration verify, mori-rei-app health and one observed delivery) recorded.
- [ ] Update the MasterPlan registry row for EP-11 and its two Progress items.


## Surprises & Discoveries

Nothing has been implemented yet. The observations below were made while writing the plan
(2026-09-26) and shape it; re-verify each before relying on it.

- Observation: Rei's Cabal plan is already at or above the Nix versions for almost everything the
  73-package gap names (hasql 1.10.3.7, aeson 2.2.5.1, tls 2.4.6, sbv 14.8, warp 3.4.16). Rei's
  source has therefore already compiled and passed its tests against those. The only packages
  where the freeze must move rei's Cabal plan *upward* are the ones where Nix was ahead —
  `brick` 2.6 to 2.9 and `vty` 6.2 to 6.4, capped by `brick ^>=2.6` and `vty ^>=6.2` in
  `rei-cli/rei-cli.cabal`, and `baikai-effectful` 0.4.0.1 to 0.4.0.2 — plus anything another
  application selects higher, plus the user's effectful 2.7 target (next observation). Evidence:
  the version lists in the MasterPlan and `grep -nE 'brick|vty' rei-cli/rei-cli.cabal` in rei
  (lines 345 and 379).
  Consequence: a source break in rei is expected in the 20 modules importing `Brick`, the 4
  importing `Graphics.Vty`, and the modules that touch effectful's internals (next observation). A
  Nix build failure in a package whose Cabal version was already the frozen one is not a source
  break; it is build policy (jailbreak, tests, a system library) and belongs in the channel (plans
  9 and 10), not in rei.
- Observation: the freeze moves `effectful` and `effectful-core` from 2.6.x to 2.7.1.1 or later
  (user decision 2026-09-26, delivered through plan 8's policy floor and plan 15's releases of
  keiro, keiro-ops, keiro-pgmq, keiro-test-support and kioku-core). effectful 2.7 changed
  `LocalEnv` (it gained a second type parameter), `SharedSuffix`, `KnownEffects` and the strict
  modules. A grep for those names and for `localSeqUnlift`, `localUnlift`,
  `Effectful.Dispatch.Static` and `Effectful.Internal` on rei `880093cc` finds three modules:
  `rei-core/src/Rei/Infrastructure/Trace.hs`,
  `rei-core/src/Rei/Infrastructure/Hasql/Static/Connection.hs` and
  `rei-core/src/Rei/Infrastructure/Hasql/Static/Pool.hs`. The last two, with
  `rei-core/src/Rei/Infrastructure/Hasql/Effect.hs`, are Rei's vendored copy of `hasql-effectful`
  (from `topagentnetwork/tan-effectful` `5e081ad8`), so Rei owns their port. rei's `.cabal` files
  list `effectful`/`effectful-core` without a bound, so no bound moves in rei itself. mori-app
  (`mori-app/mori-app.cabal` lines 63-64 and 101-102) and mori-rei-app (`mori-rei-app.cabal`
  lines 65-66 and 148-149) both declare `effectful ^>=2.6` and `effectful-core ^>=2.6`, which the
  freeze no longer admits; the same grep finds no effectful-internal use in either, so they are
  expected to need only the bound change.
- Observation: mori-app's test suite declares `ephemeral-pg ^>=0.2`, while rei's Cabal plan already
  uses `ephemeral-pg` 0.3.1.0. Under an upgrade-only freeze that bound must move, and mori-app's
  test harness may need porting to the 0.3 API. Evidence: `mori-app/mori-app.cabal` line 103.
- Observation: mori-app has no `haskell-nix` flake input at all; its `packages.default` builds
  against plain `pkgs.haskell.packages.ghc9124`. So "pin the freeze import to the revision the
  flake locks" has nothing to match in mori-app; it pins to `R`, the revision rei and mori-rei-app
  lock.
- Observation (corrected 2026-10-04): a subdirectory source can inherit unrelated
  repository inputs depending on the constructor. Inspect the actual source derivation and
  test documentation/CLI-only edits. Equal relevant source and transitive inputs, rather
  than equal whole-repository commits, are the requirement for `rei-core` build identity.
- Observation: mori-rei-app's `scripts/dependency-closure-audit.sh` asserts that every `tag:` in
  its `cabal.project` also appears in `flake.nix` (script lines 240-244). Once `rei-core` reaches
  Nix through the `rei` flake input and `typeid-hs` through the channel (plan 10 carries it now
  that the repository is public), the literal `typeid-hs` revision no longer appears in
  mori-rei-app's `flake.nix`, the channel may fetch it from a registry constant rather than a flake input. Compare
  the source manifest with `cabal.project`; a literal flake-lock node is not required.
- Observation: `https://github.com/topagentnetwork/typeid-hs` became public on 2026-09-26
  (anonymous `git ls-remote` works; HEAD `7164a74c`), so plan 10 moves `typeid-hs-sql` and
  `typeid-hs-pg-migrate` into the channel. typeid-hs is still not on Hackage, so every
  `cabal.project` keeps its `source-repository-package` at `7164a74c`.
- Observation: rei's `flake.nix` is seihou-managed and says editing a revision there "is a conflict
  at the next run". Rei commit `880093cc` nevertheless moved the haskell-nix revision by a direct
  one-line edit, and that is the precedent this plan follows.


## Decision Log

- Decision (2026-10-04 review update): adopt the Review requirements above and ADR 5's update-isolation/build-evidence contract. Historical closure-only acceptance, fixed package counts and duplicated comparison implementations are superseded where noted. Preserve the agreed advisory fleet guard and effectful migration policy. Implementation evidence remains pending.

- Decision: Rei exports `lib.haskellExtension` from its flake with the same calling convention as
  haskell-nix's own `lib.haskellExtension` — a function `haskellLib: pkgs: final: prev: { … }` —
  containing only Rei's own packages (`rei-core`, `rei-api`, `rei-cli`). `typeid-hs-sql` and
  `typeid-hs-pg-migrate` come from the channel (plan 10; revised 2026-09-26, see the
  user-decisions entry below). Consumers compose it after the channel extension. Rei's own `flake.module.nix` builds from exactly the
  same extension.
  Rationale: one definition means Rei and every consumer evaluate the same `rei-core` expression,
  so equal inputs give an equal derivation. Matching haskell-nix's shape lets consumers write one
  `composeManyExtensions` list, and plan 12 can copy the shape for `mori-types`.
  Date: 2026-09-26
- Decision: mori-rei-app follows Rei's pins, not the other way round: `haskell-nix.follows =
  "rei/haskell-nix"` and `haskell-nix-dev.follows = "rei/haskell-nix-dev"`, with `nixpkgs`,
  `flake-parts`, `treefmt-nix` and `pre-commit-hooks` following `haskell-nix-dev`.
  Rationale: `rei-core` is only identical when it is evaluated against the channel Rei was proven
  on. Following rei makes a drift impossible rather than detectable, and it replaces
  mori-rei-app's unpinned `haskell-nix-dev` (locked at `af29a486`, a revision with no
  `flake-parts` input) with Rei's rev-pinned `206ecd25`.
  Date: 2026-09-26
- Decision: Lift the `brick`, `vty`, `ephemeral-pg` and `effectful`/`effectful-core` caps (and any
  `keiro`/`kioku-core` cap plan 15's release numbers fall outside) by moving the bound in the
  `.cabal` file, never by `allow-newer`.
  Rationale: these are the application's own bounds, so remedy 1 of
  `mori://shinzui/rei/okf/adrs/concepts/ADR-16` (take the current release) applies. An
  `allow-newer` for one's own package would assert the bound is wrong while leaving it wrong.
  Date: 2026-09-26
- Decision: The `import:` revision in each `cabal.project` and the haskell-nix revision in each
  `flake.nix` move in the same commit, and are the same 40-character revision `R`.
  Rationale: a remote Cabal import carries no content hash, so the revision is its only identity,
  and splitting the move across commits creates a commit where Cabal and Nix select different
  cohorts, which is the failure this initiative exists to remove.
  Date: 2026-09-26
- Decision (revised 2026-10-04): use commit `C` as the initial aligned baseline, then
  permit later Rei commits without moving mori-rei-app when manifests prove unchanged
  `rei-core` source and build inputs. Library/interface changes advance its consumer pin
  and receive the normal dependent tests.
  Rationale: requiring coordinated redeployment for documentation or CLI-only changes
  would preserve unnecessary work. Source-boundary and identity checks establish reuse.
  Date: 2026-10-04
- Decision: Do not edit dotfiles' `flake.nix` in this plan. Update only the `rei` and
  `mori-rei-app` lock entries, and prove the two `rei-core` store paths are equal.
  Rationale: plan 14 owns the dotfiles inputs (a root `haskell-nix` input and
  `mori-rei-app.inputs.rei.follows`). Here equality is established by pinning both to `C` and
  checked by comparing store paths.
  Date: 2026-09-26
- Decision: Treat this deploy as a normal restart, not a schema cutover, but gate that
  classification on evidence: the shipped `rei-migrations` must report `pending=0` against a fresh
  clone of the global database, and the `pgmq-migration` version in mori-rei-app's closure must be
  unchanged. If either fails, stop and switch to the MasterPlan's stop-writers procedure.
  Rationale: both programs already link Kiroku 0.9 and the global database already has Kiroku
  `0012` (186 applied migrations), but the freeze may move a first-party migration package, and a
  pending migration discovered at startup would be an unrehearsed production write.
  Date: 2026-09-26
- Decision: The ADR "an application that depends on another application's library consumes that
  application's flake output" lives in rei's `docs/adr/` (rei owns the exported interface).
  mori-rei-app amends its own ADR-1, whose "mirror rei's `cabal.project` verbatim" rule changes
  now that both import the freeze.
  Rationale: the producer's repository is where a future change to the export is made and reviewed;
  the consumer's ADR must not keep describing a derivation rule it no longer follows.
  Date: 2026-09-26
- Decision: Names that plans 9 and 10 define (the parity script's path and arguments, the
  consumer extension attribute, the per-repository deletion list) are written here as
  placeholders, marked as such. When plans 9 and 10 are Complete, their final text wins, and this
  plan is revised to match before Milestone 1 starts.
  Rationale: plans 9 and 10 were being drafted in parallel with this one.
  Date: 2026-09-26
- Decision (user decisions, 2026-09-26): four of the user's five decisions reach this plan.
  1. **effectful 2.7 everywhere, no `allow-newer` bridge.** The freeze carries `effectful` and
     `effectful-core` at 2.7.1.1 or later. rei (including its vendored
     `rei-core/src/Rei/Infrastructure/Hasql/` modules), mori-app and mori-rei-app are ported to
     compile against it; no `allow-newer` naming `effectful` or `effectful-core` may be added in
     any of the three. Plan 15 (`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`)
     releases the keiro and kioku-core versions that admit it, and plan 8's freeze depends on
     those releases, so plan 15 is an indirect dependency of this plan through the freeze.
  2. **`typeid-hs` is public.** Plan 10 moves `typeid-hs-sql` and `typeid-hs-pg-migrate` into the
     channel. rei and mori-rei-app delete their `typeid-hs` overlay entries and their
     `typeid-hs-src` flake inputs unconditionally. The earlier branch ("if the channel's revision
     is not `7164a74c`, rei keeps its input") is resolved: the channel provides typeid-hs at
     `7164a74c`, and if it ever does not, that is a plan 10 defect fixed in this repository by
     moving `R`, not by keeping a local input. The Cabal `source-repository-package` at
     `7164a74c` stays in every `cabal.project`, because typeid-hs is not on Hackage.
  3. **`hasql-effectful` is mori's concern only.** Plan 12 vendors it into `mori-core` as Rei
     did. rei already vendors it as `Rei.Infrastructure.Hasql.Effect`; mori-rei-app uses it only
     through that rei-core module, and mori-app not at all (only comments in their
     `cabal.project` files mention it). So nothing here changes except that rei's vendored copy
     is part of the effectful 2.7 port.
  4. **Plan 14's dotfiles guard is relaxed.** Different channel revisions across applications
     only warn; a deploy fails only when an application's closure differs from the freeze its own
     pinned channel revision publishes. This plan's deploy (rei and mori-rei-app on `R` while
     mori, mina and reiko may still be on older revisions) is therefore acceptable to plan 14's
     guard, and this plan's own closure-parity checks against the freeze at `R` are exactly the
     condition that guard enforces.
  (The fifth decision, mina's streamly, does not touch this plan.)
  Rationale: the user settled these on 2026-09-26 after the plan was drafted; each removes a
  conditional branch or adds a known source break the implementer must plan for.
  Date: 2026-09-26


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

### Repositories, checkouts, and how references are written

Four repositories are touched. Each is named by its Mori project URI; a file inside one is
written as the project plus a project-relative path (artifact-level Mori URIs for plain files
are pending). The local checkouts, used as working directories below, are:

- `mori://shinzui/rei`: `/Users/shinzui/Keikaku/bokuno/rei-project/rei` (HEAD `880093cc` when
  this plan was written; GitHub repository private).
- `mori://shinzui/mori-app`: `/Users/shinzui/Keikaku/bokuno/mori-project/mori-app` (HEAD
  `30aca6e3`). A library, not deployed on its own.
- `mori://shinzui/mori-rei-app`: `/Users/shinzui/Keikaku/bokuno/mori-project/mori-rei-app`
  (HEAD `2acd4ed`).
- `mori://shinzui/dotfiles.nix`: `/Users/shinzui/.config/dotfiles.nix` (HEAD `e652c2d`; it may
  carry other people's uncommitted files, which must be left alone).
- This repository, `mori://shinzui/haskell-nix`: `/Users/shinzui/Keikaku/bokuno/haskell-nix`
  (public on GitHub).

All code uses GHC 9.12.4 and cabal-install 3.16.1.0. Commit messages in every repository follow
Conventional Commits and end with the trailers shown in Concrete Steps.

### Terms

- **Cohort freeze** (or just "the freeze"): the file `cabal/cohort.freeze` in this repository,
  produced by plan 8
  (`docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`). It
  is a Cabal `constraints:` file with one `any.<package> ==<version>` line per package (the syntax
  `cabal freeze` writes), plus an `index-state:` line, resolved so no package is older than any of
  the five applications selects today. It also enforces one user-set target: `effectful` and
  `effectful-core` at 2.7.1.1 or later (the floor `kiroku-store` 0.9.0.1 and `shibuya` use, since
  they exclude 2.7.0.0 to 2.7.1.0 for a performance regression). Plan 8 also writes an upgrade
  report naming the application bounds that cap an upgrade.
- **Plan 15**: `docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md` releases
  new versions of keiro, keiro-ops, keiro-pgmq, keiro-test-support, kioku-core, shikumi,
  shikumi-trace and shikumi-cache that admit `effectful >=2.7.1.0` and `effectful-core >=2.7.1.1`, and refreshes the channel.
  Plan 8 resolves the freeze only after those releases exist, so this plan depends on plan 15
  through the freeze. Read the released version numbers from plan 15's Outcomes & Retrospective.
- **effectful 2.7**: the effect-system library rei, mori-app and mori-rei-app are written in
  (`effectful-core` is its core; `effectful` adds standard effects). Version 2.7 changed
  `LocalEnv` (a second type parameter), `SharedSuffix`, `KnownEffects` and the strict modules, so
  code that writes its own static-dispatch effects or unlifting helpers may need edits.
- **Channel**: this repository's Nix library. A consumer calls
  `inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose pkgs` and gets a Haskell
  package-set extension (a function `final: prev: { … }` passed as `overrides` to
  `pkgs.haskell.packages.ghc9124.override`). After plan 9 the channel's versions are generated from
  the freeze and `nix flake check` fails if any frozen package's `.version` differs. After plan 10
  the channel also owns the shared build overrides consumers used to carry.
- **Overlay** (in an application): `nix/haskell-overlay.nix`, the application's own extension,
  composed after the channel.
- **`R`**: the full 40-character haskell-nix revision on `master` after plans 9 and 10 are both
  merged and pushed. **`C`**, **`A`**, **`M`**: the rei, mori-app and mori-rei-app commits this plan
  produces and pushes.
- **Parity script**: the flake app `cohort-compare` that plan 9 (`docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md`, Milestone 5) adds as `scripts/cohort-compare.sh`. Invoke it as `nix run "github:shinzui/haskell-nix/$R#cohort-compare" -- --freeze <file-or-https-url> (--plan-json <file> | --nix-manifest <file>) [--all]`, where `$R` is the haskell-nix revision the application pins. It prints tab-separated `STATUS name freeze found` lines for `mismatch` (a frozen package at another version) and `unfrozen` (a package the freeze does not cover), then a summary, and exits 0 when there are none, 1 otherwise, 2 on a usage error. In `--closure` mode a frozen name passes if any store path of that name has the frozen version, so a C library sharing a Haskell package's name (C `zlib-1.3.1` beside Haskell `zlib-0.7.1.1`) is harmless. This plan abbreviates it as `$PARITY`, set once with `PARITY=(nix run "github:shinzui/haskell-nix/$R#cohort-compare" --)` and called as `"${PARITY[@]}" --freeze …`.
- **Replay audit**: `scripts/replay-audit-gate.sh` in rei re-folds every stored event stream
  through the event decoders and state machines the shipping binary contains, and fails on any
  failure outside a declared, closed exclusion of 13 `journal_entry` streams holding 89 events.
- **Clone rehearsal**: `scripts/validate-on-clone.sh` in rei dumps a named source database
  read-only, restores it into a uniquely named scratch database, runs a chosen command there
  (default: read-only migration `preflight`), and proves protected rows are unchanged.

### rei today

`cabal.project` sets `index-state: 2026-09-26T18:09:31Z`, packages `rei-core`, `rei-cli`,
`rei-api`, an optional generated conformance package, one `source-repository-package` for
`typeid-hs` (`typeid-hs-sql`, `typeid-hs-pg-migrate`, tag `7164a74c…`, not on Hackage; the
repository `https://github.com/topagentnetwork/typeid-hs` is public since 2026-09-26), a
`constraints:` block (`crypton >= 1.1`, `http-client-tls >= 0.4`, `dhall -use-http-client-tls`,
`blake3 -avx512 -avx2 -sse41 -sse2`), and six package-qualified `allow-newer` entries
(`fuzzyfind:containers`, `link-canonical:http-client-tls`, `link-canonical:generic-lens`,
`kiroku-cli:http-client-tls`, `claude:http-client-tls`, `baikai-kit:crypton`), each preceded by a
comment in the same order as the list. The `Justfile`'s `keiro-dsl` recipe repeats the
`index-state` in a `cabal install keiro-dsl-0.19.0.0 --index-state=…` line.

`flake.nix` rev-pins `haskell-nix-dev` (`206ecd25`) and `haskell-nix` (`4cabd105…`, following
`haskell-nix-dev` and `nixpkgs`), plus `typeid-hs-src`. `flake.module.nix` builds
`pkgs.haskell.packages.ghc9124.override` with `inputs.haskell-nix.lib.haskellExtensions.github`
composed with `import ./nix/haskell-overlay.nix { inherit pkgs gitRev; inherit (inputs)
typeid-hs-src; }`, and exposes `packages.rei` (= `rei-cli`), `packages.default`, and
`packages.rei-api`. It also declares pre-commit hooks, including `dependency-closure-audit`
(`scripts/dependency-closure-audit.sh`, which pins counts such as `EXPECT_TAN_FLAKE=1` and
`EXPECT_LOCK_TYPEID=2`; re-derive them with `--census` after a reviewed change).

`nix/haskell-overlay.nix` defines, besides Rei's own packages (refresh the five-package inventory): `typeid-hs-sql` and
`typeid-hs-pg-migrate` from `typeid-hs-src`; Hackage pins for `link-canonical` 0.1.0.0,
`openapi-hs` 5.0.0, `servant-openapi-hs` 5.1.0, `servant-health` 0.1.0.0,
`hs-opentelemetry-instrumentation-wai`/`-sdk`/`-exporter-otlp` 1.0.0.0 and the four
`relay-pagination*` 0.1.1.0 packages; and `kioku-core = disableLibraryProfiling prev.kioku-core`.
Every one of those is on plan 10's list of shared overrides moving into the channel. Rei's own
entries are `rei-core` and `rei-api` (`callCabal2nix … ../rei-core` / `../rei-api`) and `rei-cli`
(same, plus `-DGIT_HASH` from `gitRev`).

Bounds that matter: `rei-cli/rei-cli.cabal` has `brick ^>=2.6` and `vty ^>=6.2`; `rei-core` has
`hasql >=1.10`, `hasql-pool >=1.4`, `^>=0.19` for keiro, `^>=0.9.0.1` for `kiroku-store`,
`shibuya-pgmq-adapter ^>=0.16.1` (in rei-cli), and `link-canonical`, `typeid-hs-*`,
`effectful` and `effectful-core` without bounds. The keiro packages (`keiro`, `keiro-core`,
`keiro-ops`, `keiro-pgmq`, `keiro-migrations`, `keiro-test-support`, `keiro-dsl`) are bounded
`^>=0.19` and `kioku-*` `^>=0.8` across `rei-core`, `rei-cli` and `rei-api`; if plan 15 released
keiro or kioku-core under a new major version, those bounds move too.

rei vendors `hasql-effectful` (from `topagentnetwork/tan-effectful` `5e081ad8`) as
`rei-core/src/Rei/Infrastructure/Hasql/Effect.hs`, `Hasql/Static/Connection.hs` and
`Hasql/Static/Pool.hs`, because Hackage's `hasql-effectful` 0.2.0.0 has an older, incompatible
API. The two `Static` modules and `rei-core/src/Rei/Infrastructure/Trace.hs` use effectful's
static-dispatch and unlifting internals, the parts effectful 2.7 changed.

Test and check commands (run inside `nix develop`, which the directory's `.envrc` enters):
`cabal build all`, `cabal test all` (uses ephemeral PostgreSQL servers, not the dev database),
`just openapi-check`, `just keiro-check`, `just dependency-closure-audit`, `just adr-validate`,
`nix build .#rei`, `nix flake check`. Never run two cabal builds in the same `dist-newstyle` at
once (spurious `renameFile … .o.tmp` failures).

Deployed agents (launchd, user domain): `com.shinzui.rei-worker-kiroku` (Kiroku subscriptions,
timers; metrics on port 9091), `com.shinzui.rei-worker` (PGMQ jobs), `com.shinzui.rei-watchdog`
(restarts unhealthy workers), and foreground `rei` CLI sessions. Logs are in `~/.rei/logs/`
(`worker-kiroku.stderr.log`, `worker.stderr.log`, …). The global database has 186 applied
migrations, including Kiroku `0012`, applied 2026-09-26.

### mori-app today

`cabal.project`: `index-state: 2026-09-26T18:09:31Z`, package `mori-app`, one pin for
`mori-types` (mori `32882f2d`), no `constraints` or `allow-newer`. `mori-app/mori-app.cabal`
bounds: library `hasql ^>=1.10`, `servant-server ^>=0.20`, `wai ^>=3.2`, `warp ^>=3.4`,
`generic-lens >=2.2 && <2.4`, `pg-migrate ^>=1.2`, `pgmq-* ^>=0.6.1`, `effectful ^>=2.6`,
`effectful-core ^>=2.6`; test suite `ephemeral-pg ^>=0.2`, `tasty ^>=1.5`, and the same two
effectful bounds. It has its own `scripts/dependency-closure-audit.sh`
with `EXPECT_COMMENT_SUPPRESSED=16`. It is consumed by mori-rei-app through a Cabal
`source-repository-package` and a Nix `mori-app-src` input.

### mori-rei-app today

`cabal.project`: same `index-state`, package `.`, four pins — `mori-app` `30aca6e3`, `mori-types`
(mori `32882f2d`), `rei-core` (rei `880093cc`, subdir `rei-core`), `typeid-hs` `7164a74c` — and
`constraints`/`allow-newer` copied from rei's, per mori-rei-app's ADR-1
(`mori://shinzui/mori-rei-app/okf/adrs/concepts/ADR-1`, "Mirror the pinned dependency's closure,
minus what it no longer needs": Cabal reads only the top-level project's `cabal.project`, so this
tree must repeat whatever rei-core's closure needs).

`flake.nix`: `haskell-nix-dev` is **unpinned** (`github:shinzui/haskell-nix-dev`, locked
`af29a486`, whose nixpkgs is `4df1b885`), `flake-parts` and `pre-commit-hooks` are separate
unpinned inputs, `haskell-nix` is `4cabd105…` following only `nixpkgs` (it cannot also follow
`haskell-nix-dev`, because that old `haskell-nix-dev` has no `flake-parts` input and Nix fails
with "follows a non-existent input"), and four non-flake sources: `mori-src`, `mori-app-src`,
`rei-src`, `typeid-hs-src`. `flake.module.nix` composes `inputs.haskell-nix.lib.haskellExtension`
with `nix/haskell-overlay.nix`, which defines `typeid-hs-*` (from `typeid-hs-src`), `link-canonical`,
`wai-app-static` 3.2.1, `servant-server = dontCheck (doJailbreak prev.servant-server)`,
`mori-types`, `mori-app` (with a `sourceRoot` fix for `../LICENSE`), `rei-core` (from
`${rei-src}/rei-core`) and `mori-rei-app`. `mori-rei-app.cabal` bounds `effectful ^>=2.6` and
`effectful-core ^>=2.6` in both the library and the test suite, and `keiro ^>=0.19` and
`keiro-migrations ^>=0.19` in the test suite.

Its `cabal test all` needs Rei's **repository-local development** PostgreSQL running (in rei:
`just process-up`, socket `rei/db/.s.PGSQL.5432`, with a `mori_rei_app` database migrated there);
`test/MoriReiApp/TestDb.hs` finds it with `mori path rei` and prints "To start the database: cd
$(mori path rei) && just process-up" when it is absent. 178 tests passed on 2026-09-26.

Deployed as `com.shinzui.mori-rei-app` (`mori-rei-app serve`, HTTP port 26862, `/health`), logs in
`~/.mori-rei-app/logs/server.stderr.log`. It appends Rei events to `dbname=rei` and keeps its own
state in `dbname=mori_rei_app` on the global instance, where it installs PGMQ migrations at
startup.

### dotfiles today

`flake.nix` has unpinned inputs `rei = github:shinzui/rei` and `mori-rei-app =
github:shinzui/mori-rei-app`, each with `inputs.nixpkgs.follows = "haskell-nix-dev/nixpkgs"` and
`inputs.haskell-nix-dev.follows = "haskell-nix-dev"`; the root `haskell-nix-dev` is locked at
`206ecd25`. `just update-rei` runs `nix flake update haskell-nix-dev rei` and must not be used:
moving `haskell-nix-dev` with an application has broken the closure before. `./bin/build.sh` runs
`nix build .#darwinConfigurations.SungkyungM1X.system`; the packages are
`.#darwinConfigurations.SungkyungM1X.pkgs.rei` and `.pkgs.mori-rei-app`. Only the user runs
`sudo ./bin/darwin-rebuild-sungkyung.sh`. Plan 14 later adds a deploy-time guard to dotfiles;
as the user relaxed it on 2026-09-26, applications on different channel revisions only produce
a warning, and the guard fails only when an application's closure differs from the freeze its
own pinned channel revision publishes. Activation re-bootstraps every agent at once; the
watchdog heals `rei-worker-kiroku` within about 30 seconds if activation kills it. `ps` shows
wrapper argv, so check a real binary with `lsof -p <pid>`. Old errors linger in logs, so filter
by today's timestamp.

### Operating rules

Never search or read `/nix/store` or `/`; query known paths with `nix-store -qR`, `nix path-info`,
`nix derivation show`, `nix eval`. Never `pkill` by pattern; stop agents with `launchctl bootout
gui/$(id -u)/<label>`. Quote heredoc delimiters (`<<'EOF'`). Two PostgreSQL instances each hold
a database named `rei`: the repository-local development one and the global one at
`/Users/shinzui/.local/state/postgresql`; always pass the connection string explicitly. Agents
never push, migrate a production database, or activate without the user's explicit go-ahead.

### Relevant ADRs

- `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` (this repository): one
  Nixpkgs fixed point with one version per package name, and no solver here. Rei's extension is
  composed into that one scope, not a second package set.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-16` ("Prefer moving a pin to lifting a bound"): when a
  bound blocks the cohort, take the current release or move a pin before any `allow-newer`; every
  surviving `allow-newer` names the bound, why the break does not reach Rei, the evidence, and the
  release that retires it.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort
  adoption"): adopting a cohort means changing and proving both Cabal and Nix, diffing the
  resolved plan for passengers, evaluating the Nix version rather than reading `flake.lock`, and
  reading exit codes rather than the last lines of output. This plan amends it: the
  `index-state` and versions now arrive through the freeze import.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-26` ("A replay audit must replay the code that
  ships") and `mori://shinzui/rei/okf/adrs/concepts/ADR-31` ("Gate runtime releases on restored
  history and observed delivery"): prove a release with the shipping binary against an
  identified restore; record source revision, package plan, binary identity, database identity
  and time; no traffic means untested, not passed.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-36` ("Discharge a removed pin with an absence proof
  and a guard"): removing a pin is proven by absence in both build systems plus a guard.
- `mori://shinzui/mori/okf/adrs/concepts/ADR-24` ("Source first-party Haskell packages from the
  shared overlay"): a consumer must not shadow the channel with a local pin.
- `mori://shinzui/mori-rei-app/okf/adrs/concepts/ADR-1` (see above; the Mori registry may not list
  it yet). Amended by this plan.

Rei's `docs/adr/` is an OKF bundle governed by `docs/adr/profile.dhall`: each record has
frontmatter `type: Architecture Decision Record`, `title`, `description` (one sentence),
`timestamp`, `docId: ADR-N`, `status`, `date`; filenames are `NNN-kebab-title.md`; `index.md`
lists each record and `log.md` records each change. mori-rei-app's `docs/adr/` has the same shape.


## Plan of Work

Work proceeds in six milestones. Milestones 1 to 3 happen in rei, 4 in mori-app, 5 in
mori-rei-app, and 6 in dotfiles with the user. Nothing is pushed or deployed without the user's
go-ahead. Before Milestone 1, confirm plans 9 and 10 are marked Complete in the MasterPlan
registry (plan 9 depends on plan 8, which depends on plan 15, so those are complete too; check
that plan 15's row says Complete and read its released versions), record `R`, read plan 9's Interfaces section for the parity script's real name and
arguments and the consumer extension attribute, read plan 10's deletion lists for rei and
mori-rei-app, and read plan 8's upgrade report for the three repositories. Write all of these into
Surprises & Discoveries and replace the placeholders in this plan.

### Milestone 1: rei's Cabal plan equals the freeze

Scope: `cabal.project`, `rei-cli/rei-cli.cabal` (and any other `.cabal` file plan 8's report
names), the `Justfile`'s `keiro-dsl` index-state, and whatever Haskell source the upgraded
packages break. At the end, `cabal build all` and `cabal test all` pass with the freeze imported,
and the parity script reports zero differences for `dist-newstyle/cache/plan.json`.

First capture the current resolved plan so passengers can be named afterwards (ADR-18 rule 2).
Then add, near the top of `cabal.project` and after its header comment, a comment and the import:

```cabal
-- The shared cohort: one version of every Hackage package the Rei family uses,
-- resolved upgrade-only by mori://shinzui/haskell-nix and imported at the SAME
-- revision flake.nix pins for haskell-nix. Move both together, never one.
-- See mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
import: https://raw.githubusercontent.com/shinzui/haskell-nix/<R>/cabal/cohort.freeze
```

Reconcile the rest of the file against the freeze, one kind of field at a time:

- `index-state`: if the freeze file carries an `index-state:` line, delete rei's own (two
  sources for one setting is exactly the drift being removed) and replace the header comment's
  claim with a pointer to the import. If it does not, set rei's to the index-state plan 8 records
  as the resolve point. Change the `--index-state=` in the `Justfile`'s `keiro-dsl` recipe to the
  same value.
- `constraints:`: delete a line when the freeze already fixes that package to a version that
  satisfies it (for example `crypton >= 1.1` when the freeze has `any.crypton ==1.1.5`, or
  `http-client-tls >= 0.4` when it has a 0.4 version). Flag constraints (`dhall
  -use-http-client-tls`, the `blake3` SIMD flags) stay unless the freeze carries the identical
  flag line; if the freeze carries the *opposite* flag, stop — that is a plan 8 defect, and
  resolving it here would fork the cohort. Keep the `package blake3` `ghc-options` stanza and the
  `tests: False` stanza; they are build settings, not versions. Update the long comment above
  `constraints:` so every survivor still has its own reason.
- `allow-newer:`: the freeze fixes versions, not bounds, so most entries will survive. Test each:
  delete it, run `cabal build all --dry-run`, and keep it only if the solver then fails. For a
  survivor, re-read its justification and update the version numbers it cites (for example
  `baikai-kit 0.3.0.0`, `kiroku-cli 0.2.0.6`) to the frozen ones; keep the comment order equal to
  the list order.

Then lift every bound in rei's own `.cabal` files that plan 8's report names. Expected: in
`rei-cli/rei-cli.cabal` change `brick ^>=2.6` to a bound admitting the frozen brick (for 2.9,
`brick ^>=2.9`) and `vty ^>=6.2` to `vty ^>=6.4`; check whether `vty-crossplatform` or
`vty-unix` need the same. Run `cabal build all`. Where it fails, read the upgraded package's
changelog before editing: find the source with `mori registry search brick` (and `vty`), or
unpack the tarball Cabal has already downloaded with `cabal get brick-<version>` into
`.dev/cohort/`, and read `CHANGELOG.md`. Fix the call sites in rei's source (the TUI modules under
`rei-cli/src` that import `Brick` or `Graphics.Vty`). Do not add a `constraints:` line to hold a
package back; that would violate upgrade-only.

The freeze also moves `effectful` to 2.7.1.0 and `effectful-core` to 2.7.1.1 or later and the keiro and
kioku-core packages to plan 15's releases. If plan 15 released a new major (for example keiro
0.20), move rei's `^>=0.19` keiro and `^>=0.8` kioku bounds to it in `rei-core/rei-core.cabal`,
`rei-cli/rei-cli.cabal` and `rei-api/rei-api.cabal` (and the `keiro-dsl` version in the
`Justfile`'s `cabal install` line if keiro-dsl moved); otherwise they already admit it. rei
declares `effectful`/`effectful-core` without bounds, so no bound moves for them. Then port rei
to effectful 2.7. Read effectful's changelog for 2.7 first (`mori registry search effectful`, or
`cabal get effectful-core-<frozen version>` into `.dev/cohort/`). Find the affected code with:

```bash
grep -rnE 'LocalEnv|SharedSuffix|KnownEffects|localSeqUnlift|localUnlift|localLend|localBorrow|Effectful\.Dispatch\.Static|Effectful\.Internal|Effectful\.[A-Za-z.]*\.Strict' rei-core/src rei-core/test rei-cli/src rei-api/src
```

On `880093cc` this names `rei-core/src/Rei/Infrastructure/Trace.hs` and the vendored
`rei-core/src/Rei/Infrastructure/Hasql/Static/Connection.hs` and `.../Hasql/Static/Pool.hs`;
also rebuild `rei-core/src/Rei/Infrastructure/Hasql/Effect.hs`, the third vendored module, which
uses dynamic dispatch. The vendored modules are Rei's own code now (their header names the
upstream revision): port them in place, keep the header, and add one line saying they were
adapted to effectful 2.7. Do not replace them with Hackage's `hasql-effectful`, and never add an
`allow-newer` for `effectful` or `effectful-core`, which the user ruled out. If a dependency
outside rei still caps effectful below 2.7.1.1, that is a plan 8 or plan 15 defect: stop and
record it rather than working around it here.

Prove it: `cabal test all`, `just openapi-check` (the OpenAPI document must not change; if an
upgraded `aeson` or `openapi-hs` changes it, record why in Surprises and regenerate deliberately),
`just keiro-check`, and `just dependency-closure-audit` (re-derive a census only if the change is
reviewed and explained). Then run the parity script on `plan.json`. Commit.

### Milestone 2: rei's Nix closure equals the freeze, and Rei exports `rei-core`

Scope: `flake.nix`, `flake.lock`, `flake.module.nix`, `nix/haskell-overlay.nix`, and possibly
`scripts/dependency-closure-audit.sh`'s counts. At the end, `nix build .#rei`, `.#rei-api` and
`.#rei-core` succeed from the channel at `R` with no shared overrides left locally; the parity
script reports zero differences for the `rei-cli` closure; and `nix eval .#lib.haskellExtension`
is a function other flakes can compose.

In `flake.nix`, change the `haskell-nix.url` revision from `4cabd105…` to `R` (the only edit to
that input), then run `nix flake lock` and confirm with `git diff flake.lock` that only
`haskell-nix` and its own new sub-inputs moved. Also delete the `typeid-hs-src` input and its
comment block: `typeid-hs` is public, and plan 10 put `typeid-hs-sql` and `typeid-hs-pg-migrate`
into the channel at `7164a74c490cc92ffe73a315d827c9515de125d3`, the same revision as the `tag:`
in `cabal.project` (which stays, because typeid-hs is not on Hackage). After relocking, the only
`typeid-hs` node left in `flake.lock` is the one reached through `haskell-nix`; its `rev` must be
`7164a74c…` (Concrete Steps shows the `jq` query; if plan 10 records the source in its own lock
file instead of a flake input, read the revision there as plan 10's Interfaces describe). If the
channel's revision differs from `7164a74c`, that is a plan 10 defect: fix the channel, push, and
move `R`; do not keep a local input.

In `nix/haskell-overlay.nix`, delete every entry plan 10's deletion list names for rei. Expected
deletions: `link-canonical`, `openapi-hs`, `servant-openapi-hs`, `servant-health`, the three
`hs-opentelemetry-*` entries, the four `relay-pagination*` entries, `kioku-core`'s
`disableLibraryProfiling`, and `typeid-hs-sql`/`typeid-hs-pg-migrate`. Delete their comments too,
replacing them with one short paragraph saying shared packages come from the channel per
`mori://shinzui/mori/okf/adrs/concepts/ADR-24` as extended by plan 10. What remains is Rei's own
`rei-core`, `rei-api` and `rei-cli`. Change the file's argument set to `{ pkgs, gitRev }`.

In `flake.module.nix`, define the extension once at the top level and export it, and build Rei
from it:

```nix
{ inputs, ... }:
let
  # Rei's own Haskell packages as an extension for a ghc9124 scope that already
  # carries the haskell-nix channel. Same calling convention as
  # inputs.haskell-nix.lib.haskellExtension, so consumers compose both in one list.
  # Another application that links rei-core composes THIS, instead of calling
  # callCabal2nix on a copy of Rei's source (docs/adr/0NN-…).
  haskellExtension = _haskellLib: pkgs:
    import ./nix/haskell-overlay.nix {
      inherit pkgs;
      gitRev = inputs.self.shortRev or "dirty";
    };
in
{
  flake.lib.haskellExtension = haskellExtension;

  perSystem = { system, pkgs, config, ... }:
    let
      haskellPackages = pkgs.haskell.packages.ghc9124.override {
        overrides = pkgs.lib.composeManyExtensions [
          (inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose pkgs)
          (haskellExtension pkgs.haskell.lib.compose pkgs)
        ];
      };
      # … unchanged …
    in
    {
      packages.rei = haskellPackages.rei-cli;
      packages.default = haskellPackages.rei-cli;
      packages.rei-api = haskellPackages.rei-api;
      # The library other applications link, exposed so a consumer's copy can be
      # compared with this one by store path, and so the deploy gate can build the
      # rei-migrations runner from the same revision as the CLI.
      packages.rei-core = haskellPackages.rei-core;
      # … unchanged …
    };
}
```

Use `inputs.haskell-nix.lib.haskellExtension` (which equals `.haskellExtensions.github`) unless plan
9 or 10 names a different consumer entry point, in which case use that one in both rei and
mori-rei-app. The `gitRev` argument only affects `rei-cli`, so `rei-core`'s derivation does not
depend on it.

Prove it: `nix build .#rei --print-out-paths`, `nix build .#rei-api`, `nix build .#rei-core`, each
checked by exit code. Any failure in a *dependency* whose Cabal version is already the frozen one
is a channel build-policy gap: record it, fix it in this repository (plan 9 or 10's registry),
push, and move `R` — do not re-add a local override. Run the parity script on the `rei-cli`
closure and on the `rei-core` derivation's version (`nix eval --raw .#rei-core.version` should
equal rei-core's `.cabal` version). The closure parity also proves the Nix side of the effectful
2.7 move: the `rei-cli` derivation closure must contain `effectful-core` only at the frozen 2.7
version, never 2.6 (Concrete Steps shows the query). Run `nix flake check`. Re-run `just
dependency-closure-audit`; deleting `typeid-hs-src` will likely move `EXPECT_TAN_FLAKE` or
`EXPECT_LOCK_TYPEID`; if so, run it with `--census`, update the constants with a comment saying the
typeid-hs source now reaches Nix through the channel, and explain it in the commit. Commit.

### Milestone 3: record the decision in rei and publish `C`

Allocate a handle with `okf id next docs/adr --profile docs/adr/profile.dhall ADR` (it printed
`ADR-49` on 2026-09-26; use whatever it prints). Write
`docs/adr/049-an-application-that-depends-on-another-application-s-library-consumes-that-application-s-flake-output.md`
(number from the handle) with the profile's frontmatter and these sections:

- Context: mori-rei-app rebuilt `rei-core` with `callCabal2nix` on a `rei-src` input in its own
  scope, and its unrelated overrides (`wai-app-static` 3.2.1, a jailbroken `servant-server`)
  changed the hash of everything above them up to `rei-core`, so two deployed programs carried
  two different builds of the same library, and an unpinned `haskell-nix-dev` let its channel
  drift.
- Decision: an application whose library another application links exports a Haskell extension
  (`lib.haskellExtension`, calling convention `haskellLib: pkgs: final: prev:`) containing only its
  own packages and builds itself from that same extension; the consumer takes the producer as a
  rev-pinned flake input, composes the channel then the producer's extension, and follows the
  producer's `haskell-nix` and `haskell-nix-dev`; on the Cabal side the consumer keeps a
  `source-repository-package` at the same commit and imports the same freeze. Both programs are
  deployed from the same producer commit, which is proven by comparing the library's store path.
- Alternatives rejected: `callCabal2nix` on a source input (the status quo; two derivations and a
  drift nothing reports); publishing `rei-core` to Hackage (rei is private and unreleased);
  making `rei-core` a first-party family in the haskell-nix channel (ties the channel's release
  cadence to an application's commits); having the producer follow the consumer (inverts
  ownership).
- Consequences: a producer commit that changes nothing in the library still changes its
  derivation (the source is the whole repository), so deploys pin both programs to one commit;
  plan 12 reuses the shape for `mori-types`.

Add it to `docs/adr/index.md`, and log it with `okf log add docs/adr --kind Added -m "ADR-49 …
(haskell-nix ExecPlan 11)"`. Amend ADR-18: add an "Amended 2026-…" line under its header noting
that since this plan the `index-state` and every Hackage version reach Cabal through the
`import:` of haskell-nix's freeze, and that the Nix side is generated from the same file, so
rules 1 to 4 are carried out in haskell-nix; advance its `timestamp` and add an `Updated` log
entry. Run `just adr-validate` and the strict command from Concrete Steps. Commit. Ask the user
to push; after the push, record `C = git rev-parse HEAD` and confirm
`nix flake metadata github:shinzui/rei/<C>` resolves.

### Milestone 4: mori-app imports the freeze

Scope: `cabal.project`, `mori-app/mori-app.cabal`, test sources if `ephemeral-pg` 0.3 changed its
API, possibly `scripts/dependency-closure-audit.sh`'s comment census. Add the same comment and
`import:` at `R` (mori-app has no haskell-nix flake input, so `R` is taken from rei). Apply the
same `index-state` rule. Lift the bounds plan 8's report names; expected: `ephemeral-pg ^>=0.2`
to `ephemeral-pg ^>=0.3` in the test suite, `effectful ^>=2.6` and `effectful-core ^>=2.6` to
`^>=2.7` in both the library and the test suite (plan 8's freeze has them at 2.7.1.1 or later),
and any other cap the solver reports (read the `cabal build all --dry-run` rejection, which names
the package and bound). Run the same effectful grep as Milestone 1 over `mori-app/src` and
`mori-app/test`; on `30aca6e3` it finds nothing, so the bound change should be enough, but fix any
site the compiler names. Never `allow-newer` effectful. Port the tests if the
`EphemeralPg` API changed (compare with rei's `rei-core` test harness, which already runs on
0.3.1.0, and with mori-rei-app's `test/MoriReiApp/KirokuTestDb.hs`). Prove with `cabal build all`,
`cabal test all`, `scripts/dependency-closure-audit.sh`, and the parity script on `plan.json`.
Commit, ask the user to push, record `A`.

### Milestone 5: mori-rei-app imports the freeze and consumes Rei's `rei-core`

Scope: `cabal.project`, `mori-rei-app.cabal` (at least its `effectful` bounds), `flake.nix`,
`flake.lock`, `flake.module.nix`, `nix/haskell-overlay.nix`, `scripts/dependency-closure-audit.sh`,
`docs/adr/001-…md`, `docs/adr/log.md`. At the end, the Cabal plan equals the freeze, the Nix
build contains no shared overrides and no copy of Rei's source, and the built `rei-core` store path
equals rei's.

Cabal side: add the comment and `import:` at `R`. Move the `rei-core` pin's `tag:` to `C` and the
`mori-app` pin's `tag:` to `A`; keep `mori-types` (plan 12 owns it) and `typeid-hs` (public now,
but still not on Hackage, so Cabal needs the pin at `7164a74c`). Then make the `index-state`, `constraints:` and `allow-newer:` blocks equal to what rei
kept in Milestone 1 (ADR-1 still applies to constraints and allow-newer: this tree must repeat what
rei-core's closure needs), and rewrite the header comment: versions and `index-state` now come
from the freeze, and only rei-core's surviving constraints and allow-newer entries are mirrored.
Run `cabal build all`; lift any bound the report names in `mori-rei-app.cabal`. Expected:
`effectful ^>=2.6` and `effectful-core ^>=2.6` to `^>=2.7` in the library and the test suite,
and the test suite's `keiro`/`keiro-migrations ^>=0.19` if plan 15 released a new keiro major.
Run the Milestone 1 effectful grep over `src`, `app` and `test`; on `2acd4ed4` it finds nothing,
and the ten modules that import `Rei.Infrastructure.Hasql.Effect` get rei's ported copy through
the `rei-core` pin at `C`. Never `allow-newer` effectful. Start Rei's
development database (`cd /Users/shinzui/Keikaku/bokuno/rei-project/rei && just process-up`) and
run `cabal test all`; expect the 178 tests (or more) to pass. Run the parity script on `plan.json`.

Nix side, `flake.nix`:

```nix
inputs = {
  # Rei, rev-pinned to the commit whose rei-core this application links. Every
  # toolchain input follows Rei's, so this flake cannot select a different channel
  # or nixpkgs than the one rei-core was proven on. Keep the revision equal to the
  # rei-core `tag:` in ./cabal.project.
  rei.url = "github:shinzui/rei/<C>";

  haskell-nix-dev.follows = "rei/haskell-nix-dev";
  nixpkgs.follows = "haskell-nix-dev/nixpkgs";
  flake-parts.follows = "haskell-nix-dev/flake-parts";
  treefmt-nix.follows = "haskell-nix-dev/treefmt-nix";
  pre-commit-hooks.follows = "haskell-nix-dev/pre-commit-hooks";
  haskell-nix.follows = "rei/haskell-nix";

  mori-src = { url = "github:shinzui/mori/32882f2d48bde6735d73cbd81c012c8d30ba11f3"; flake = false; };
  mori-app-src = { url = "github:shinzui/mori-app/<A>"; flake = false; };
  # typeid-hs-sql and typeid-hs-pg-migrate come from the haskell-nix channel (plan 10).
};
```

Delete `rei-src` and `typeid-hs-src`; the channel supplies `typeid-hs-*` at `7164a74c`. Run `nix flake lock` and confirm in `flake.lock` that there is exactly one
`haskell-nix` node and one `haskell-nix-dev` node and that the latter is `206ecd25…`.

`flake.module.nix`:

```nix
haskellPackages = pkgs.haskell.packages.ghc9124.override {
  overrides = pkgs.lib.composeManyExtensions [
    (inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose pkgs)
    (inputs.rei.lib.haskellExtension pkgs.haskell.lib.compose pkgs)
    (import ./nix/haskell-overlay.nix {
      inherit pkgs;
      inherit (inputs) mori-src mori-app-src;
    })
  ];
};
```

`nix/haskell-overlay.nix`: delete `rei-core`, `link-canonical`, `wai-app-static`,
`servant-server` and `typeid-hs-sql`/`typeid-hs-pg-migrate` (per plan 10's list for
mori-rei-app), and the `rei-src` /
`typeid-hs-src` arguments. Keep `mori-types`, `mori-app` (with its `sourceRoot` fix) and
`mori-rei-app`. Add a short comment that `rei-core` comes from Rei's flake per rei's new ADR.

`scripts/dependency-closure-audit.sh`: retarget the leg at lines 240-244 from `flake.nix` to
`flake.lock`, whose nodes record every source Nix will fetch including those reached through
`rei` and `haskell-nix`, and update its comment to say so; the intent (Cabal and Nix select the
same source revisions) is unchanged. Re-run with `--census`; if `EXPECT_COMMENT_SUPPRESSED` moved
because comments changed, update it deliberately with a note. Its "exactly 4 git pins" assertion
still holds.

Prove it: `nix build --print-out-paths`, the parity script on that closure, and the `rei-core`
identity check in Validation. Run the audit and `nix flake check`. Amend ADR-1 (header "Amended"
line, updated `timestamp`, a paragraph saying `index-state` and versions now come from the freeze
and `rei-core` from Rei's flake output, citing `mori://shinzui/rei/okf/adrs/concepts/ADR-49` or
whatever handle Milestone 3 allocated) and log it with `okf log add`. Validate the bundle with
mori-rei-app's profile. Commit, ask the user to push, record `M`.

### Milestone 6: deploy both with the user

Scope: dotfiles `flake.lock` only, then the user's activation, then verification. This is a
restart, not a schema cutover, provided the two gates in the Decision Log hold. At the end, the
running agents execute the proven store paths and delivery has been observed or explicitly
recorded as untested.

First take a read-only baseline of production (Concrete Steps). Then, in dotfiles, confirm that
`github:shinzui/rei` and `github:shinzui/mori-rei-app` `master` are exactly `C` and `M`
(`git ls-remote`). If so run `nix flake update rei mori-rei-app` (the other applications stay on their own channel revisions;
under plan 14's relaxed guard that is a warning, not a failure, as long as each closure matches
the freeze of its own pinned revision) — never `just update-rei` or
`just update-mori-rei-app`, which also move `haskell-nix-dev`. If either `master` has moved on,
use `nix flake lock --override-input rei github:shinzui/rei/<C> --override-input mori-rei-app
github:shinzui/mori-rei-app/<M>` instead. `git diff flake.lock` must touch only those two
inputs and their sub-inputs; leave every other uncommitted file untouched. Run `./bin/build.sh`,
build the two packages to out-links, and confirm the store paths and the `rei-core` path equal the
ones proven in Milestones 2 and 5 (if they differ, stop: the dotfiles overrides changed a hash, and
the difference must be explained before anything runs).

Then rehearse with the shipped binaries on a fresh clone of the global database: the clone harness
with the shipped `rei-migrations`, then migration `status` and `verify` on the clone (expect
`pending=0`; if not, stop and follow the MasterPlan's stop-writers cutover instead), then the replay
gate with `REI_BIN` set to the shipped `rei`. Compare the `pgmq-migration` version in the old and
new mori-rei-app closures; if it changed, also rehearse mori-rei-app's startup against a clone of
`mori_rei_app`. Only then ask the user to run `sudo ./bin/darwin-rebuild-sungkyung.sh`, and verify.
Commit the dotfiles lock (with the trailers) only after the user confirms, and only the lock.


## Concrete Steps

Use the Review requirements for final manifest-based acceptance. Historical runtime-closure commands below describe baseline diagnostics; they cannot establish Haskell dependency parity. Consumers export an app alias `apps.<system>.cohort-compare` from their pinned channel to bootstrap lock resolution without guessing node names.

Set these once per shell. `R`, `C`, `A`, `M` are filled in as they become known.

```bash
export R=<40-hex haskell-nix revision after plans 9 and 10>
export HN=/Users/shinzui/Keikaku/bokuno/haskell-nix
export FREEZE="https://raw.githubusercontent.com/shinzui/haskell-nix/$R/cabal/cohort.freeze"
PARITY=(nix run "github:shinzui/haskell-nix/$R#cohort-compare" --)   # plan 9's flake app; a bash array, so not exported
grep -n '^| 15 \|^| 9 \|^| 10 ' "$HN/docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md"   # all Complete
curl -sf "$FREEZE" | grep -E 'any\.(effectful|effectful-core|keiro|kioku-core) '   # effectful 2.7.1.1 or later; plan 15's keiro/kioku-core
```

### Milestone 1 (working directory: /Users/shinzui/Keikaku/bokuno/rei-project/rei)

```bash
mkdir -p .dev/cohort
cabal update
cabal build all --dry-run
jq -r '."install-plan"[] | select((.["pkg-src"].type? // "") != "local") | "\(.["pkg-name"]) \(.["pkg-version"])"' \
  dist-newstyle/cache/plan.json | sort -u > .dev/cohort/before.txt
# edit cabal.project, rei-cli/rei-cli.cabal, Justfile as described
cabal build all --dry-run -v1 2>&1 | grep -i 'historical state'   # shows the index-state in force
jq -r '."install-plan"[] | select(.["pkg-name"] | test("^effectful(-core)?$")) | "\(.["pkg-name"]) \(.["pkg-version"])"' \
  dist-newstyle/cache/plan.json | sort -u                          # 2.7.1.1 or later, never 2.6
grep -rnE 'LocalEnv|SharedSuffix|KnownEffects|localSeqUnlift|localUnlift|localLend|localBorrow|Effectful\.Dispatch\.Static|Effectful\.Internal|Effectful\.[A-Za-z.]*\.Strict' \
  rei-core/src rei-core/test rei-cli/src rei-api/src              # the effectful 2.7 sites to port
grep -n 'allow-newer' -A12 cabal.project | grep -i effectful     # must print nothing
cabal build all
cabal test all
jq -r '."install-plan"[] | select((.["pkg-src"].type? // "") != "local") | "\(.["pkg-name"]) \(.["pkg-version"])"' \
  dist-newstyle/cache/plan.json | sort -u > .dev/cohort/after.txt
diff .dev/cohort/before.txt .dev/cohort/after.txt     # the passengers; summarise in the commit and in Surprises
just openapi-check
just keiro-check
just dependency-closure-audit
"${PARITY[@]}" --freeze "$FREEZE" --plan-json dist-newstyle/cache/plan.json
```

Expected parity result (exact wording is plan 9's): zero packages that differ from the freeze, and
no frozen package reported as absent from the freeze. The allow-newer test for each entry:

```bash
# after deleting one entry from allow-newer:
cabal build all --dry-run   # rejection => restore the entry; success => leave it deleted
```

Commit message shape (each repository uses the same trailer block; rei adds `Module:`):

```text
build(deps): import the shared cohort freeze from haskell-nix <R:0:8>

Import cabal/cohort.freeze at the haskell-nix revision the flake pins, drop
the constraints it makes redundant, lift the brick and vty bounds the freeze
moves, adapt the TUI to brick <v>, and port the vendored Hasql effect and
the trace module to effectful 2.7. Passengers: <list from the diff>.

Module: infrastructure
MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/11-adopt-the-shared-package-set-in-rei-and-mori-rei-app
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

### Milestone 2 (same directory)

```bash
# edit flake.nix (haskell-nix url -> R), then:
nix flake lock
git diff --stat flake.lock
jq -r '.nodes["haskell-nix"].locked.rev' flake.lock                     # must print R
grep -o 'haskell-nix/[0-9a-f]\{40\}/cabal' cabal.project               # must name R
jq -r '.nodes | to_entries[] | select(.value.locked.repo? == "typeid-hs") | "\(.key) \(.value.locked.rev)"' flake.lock
                                                                        # only the channel's node, rev 7164a74c...
grep -n 'typeid-hs-src' flake.nix nix/haskell-overlay.nix flake.module.nix   # must print nothing
# edit nix/haskell-overlay.nix and flake.module.nix as described
nix build .#rei --print-out-paths; echo "exit=$?"
nix build .#rei-api --no-link; echo "exit=$?"
nix build .#rei-core --print-out-paths; echo "exit=$?"
REI_OUT=$(nix build .#rei --print-out-paths)
"${PARITY[@]}" --freeze "$FREEZE" --closure "$REI_OUT"
nix-store -qR "$(nix path-info --derivation .#rei)" | grep -oE -- '-effectful(-core)?-[0-9][0-9.]*\.drv$' | sort -u
                                                                        # only the frozen 2.7 versions, no 2.6
nix eval --raw .#rei-core.version
nix eval .#lib.haskellExtension --apply builtins.isFunction          # true
nix flake check; echo "exit=$?"
just dependency-closure-audit
```

Never pipe a `nix build` through `tail` and read the output; read `exit=`.

### Milestone 3 (same directory)

```bash
okf id next docs/adr --profile docs/adr/profile.dhall ADR
# write the ADR, edit docs/adr/index.md, amend ADR-18
okf log add docs/adr --kind Added -m "ADR-49 an application that depends on another application's library consumes that application's flake output (haskell-nix ExecPlan 11)"
okf log add docs/adr --kind Updated -m "ADR-18 the index-state and Hackage versions now arrive through the haskell-nix cohort freeze import (haskell-nix ExecPlan 11)"
just adr-validate
okf validate docs/adr --strict --profile docs/adr/profile.dhall --profile-enforce --log-enforce
git log --oneline -5
# after the user pushes:
export C=$(git rev-parse HEAD)
nix flake metadata "github:shinzui/rei/$C" >/dev/null && echo resolved
```

### Milestone 4 (working directory: /Users/shinzui/Keikaku/bokuno/mori-project/mori-app)

```bash
cabal update
# edit cabal.project and mori-app/mori-app.cabal
cabal build all --dry-run
cabal build all && cabal test all
scripts/dependency-closure-audit.sh
"${PARITY[@]}" --freeze "$FREEZE" --plan-json dist-newstyle/cache/plan.json
# commit; after the user pushes:
export A=$(git rev-parse HEAD)
```

### Milestone 5 (working directory: /Users/shinzui/Keikaku/bokuno/mori-project/mori-rei-app)

```bash
(cd /Users/shinzui/Keikaku/bokuno/rei-project/rei && just process-up)   # Rei's dev database for the tests
cabal update
# edit cabal.project
cabal build all
cabal test all
"${PARITY[@]}" --freeze "$FREEZE" --plan-json dist-newstyle/cache/plan.json
# edit flake.nix, flake.module.nix, nix/haskell-overlay.nix
nix flake lock
jq -r '.nodes | keys[]' flake.lock | grep -E '^haskell-nix'           # exactly: haskell-nix, haskell-nix-dev
jq -r '.nodes["haskell-nix-dev"].locked.rev' flake.lock                 # 206ecd25...
MRA_OUT=$(nix build --print-out-paths); echo "exit=$?"
"${PARITY[@]}" --freeze "$FREEZE" --closure "$MRA_OUT"
REI_CORE_HERE=$(nix-store -qR "$MRA_OUT" | grep -- '-rei-core-[0-9]')
REI_CORE_REI=$(nix build "github:shinzui/rei/$C#rei-core" --print-out-paths)
echo "$REI_CORE_HERE"; echo "$REI_CORE_REI"                              # must be the same path
scripts/dependency-closure-audit.sh --census
scripts/dependency-closure-audit.sh
nix flake check; echo "exit=$?"
# after the user pushes:
export M=$(git rev-parse HEAD)
```

If `rei-core` does not appear in the runtime closure (a statically linked executable need not
retain it), compare derivations instead: `nix-store -qR "$(nix-store -qd "$MRA_OUT")" | grep
'rei-core-[0-9].*\.drv$'` against `nix path-info --derivation "github:shinzui/rei/$C#rei-core"`.

### Milestone 6 (dotfiles, with the user)

Baseline (read-only; working directory rei):

```bash
REI_RELEASE_URL='host=/Users/shinzui/.local/state/postgresql dbname=rei user=shinzui'
date -u '+%Y-%m-%dT%H:%M:%SZ'
rei --version
launchctl list | grep com.shinzui
lsof -nP -iTCP:9091 -sTCP:LISTEN; lsof -nP -iTCP:26862 -sTCP:LISTEN
rei kiroku subscriptions status --remote-url http://localhost:9091
curl -sf http://localhost:26862/health; echo " exit=$?"
```

Lock and build (working directory /Users/shinzui/.config/dotfiles.nix):

```bash
git status --short                               # note unrelated dirty files; do not touch them
git ls-remote https://github.com/shinzui/rei refs/heads/master
git ls-remote https://github.com/shinzui/mori-rei-app refs/heads/master
nix flake update rei mori-rei-app                # or the --override-input form if master moved past C / M
git diff --stat flake.lock
./bin/build.sh; echo "exit=$?"
REI_PKG=$(nix build .#darwinConfigurations.SungkyungM1X.pkgs.rei --print-out-paths)
MRA_PKG=$(nix build .#darwinConfigurations.SungkyungM1X.pkgs.mori-rei-app --print-out-paths)
nix-store -qR "$REI_PKG" | grep -E -- '-(rei-cli|rei-core)-[0-9]'
nix-store -qR "$MRA_PKG" | grep -E -- '-(mori-rei-app|rei-core)-[0-9]'
"$REI_PKG/bin/rei" --version                     # rei 6.x (<C:0:7>)
"${PARITY[@]}" --freeze "$FREEZE" --closure "$REI_PKG"
"${PARITY[@]}" --freeze "$FREEZE" --closure "$MRA_PKG"
```

The `rei-cli` path must equal Milestone 2's `REI_OUT` closure member, the `mori-rei-app` path
must equal Milestone 5's `MRA_OUT`, and both closures must list the same `rei-core` path.

Clone rehearsal with the shipped binaries (working directory rei):

```bash
REI_BIN=$(nix-store -qR "$REI_PKG" | grep -- '-rei-cli-[0-9]')/bin/rei
REI_MIGRATIONS_BIN=$(nix build "github:shinzui/rei/$C#rei-core" --print-out-paths)/bin/rei-migrations
shasum -a 256 "$REI_BIN" "$REI_MIGRATIONS_BIN"
REI_SCRATCH_URL="host=/Users/shinzui/.local/state/postgresql dbname=rei_ep11_$(date -u +%Y%m%d%H%M) user=shinzui"
SOURCE_DATABASE_URL="$REI_RELEASE_URL" SCRATCH_DATABASE_URL="$REI_SCRATCH_URL" \
  REI_BIN="$REI_BIN" REI_MIGRATIONS_BIN="$REI_MIGRATIONS_BIN" \
  RELEASE_CANDIDATE_COMMIT="$C" KEEP_SCRATCH=1 \
  EVIDENCE_DIR=.backups/clone-prove/hn-ep11-$(date -u +%Y%m%d) \
  ./scripts/validate-on-clone.sh; echo "exit=$?"
"$REI_MIGRATIONS_BIN" status --database-url "$REI_SCRATCH_URL"
"$REI_MIGRATIONS_BIN" verify --database-url "$REI_SCRATCH_URL"
REI_BIN="$REI_BIN" ./scripts/replay-audit-gate.sh "$REI_SCRATCH_URL"; echo "exit=$?"
```

If `rei-core` has no `bin/rei-migrations` (check with `ls "$(nix build … --print-out-paths)/bin"`),
use `cabal list-bin rei-core:rei-migrations` from a clean checkout of `C` and record that the
runner came from Cabal at the same revision (ADR-31 requires the revision, not the builder, to
match). Expected:

```text
result=PASS                                   (validate-on-clone summary)
applied=186 pending=0 unknown=0 issues=0      (or the candidate plan's count, with pending=0)
verification=passed
replay gate: exit 0; 13 streams / 89 events excused, no other failure
```

Then, after the user runs `sudo ./bin/darwin-rebuild-sungkyung.sh` in dotfiles:

```bash
for label in com.shinzui.rei-worker-kiroku com.shinzui.rei-worker com.shinzui.mori-rei-app; do
  pid=$(launchctl list | awk -v l="$label" '$3==l {print $1}')
  echo "$label pid=$pid"; lsof -p "$pid" | awk '$4=="txt" && /\/bin\//'
done
rei --version
rei kiroku subscriptions status --remote-url http://localhost:9091
curl -sf http://localhost:26862/health; echo " exit=$?"
TODAY=$(date +%Y-%m-%d)
grep "$TODAY" ~/.rei/logs/worker-kiroku.stderr.log | tail -40
grep "$TODAY" ~/.rei/logs/worker.stderr.log | tail -40
grep "$TODAY" ~/.mori-rei-app/logs/server.stderr.log | tail -40
"$REI_MIGRATIONS_BIN" verify --database-url "$REI_RELEASE_URL"
```

Each `lsof` line must show an executable under the proven `rei-cli` or `mori-rei-app` store path
(or the wrapper that execs it). If `rei-worker-kiroku` is absent right after activation, wait for
the watchdog (about 30 seconds) before concluding anything. Log timestamps may be in UTC or local
time; match the log's own format.

Finally observe delivery: note genuine traffic since activation (a note edit reaching its task and
workspace Git commit; a push with an `Intention:` trailer recorded as a Rei action by
mori-rei-app). Record each class observed with its evidence, and every class without traffic as
untested (ADR-31). Commit the dotfiles lock with the trailer block only after the user confirms.

Drop the scratch database when the evidence is recorded (`dropdb` on the explicit scratch name,
never on `rei`).


## Validation and Acceptance

The review requirements above are additional completion gates, including the assigned update-isolation, manifest and cache evidence. Historical runtime-closure/version tables are diagnostic evidence only; they cannot replace those gates.

The plan is accepted when all of the following are observed and recorded in Outcomes:

1. In rei, mori-app and mori-rei-app, `cabal build all` and `cabal test all` pass with the freeze
   imported at `R`, and the parity script reports zero differences for each `plan.json`. Each
   `plan.json` selects `effectful` and `effectful-core` at the frozen 2.7.1.1-or-later version,
   and no `cabal.project` among the three has an `allow-newer` entry naming `effectful` or
   `effectful-core`.
2. In rei, `jq -r '.nodes["haskell-nix"].locked.rev' flake.lock` and the `import:` line name the
   same `R`; in mori-rei-app, the single `haskell-nix` node's rev is `R` and it is reached only
   through `rei`.
3. `nix/haskell-overlay.nix` in rei defines only rei's own packages, and mori-rei-app's defines
   only `mori-types`, `mori-app`, `mori-rei-app`; neither contains any package on plan 10's list,
   including `typeid-hs-sql` and `typeid-hs-pg-migrate`. `grep -nE
   'link-canonical|wai-app-static|servant-server|relay-pagination|hs-opentelemetry|openapi|servant-health|rei-src|typeid-hs-src'`
   over both overlays and flakes returns only comments. Both `cabal.project` files still carry the
   `typeid-hs` `source-repository-package` at `7164a74c`.
4. The parity script reports zero differences for the `rei` and `mori-rei-app` closures built by
   dotfiles, and both closures (or derivation closures) contain the same `rei-core` store path,
   which also equals `nix build github:shinzui/rei/<C>#rei-core`.
5. The clone rehearsal passes with the shipped binaries: migration `pending=0`, verification
   passed, and the replay gate exits 0 with only the declared exclusion.
6. After activation: `rei --version` reports `C`'s short hash; `lsof` shows the agents executing
   the proven store paths; `rei kiroku subscriptions status --remote-url http://localhost:9091`
   lists subscriptions as live with no halted entry; `curl http://localhost:26862/health`
   succeeds; today's logs show no decode error, halt, dead letter or startup failure; `verify`
   against the global database reports 186 (or the candidate's count) applied, 0 pending, 0
   unknown, 0 issues.
7. Delivery: at least one mori-rei-app delivery (a pushed commit with an `Intention:` trailer
   producing a Rei action) and one Rei worker terminal effect observed, or each explicitly
   recorded as untested.
8. `just adr-validate` and mori-rei-app's bundle validation pass; the MasterPlan registry shows
   EP-11 Complete.


## Idempotence and Recovery

Every Cabal and Nix step can be repeated. `cabal build --dry-run` and parity runs only read.
`nix flake lock` is idempotent once the URLs are fixed. Scratch evidence goes under `.dev/cohort/`
(rei, ignored) and `.backups/clone-prove/` (rei, ignored).

If the freeze cannot be satisfied (a solver rejection naming a bound that is not the
application's own, or an opposite flag), do not work around it locally: record it, fix it in plan
8's regeneration, push a new `R`, and restart the affected milestone with the new `R`. Moving `R`
means re-running every milestone already done in each repository, because the import and the
flake pin must move together.

If a Nix dependency fails to build, fix it in the channel (plans 9 and 10) and move `R`; never add
a local override back. If `nix flake lock` in mori-rei-app reports "follows a non-existent
input", the `rei` revision in the URL is wrong or not pushed; correct the URL.

Before Milestone 6's activation nothing in production has changed; abandoning is `git checkout
flake.lock` in dotfiles. After activation, both programs are Kiroku 0.9 on a database that already
had `0012`, and no migration ran, so rolling back is re-locking dotfiles' `rei` and `mori-rei-app`
to `880093cc` and `2acd4ed4`, rebuilding, and having the user activate again; no database restore
is involved and none may be done after new writes (restoring would discard them). If the clone
rehearsal shows `pending>0`, this plan stops and the deploy becomes a stop-writers cutover per
the MasterPlan (stop writers, back up with `just backup "$REI_RELEASE_URL"`, `up`, `VACUUM
(ANALYZE) kiroku.stream_events`, start only new builds), which needs its own go-ahead.

Never delete or recreate the global `rei`, `mori` or `mori_rei_app` databases. Scratch database
names must be unique; `validate-on-clone.sh` refuses protected names.


## Interfaces and Dependencies

Hard dependencies: plan 9
(`docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md`)
supplies `cabal/cohort.freeze` generation into Nix, the channel parity check, and the parity
script; plan 10
(`docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md`)
supplies the shared overrides in the channel (including `typeid-hs-sql` and
`typeid-hs-pg-migrate` at `7164a74c`) and the per-repository deletion lists. Plan 8
(`docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`)
supplies the freeze and the upgrade report. Indirect dependency, through the freeze: plan 15
(`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`) supplies the keiro,
keiro-ops, keiro-pgmq, keiro-test-support and kioku-core releases on `effectful >=2.7.1.0` / `effectful-core >=2.7.1.1` that
the freeze selects. Plan 12 reuses the extension shape defined here and vendors
`hasql-effectful` into mori-core; it does not affect this plan. Plan 14 adds the dotfiles guard,
which warns on differing channel revisions and fails only when a closure differs from the freeze
of its own pinned revision.

Interfaces that must exist at the end:

- rei `flake.nix` output `lib.haskellExtension :: haskellLib -> pkgs -> (final -> prev -> attrset)`,
  defining exactly `rei-core`, `rei-api`, `rei-cli` (`typeid-hs-*` come from the channel);
  intended to be composed after
  `inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose pkgs` in a
  `pkgs.haskell.packages.ghc9124.override`.
- rei `packages.<system>.rei-core`, `.rei`, `.rei-api`, `.default`.
- mori-rei-app inputs `rei` (rev-pinned to `C`), `haskell-nix` and `haskell-nix-dev` following
  `rei`.
- In each of the three `cabal.project` files: `import:
  https://raw.githubusercontent.com/shinzui/haskell-nix/<R>/cabal/cohort.freeze`.
- rei `docs/adr/<NNN>-an-application-that-depends-on-another-application-s-library-consumes-that-application-s-flake-output.md`
  (`docId` from `okf id next`), and the amended rei ADR-18 and mori-rei-app ADR-1.

Tools: cabal-install 3.16.1.0 (applies HTTPS `import:`, verified 2026-09-26), `jq`, `okf`,
`mori`, Nix with flakes; rei's `scripts/validate-on-clone.sh`, `scripts/replay-audit-gate.sh`,
`scripts/dependency-closure-audit.sh`, `rei-migrations` (from `rei-core`), and `rei kiroku
subscriptions status`; mori-rei-app's `scripts/dependency-closure-audit.sh`.


## Revision Notes

- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The `$PARITY` placeholder is replaced by plan 9's `cohort-compare` flake app and its exact interface. The freeze carries the `index-state:` line, so rei and mori-app delete their own.
- 2026-09-26 (user decisions): The freeze now moves the family to `effectful` 2.7.1.0 / `effectful-core` 2.7.1.1 or later with no `allow-newer` bridge, so rei (including the vendored `rei-core/src/Rei/Infrastructure/Hasql/` modules and `Rei/Infrastructure/Trace.hs`, found by grep), mori-app and mori-rei-app must compile against effectful 2.7: added the expected source breaks and bound lifts (`effectful ^>=2.6` in mori-app and mori-rei-app, keiro/kioku bounds if plan 15 released a new major), the grep the implementer runs, and plan 15 as an indirect dependency through the freeze. `typeid-hs` is public and plan 10 carries it in the channel, so the conditional "keep `typeid-hs-src` if the channel's revision differs" branch is resolved: both repositories delete their overlay entries and `typeid-hs-src` inputs, and keep the Cabal pin at `7164a74c`. Recorded that `hasql-effectful` (vendored into mori-core by plan 12) does not affect these repositories, and that plan 14's relaxed guard only warns on differing channel revisions. Also replaced the stale `export PARITY=` placeholder in Concrete Steps with the `cohort-compare` array and made `FREEZE` the pinned URL.

- 2026-09-26 (MasterPlan coordination): Corrected the effectful floor. `effectful` has no 2.7.1.1 release (its newest is 2.7.1.0), so the floors are `effectful` 2.7.1.0 and `effectful-core` 2.7.1.1. Only `effectful-core` 2.7.0.0 to 2.7.1.0 are excluded by kiroku and shibuya for the performance regression. Plan 15's research found this.

- 2026-10-04: MasterPlan review for reducing change time: clarified shared ownership and acceptance, added the applicable targeted-update/build-identity/cache contracts, and corrected historical assumptions. No implementation completion is claimed.
