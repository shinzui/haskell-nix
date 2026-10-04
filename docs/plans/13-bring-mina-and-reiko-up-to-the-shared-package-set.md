---
id: 13
slug: bring-mina-and-reiko-up-to-the-shared-package-set
title: "Bring mina and reiko up to the shared package set"
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
      note: "Original review found duplicate parity logic, assumed lock node and half-adoption risk; applied findings in update."
---

# Bring mina and reiko up to the shared package set

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Two of the five Rei-family applications, `mori://shinzui/mina` (a planning tool that drives the
`rei` and `mori` command-line programs and serves a local web UI) and `mori://shinzui/reiko` (a
web companion that reads Rei only through the `rei` command-line program), are the furthest from
the shared package set this repository now publishes. mina is a whole library generation behind
(baikai 0.6 and shikumi 0.3 while the rest of the family is on baikai 0.7 and shikumi 0.4), its
Cabal build uses an unreleased streamly from a git pin that its shipped Nix binary does not use,
and it has no `index-state` at all. reiko's Cabal `index-state` is 2026-06-01 and its Nix build
floats on an old toolchain pin and an unpinned channel revision.

After this plan, both applications build under Cabal from exactly the versions in this
repository's cohort freeze (`cabal/cohort.freeze`), and their Nix builds come from the same
channel revision that freeze was published at, so the versions their tests exercise are the
versions that ship. For mina that means three moves the user decided on 2026-09-26: the baikai
0.7 family, the shikumi family at the new releases plan 15
(`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`) publishes on effectful
2.7, and `streamly` from Hackage instead of a Git pin. Both applications also compile against
`effectful` 2.7.1.0 / `effectful-core` 2.7.1.1 or later, which the freeze selects for the whole family. You
can see it working in four ways. First, `just cohort-check` in each application reports no
package whose Cabal version differs from the freeze. Second, the Nix closure of each
application's executable contains the frozen versions (for example `baikai-0.7.1.0`, plan 15's
`shikumi`, `streamly-0.11.1` and `effectful-core-2.7.x` in mina, and the frozen `warp` and `tls`
in both). Third, after the user activates the dotfiles, `curl http://127.0.0.1:8765/api/health`
answers `{"status":"ok","source":"mina-web"}` and `curl http://127.0.0.1:8770/api/health`
answers `{"status":"ok","source":"reiko-web"}`. Fourth, `mina ci --json "<title>"` still creates a
Rei intention in the global Rei database.

Neither application links Kiroku (the event store library) or writes to a Kiroku store itself.
But the deployed `mina web` agent spawns the `mori` and `rei` programs with both global database
URLs, so this plan also states how its deployment must be ordered against plan 12's Kiroku
migration of the mori database (see "Deployment ordering against the mori Kiroku cutover" in Plan
of Work).


## Review requirements (2026-10-04)

Follow [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md): ordinary application edits retain the cohort and toolchain pins. Matching versions alone is insufficient evidence of reused builds. Historical input revisions, package counts and deletion lists below are starting observations; refresh them from recorded contributor revisions.

Plan 9 owns the shared `cohort-compare` app. Use `--freeze FILE_OR_URL --plan-json FILE` for a freshly generated Cabal plan and `--freeze FILE_OR_URL --nix-manifest FILE` for the executable's build evidence. Use `--compare-manifests FILE FILE` to compare build identities and `--resolve-channel-lock FILE --input-path PATH` to obtain a channel's full locked revision. The resolver starts at the lock's declared root and handles recursive array `follows`, string nodes, missing nodes and cycles. Check the Cabal import revision against the application's own resolved lock, rather than assuming a node named `haskell-nix` exists. Return 0 on success, 1 on drift or missing/unverifiable evidence, and 2 on usage error.

Export `packages.<system>.cohort-manifest` through plan 9's construction helper. Its JSON schema records the system, compiler/toolchain/channel, actual executable root drv/output and Haskell packages with names, versions, component roles, source/metadata identities, flags/policy and drv/output paths. Generate records from the actual composed scope used to build the executable, then verify dependency edges against that root's derivation graph through Nix metadata APIs. Runtime closures may omit static Haskell libraries; basename parsing and unrelated channel evaluation cannot prove parity. All instances of a Haskell package must pass, including when one correct and one incorrect version coexist. Missing expected dependencies fail. Native build tools and compiler packages are distinguished by role.

Refresh `plan.json` with tests and benchmarks enabled for supported configurations; check all non-local packages. Record own packages and non-Hackage source pins in the channel's declared policy and `cabal/cohort-sources.json` (exact source revision/subdirectory plus reasons and owners for intentional Cabal/Nix source or flag differences). Do not use arbitrary `--ignore` lists. Keep exact-binary release rehearsals: version parity alone does not establish flag/source or behavioral equivalence. Consumer checks are thin calls to shared tooling, with no fallback comparator.

Use one atomic selector adoption per application: Cabal imports, bounds, Nix pins/lock, policy changes and checks land together after both build paths pass. M2 and M3 may be prepared separately, but do not commit an intermediate Mina adoption selecting different cohorts. Preserve required shared files when filtering local package sources; documentation and CLI-only edits must not invalidate unchanged shared libraries.

The mori global database is already on `0012` and Kiroku 0.9; do not add its completed cutover as a hard prerequisite or run it again. Keep read-only deployed-state checks and preserve existing schema compatibility during binary swaps. The mina `mori-schema-pin` exception stays as agreed; moving it is a separate follow-up. Remove bespoke Python/runtime-closure comparisons. A pre-existing test failure needs baseline evidence and no regression; new failures are fixed before acceptance.

## Progress

- [ ] Shared comparator/recursive resolver and atomic adoption pass for both applications

- [ ] M0: Confirm plans 15, 8, 9 and 10 are complete and the channel revision carrying `cabal/cohort.freeze` is pushed; record `<CHANNEL_REV>` and plan 15's released `shikumi`, `shikumi-trace` and `shikumi-cache` versions in the Decision Log.
- [ ] M0: Record baselines for mina and reiko (current test results, current `plan.json`, current deployed closures) under the scratch directory.
- [ ] M1: reiko `flake.nix` pins `haskell-nix-dev` to 206ecd25 and `haskell-nix` to `<CHANNEL_REV>`; `flake.lock` relocked.
- [ ] M1: reiko `cabal.project` imports the freeze at `<CHANNEL_REV>` and no longer carries its own `index-state`.
- [ ] M1: reiko compiles (including against `effectful` 2.7 if its plan reaches effectful), its tests match the baseline, and `just cohort-check` reports no difference.
- [ ] M1: reiko `nix build .#reiko` succeeds and its closure matches the freeze; commit.
- [ ] M2: mina `cabal.project` gains `with-compiler` and the freeze import; streamly source pins and the `baikai-trace-otel:streamly-core` allow-newer removed (user decision: streamly from Hackage).
- [ ] M2: mina bounds moved to baikai 0.7, baikai-trace-otel 0.4.0.1, and plan 15's shikumi and shikumi-trace releases (shikumi-trace-otel to whatever the freeze selects).
- [ ] M2: mina source breaks fixed (`LLMConfig` literal, provider-error text heuristic, effectful 2.7 sites such as the `interpose` in `withThinking`, any compiler-named sites); `cabal build all` succeeds with `effectful` >= 2.7.1.0 / `effectful-core` >= 2.7.1.1 in `plan.json`.
- [ ] M2: mina `cabal test all` matches the baseline and `just cohort-check` reports no difference; commit.
- [ ] M3: mina `flake.nix` moves `haskell-nix` from b88d3173 to `<CHANNEL_REV>` and drops the `okf-src` input; overlay drops `generic-lens`, `generic-lens-core` and `kdl-hs`.
- [ ] M3: mina `nix build .#mina-cli` and `nix flake check` succeed, closure matches the freeze; commit.
- [ ] M4: With the user's go-ahead, push mina and reiko.
- [ ] M4: In dotfiles, `nix flake update mina reiko` only; lock diff limited to mina and reiko; `./bin/build.sh` succeeds; commit.
- [ ] M4: User activates; mina-web and reiko-web answer health, rei and mori endpoints; `mina ci --json` works against the global Rei database; mina-web's `mori` Kiroku version is consistent with the mori database ledger.
- [ ] Close-out: Outcomes & Retrospective written, ADR distillation done, MasterPlan 3 registry and progress updated.


## Surprises & Discoveries

These were found while drafting the plan (2026-09-26) and shaped it.

- Observation: mina's Cabal plan and mina's shipped binary disagree on streamly. `mina/cabal.project`
  pins `streamly` and `streamly-core` from `github.com/shinzui/streamly-project` at f8e33b56, so the
  Cabal plan (`mina/dist-newstyle/cache/plan.json`, 2026-09-17) selects `streamly 0.12.0` and
  `streamly-core 0.4.0` as `source-repo` packages. The Nix overlay does not reproduce that pin, so
  the deployed mina closure ships the channel's versions. The pin was added on 2026-05-27 (mina
  `de7363f`) when baikai needed unreleased streamly; baikai's own `cabal.project` now says "all
  dependencies resolve from Hackage … streamly / streamly-core pair (latest released 0.11 / 0.3)",
  and `baikai 0.7.1.0` bounds `streamly >=0.11 && <0.13`, `streamly-core >=0.3 && <0.5`. The user
  confirmed on 2026-09-26 that mina drops the pin and takes `streamly` from Hackage (see the
  Decision Log).
  Evidence:

  ```text
  $ nix-store -qR /nix/store/xrf8q7gbq4pkhh88pf4bbl7qqc0dpdy7-mina | grep -E -- '-streamly'
  …-streamly-0.11.0
  …-streamly-core-0.3.0
  ```

- Observation: an `index-state` line inside an imported file is honoured by cabal-install
  3.16.1.0. In a scratch copy of reiko with `index-state` removed from `cabal.project` and placed
  in an imported file, the solve returned the 2026-06-01 versions (`tls 2.4.2`, `warp 3.4.13.1`,
  `aeson 2.2.5.0`); with rei's `2026-09-26T18:09:31Z` it returned `tls 2.4.7`, `warp 3.4.16`,
  `aeson 2.2.5.1` (20 of 140 packages moved). So an application can take its `index-state` from the
  freeze import and must not keep its own.

- Observation: a prototype solve of mina against a stand-in freeze (the highest version of each
  package that rei or mori selected on 2026-09-26, imported from a scratch file) succeeded only after
  two additions. First, `allow-newer: claude:http-client-tls`, because `claude 1.5.0` (the newest on
  Hackage) caps `http-client-tls <0.4` while the cohort uses 0.4.0; rei and mori carry the same line.
  Second, mori's `dhall` source pin (dhall-haskell `03b40e85`), because the stand-in freeze carried
  mori's `microlens 0.5.0.0` and Hackage `dhall 1.42.3` caps `microlens <0.5`; mina reaches `dhall`
  through `okf-core`. Without the stand-in, mina alone selects `tls 2.2.2` and `crypton 1.0.6`, far
  behind the family. Whether the real freeze needs the dhall pin is plan 8's result, not this plan's.
  Evidence (scratch solve, abridged):

  ```text
  [__4] rejecting: claude-1.5.0 (conflict: http-client-tls==0.4.0, claude => http-client-tls>=0.3 && <0.4)
  [_11] rejecting: dhall-1.42.3 (conflict: microlens==0.5.0.0, dhall => microlens>=0.4.14.0 && <0.5)
  ```

  With both additions the solve selected `baikai 0.7.1.0`, `shikumi 0.4.0.0`, `streamly 0.11.1`,
  `streamly-core 0.3.1`, `tls 2.4.6`, `crypton 1.1.5`, `warp 3.4.16`, `kdl-hs 1.0.1`,
  `generic-lens 2.3.0.0` with no streamly source pin. That stand-in predates the user's
  effectful 2.7 decision: the real freeze also carries `effectful` 2.7.1.0 / `effectful-core` 2.7.1.1 or
  later and therefore plan 15's shikumi releases instead of `shikumi 0.4.0.0`, whose
  `effectful` bound stops below 2.7.

- Observation: shikumi 0.4 changes how provider failures look, and mina classifies them by text.
  `Shikumi.Error.ShikumiError` gained `ProviderError !BaikaiError`, and `fromBaikaiError` now maps
  process and refusal failures to it instead of `ProviderFailure`. `mina-core/src/Mina/Core/Plan.hs`
  (`explainDigestFailure`) only recognises the substring `"ProviderFailure"`, and the spec that
  guards it (`mina-core/test/Mina/Core/PlanSpec.hs`) builds that string by hand, so the heuristic
  would silently stop firing while the test still passes. shikumi 0.4 also stops retrying process
  and refusal failures (`isTransient` retries only typed rate-limit and transient errors).

- Observation: reiko's Nix build is not on the family's nixpkgs. reiko's `haskell-nix` input is
  unpinned (locked b88d3173, a revision that predates the `haskell-nix-dev` input) and follows only
  `nixpkgs`, while reiko's own `haskell-nix-dev` is unpinned and locked at af29a486, whose nixpkgs is
  4df1b885, not the family's d5dfd8e6. The deployed reiko closure
  (`/nix/store/96qmg11zhq9p19dgbl4zpskv5rzb50wl-reiko`) ships `generic-lens-2.2.2.0`,
  `warp-3.4.9`, `tls-2.3.1`, `wai-3.2.4`, `crypton-1.1.2`.

- Observation: the deployed mina-web agent runs a Kiroku-0.8 `mori`, and the mori database is
  still at Kiroku migration 0011, which is consistent today. Evidence (read-only):

  ```text
  $ grep -oE '/nix/store/[a-z0-9]{32}-mori[^/:" ]*' /nix/store/9lyps8j45lynmlli6a2bgdqf0pbha4fz-mina-web | sort -u
  /nix/store/c8by51vm3di6zgyw4g106lzr83vlcgp2-mori
  $ nix-store -qR /nix/store/c8by51vm3di6zgyw4g106lzr83vlcgp2-mori | grep -oE 'kiroku-store-[0-9.]*[0-9]' | sort -u
  kiroku-store-0.8.0.0
  $ psql 'host=/Users/shinzui/.local/state/postgresql dbname=mori' -Atc "set default_transaction_read_only=on; select migration from pgmigrate.migrations where component='kiroku' and status='applied' order by position desc limit 1"
  0011
  ```


## Decision Log

- Decision (2026-10-04 review update): adopt the Review requirements above and ADR 5's update-isolation/build-evidence contract. Historical closure-only acceptance, fixed package counts and duplicated comparison implementations are superseded where noted. Preserve the agreed advisory fleet guard and effectful migration policy. Implementation evidence remains pending.

- Decision: Retire mina's streamly source pin and take the frozen released streamly (expected
  0.11.1 / streamly-core 0.3.1), even though mina's Cabal plan selects 0.12.0 / 0.4.0 today.
  Rationale: The MasterPlan's upgrade-only rule forbids moving any package below the highest
  version an application selects. This is a declared exception, not a downgrade of anything that
  ships: 0.12.0 and 0.4.0 are unreleased git snapshots that no freeze line can express without every
  application carrying the same git stanza; mina's deployed Nix binary already ships streamly
  0.11.0, so 0.11.1 is an upgrade for the shipped artifact; mina has no direct streamly import; and
  baikai 0.7.1.0 is released and tested against the Hackage pair. Plan 8's upgrade report lists
  the Git pin under "source pins" as retired by this plan. The user confirmed this on 2026-09-26
  (see the user-decisions entry below), so it is a user decision, not an open question.
  Date: 2026-09-26

- Decision: mina keeps sourcing `mori-schema-pin` from its own `mori-src` flake input and its own
  `source-repository-package` at mori `7af02c55`, and does not consume a mori flake export from
  plan 12, in this plan.
  Rationale: `mori-schema-pin` is not a version-set concern; it depends only on `base` and `text`
  and is not on Hackage. What it carries is behaviour: the mori-schema commit and Dhall integrity
  hashes that mina writes into other repositories' `mori/agent-plans.dhall` files
  (`Mina.Mori.Catalog`) and that `mina-core/test/Mina/Mori/CatalogSpec.hs` asserts
  (`a3c59033…`). Mori's current `mori-schema-pin` (still version 0.2.0.0) pins mori-schema
  `3522f4a5` with different hashes and adds a `dddExtension` pair and a `Mori.Schema.TrustRoot`
  module. Consuming plan 12's export would move that schema pin as a side effect of a package-set
  change and rewrite catalog files in other repositories on the next `mina mori publish`. That is a
  product change for a separate mina plan. This is a documented exception to plan 10's rule that
  consumer overlays define only their own packages; plan 10's owner is asked to record it (see Open
  Questions under Interfaces and Dependencies).
  Date: 2026-09-26

- Decision: Adopt reiko first (M1), then mina (M2, M3).
  Rationale: reiko has no first-party library dependencies and no source pins, so it proves the
  freeze import, the pinned channel and the parity check with the smallest possible surface. mina
  then only adds its own library migration on top of mechanics already shown to work.
  Date: 2026-09-26

- Decision: In reiko's `flake.nix`, change only the `haskell-nix-dev` and `haskell-nix` inputs;
  leave reiko's own `flake-parts` and `pre-commit-hooks` inputs as they are.
  Rationale: Only those two inputs determine reiko's Haskell package set (the GHC 9.12.4 package set
  comes from `haskell-nix-dev`'s nixpkgs, and the overrides from `haskell-nix`). Collapsing the
  other inputs onto `haskell-nix-dev`, as mina's newer seihou template does, is a template upgrade
  (`seihou update nix-haskell-flake` from reiko's 0.13.0) with its own risks and belongs elsewhere.
  Date: 2026-09-26

- Decision: Fix mina's `LLMConfig` construction with record update on `defaultLLMConfig` instead of
  a literal that names every field.
  Rationale: shikumi 0.4 added `LLMConfig.observer`; a record update keeps shikumi's default for
  every field mina does not set and survives the next additive field.
  Date: 2026-09-26

- Decision: Teach `explainDigestFailure` to recognise both the legacy `ProviderFailure` rendering
  and the new `ProviderError` rendering, and add a spec built from a real `ShikumiError` value.
  Rationale: The existing spec builds its input by hand and would not notice the rendering change
  (see Surprises & Discoveries).
  Date: 2026-09-26

- Decision: Remove each application's own `index-state` and take it from the freeze import.
  Rationale: Proven in a scratch solve (see Surprises & Discoveries). Two `index-state` lines, one
  local and one imported, would leave the reader guessing which wins.
  Date: 2026-09-26

- Decision: Remove mina's `okf-src` flake input and the `haskell-nix.inputs.okf-src.follows` line.
  Rationale: The channel fetches every first-party family from the revision and NAR hash in
  `packages/first-party-lock.json` (`fetchLockedSource` in `lib/mkFirstPartyPackageSet.nix`); per
  `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` the `*-src` inputs exist only
  for refresh observation. The follow therefore no longer decides mina's `okf-core`, and it would
  break with "follows a non-existent input" if a later channel revision drops `okf-src`.
  Date: 2026-09-26

- Decision: Add `allow-newer: claude:http-client-tls` to mina's `cabal.project` if the freeze pins
  `http-client-tls` 0.4 and `claude` 1.5.0, with a comment citing the reason.
  Rationale: `mori://shinzui/rei/okf/adrs/concepts/ADR-16` prefers moving a pin to lifting a
  bound, but its condition for lifting holds here: `claude 1.5.0` is the newest release on Hackage
  and caps `http-client-tls <0.4`. rei and mori carry the same line.
  Date: 2026-09-26

- Decision: Deploy through dotfiles with `nix flake update mina reiko` only, never
  `just update-mina` or `just update-reiko`.
  Rationale: Those recipes run `nix flake update haskell-nix-dev <input>`, which moves the base
  toolchain pin for every application (it broke the Haskell closure once, on 2026-09-11) and would
  also rebuild the deployed `mori` and `rei`, which this plan must not touch.
  Date: 2026-09-26

- Decision: Prove `mina ci --json` against the global Rei database by creating one clearly named
  smoke intention and abandoning it immediately.
  Rationale: `mina ci` is the user's alias for `mina rei create-intention` (defined in
  `~/.config/mina/config.kdl`), so it has no read-only form. One abandoned intention is a small,
  labelled footprint, and the alias itself exercises mina's KDL configuration parsing on `kdl-hs`.
  Date: 2026-09-26

- Decision (user decisions, 2026-09-26): three of the user's five decisions change this plan.
  1. **effectful 2.7 everywhere, with no `allow-newer` bridge.** The freeze carries `effectful`
     and `effectful-core` at 2.7.1.1 or later (the floor `kiroku-store` and `shibuya` use, since
     they exclude 2.7.0.0 to 2.7.1.0 for a performance regression). Plan 15
     (`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`) releases new versions
     of shikumi, shikumi-trace and shikumi-cache (and keiro and kioku-core, which mina and reiko
     do not use) that admit it. mina's shikumi family therefore moves to plan 15's releases, not
     to shikumi 0.4.0.0 / shikumi-trace 0.3.0.0 as first drafted; read the exact versions from
     plan 15's Outcomes & Retrospective and record them in this Decision Log in M0. mina, and
     reiko if its plan reaches effectful, must compile against effectful 2.7; neither may add an
     `allow-newer` naming `effectful` or `effectful-core`.
  2. **mina takes `streamly` from Hackage.** mina's Git pin (`streamly-project` `f8e33b56`,
     `streamly` 0.12.0 / `streamly-core` 0.4.0) is dropped in favour of the Hackage line the
     freeze selects (expected 0.11.1 / 0.3.1), and `allow-newer: baikai-trace-otel:streamly-core`
     is dropped because `baikai-trace-otel` 0.4.0.1 already admits `streamly-core` 0.3.
  3. **Plan 14's dotfiles guard is relaxed.** Different channel revisions across applications
     only warn; the guard fails only when an application's closure differs from the freeze its own
     pinned channel revision publishes. So `<CHANNEL_REV>` should still equal the revision plans 11
     and 12 adopted when possible (less to reconcile), but a different revision is not a deploy
     blocker; each application's closure must match the freeze of its own pinned revision.
  The other two decisions (`typeid-hs` public; `hasql-effectful` vendored into mori-core by plan
  12) do not touch mina or reiko, neither of which depends on those packages.
  Rationale: the user settled these after the plan was drafted; they change mina's target
  versions, add effectful 2.7 source breaks, and remove an open question.
  Date: 2026-09-26


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

This plan is written in `mori://shinzui/haskell-nix` but its code changes happen in three other
repositories: mina, reiko and the dotfiles. Paths below are relative to the named repository.

- haskell-nix (this repository): `/Users/shinzui/Keikaku/bokuno/haskell-nix`,
  `mori://shinzui/haskell-nix`.
- mina: `/Users/shinzui/Keikaku/bokuno/mina`, `mori://shinzui/mina`. HEAD `6a4b3f9` when this plan
  was written. Packages `mina-core` (library, test suites, demo executables) and `mina-cli`
  (private library `mina-cli-internal`, executable `mina`, test suite), plus a TypeScript UI in
  `mina-ui/` that Nix builds and copies into the `mina-cli` output.
- reiko: `/Users/shinzui/Keikaku/bokuno/rei-project/reiko`, `mori://shinzui/reiko`. HEAD `4f98ba9`.
  Packages `reiko-core` and `reiko-cli` (executable `reiko`), plus `reiko-ui/`.
- dotfiles: `/Users/shinzui/.config/dotfiles.nix`, `mori://shinzui/dotfiles.nix`. HEAD `e652c2d`. It
  deploys every application on this Mac (aarch64-darwin) as launchd agents. Other people's
  uncommitted mori agent-skill files may be present in it; never stage or revert them.

Terms used in this plan:

- **Cohort freeze.** The file `cabal/cohort.freeze` in this repository, produced by plan 8
  (`docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`). It
  has the syntax `cabal freeze` writes: an `index-state:` line and a `constraints:` block with one
  `any.<package> ==<version>` line per package. An application uses it by adding
  `import: https://raw.githubusercontent.com/shinzui/haskell-nix/<rev>/cabal/cohort.freeze` to its
  `cabal.project`. cabal-install 3.16.1.0 fetches such a remote import. A remote import has no
  content hash, so it must name a commit, never `master`.
- **Channel.** This repository's flake library. An application's `flake.module.nix` calls
  `inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose pkgs` and composes the result
  with the application's own `nix/haskell-overlay.nix` over `pkgs.haskell.packages.ghc9124`. After
  plan 9 the channel also sets every frozen package to its frozen version; after plan 10 it carries
  the shared build overrides (`generic-lens` 2.3, `kdl-hs`, and others) that applications used to
  define locally.
- **`<CHANNEL_REV>`.** The full commit hash of this repository's `master` after plans 8, 9 and 10
  have landed and been pushed. It is the revision both the freeze import URL and the
  application's `flake.nix` `haskell-nix` input name. If plans 11 or 12 have already adopted a
  revision, prefer the same one. It is not required: plan 14's deploy guard, as the user relaxed
  it on 2026-09-26, only warns when applications pin different channel revisions, and fails only
  when an application's closure differs from the freeze its own pinned revision publishes.
- **Plan 15.** `docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md` in this
  repository releases new versions of keiro, keiro-ops, keiro-pgmq, keiro-test-support,
  kioku-core, shikumi, shikumi-trace and shikumi-cache that admit `effectful`/`effectful-core`
  2.7.1.1 or later, and refreshes the channel. Plan 8's freeze is solved after it, so the freeze
  selects those releases. Of them, mina uses shikumi and shikumi-trace directly (and may reach
  shikumi-cache through them); reiko uses none.
- **effectful.** The effect-system library mina is written in (`effectful-core` is the core;
  `effectful` adds standard effects). The user decided on 2026-09-26 that the whole family moves
  to `effectful` 2.7.1.0 / `effectful-core` 2.7.1.1 or later, with no `allow-newer` to get there.
- **Toolchain flake.** `github:shinzui/haskell-nix-dev`, which supplies GHC 9.12.4, cabal-install
  3.16.1.0 and the family's single nixpkgs pin. The family's revision is
  `206ecd25bcb4a07581210bdae3e6f43c8fd179d8`, whose nixpkgs is `d5dfd8e6`.
- **Parity check.** A comparison between the freeze and either a Cabal plan
  (`dist-newstyle/cache/plan.json`, written by any `cabal build`, including `--dry-run`) or a Nix
  closure. Plan 9 owns the one shared script under `scripts/` in this repository; this plan wraps it
  in a `just cohort-check` recipe in each application.
- **Kiroku 0012.** Kiroku 0.9 needs migration `0012` in a database before any 0.9 process appends,
  and after `0012` every append by a Kiroku 0.8 process fails. There is no rolling deploy. The Rei
  database received it on 2026-09-26; the mori database has not (plan 12 applies it).

State of mina today. `cabal.project` lists the two packages, pins `mori-schema-pin` from
`https://github.com/shinzui/mori` at `7af02c55257abfab52644b9e129496a0efb70f6a`, pins `streamly`
and `streamly-core` from `https://github.com/shinzui/streamly-project` at
`f8e33b5600f5ddadc17ce5d9a8e45a16c09899cb` (with `tests: False` for both), has
`allow-newer: baikai-trace-otel:streamly-core`, sets `blake3` flags
`-avx512 -avx2 -sse41 -sse2` with `ghc-options: -optc-DBLAKE3_USE_NEON=0`, and has neither
`index-state` nor `with-compiler`. The bounds in `mina-core/mina-core.cabal` and
`mina-cli/mina-cli.cabal` are `baikai`, `baikai-claude`, `baikai-openai` `^>=0.6.0.0`,
`baikai-trace-otel ^>=0.4.0.0`, `shikumi ^>=0.3.0.2`, `shikumi-trace ^>=0.2.0.2`,
`shikumi-trace-otel ^>=0.1.1.0`, `generic-lens ^>=2.3.0.0`, `kdl-hs ^>=1.0`,
`okf-core ^>=0.9.0.0`, `hs-opentelemetry-* >=1.0 && <1.1`, and an unbounded `effectful`. In
`flake.nix`, `haskell-nix-dev` is already pinned by revision to 206ecd25; `haskell-nix` is pinned by
revision to `b88d317396e4787e2ee01ff3c7e9849446bd0ea5` with
`inputs.haskell-nix-dev.follows`, `inputs.nixpkgs.follows` and `inputs.okf-src.follows`; other
inputs are `okf-src`, `mori-src` (7af02c55), `bun2nix` and `keiro-syntax`. `flake.module.nix`
builds the Haskell set and the two UI derivations. `nix/haskell-overlay.nix` defines
`generic-lens-core` and `generic-lens` 2.3.0.0 and `kdl-hs` 1.0.1 (each `callCabal2nix` on a
`fetchTarball` of the Hackage tarball), `mori-schema-pin` from `mori-src`, and mina's own
`mina-core` and `mina-cli`. The `Justfile` has `build` (`cabal build all`), `test`
(`cabal test all`), `check` (`nix flake check` plus the ADR check) and `nix-build`. mina's
`AGENTS.md` requires Conventional Commits on the current branch.

How mina uses baikai and shikumi. Sixty-two Haskell files import them. The runtime seams are
`mina-core/src/Mina/Agent/JudgeRuntime.hs` (builds a `JudgeEnv`, registers one provider per
configured `AgentProvider`, runs shikumi `Program`s through `runRouting`, `runLLMResilient`,
`routeLLM` and, when tracing, `Shikumi.Trace.Program.runProgramTraced`, then throws
`userError (show err)` on a `ShikumiError`), `mina-core/src/Mina/Core/AgentCompletion.hs` (builds a
`Baikai.Model` with record updates on `Baikai.emptyModel`, calls `Baikai.completeRequest` or
`Baikai.Trace.withTrace` with `Baikai.Trace.Sink.OpenTelemetry.otelSink`),
`mina-core/src/Mina/Trace/Export.hs` (reads `Shikumi.Trace` spans), and the typed judges that import
`Shikumi.Schema.Types`, `Shikumi.Program`, `Shikumi.Signature`, `Shikumi.Module`,
`Shikumi.Combinator` and `Shikumi.Adapter`.

What changed upstream between the versions mina has and the frozen ones (from the changelogs at
`/Users/shinzui/Keikaku/bokuno/baikai/CHANGELOG.md` and
`/Users/shinzui/Keikaku/bokuno/shikumi/*/CHANGELOG.md`, located with
`mori registry show shinzui/baikai --full` and `mori registry show shinzui/shikumi --full`):

- baikai 0.7.0.0 adds fields to public records (`BaikaiError.refusalCategory`, `Options.speed`,
  `Usage.availability`, `Model.pricingPolicy` and speed fields, `Cost.basis`, fields on the trace
  events `CallFinished` and `CallFailed`), adds the `OpenAIResponses` constructor to `Api` and
  `ThinkingSummaryUnavailable` to `ThinkingAdjustment`. Code that builds these records with every
  field, or that matches `Api` or `ThinkingAdjustment` exhaustively without a wildcard, breaks.
  mina builds models and options with record updates on `emptyModel` and `emptyOptions`, so most of
  this is absorbed. GPT-6 Astra, Sol and Luna now dispatch to `OpenAIResponses`, which needs an
  explicit `Baikai.Provider.OpenAI.Responses.register`; mina registers only the Chat Completions
  provider, so selecting one of those models through mina's `openai` provider would fail at call
  time. mina's default OpenAI model is `gpt-4o-mini`, so nothing changes unless a configuration
  names a GPT-6 model.
- baikai 0.7.1.0 adds curated models only. baikai-claude and baikai-openai 0.7.0.0 require
  `baikai ^>=0.7.0`. baikai-trace-otel 0.4.0.1 exports two new span attributes, requires
  `baikai ^>=0.7.0` and allows `streamly-core >=0.3 && <0.5`.
- shikumi 0.4.0.0 adds `LLMConfig.observer` (breaks mina's full-field literal in
  `llmConfigWithRateLimit`), makes `routeLLM` require `Error ShikumiError` in the effect row (mina
  already runs `runErrorNoCallStack @ShikumiError` outside it, so this should hold), adds the
  `ProviderError` constructor to `ShikumiError` (see Surprises), adds a `PredictCaptured`
  constructor to the `Program` GADT (breaks exhaustive traversals of `Program`; mina has none that
  the grep for `Predict` found), and preserves structured failures. shikumi-trace 0.3.0.0 adds
  `runProgramObserved` and record fields, shikumi-trace-otel 0.1.2.0 exports extra attributes,
  shikumi-cache 0.2.0.0 makes memoizers require `Error ShikumiError`.
- The freeze does not stop at those 0.4-family versions: plan 15 releases new shikumi,
  shikumi-trace and shikumi-cache versions whose only intended change is admitting effectful 2.7,
  and the freeze selects them. Read their changelogs (same location) for anything beyond the
  bound change before M2; if plan 15 made an API change, add it to the source-break list.
- The freeze moves `effectful` to 2.7.1.0 and `effectful-core` to 2.7.1.1 or later (a user decision; it is
  also what `baikai-effectful` 0.4.0.2 requires). The 2.7 breaks are `LocalEnv`'s second type
  parameter, `SharedSuffix`, `KnownEffects` and the ticked strict modules. mina's only direct use
  of effectful's dispatch layer found on `6a4b3f9` is the `interpose` call in `withThinking`
  (`mina-core/src/Mina/Agent/JudgeRuntime.hs`, imported from `Effectful.Dispatch.Dynamic`), which
  still type-checks as long as its first lambda argument (the `LocalEnv`) stays ignored. Find any
  other site with the grep in Milestone 2. mina's `.cabal` files list `effectful` without a bound,
  so no bound moves for it.

State of reiko today. `cabal.project` lists `reiko-core` and `reiko-cli`, has
`with-compiler: ghc-9.12.4` and `index-state: 2026-06-01T00:17:45Z` (with a comment explaining it
no longer tracks rei), test and job settings and RTS options. No source pins, constraints or
allow-newer. Dependencies are ordinary Hackage packages (`aeson`, `warp`, `wai`, `http-client-tls
>=0.4`, `optparse-applicative`, `generic-lens` unbounded, `cmark-gfm`, `yaml`, and so on). In
`flake.nix` (seihou `nix-haskell-flake` template 0.13.0) `haskell-nix-dev` is
`github:shinzui/haskell-nix-dev` unpinned (locked af29a486, nixpkgs 4df1b885), `flake-parts` and
`pre-commit-hooks` are separate GitHub inputs, and `haskell-nix` is `github:shinzui/haskell-nix`
unpinned (locked b88d3173) with only `inputs.nixpkgs.follows`. The file's own comment says the
project-specific inputs must be reapplied after any `seihou update nix-haskell-flake`.
`nix/haskell-overlay.nix` defines only `reiko-core` and `reiko-cli`. The `Justfile` has `build`,
`test`, `clean`, `format` and UI recipes. reiko has no `docs/adr/`.

State of the dotfiles today. `flake.nix` declares every application as `github:shinzui/<name>`
with `inputs.nixpkgs.follows = "haskell-nix-dev/nixpkgs"` and
`inputs.haskell-nix-dev.follows = "haskell-nix-dev"`; the root `haskell-nix-dev` is locked at
206ecd25. `flake.lock` pins mina at `6a4b3f9d` (nested haskell-nix b88d3173) and reiko at
`4f98ba91` (nested haskell-nix b88d3173). `home/mina.nix` defines the `com.shinzui.mina-web` agent:
its wrapper exports `MORI_PG_CONNECTION_STRING="host=<socket> dbname=mori"`,
`REI_PG_CONNECTION_STRING` and `KIROKU_REMOTE_URL` (from `home/rei-cli-env.nix`: `host=<socket>
dbname=rei` and `http://localhost:9091`), puts `${pkgs.mori}/bin` and `${pkgs.rei}/bin` on `PATH`,
and runs `mina web --global --host 127.0.0.1 --port 8765 --no-open`. `pkgs.mori` and `pkgs.rei`
come from the dotfiles' own `mori` and `rei` inputs, not from mina's flake. `home/reiko.nix` defines
`com.shinzui.reiko-web`, which runs `reiko web --host 127.0.0.1 --port 8770 --no-open` with the rei
CLI on `PATH`. `./bin/build.sh` builds the system; activation
(`sudo ./bin/darwin-rebuild-sungkyung.sh`) is only ever run by the user, and it re-bootstraps every
launchd agent at once.

Relevant ADRs. In this repository, `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md`
decides one Nixpkgs fixed point with one version per package name, immutable first-party snapshots
fetched from locked revisions, and no solver; the `*-src` flake inputs exist only for refresh
observation. `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort
adoption"): Cabal and Nix select versions by different mechanisms and both must be moved and
proven, which is why every milestone here checks both. `mori://shinzui/rei/okf/adrs/concepts/ADR-16`
("Prefer moving a pin to lifting a bound"): raise mina's own bounds rather than `allow-newer` them;
lift a third-party bound only when no newer release exists, with a comment. 
`mori://shinzui/mori/okf/adrs/concepts/ADR-24` ("Source first-party Haskell packages from the shared
overlay"): consumers must not shadow the channel with local pins; this is why mina's
`generic-lens` and `kdl-hs` overlay entries go and why the `mori-schema-pin` entry is recorded as an
exception. In mina, `mori://shinzui/mina/okf/adrs/concepts/ADR-17` ("A spec that can reach a model
is hermetic against the resolved provider"): a test on a path that can call a language model must pin
the provider and clear provider credentials, so any spec this plan adds around provider errors must
not reach a real provider. (mina's ADRs may not yet be indexed by the Mori registry; the handle is
the one mina's `mori.dhall` bundle `adrs` implies.) reiko has no ADRs.

Operating rules that apply throughout. Never search or read `/nix/store` or `/`; use
`nix-store -qR`, `nix path-info` and `nix derivation show` on known paths. Never run two cabal
builds in the same `dist-newstyle` at once. Never stop an agent with `pkill`; use
`launchctl bootout gui/$(id -u)/<label>`. Quote heredoc delimiters (`<<'EOF'`). Two PostgreSQL
servers exist; always name the URL explicitly. Inside the rei repository's shell
`REI_PG_CONNECTION_STRING` points at rei's development database, not the global one. Agents never
push, run a production migration, or activate without the user's explicit go-ahead.


## Plan of Work


### Milestone 0: preconditions and baselines

Nothing in this plan can start until plans 15, 8, 9 and 10 are complete, because the applications
import a freeze that plan 8 writes after plan 15's effectful 2.7 releases exist, rely on a channel
whose versions plan 9 generates from it, and delete overrides that plan 10 moves into the channel.
Confirm all four are marked Complete in
`docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md`,
that `cabal/cohort.freeze` exists on this repository's pushed `master`, and pick `<CHANNEL_REV>`.
Read plan 15's Outcomes & Retrospective and record the released `shikumi`, `shikumi-trace` and
`shikumi-cache` versions (and whether `shikumi-trace-otel` was re-released) in the Decision Log;
confirm the freeze carries exactly those and `effectful` at 2.7.1.0 or later / `effectful-core` at 2.7.1.1 or later.
Read plan 8's upgrade report and note three things for later milestones: that it lists mina's
streamly Git pin under "source pins" as retired (the user's decision), whether the freeze depends
on any `source-repository-package` (for example mori's `dhall` pin), and which `allow-newer` lines
it says consumers need (never one on `effectful` or `effectful-core`). Read plan 9's Interfaces
section for the exact command line of the parity script. Then record baselines so later regressions
are distinguishable from pre-existing failures: run each application's test suite on its current
HEAD and keep the summary lines, copy each current `plan.json`, and record each deployed store path.
At the end of this milestone the Decision Log names `<CHANNEL_REV>`'s real value, and the scratch
directory holds the baselines.


### Milestone 1: reiko on the freeze and the channel

In `reiko/flake.nix`, change the `haskell-nix-dev` URL to
`github:shinzui/haskell-nix-dev/206ecd25bcb4a07581210bdae3e6f43c8fd179d8` and the `haskell-nix`
input to `url = "github:shinzui/haskell-nix/<CHANNEL_REV>";` with both
`inputs.haskell-nix-dev.follows = "haskell-nix-dev";` and `inputs.nixpkgs.follows = "nixpkgs";`.
Replace the comment above it with one sentence saying the revision must equal the one in the freeze
import in `cabal.project`. Relock with `nix flake lock` (which relocks only inputs whose
specification changed). Afterwards `flake.lock` must show `haskell-nix` at `<CHANNEL_REV>`,
`haskell-nix-dev` at 206ecd25 and the root `nixpkgs` at d5dfd8e6.

In `reiko/cabal.project`, delete the `index-state` line and its comment, and add after
`with-compiler` a short comment and
`import: https://raw.githubusercontent.com/shinzui/haskell-nix/<CHANNEL_REV>/cabal/cohort.freeze`.
Add any `allow-newer` or `source-repository-package` stanza plan 8's report says a consumer with
reiko's dependencies needs (probably none). Solve and build: `cabal build all`. reiko has few
dependencies and all are mainstream, so compile breaks are unlikely; the largest moves are `aeson`,
`warp` 3.4.16, `tls`, `crypton`, `http2`, and, on the Nix side, `generic-lens` 2.2.2.0 to 2.3.0.0.
reiko's `.cabal` files do not name `effectful`, so the effectful 2.7 move reaches it only if a
dependency pulls it in. Fix any break at the site the compiler names. Run `cabal test all` and compare with the baseline.

Add a `cohort-check` recipe to `reiko/Justfile` (the exact body is in Concrete Steps and Interfaces)
that reads the locked `haskell-nix` revision from `flake.lock`, refreshes `plan.json` with
`cabal build all --dry-run`, and runs plan 9's parity script against the freeze at that revision.
Build with Nix, `nix build .#reiko`, and run the parity script against the built closure. Commit
once both comparisons report no difference. The result: reiko's tests exercise exactly the freeze,
and the Nix binary contains the same versions.


### Milestone 2: mina's Cabal side on baikai 0.7, plan 15's shikumi and effectful 2.7

In `mina/cabal.project`: add `with-compiler: ghc-9.12.4` and the freeze import (same URL form as
reiko) after the `packages:` block; delete the streamly comment, both streamly
`source-repository-package` stanzas, the `package streamly` and `package streamly-core` blocks, and
the `allow-newer: baikai-trace-otel:streamly-core` block with its comment (the user decided mina
takes `streamly` from Hackage; `baikai-trace-otel` 0.4.0.1 admits the Hackage `streamly-core`); keep the
`mori-schema-pin` stanza, the `blake3` block and `write-ghc-environment-files: never`. Add
`allow-newer: claude:http-client-tls` with a comment (as rei's `cabal.project` has) if the freeze
pins `http-client-tls` 0.4 and `claude` 1.5.0, and add any `source-repository-package` stanza plan
8's report says the freeze relies on (for example dhall-haskell `03b40e85` subdir `dhall`, if the
freeze carries `microlens` 0.5.0.0).

In `mina-core/mina-core.cabal` (library, `mina-core-test`, `plandigest-spike`) and
`mina-cli/mina-cli.cabal` (`mina-cli-internal`, `mina-cli-test`), change `baikai`,
`baikai-claude` and `baikai-openai` to `^>=0.7.0.0`, `baikai-trace-otel` to `^>=0.4.0.1`,
`shikumi` and `shikumi-trace` to `^>=` the versions plan 15 released (recorded in the Decision Log
in M0; for example `shikumi ^>=0.4.1.0` if plan 15 published 0.4.1.0), and `shikumi-trace-otel`
to `^>=` the version the freeze carries (0.1.2.0 unless plan 15 re-released it). If mina lists
`shikumi-cache` anywhere, set it the same way; today it does not. `effectful` stays unbounded,
as it is today. If the freeze's `kdl-hs` is outside `^>=1.0` (it is 1.0.1 unless plan 8 moved it),
move that bound to the frozen major version too. Do not add bounds to packages mina leaves
unbounded unless the solver needs them.

Then fix source breaks. Expected, from the changelogs and a grep of mina:

1. `mina-core/src/Mina/Agent/JudgeRuntime.hs`, `llmConfigWithRateLimit`: replace the `LLMConfig`
   literal with `(defaultLLMConfig env.registry) {rateLimit = env.rateLimit}` (the other three fields
   were copied from the default anyway). If `OverloadedRecordUpdate` rules require it, use the
   qualified field form the module already uses for `Options.thinking`.
2. `mina-core/src/Mina/Core/Plan.hs`, `explainDigestFailure`: accept either `"ProviderFailure"` or
   `"ProviderError"` in the first guard, keeping the other two substring guards. In
   `mina-core/test/Mina/Core/PlanSpec.hs` add a case whose input is
   `toException (userError (show (ProviderError err)))`, where `err` is a `BaikaiError` built the way
   baikai's CLI providers build a non-zero process exit (read
   `/Users/shinzui/Keikaku/bokuno/baikai/baikai-openai/src/Baikai/Provider/OpenAI/Cli.hs` for how its
   message is formed, and if the Codex stdin notice is not in `message`, match on the field that
   carries it). The case is pure, so it cannot reach a provider (ADR-17 holds).
3. effectful 2.7. Find the sites with
   `grep -rnE 'LocalEnv|SharedSuffix|KnownEffects|localSeqUnlift|localUnlift|localLend|localBorrow|interpose|reinterpret|Effectful\.Dispatch|Effectful\.Internal|Effectful\.[A-Za-z.]*\.Strict' mina-core/src mina-core/test mina-cli/src mina-cli/test`.
   On `6a4b3f9` the only dispatch-layer use is `interpose` in `withThinking`
   (`mina-core/src/Mina/Agent/JudgeRuntime.hs`); keep its `LocalEnv` argument ignored (`_`), and
   if its type changed, follow the 2.7 changelog. Fix any other site the compiler names. Never add
   an `allow-newer` for `effectful` or `effectful-core`; if a dependency still caps them below
   2.7.1.1, that is a plan 8 or plan 15 defect, and this plan waits.
4. Anything else the compiler names: exhaustive `case` over `Baikai.Api` (add the
   `OpenAIResponses` arm or a wildcard with the same behaviour as `OpenAIChatCompletions`), fake
   providers in `mina-core/test/Mina/Agent/JudgeCacheSpec.hs` and
   `mina-core/test/Mina/Trace/RuntimeSpec.hs` that build records in full, and trace-tree readers in
   `Mina.Trace.Export` if `Shikumi.Trace` span records changed shape.

Build with `cabal build all` (this includes tests and the demo executables), then run
`cabal test all` with provider credentials cleared from the environment and compare with the
baseline. Add the same `cohort-check` recipe to `mina/Justfile` and run it. Commit.


### Milestone 3: mina's Nix side on the channel

In `mina/flake.nix`, change the `haskell-nix` URL to `github:shinzui/haskell-nix/<CHANNEL_REV>`,
keep its `haskell-nix-dev` and `nixpkgs` follows, delete `inputs.okf-src.follows = "okf-src";`,
delete the `okf-src` input and its comment, and rewrite the comment above `haskell-nix` to say the
revision must equal the freeze import's revision in `cabal.project`. Keep `mori-src` at 7af02c55
with a comment pointing at this plan's Decision Log entry. Relock with `nix flake lock`.

In `mina/nix/haskell-overlay.nix`, delete the `generic-lens-core`, `generic-lens` and `kdl-hs`
entries and their comments, because plan 10 moved them into the channel. Keep `mori-schema-pin`,
`mina-core` and `mina-cli`. Build with `nix build .#mina-cli`, run `nix flake check`, and run the
parity script against the built closure. The closure must contain `generic-lens-2.3.0.0`, the
frozen `kdl-hs`, `baikai-0.7.1.0`, plan 15's `shikumi` and `shikumi-trace`, `streamly-0.11.1` (or
whatever the freeze says), `effectful-core` at the frozen 2.7 version, and no second version of
any frozen package. Commit.


### Milestone 4: deploy through the dotfiles

Ask the user for the go-ahead to push mina and reiko, because dotfiles consumes
`github:shinzui/mina` and `github:shinzui/reiko`. After both are pushed, in the dotfiles run
`nix flake update mina reiko` and nothing else, check that the lock diff touches only the `mina`
and `reiko` nodes and nodes newly reachable from them (their nested `haskell-nix`, `mori-src`,
`bun2nix`, `keiro-syntax` and so on), and that the root `haskell-nix-dev`, `mori` and `rei` nodes are
unchanged. Build with `./bin/build.sh`. If plan 14's deploy guard is already installed in the
dotfiles by then, it may warn that mina and reiko pin a different channel revision from other
applications; that is expected and not a failure under the user's relaxed rule. It fails only if
the mina or reiko closure differs from the freeze at its own pinned `<CHANNEL_REV>`, which M1 and
M3 already proved it does not; if it fails, stop and find out why. Commit the lock change alone.
Hand activation to the user.
After activation, verify the two web agents, the rei and mori paths through mina-web, `mina ci`,
and the Kiroku consistency of mina-web's `mori` (below).


### Deployment ordering against the mori Kiroku cutover

mina-web's `PATH` puts the dotfiles' `pkgs.mori` first, and mina-web spawns that `mori` with
`MORI_PG_CONNECTION_STRING` pointing at the global mori database, so anything mina-web does through
`mori` is a Kiroku 0.8 or 0.9 client of that database depending on which `mori` is deployed. Plan 12
applies Kiroku migration `0012` to the mori database and, in the same activation, moves the
dotfiles `mori` input to a Kiroku-0.9 build. This plan never moves the dotfiles `mori` input. Three
rules keep the two plans from producing a Kiroku-0.8 `mori` on mina-web's `PATH` after `0012`:

1. This plan's dotfiles change is `nix flake update mina reiko` only. It must not run
   `nix flake update` without arguments, `just update-mina`, `just update-reiko`, or any recipe that
   updates `mori`, `rei` or `haskell-nix-dev`, and its lock diff must leave the `mori` node's
   `locked.rev` unchanged.
2. Build from the dotfiles' current HEAD. If plan 12 has already deployed, HEAD's `mori` node is
   the Kiroku-0.9 revision plan 12 recorded; pull or rebase onto it before running this plan's
   update, and confirm the node still shows that revision before `./bin/build.sh`. Building from an
   older checkout, or resolving a merge conflict in `flake.lock` in favour of the older `mori` node,
   would activate a Kiroku-0.8 `mori` against a `0012` database, and every append mina-web triggers
   through `mori` would fail.
3. Never activate this plan while plan 12's cutover window is open, meaning from the moment plan 12
   stops the mori writers until plan 12's activation has completed. Activation re-bootstraps every
   launchd agent, so it would restart `com.shinzui.mori-automate` and mina-web in the middle of
   plan 12's stop-the-writers procedure. Either finish this plan's activation before plan 12 stops
   the writers, or wait until plan 12 records its deployment as done.

The post-activation proof is to resolve the `mori` on mina-web's `PATH`, read its Kiroku version
from its closure, and read the mori database's Kiroku ledger head. A `0011` head must pair with
`kiroku-store-0.8.x`, and a `0012` head must pair with `kiroku-store-0.9.x`. Any other pairing is a
stop: report it to the user and do not attempt a fix from this plan. The `rei` on mina-web's `PATH`
comes from the dotfiles' `rei` input, which is already Kiroku 0.9 against a `0012` Rei database, and
this plan does not move it either.


## Concrete Steps

Use the Review requirements for final manifest-based acceptance. Historical runtime-closure commands below describe baseline diagnostics; they cannot establish Haskell dependency parity. Consumers export an app alias `apps.<system>.cohort-compare` from their pinned channel to bootstrap lock resolution without guessing node names.

All commands are for zsh on the user's Mac. `<CHANNEL_REV>` is the 40-character revision recorded in
the Decision Log in M0. `$SCRATCH` is any scratch directory outside the repositories, for example a
session scratchpad.

M0, preconditions (working directory `/Users/shinzui/Keikaku/bokuno/haskell-nix`):

```bash
git fetch origin
git log -1 --format='%H %s' origin/master
git show origin/master:cabal/cohort.freeze | head -5
git show origin/master:cabal/cohort.freeze | grep -E 'any\.(effectful|effectful-core|shikumi|shikumi-trace|shikumi-cache|shikumi-trace-otel|streamly|streamly-core) '
grep -n '^| 8 \|^| 9 \|^| 10 \|^| 15 ' docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
```

Expect the freeze to start with an `index-state:` line and a `constraints:` line, to carry
`effectful` at 2.7.1.0 or later / `effectful-core` at 2.7.1.1 or later, plan 15's shikumi versions and Hackage
`streamly`/`streamly-core` (0.11.x / 0.3.x), and rows 8, 9, 10 and 15 to say `Complete`. If any is
not complete, stop: this plan's hard dependencies are unmet.

M0, baselines (repeat for reiko at `/Users/shinzui/Keikaku/bokuno/rei-project/reiko`):

```bash
cd /Users/shinzui/Keikaku/bokuno/mina
git status --short
nix develop -c cabal test all 2>&1 | tee "$SCRATCH/mina-baseline-tests.log" | tail -20
cp dist-newstyle/cache/plan.json "$SCRATCH/mina-baseline-plan.json"
launchctl print gui/$(id -u)/com.shinzui.mina-web | grep -oE '/nix/store/[a-z0-9]{32}-mina-web' | head -1
```

M1, reiko (working directory `/Users/shinzui/Keikaku/bokuno/rei-project/reiko`). After editing
`flake.nix` and `cabal.project` as described in Plan of Work:

```bash
nix flake lock
jq -r '.nodes | to_entries[] | select(.value.locked.rev != null) | "\(.key) \(.value.locked.rev[0:8])"' flake.lock | grep -E '^(haskell-nix|haskell-nix-dev|nixpkgs) '
grep -n 'index-state\|^import:' cabal.project
nix develop -c cabal build all
nix develop -c cabal test all 2>&1 | tail -20
nix develop -c just cohort-check
nix build .#reiko
```

Expected (revisions abbreviated):

```text
haskell-nix <CHANNEL_REV first 8>
haskell-nix-dev 206ecd25
nixpkgs d5dfd8e6
<n>:import: https://raw.githubusercontent.com/shinzui/haskell-nix/<CHANNEL_REV>/cabal/cohort.freeze
```

`just cohort-check` must end with no difference reported and exit status 0. Then run the parity
script in closure mode against `./result` (see Interfaces for the command). Commit:

```bash
git add flake.nix flake.lock cabal.project Justfile
git commit -F- <<'EOF'
build(deps): adopt the shared Rei-family package set

Take index-state and every dependency version from the haskell-nix cohort
freeze, pinned to the same channel revision as the flake's haskell-nix
input, and pin haskell-nix-dev to the family toolchain revision so the
Nix build uses the family's nixpkgs. Add `just cohort-check`.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/13-bring-mina-and-reiko-up-to-the-shared-package-set
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
```

Add any source file you had to fix to the same commit, or make a preceding `fix:` commit for it.

M2, mina Cabal side (working directory `/Users/shinzui/Keikaku/bokuno/mina`). After editing
`cabal.project` and both `.cabal` files:

```bash
grep -n 'streamly\|allow-newer\|index-state\|with-compiler\|^import:' cabal.project
nix develop -c cabal build all --dry-run 2>&1 | tail -5
jq -r '."install-plan"[] | select(."pkg-name" | test("^(baikai|shikumi|streamly|effectful)")) | "\(."pkg-name") \(."pkg-version") \(."pkg-src".type // "")"' dist-newstyle/cache/plan.json | sort -u
nix develop -c cabal build all 2>&1 | grep -E 'error' -A6 | head -80
```

Expected after the edits (versions follow the freeze; the baikai and streamly values are the
ones the prototype solve selected, and `<plan 15>` stands for the versions recorded in M0):

```text
baikai 0.7.1.0 repo-tar
baikai-claude 0.7.0.0 repo-tar
baikai-openai 0.7.0.0 repo-tar
baikai-trace-otel 0.4.0.1 repo-tar
effectful 2.7.x repo-tar          (2.7.1.1 or later)
effectful-core 2.7.x repo-tar     (same)
shikumi <plan 15> repo-tar
shikumi-trace <plan 15> repo-tar
shikumi-trace-otel 0.1.2.0 repo-tar   (or plan 15's release, if any)
streamly 0.11.1 repo-tar
streamly-core 0.3.1 repo-tar
```

No streamly line may say `source-repo`, and no effectful line may say 2.6. The first full build reports the `LLMConfig` error in
`Mina/Agent/JudgeRuntime.hs` (a missing `observer` field) and any other sites, including
effectful 2.7 ones; fix them as in Plan of Work and rebuild until `cabal build all` succeeds. Then:

```bash
nix develop -c env -u OPENAI_API_KEY -u ANTHROPIC_API_KEY cabal test all 2>&1 | tee "$SCRATCH/mina-after-tests.log" | tail -20
nix develop -c just cohort-check
```

Compare the test summaries with the baseline log; every suite that passed before must pass. Commit
the Cabal-side change with a subject such as
`build(deps): move mina to baikai 0.7, shikumi on effectful 2.7 and Hackage streamly` and the
same three trailers, and
the source fixes either in it or as a preceding `fix(agent): …` commit.

M3, mina Nix side (same directory), after editing `flake.nix` and `nix/haskell-overlay.nix`:

```bash
nix flake lock
jq -r '.nodes | to_entries[] | select(.value.locked.rev != null) | "\(.key) \(.value.locked.rev[0:8])"' flake.lock | grep -E '^(haskell-nix|haskell-nix-dev|nixpkgs|okf-src|mori-src) '
nix build .#mina-cli
nix-store -qR ./result | grep -oE -- '-(baikai|shikumi|streamly|generic-lens|kdl-hs|okf-core|mori-schema-pin)(-[a-z-]+)?-[0-9][0-9.]*[0-9]$' | sort -u
nix-store -qR "$(nix path-info --derivation .#mina-cli)" | grep -oE -- '-effectful(-core)?-[0-9][0-9.]*\.drv$' | sort -u
nix flake check
```

Expected: `okf-src` absent, `mori-src 7af02c55`, `haskell-nix` at `<CHANNEL_REV>`, the derivation
closure lists only the frozen 2.7 `effectful`/`effectful-core` (no 2.6), and the closure
lists `-baikai-0.7.1.0`, plan 15's `-shikumi-…` and `-shikumi-trace-…`, `-streamly-0.11.1`, `-streamly-core-0.3.1`,
`-generic-lens-2.3.0.0`, `-generic-lens-core-2.3.0.0`, the frozen `-kdl-hs-…`, `-okf-core-0.9.0.0`
and `-mori-schema-pin-0.2.0.0`. Run the parity script in closure mode against `./result`. Commit as
`build(nix): move mina to the shared channel revision` with the three trailers.

M4, deploy. Only after the user says to push:

```bash
cd /Users/shinzui/Keikaku/bokuno/rei-project/reiko && git push
cd /Users/shinzui/Keikaku/bokuno/mina && git push
```

Then in `/Users/shinzui/.config/dotfiles.nix`:

```bash
git status --short
git pull --rebase
jq -r '.nodes.mori.locked.rev, .nodes.rei.locked.rev, .nodes["haskell-nix-dev"].locked.rev' flake.lock > "$SCRATCH/dotfiles-before.txt"
nix flake update mina reiko
jq -r '.nodes.mori.locked.rev, .nodes.rei.locked.rev, .nodes["haskell-nix-dev"].locked.rev' flake.lock | diff "$SCRATCH/dotfiles-before.txt" - && echo "mori, rei and haskell-nix-dev unchanged"
jq -r '.nodes.mina.locked.rev, .nodes.reiko.locked.rev' flake.lock
git diff --stat flake.lock
./bin/build.sh
git add flake.lock
git commit -F- <<'EOF'
chore(mina,reiko): deploy the shared Rei-family package set

Move only the mina and reiko inputs to the revisions that import the
haskell-nix cohort freeze; mori, rei and haskell-nix-dev are unchanged.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/13-bring-mina-and-reiko-up-to-the-shared-package-set
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
```

`git status --short` may show someone else's uncommitted mori agent-skill files; leave them
unstaged. If the `diff` prints anything, stop: something other than mina and reiko moved. Before
asking the user to activate, check the Kiroku ordering rules (plan 12's state) and tell the user
which case applies. The user then runs `sudo ./bin/darwin-rebuild-sungkyung.sh`.

M4, verification after activation:

```bash
curl -s -m 5 http://127.0.0.1:8765/api/health; echo
curl -s -m 5 http://127.0.0.1:8770/api/health; echo
curl -s -m 20 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8765/api/projects
curl -s -m 20 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8765/api/rei/views
curl -s -m 20 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8770/api/collections
W=$(launchctl print gui/$(id -u)/com.shinzui.mina-web | grep -oE '/nix/store/[a-z0-9]{32}-mina-web' | head -1)
grep -oE '/nix/store/[a-z0-9]{32}-mina[^/ ]*/bin/mina' "$W"
M=$(grep -oE '/nix/store/[a-z0-9]{32}-mori[^/:" ]*' "$W" | head -1); echo "$M"
nix-store -qR "$M" | grep -oE 'kiroku-store-[0-9.]*[0-9]' | sort -u
psql 'host=/Users/shinzui/.local/state/postgresql dbname=mori' -Atc "set default_transaction_read_only=on; select migration from pgmigrate.migrations where component='kiroku' and status='applied' order by position desc limit 1"
```

Expected:

```text
{"status":"ok","source":"mina-web"}
{"status":"ok","source":"reiko-web"}
200
200
200
/nix/store/<new hash>-mina/bin/mina
/nix/store/<hash>-mori
kiroku-store-0.8.0.0      (paired with 0011)  or  kiroku-store-0.9.x (paired with 0012)
0011                      or  0012…
```

Then the `mina ci` proof, from a normal login shell (not the rei repository's shell), in the mina
checkout so that `rei.create.default-parent` from `mina.kdl` applies:

```bash
cd /Users/shinzui/Keikaku/bokuno/mina
export REI_PG_CONNECTION_STRING='host=/Users/shinzui/.local/state/postgresql dbname=rei'
export KIROKU_REMOTE_URL='http://localhost:9091'
command -v mina rei
mina ci --json "EP-13 deploy smoke test (abandon)"
```

The output is one JSON document naming the new intention's id (`intention_…`). Abandon it at once:

```bash
rei intention abandon <that id> --reason "haskell-nix plan 13 deploy smoke test"
```

`command -v mina` must print the Nix profile path whose target is the newly deployed mina. If
`mina ci` fails with a connection error, check `REI_PG_CONNECTION_STRING` first: in the rei
repository's shell it points at the development database.


## Validation and Acceptance

The review requirements above are additional completion gates, including the assigned update-isolation, manifest and cache evidence. Historical runtime-closure/version tables are diagnostic evidence only; they cannot replace those gates.

The plan is accepted when all of the following hold, each observed rather than inferred.

For each application, `just cohort-check` exits 0 and prints no differing package: every package
in the application's `plan.json` that is named in the freeze has exactly the frozen version, and
the application's own `cabal.project` carries no `index-state`. For mina, `plan.json` contains no
`streamly` or `streamly-core` unit whose source is `source-repo`, selects `effectful` and
`effectful-core` at the frozen 2.7.1.1-or-later version and `shikumi`/`shikumi-trace` at plan 15's
versions, and mina's `cabal.project` has no `allow-newer` naming `effectful`, `effectful-core` or
`streamly-core`.

For each application, the Nix build succeeds from a clean checkout at the committed revision
(`nix build .#reiko`, `nix build .#mina-cli`), and the parity script in closure mode reports no
frozen package at a version other than the frozen one. mina's `nix flake check` passes.
`nix/haskell-overlay.nix` in mina defines only `mori-schema-pin`, `mina-core` and `mina-cli`, and in
reiko only `reiko-core` and `reiko-cli`.

mina's test suites (`mina-core-test`, `mina-core-golden`, `mina-cli-test`) and reiko's
(`reiko-cli-test` and any `reiko-core` suite) pass wherever they passed in the M0 baseline, and the
new `PlanSpec` case for a `ProviderError` rendering passes. To show the new case matters, revert only
the `explainDigestFailure` guard change and see that case fail, then restore it.

After activation, `GET /api/health` on port 8765 returns `{"status":"ok","source":"mina-web"}` and
on port 8770 returns `{"status":"ok","source":"reiko-web"}`; `GET /api/projects` (which runs the
`mori` program) and `GET /api/rei/views` (which runs the `rei` program) on port 8765, and
`GET /api/collections` on port 8770 (which runs `rei`), return 200. `mina ci --json "<title>"` with
the global Rei URL prints the created intention as JSON, and the intention is then abandoned. The
`mori` on mina-web's `PATH` has the Kiroku version that matches the mori database's Kiroku ledger
head (0.8 with `0011`, 0.9 with `0012`). The dotfiles lock diff for this plan's commit changes no
`mori`, `rei` or `haskell-nix-dev` revision.


## Idempotence and Recovery

Every edit is a text change in a git working tree, so each milestone can be redone from a clean
checkout, and `nix flake lock` and `cabal build` are safe to repeat. If a milestone fails halfway,
`git diff` shows exactly what was changed; `git restore <file>` puts a file back. Never run two
`cabal` commands against the same `dist-newstyle` at once, and if a background build's completion
notice arrives, check that the process has actually exited before starting another.

If the freeze solve fails in an application, read the conflict: a cap in the application's own
`.cabal` file is raised in that file (ADR-16); a cap in a third-party package with no newer release
gets an `allow-newer` line with a comment; a conflict that needs the freeze itself to change goes
back to plan 8, and this plan waits. Never edit `cabal/cohort.freeze` from this plan.

If a remote import cannot be fetched (network down, or the revision not yet pushed), cabal fails
before solving; push or wait, then retry. Do not switch the import to `master`.

The dotfiles step is recoverable before activation by `git restore flake.lock` or
`git revert` of the lock commit. After activation, the previous generation remains available:
the user can roll back with the darwin rollback they normally use, which restores the previous mina
and reiko store paths. Neither application writes any database schema, so a rollback needs no data
step. If activation happened in the wrong Kiroku window (a Kiroku-0.8 `mori` with a `0012` mori
database), stop mina-web with `launchctl bootout gui/$(id -u)/com.shinzui.mina-web` and tell the user;
the fix is plan 12's deploy, not a change here.

The `mina ci` smoke intention is created once per run; if a run is repeated, abandon each created
intention. It is safe to rerun every other verification command; the database query sets the
transaction read-only.


## Interfaces and Dependencies

Libraries and versions this plan moves mina onto (the freeze is authoritative): `baikai 0.7.1.0`,
`baikai-claude 0.7.0.0`, `baikai-openai 0.7.0.0`, `baikai-trace-otel 0.4.0.1`; `shikumi`,
`shikumi-trace` and `shikumi-cache` at the versions plan 15 releases on effectful 2.7 (the
successors of shikumi 0.4.0.0, shikumi-trace 0.3.0.0 and shikumi-cache 0.2.0.0, which the channel's
`default` set selected before plan 15); `shikumi-trace-otel` 0.1.2.0 unless plan 15 re-releases
it; `effectful` 2.7.1.0 / `effectful-core` 2.7.1.1 or later; `streamly 0.11.1`, `streamly-core 0.3.1` from
Hackage; `generic-lens 2.3.0.0`; `kdl-hs 1.0.1` (Hackage also has 1.1 and 1.2; the freeze decides);
`okf-core 0.9.0.0`. The baikai values match the channel's `default` package set, whose
`shikumi-baikai` group generation 4 selects baikai family generation 3 (baikai 0.7.1.0,
baikai-effectful 0.4.0.2, baikai-trace-otel 0.4.0.1); plan 15 adds a newer shikumi family
generation to that group, and `okf` group generation 1 selects okf-core 0.9.0.0.

At the end of M2 these signatures and behaviours exist in mina:

```haskell
-- mina-core/src/Mina/Agent/JudgeRuntime.hs
llmConfigWithRateLimit :: JudgeEnv -> LLMConfig
-- built as a record update of (defaultLLMConfig env.registry), setting only rateLimit

-- mina-core/src/Mina/Core/Plan.hs
explainDigestFailure :: Text -> Text
-- the Codex stdin explanation fires for a message containing either "ProviderFailure" or
-- "ProviderError", together with "process exited 1" and "Reading additional input from stdin"
```

The `cohort-check` recipe in both consumers uses the following contract. Export an app
alias `apps.<system>.cohort-compare` from the pinned `haskell-nix` input, then call that
alias to resolve the channel lock. Verify the sole Cabal freeze import uses that revision;
reject another import, local index-state or overriding freeze constraint. Run fresh Cabal
resolution for the supported configurations, build the executable and its exported manifest,
and compare both against the pinned freeze. Own package/source declarations are checked by
the shared tool, without local Python/jq version comparison.

```bash
R=$(nix run .#cohort-compare -- --resolve-channel-lock flake.lock --input-path haskell-nix)
# The recipe first verifies cabal.project imports exactly the freeze at R.
FREEZE_URL="https://raw.githubusercontent.com/shinzui/haskell-nix/$R/cabal/cohort.freeze"
cabal build all --dry-run --enable-tests --enable-benchmarks
nix run .#cohort-compare -- --freeze "$FREEZE_URL" --plan-json dist-newstyle/cache/plan.json
nix build .#cohort-manifest --out-link result-cohort-manifest
nix run .#cohort-compare -- --freeze "$FREEZE_URL" --nix-manifest ./result-cohort-manifest
```

The construction helper verifies the manifest is tied to the actual executable. Treat
runtime closure queries elsewhere in Concrete Steps as diagnostics only. The recipe must
propagate failures rather than mask them with shell pipelines.

Upstream plans this plan depends on and what it needs from each:

- Plan 15 (`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`) provides the
  shikumi, shikumi-trace and shikumi-cache releases on `effectful >=2.7.1.0` / `effectful-core >=2.7.1.1`, on Hackage and in the
  channel. This plan consumes them only through the freeze, but reads their version numbers from
  plan 15's Outcomes to set mina's bounds.
- Plan 8 provides `cabal/cohort.freeze` at `<CHANNEL_REV>` including mina's and reiko's dependency
  closures (mina-only packages include `baikai-trace-otel`, `shikumi-trace-otel`, `kdl-hs`,
  `sqlite-simple`, `blaze-textual`), with `effectful` at 2.7.1.0 or later / `effectful-core` at 2.7.1.1 or later, its
  upgrade report listing mina's streamly Git pin as retired, and a statement of any
  `source-repository-package` or `allow-newer` a consumer must carry.
- Plan 9 provides the channel whose frozen packages have the frozen versions, and the parity script.
- Plan 10 provides `generic-lens` and `generic-lens-core` 2.3.0.0 and `kdl-hs` in the channel, so
  mina's overlay entries can go.
- Plan 12 verifies the already completed Kiroku `0012` state and adopts the new Mori
  binary. This plan needs the verified schema-compatible deployed state, not a repeated cutover.
- Plan 14 later adds a root `haskell-nix` input to the dotfiles that mina and reiko will follow and
  replaces `_update-with-base`; nothing here pre-empts it. Its deploy guard only warns when
  applications pin different channel revisions and fails when an application's closure differs
  from the freeze of its own pinned revision.

Open questions to settle with the owners of other plans before or during M0 (the earlier question
about mina's streamly Git pin is closed: the user decided on 2026-09-26 that mina takes streamly
from Hackage):

- Plan 8: does the freeze depend on mori's dhall-haskell git pin (it will if it carries `microlens`
  0.5.0.0)? If so, the freeze's companion instructions must say so, and mina and every other `dhall`
  consumer carries the stanza.
- Resolved: plan 10 records mina's `mori-schema-pin` exception. Preserve it in this plan;
  a future schema-pin change receives separate adoption evidence.
- Plan 12: will mori's flake export `mori-schema-pin`, and at which revision will mori's
  `mori-schema-pin` sit when it deploys? A follow-up mina plan that moves the schema pin should use
  that revision.


## Revision Notes

- 2026-09-26: Initial content drafted from the skeleton, with research into mina, reiko, baikai,
  shikumi and the dotfiles, a scratch-copy prototype solve for each application, and read-only
  inspection of the deployed agents and the mori database ledger.
- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The `<parity-app>` placeholder is replaced by plan 9's `cohort-compare` flake app and its exact interface. Removing each application's own `index-state` in favour of the freeze's is confirmed as the MasterPlan's contract.
- 2026-09-26 (user decisions): Applied the user's decisions. (1) effectful 2.7 everywhere with no `allow-newer` bridge: mina's shikumi family now moves to plan 15's new shikumi, shikumi-trace and shikumi-cache releases (versions read from plan 15's Outcomes in M0) instead of shikumi 0.4.0.0 / shikumi-trace 0.3.0.0, mina must compile against `effectful` 2.7.1.0 / `effectful-core` 2.7.1.1 or later (added the grep, the `interpose` site and the no-`allow-newer` rule), plan 15 became a precondition in M0, and the expected transcripts, closure checks, validation and interfaces were updated. (2) Dropping mina's Git streamly pin for the Hackage line, and the `baikai-trace-otel:streamly-core` entry, is recorded as a user decision; the open question to plan 8 about it was removed. (3) Plan 14's guard only warns on differing channel revisions, so `<CHANNEL_REV>` no longer has to equal plans 11 and 12's revision, and M4 says what a warning means. `typeid-hs` becoming public and `hasql-effectful` moving into mori-core do not affect mina or reiko.

- 2026-09-26 (MasterPlan coordination): Corrected the effectful floor. `effectful` has no 2.7.1.1 release (its newest is 2.7.1.0), so the floors are `effectful` 2.7.1.0 and `effectful-core` 2.7.1.1. Only `effectful-core` 2.7.0.0 to 2.7.1.0 are excluded by kiroku and shibuya for the performance regression. Plan 15's research found this.
- 2026-09-26 (MasterPlan coordination): Mori's database received Kiroku `0012` on 2026-09-26, and mina-web was restarted at 16:00 with a PATH whose `mori` is `mori-cli` `35dr5zq5…` on kiroku-store 0.9.0.1 (checked with `nix-store -qR` on its PATH entry). The ordering hazard this plan guarded against, a Kiroku 0.8 `mori` on mina-web's PATH after `0012`, is gone. The post-activation ledger-vs-`kiroku-store` check stays as a cheap confirmation.

- 2026-10-04: MasterPlan review for reducing change time: clarified shared ownership and acceptance, added the applicable targeted-update/build-identity/cache contracts, and corrected historical assumptions. No implementation completion is claimed.
