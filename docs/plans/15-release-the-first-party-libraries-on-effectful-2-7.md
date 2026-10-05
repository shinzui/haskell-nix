---
id: 15
slug: release-the-first-party-libraries-on-effectful-2-7
title: "Release the first-party libraries on effectful 2.7"
kind: exec-plan
created_at: 2026-09-26T22:52:35Z
intention: "intention_01m3fw8cpte9xtje3e5j7f2ng2"
master_plan: "docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md"
provenance:
  created_by:
    model: "claude-opus-5-5"
    harness: "claude-code"
    at: 2026-09-26T22:52:35Z
  reviews:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-04T13:51:42Z
      verdict: "changes-requested"
      note: "Original review found redundant release/full-consumer-build risk; added current-release preflight and focused acceptance in update."
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-04T13:51:42Z
      mode: "update"
      note: "Apply dependency-alignment review: routine update isolation, shared build evidence and applicable cache/ownership corrections; implementation pending."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-05T14:23:13Z
      mode: "implement"
      note: "Begin EP-15 with current Hackage and upstream tag preflight."
---

# Release the first-party libraries on effectful 2.7

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

`effectful` is the Haskell effect-system library that every Rei-family application and most of their first-party libraries are written against. It ships as two packages: `effectful-core`, which holds the effect machinery, and `effectful`, which re-exports it and adds effects such as concurrency and the file system. Version 2.7 of both is on Hackage. Some first-party libraries already require it. `baikai-effectful` 0.4.0.2, which this repository's Nix channel already ships, will not build with anything older. Three other first-party libraries still refuse 2.7 in their `.cabal` bounds: `keiro`, `kioku` and `shikumi`. As long as they do, Cabal cannot put the Rei family on one effectful version without an `allow-newer` override, and the user decided on 2026-09-26 to "migrate to effectful 2.7 everywhere", with no `allow-newer` bridge.

After this plan, new releases of `keiro`, `kioku` and `shikumi` that admit effectful 2.7 are on Hackage, and this repository's default package set carries them. The observable proof is a scratch Cabal project that depends on every first-party library the five applications use. It must declare no `allow-newer` entry for `effectful` or `effectful-core`. Its `cabal build --dry-run` must resolve `effectful` 2.7.1.0 or newer and `effectful-core` 2.7.1.1 or newer. The same solve pinned to the old `keiro` 0.19.0.0 fails, which shows the new releases are what made 2.7 reachable. As a by-product, the plan compiles each application against effectful 2.7 in a scratch copy and records which modules break, for the consumer plans 11 to 13 to fix.

This plan is new EP-15 of MasterPlan 3 (`docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md`). It has no hard dependencies. Plan 8 (`docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`) hard-depends on it: plan 8 resolves the family's single Cabal freeze, and its upgrade-only rule forces `baikai-effectful` 0.4.0.2, and so effectful-core 2.7. Without this plan it could reach 2.7 only through an `allow-newer` override, which the user has ruled out.

A correction to the MasterPlan's wording: the floors are **`effectful` ≥ 2.7.1.0 and `effectful-core` ≥ 2.7.1.1**, not 2.7.1.1 for both. Hackage has no `effectful` 2.7.1.1. Its newest release is 2.7.1.0, which requires `effectful-core >= 2.7.1.0 && < 2.7.2.0`, and the newest `effectful-core` is 2.7.1.2.


## Review requirements (2026-10-04)

Follow [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md): ordinary application edits retain the cohort and toolchain pins. Matching versions alone is insufficient evidence of reused builds. Historical input revisions, package counts and deletion lists below are starting observations; refresh them from recorded contributor revisions.

Before preparing releases, use Mori to locate current source and verify authoritative Hackage metadata and upstream release tags. If a current release already admits the policy floors and compiles in the required configurations, adopt it and record evidence instead of publishing a redundant patch. Treat the exact patch versions below as historical candidates, not requirements to republish occupied versions. Preserve the user's effectful 2.7/no-allow-newer decision and release workflow gates.

Build/test the changed libraries in the required supported configurations. Scratch application compiles identify likely ports but are optional diagnostics; final full application builds and tests belong to plans 11–13 after the resolved freeze exists. Do not duplicate all application acceptance before and after cohort resolution. The acceptance solve still demonstrates that the former bound was the blocker; select the verified admitting releases in the first-party snapshot and record them for plan 8.

## Progress

- [ ] Already-admitting releases are reused after registry/tag verification; redundant publication is skipped

- [x] (2026-09-26) Research: verified Hackage bounds, the dependency graph among shikumi, keiro and kioku, each repository's release skill, and the applications' own effectful bounds. Recorded in Context and Orientation and Surprises & Discoveries.
- [x] (2026-10-05) Milestone 0 preflight: queried current Hackage metadata and remote tags; clean source revisions are Shikumi `7cd5f9e121166874fdb9a6a99f0a8a3051761149`, Keiro `4b01af10aa55ed09d33a1304331b5adf3931c7ac`, Kioku `f0f116b7168b651afa6209eed2293cdb4ed36026`.
- [ ] Release approval: present concrete verified package changes before commit/tag/upload; historical confirmation questions are deferred until applicable.
- [x] (2026-10-05) Milestone 1 preparation: drafted nine Shikumi patch versions, internal bounds and changelogs; validated 38 capability records and 112 filesystem evidence references; formatting and the isolated Hackage effectful 2.6 build passed.
- [x] (2026-10-05) Milestone 1 release gates: effectful 2.6.1.0 and 2.7.1.0 full builds; 13/13 test suites passed on each; effectful-core 2.7.1.2; nine source archives and warning-free `cabal check`; `nix flake check` passed on aarch64-darwin.
- [x] (2026-10-05) Milestone 1 approval/commit/tags: user approved the nine concrete Shikumi releases; commit `c22efb9` and nine annotated tags are pushed.
- [x] (2026-10-05) Milestone 1 publication complete: all nine sources and Haddock docs are live on Hackage; nine non-draft GitHub releases match the annotated tags. All package/docs pages returned 200 with HTML. Evidence: `/tmp/mp3-ep15-shikumi-release-evidence.json`; publish script exited 0.
- [x] (2026-10-05) Milestone 2 preparation: widened all effectful bounds in the four Keiro packages, preserving 2.6 and excluding effectful-core 2.7.0.0–2.7.1.0; added five changelog entries and passed formatting.
- [x] (2026-10-05) Milestone 2 compatibility proof: full builds with tests enabled passed on effectful-core 2.6.1.0 and 2.7.1.2; bound/changelog commit `d790efb5` is local.
- [x] (2026-10-05) Milestone 2 approved release preparation: all seven versions/internal bounds are 0.19.0.1; corpus regeneration changed only version provenance. Release commit `9b215c11` in `mori://shinzui/keiro` contains 722 files and is verified and pushed after clean-tree verification. No upgrade blueprint edge is needed.
- [x] (2026-10-05) Milestone 2 release gates: clean-tree `just verify` passed on effectful 2.7; 62 passing suite runs. The full effectful 2.6 test run passed; 63 passing suites. Seven manifests are warning-free; seven source archives and host Nix checks passed. Release commit `9b215c11` and all seven annotated tags are pushed.
- [x] (2026-10-05) Milestone 2 publication complete: all seven sources/docs return HTTP 200 with HTML. GitHub release `keiro-0.19.0.1` is non-draft and matches the pushed annotated tag. Evidence: `/tmp/mp3-ep15-keiro-release-evidence.json`; publisher `/tmp/mp3-ep15-keiro-publish.log` exited 0.
- [x] (2026-10-05) Milestone 3 preparation: widened Kioku-core library/test and Kioku-cli library/executable bounds; added root/core/CLI changelog entries. Versions remain 0.8.0.0 pending compatibility builds and release approval.
- [ ] Milestone 3 (kioku): after Milestones 1 and 2 are live on Hackage, widen the effectful bounds in `kioku-core` and `kioku-cli`, prove builds against both effectful 2.6 and 2.7, commit, then release all five packages through the kioku release skill (with the user's approval).
- [ ] Milestone 4 (this repository): refresh the keiro, kioku and shikumi-baikai groups into the default package set, validate, and commit locally.
- [ ] Milestone 5: run the acceptance solve and its negative control. Compile rei, mori, mori-rei-app and mori-app against effectful 2.7 in scratch copies, record the breaks for plans 11–13, and update the MasterPlan's registry, Progress and Surprises.
- [ ] Completion: fill Outcomes & Retrospective and perform the ADR distillation pass.


## Surprises & Discoveries

- Observation (2026-10-05 Keiro gate): the DSL suite invokes an unconstrained `cabal exec`, overwriting the root plan with effectful 2.7 after the constrained 2.6 suite build. Preserve the fresh constrained solve separately: `/tmp/mp3-ep15-keiro-release-plan-2.6-constrained.json` selects effectful/core 2.6.1.0. The compiled main framework test interface confirms `ffctfl-cr-2.6.1.0`; the full constrained test command exited 0. Both lines passed; do not use the overwritten post-test plan as dependency evidence. Full gate log: `/tmp/mp3-ep15-keiro-release-gates.log`; interface evidence: `/tmp/mp3-ep15-keiro-test-interface-2.6.log`.

- Observation (2026-10-05 release preflight): ignored Shikumi `cabal.project.local` includes local Baikai packages; its Baikai-effectful 0.4.0.2 makes the effectful 2.6 control unsatisfiable. Preserve that developer file and verify from a tracked-file scratch copy without it, so both configurations solve published Baikai releases as the release skill requires. Initial failure log: `/tmp/mp3-ep15-shikumi-build-2.6.log`; scratch path is recorded in `/tmp/mp3-ep15-shikumi-scratch-path`. Formatting passed; the catalog validates 38 records and all 112 filesystem evidence references exist. Nine version/changelog/internal-bound edits are prepared in the Shikumi checkout, uncommitted pending the release gate and approval.

- Observation (2026-10-05): Hackage already publishes Shikumi and Shikumi-tools 0.4.1.0 admitting effectful `<2.8`, with matching upstream tags at `5104a7d7d1a01bacc0519661c204ed9e9313e747`. Shikumi-cache 0.2.0.0 and Shikumi-trace 0.3.0.0 still cap `<2.7`; Keiro 0.19.0.0 and Kioku 0.8.0.0 remain unchanged on Hackage. The entire Shikumi milestone cannot be skipped.

- Observation: there is no `effectful` 2.7.1.1. The effectful-core performance fix shipped as `effectful-core` 2.7.1.1 alone, so a floor of 2.7.1.1 on the `effectful` package is unsatisfiable.
  Evidence (Hackage, 2026-09-26):

  ```text
  effectful:      ... 2.6.1.0, 2.7.0.0, 2.7.1.0          (2.7.1.0 uploaded 2026-08-24)
  effectful-core: ... 2.6.1.0, 2.7.0.0, 2.7.1.0, 2.7.1.1, 2.7.1.2   (2.7.1.2 uploaded 2026-09-10)
  effectful-2.7.1.0 build-depends: effectful-core >= 2.7.1.0 && < 2.7.2.0
  ```

- Observation: kiroku and shibuya exclude `effectful-core` 2.7.0.0 to 2.7.1.0 because of a performance regression, not a correctness bug. The upstream changelog entry for 2.7.1.1 reads "Fix a performance regression introduced in 2.7.0.0 that increased the per-operation overhead of dynamically dispatched effects." Upstream's local checkout (`mori://effectful/effectful`, at `/Users/shinzui/Keikaku/hub/haskell/effectful-project/effectful`, commit `9e54de5`) already has an unreleased `effectful-core` 2.7.1.3 entry ("Kill the thread that runs a `runPureEff` computation when its result becomes unreachable"). Expect it on Hackage soon. The bounds this plan writes admit it.

- Observation: none of the three capping libraries uses an API that effectful 2.7 broke or deprecated. The 2.7.0.0 breaking changes are:
  - `LocalEnv` lost its `handlerEs` type parameter;
  - the `KnownEffects` class was removed;
  - `SharedSuffix` was deprecated;
  - the ticked names in `Effectful.Concurrent.Chan.Strict`, `Effectful.Concurrent.MVar.Strict` and `Effectful.Prim.IORef.Strict` were dropped;
  - `withLiftMap`, `stateM`, `modifyM` and `runStateMVar` were deprecated;
  - `runInBoundThread` changed semantics.

  A search of every `.hs` file in `mori://shinzui/keiro`, `mori://shinzui/kioku` and `mori://shinzui/shikumi` for those names found none. The only related use is `runPureEff`, which is unchanged in API. The same search over rei, reiko, mori, mori-rei-app, mori-app and mina also found none.
  Evidence:

  ```text
  grep -rnE "LocalEnv|SharedSuffix|KnownEffects|Effectful\.(Concurrent\.(Chan|MVar)\.Strict|Prim\.IORef\.Strict|Internal\.MTL|Provider)|withLiftMap|\b(stateM|modifyM|runStateMVar|unconsEnv|unreplaceEnv)\b" --include='*.hs' keiro kioku shikumi
  (only runPureEff hits in keiro-dsl tests and shikumi-compile/shikumi-eval)
  ```

- Observation: shikumi's `master` already admits effectful 2.7 and is pushed, but the change is not released. Commit `c26db8c` ("chore(deps): support effectful 2.6 and 2.7") set `effectful >=2.6 && <2.8` in nine shikumi packages. Its message records builds and all 13 test suites passing under both `--constraint=effectful==2.6.*` and `==2.7.*`. Hackage's `shikumi` 0.4.0.0, `shikumi-trace` 0.3.0.0, `shikumi-cache` 0.2.0.0 and `shikumi-tools` 0.4.0.0 still say `effectful >=2.5 && <2.7`. shikumi's `master` is also one local commit ahead of `origin` (`99106ac`, a docs-only plan). The release push will publish it too.

- Observation: keiro's `HEAD` (`648c18d4`) is exactly the `keiro-0.19.0.0` tag, and kioku's `HEAD` (`f0f116b`) is exactly `v0.8.0.0`. Both trees are clean, so the only change in their next releases is this plan's.

- Observation: the keiro checkout contains `keiro/dist-retention/kiroku-fix/src/shibuya-kiroku-adapter-0.5.1.2/`, an old retained copy with `effectful <2.7`. It is not in `cabal.project` and is not published. Ignore it.

- Observation: the only packages in the applications' Cabal plans that depend on `effectful` or `effectful-core` are first-party packages, plus mori's Git-pinned `hasql-effectful` (from `tan-effectful` at `5e081ad8`). mori already lifts `hasql-effectful`'s effectful bound with `allow-newer`. No third-party Hackage library in any application's plan caps effectful. `strict-mutable-base` moves from 1.1.0.0 to 2.x with effectful 2.7, but only `effectful` and `effectful-core` depend on it.

- Observation: mina cannot reach effectful 2.7 until plan 13 moves it off `shikumi ^>=0.3`. `shikumi` 0.3.0.3 caps `effectful >=2.5 && <2.7`, and mina's `baikai ^>=0.6` pulls `baikai-effectful` 0.4.0.0, which requires `effectful-core ^>=2.6`. reiko depends on no effectful package at all.


## Decision Log

- Decision (2026-10-05 implementation): reuse published Shikumi/Shikumi-tools 0.4.1.0, and prepare the nine remaining changed published packages as patch releases. Their changes are bounds, formatting and Haddock fixes; API behavior is unchanged. Do not publish documentation-only patches of the two already-compatible releases for this initiative. Run the release directly; no cross-session message or delegation is needed. Preserve effectful 2.6 compatibility and verify both lines before release approval.

- Decision (2026-10-04 review update): adopt the Review requirements above and ADR 5's update-isolation/build-evidence contract. Historical closure-only acceptance, fixed package counts and duplicated comparison implementations are superseded where noted. Preserve the agreed advisory fleet guard and effectful migration policy. Implementation evidence remains pending.

- Decision: Release new versions instead of editing bounds through Hackage metadata revisions.
  Rationale: This repository builds first-party packages from their GitHub sources at a recorded revision (`packages/first-party-lock.json`). A Hackage revision would leave the Git tag and the Hackage metadata disagreeing, and every repository's release skill requires a full verification gate that a revision would skip. A release also gives plan 8's freeze a clean version to name.
  Date: 2026-09-26

- Decision (awaiting the user's confirmation): Keep effectful 2.6 admitted, and widen instead of replacing. Every bound becomes `effectful >=<existing floor> && <2.8` and `effectful-core >=<existing floor> && <2.7 || >=2.7.1.1 && <2.8`.
  - The effectful-core range copies the shape `kiroku-store` 0.9.0.1 and `shibuya-core` 0.10.0.0 already publish.
  - The `effectful` range copies `kiroku-store`'s `effectful >=2.6.1 && <2.8`. It has no exclusion because `effectful` has no 2.7.1.1; the effectful-core bound and the cohort freeze keep the regressed effectful-core versions out.
  Rationale:
  - The cohort freeze (plan 8) still selects 2.7 everywhere, because `baikai-effectful` 0.4.0.2 forces it. So the user's "2.7 everywhere" holds in every application.
  - A widening-only change removes no build plan any existing consumer could solve. That includes kotei, shikigami and kawa, which are outside the Rei family.
  - It keeps the libraries valid under this repository's Nix channel, which still ships effectful 2.6.1.0 from nixpkgs until plan 9 regenerates versions from the freeze.
  - It also qualifies as a non-major release (see the next decision).
  - Each library is proved against both versions (Milestones 2 and 3), as shikumi's `c26db8c` already was.
  Date: 2026-09-26

- Decision (awaiting the user's confirmation): Propose non-major releases: shikumi patch releases of the changed packages, `keiro` 0.19.0.1 for all seven keiro packages, and `kioku` 0.8.0.1 for all five kioku packages.
  Rationale:
  - PVP (the Haskell Package Versioning Policy, `A.B.C.D`, where `A.B` is major, `C` minor and `D` patch) reserves a major bump for API changes. A bounds-only widening changes no exported entity, and precedents in the family agree: `baikai-effectful` 0.4.0.2 was a bounds-only patch release; `kioku` 0.4.1.0 was a bounds-only minor release.
  - Staying inside `A.B` means every consumer's existing bound (`keiro ^>=0.19`, `kioku-* ^>=0.8`, `shikumi ^>=0.4.0.0`, `shikumi-trace ^>=0.3.0.0`, `shikumi-cache ^>=0.2.0.0`) admits the new release with no edit.
  - Each repository's release skill makes the final call and must show the user the bump before committing. `keiro`'s skill says "A dependency upper-bound bump on a load-bearing upstream … is a breaking change … Treat it as major." Its example (`keiki >=0.6` → `>=0.7`) replaces the admitted range; this change keeps 2.6 and only adds 2.7, so no consumer loses a plan. If the skill or the user still decides on a major keiro release, follow the branch described under Plan of Work, "If keiro goes major".
  Date: 2026-09-26

- Decision: Release order is shikumi and keiro first (independent of each other, may run in parallel), kioku last, then this repository's refresh.
  Rationale: `kioku-core` depends on `keiro`, `keiro-core`, `shikumi`, `shikumi-trace` and `baikai-effectful`, so its 2.7 build proof can only use Hackage releases once both upstreams are published. `keiro` depends on neither shikumi nor baikai. shikumi depends on baikai, which already admits 2.7.
  Date: 2026-09-26

- Decision: Who performs each release. The implementer may delegate a release to that repository's existing Claude session by cross-session message: "keiro-release" for `mori://shinzui/keiro`, and "kioku-keiro-upgrade" (which ran kioku 0.8.0.0) for `mori://shinzui/kioku`. The implementer may also run the release directly. Either way:
  - the release goes through that repository's release skill;
  - publishing to Hackage, creating tags and pushing happen only after the user's explicit approval, obtained per release.
  Rationale: Each skill encodes repository-specific gates (keiro's `just corpus-regen` and `just verify`, kioku's PostgreSQL-backed suites and haddock tarball quirk, shikumi's independent per-package versions). Publishing to Hackage is irreversible. A message from another agent is never the user's approval.
  Date: 2026-09-26

- Decision: Refresh this repository with `refresh --family keiro --family kioku --family shikumi`, commit locally, and push only with the user's go-ahead.
  Rationale: `--family shikumi` resolves to the `shikumi-baikai` update group, so baikai is refreshed with it, which is the intended atomic unit. Plan 8 runs inside this repository, so it needs the commit but not a push. Downstream flakes pin this repository by revision, and a push is the user's call.
  Date: 2026-09-26


## Outcomes & Retrospective

Implementation checkpoint (2026-10-05): EP-15 remains in progress. Reuse published Shikumi and Shikumi-tools 0.4.1.0. Prepared releases are Shikumi-cache 0.2.0.1, Shikumi-eval 0.3.0.1, Shikumi-compile 0.2.1.1, Shikumi-trace 0.3.0.1, Shikumi-trace-otel 0.1.2.1, Shikumi-cache-redis/postgres 0.1.3.1, Shikumi-optimize 0.3.0.1 and Shikumi-okf 0.2.1.1. The changes live in `mori://shinzui/shikumi`; commit `c22efb9`, nine annotated tags, Hackage sources/docs and nine GitHub releases are published and verified. Shikumi release verification is in an isolated tracked-file scratch copy, with the path in `/tmp/mp3-ep15-shikumi-scratch-path`. The effectful 2.6 full build passed (`/tmp/mp3-ep15-shikumi-build-2.6-hackage.log`); subsequent tests/build/packaging passed with `EXIT=0` and 26 suite PASS records under `/tmp/mp3-ep15-shikumi-gates.sh`, logging to `/tmp/mp3-ep15-shikumi-gates.log`. The flake gate log is `/tmp/mp3-ep15-shikumi-flake-check.log` (exit 0; both host checks passed). Recorded plans `/tmp/mp3-ep15-shikumi-plan-2.6.json` and `/tmp/mp3-ep15-shikumi-plan-2.7.json` prove Baikai-effectful 0.4.0.1/0.4.0.2 and OKF-core 0.9.0.0 came from Hackage. All nine package lints reported no errors or warnings. The capability audit found no new or changed provision, so catalog records and their `since` fields stay unchanged. The user approved these nine releases on 2026-10-05 and explicitly directed use of the Shikumi release skill. Commit `c22efb9` in `mori://shinzui/shikumi` and all nine annotated package tags are pushed. Hackage source/documentation publication succeeded in dependency order with `EXIT=0` in `/tmp/mp3-ep15-shikumi-publish.log`. Nine GitHub releases were created from `/tmp/mp3-ep15-<package>-release-notes.md`; every release is non-draft at the matching tag, and all package/docs pages return 200 with HTML. `/tmp/mp3-ep15-shikumi-release-evidence.json` records the verified URLs.

Keiro bound-widening commit `d790efb5` is local in `mori://shinzui/keiro`, without a release version bump, tag or push. Its full builds with tests enabled passed under effectful/effectful-core 2.6.1.0 and effectful 2.7.1.0/effectful-core 2.7.1.2; logs are `/tmp/mp3-ep15-keiro-build-2.6.log` and `/tmp/mp3-ep15-keiro-build-2.7.log`, with exact plans at `/tmp/mp3-ep15-keiro-plan-2.6.json` and `/tmp/mp3-ep15-keiro-plan-2.7.json`. A seven-package 0.19.0.1 patch release was proposed to the user. The user approved the Keiro 0.19.0.1 release with “go ahead” on 2026-10-05. Release commit `9b215c11` contains the seven-package bump and provenance-only corpus regeneration. Clean-tree gates run through `/tmp/mp3-ep15-keiro-release-gates.sh` with transcript `/tmp/mp3-ep15-keiro-release-gates.log`; flake checks log to `/tmp/mp3-ep15-keiro-release-flake-check.log`. Tags and uploads wait for successful gates. Kioku is unchanged. The channel managed locks are unchanged. No durable architectural choice has changed, so there is no ADR addition at this checkpoint.

Remaining release checkpoint: the user approved the concrete Shikumi changes, and its milestone is complete. Keep both effectful lines admitted, as proven by the builds. Perform releases directly. Historical patch candidates remain proposals until each repository's skill confirms them; Keiro 0.19.0.1 version/release approval is pending. Kioku begins after the admitting Keiro release is live. The required release gates and approvals still apply; optional scratch application compiles remain deferred to consumer adoption per the review requirements.

## Context and Orientation

**Terms.**
- A *bound* is a version range in a `.cabal` file's `build-depends`, such as `effectful >=2.6 && <2.7`; Cabal's solver refuses versions outside it.
- `allow-newer` is a `cabal.project` setting that tells the solver to ignore a named package's upper bound. The user has ruled it out for effectful.
- *Hackage* is the Haskell package registry, and an upload there is permanent.
- A *release skill* is a repository's checked-in agent instruction file for cutting a release, at `agents/skills/release/SKILL.md` and symlinked from `.claude/skills/release`. Each one is marked `disable-model-invocation: true`, so it is started by the user or deliberately loaded, never implicitly.
- The *cohort* is the set of package versions solved together for the five Rei-family applications; plan 8 records it in `cabal/cohort.freeze`.

**This repository.** `mori://shinzui/haskell-nix`, checked out at `/Users/shinzui/Keikaku/bokuno/haskell-nix`. It publishes a Nix "channel": a flake whose library layers first-party Haskell packages over nixpkgs' `haskell.packages.ghc9124` (GHC 9.12.4). The parts this plan touches:
- `config/first-party-families.json` lists 14 families: baikai, keiki, keiro, kioku, kiroku, okf, openapi-hs, pg-migrate, pgmq-hs, relay-pagination, servant-openapi-hs, settei, shibuya, shikumi. It also defines one update group, `shikumi-baikai`, which contains baikai and shikumi. A family not in a group is its own group.
- `packages/first-party-lock.json` holds immutable `familySnapshots`, where every package has a GitHub-source `version` and a `hackage.version`. It also holds `groupSnapshots`, and `packageSets` whose `default` set today selects keiro generation 4 (0.19.0.0), kioku generation 3 (0.8.0.0) and shikumi-baikai generation 4.
- The updater CLI is run as `nix run .#haskell-nix-update -- …` or through `just`. `refresh` observes each family's GitHub `HEAD` and Hackage state and appends new generations. It moves only the selected set's selections, rolls back on failure, and never commits. A mutating refresh refuses to run unless `flake.lock` and `packages/first-party-lock.json` are committed. A refresh has taken more than 10 minutes; never touch `flake.lock` while one runs.
- First-party packages are always jailbroken in Nix (their bounds are deleted before building), so the Nix side builds them against nixpkgs' effectful 2.6.1.0 whatever they declare. Moving Nix's own effectful to 2.7 is plan 9's job, not this plan's.

**The three libraries this plan releases.** Locate them with `mori registry show shinzui/<project> --full`; the paths below are this machine's.

- `mori://shinzui/shikumi` at `/Users/shinzui/Keikaku/bokuno/shikumi`, `master` at `99106ac`, one commit ahead of `origin`.
  - It is a multi-package repository in which each package has its own version and its own tags (`shikumi-0.4.0.0`, `shikumi-trace-0.3.0.0`, …).
  - Unreleased since the tags: `e843745` (baikai 0.7.1.0), `1efc13a` (okf-core 0.9, hasql 1.10, ephemeral-pg 0.3.1), two Seihou tooling commits, `c26db8c` (effectful `>=2.6 && <2.8` in shikumi, shikumi-cache, shikumi-cache-redis, shikumi-cache-postgres, shikumi-compile, shikumi-eval, shikumi-optimize, shikumi-tools, shikumi-trace), and `99106ac` (docs).
  - Release skill: `agents/skills/release/SKILL.md`. It uses independent per-package PVP versions and publishes in dependency order starting with `shikumi`, then `shikumi-cache`, `shikumi-tools`, `shikumi-eval`, `shikumi-compile`, `shikumi-trace`, `shikumi-trace-otel`, and so on.
  - Gates: build inside `nix develop` (the system `ghc` 9.10.3 is the wrong compiler), `nix fmt`, `cabal build all --enable-tests`, `cabal test all`, `nix flake check`, and `cabal check` per package.
- `mori://shinzui/keiro` at `/Users/shinzui/Keikaku/bokuno/keiro`, `master` at `648c18d4`, equal to tag `keiro-0.19.0.0`, clean.
  - Seven published packages share one version: `keiro-core`, `keiro`, `keiro-pgmq`, `keiro-migrations`, `keiro-test-support`, `keiro-dsl` and `keiro-ops`. `jitsurei` is not published.
  - Effectful bounds on Hackage 0.19.0.0:
    - `keiro/keiro.cabal` and `keiro-ops/keiro-ops.cabal`: `effectful >=2.6 && <2.7`, `effectful-core >=2.6 && <2.7`.
    - `keiro-pgmq/keiro-pgmq.cabal`: `effectful-core >=2.6 && <2.7`. Its `>=0.6 && <0.7` range belongs to `pgmq-effectful`.
    - `keiro-test-support/keiro-test-support.cabal`: `effectful >=2.6 && <2.7`.
    - `keiro-dsl` lists `effectful-core` with no bound.
  - Release skill: `agents/skills/release/SKILL.md`. Publish order: keiro-core → keiro → keiro-pgmq → keiro-migrations → keiro-test-support → keiro-dsl → keiro-ops. One annotated tag per package, `<pkg>-<version>`, then a GitHub release anchored on `keiro-<version>`.
  - Gates: `nix fmt`; `just corpus-regen` (mandatory on every version bump, since generated conformance files carry a `@generated by keiro-dsl <version>` header); commit before the final gate; `just verify` (over 10 minutes, needs PostgreSQL through process-compose; run it in the background and read the exit status from the log); `nix flake check`; `cabal check` per package.
  - Every release must also decide whether `blueprints/keiro-upgrade/` needs a migration edge. A widening-only release needs none; record that decision.
- `mori://shinzui/kioku` at `/Users/shinzui/Keikaku/bokuno/kioku`, `master` at `f0f116b`, equal to tag `v0.8.0.0`, clean.
  - Five published packages share one version: `kioku-api`, `kioku-migrations`, `kioku-core`, `kioku-cli` and `kioku-migrate`. There is one tag per release, `v<version>`.
  - `kioku-core/kioku-core.cabal`:
    - library: `effectful >=2.5 && <2.7`, `effectful-core >=2.5 && <2.7` (around lines 126–127), `keiro ^>=0.19`, `shikumi ^>=0.4.0.0`, `shikumi-trace ^>=0.3.0.0`, `baikai-effectful ^>=0.4.0.1`;
    - test suite: `effectful >=2.5` and `effectful-core >=2.5`, with no upper bound.
  - `kioku-cli/kioku-cli.cabal`: `effectful >=2.5 && <2.7`.
  - Release skill: `agents/skills/release/SKILL.md`. Its step 0 checks for a half-finished release. Its suites need a live PostgreSQL started by process-compose over a Unix socket; a connection failure is a failure, not a skip. It publishes kioku-api → kioku-migrations → kioku-core → kioku-cli → kioku-migrate, and has a documented haddock tarball fix for `kioku-migrations:test-support`.

**Libraries that already admit effectful 2.7 (no work).** Latest Hackage releases as of 2026-09-26:
- `kiroku-store` 0.9.0.1 (`effectful >=2.6.1 && <2.8`; `effectful-core >=2.6.1 && <2.7 || >=2.7.1.1 && <2.8`);
- `shibuya-core` 0.10.0.0 and `shibuya-kiroku-adapter` 0.5.1.5 (same shape), `shibuya-metrics` 0.10.0.0;
- `pgmq-effectful` and `pgmq-config` 0.6.1.1 (`effectful-core ^>=2.6 || ^>=2.7`);
- `baikai-effectful` 0.4.0.2 (`effectful-core ^>=2.7`; it requires 2.7);
- with no effectful dependency at all: `shibuya-pgmq-adapter` 0.16.1.0, settei 0.2.0.0, okf-core 0.9.0.0, relay-pagination 0.1.1.0, openapi-hs 5.0.0, servant-openapi-hs 5.1.0, keiki 0.9.1.0, pg-migrate 1.2.0.0, the pgmq core packages, the baikai core/provider/kit packages, `baikai-trace-otel` 0.4.0.1, `shikumi-trace-otel` 0.1.2.0 (bare `effectful`), and `kiroku-cli`, `kiroku-otel`, `kiroku-metrics`.

**The applications** (read only; this plan never commits to them). Their own effectful bounds, which plans 11 to 13 own:
- `mori://shinzui/rei` (`/Users/shinzui/Keikaku/bokuno/rei-project/rei`, `880093cc`): `rei-core`, `rei-cli` and `rei-api` list `effectful`/`effectful-core` with no bound.
- `mori://shinzui/mori` (`/Users/shinzui/Keikaku/bokuno/mori-project/mori`, `f3c5fa4b`, local only): `mori-core`, `mori-cli` and `mori-api` declare `effectful ^>=2.5 || ^>=2.6` and `effectful-core ^>=2.5 || ^>=2.6`.
- `mori://shinzui/mori-app` (`/Users/shinzui/Keikaku/bokuno/mori-project/mori-app`, `30aca6e3`): `effectful ^>=2.6`, `effectful-core ^>=2.6`.
- `mori://shinzui/mori-rei-app` (`/Users/shinzui/Keikaku/bokuno/mori-project/mori-rei-app`, `2acd4ed4`): `effectful ^>=2.6`, `effectful-core ^>=2.6`.
- `mori://shinzui/mina` (`/Users/shinzui/Keikaku/bokuno/mina`, `6a4b3f9d`): bare `effectful`, but capped through `shikumi ^>=0.3.0.2` and `baikai ^>=0.6`.
- `mori://shinzui/reiko` (`/Users/shinzui/Keikaku/bokuno/rei-project/reiko`, `4f98ba91`): no effectful dependency.

**Relevant ADRs.**
- `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md`: one Nixpkgs scope with one version per package name, immutable first-party snapshots, and no solver in this repository. This plan adds new snapshots through the updater and keeps all three rules.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-16` ("Prefer moving a pin to lifting a bound"): when a library caps a cohort, first take a newer release of that library, and only as a last resort use a package-qualified `allow-newer`. This plan produces those newer releases, so plan 8 never needs the `allow-newer` fallback it describes.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort adoption"): a release is adopted only when both Cabal and Nix move. That is why Milestone 4 refreshes the channel as well as publishing to Hackage.
- `docs/adr/` in this repository is a plain filesystem corpus, not an OKF bundle; it has no frontmatter. The MasterPlan has already allocated ADR numbers 2 to 4 to plans 8 to 10. This plan expects to need no ADR (see Outcomes at completion).

**Operating rules.**
- Never search or read `/nix/store` or `/`.
- Find dependency sources with `mori registry show … --full`.
- Never push, tag, upload to Hackage, deploy or migrate a database without the user's explicit approval.
- Do not run two cabal builds in the same `dist-newstyle` at once.
- Quote heredoc delimiters (`<<'EOF'`).
- Commit on the current branch with Conventional Commits.

Commits in this repository carry these trailers:

```text
MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

Commits in keiro, kioku and shikumi carry the same trailers as `mori://` URIs:

```text
MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/15-release-the-first-party-libraries-on-effectful-2-7
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```


## Plan of Work

### Milestone 0: re-verify and confirm

Nothing is edited. First re-run the Hackage bound survey in Concrete Steps and confirm that `keiro`, `kioku-core`, `kioku-cli`, `shikumi`, `shikumi-trace`, `shikumi-cache` and `shikumi-tools` still cap below 2.7, and that no new release has appeared. If one has, skip that library's milestone and record why. Then confirm each repository's `HEAD`, tags and clean tree. Finally, put the Decision Log entries marked "awaiting the user's confirmation" to the user: keep 2.6 admitted, the proposed version numbers, delegation, and shikumi's extra unreleased changes. Record the answers in the Decision Log. The milestone ends when the answers are recorded.

### Milestone 1: shikumi patch releases

shikumi's bounds are already correct on `master`, so this milestone is a release only.
- Start the shikumi release skill in `/Users/shinzui/Keikaku/bokuno/shikumi`, directly or by asking the user to run `/release patch` there. It derives which packages changed since their tags.
- Expect patch bumps at least for `shikumi` (0.4.0.1), `shikumi-cache` (0.2.0.1), `shikumi-trace` (0.3.0.1) and `shikumi-tools` (0.4.0.1), plus shikumi-eval, shikumi-compile, shikumi-optimize, shikumi-cache-redis and shikumi-cache-postgres.
- `shikumi-okf`'s move to `okf-core ^>=0.9` is the skill's call and may be larger. The applications do not use `shikumi-okf`.
- The only hard requirement for this plan: `shikumi`, `shikumi-trace` and `shikumi-cache` stay inside `0.4.*`, `0.3.*` and `0.2.*` respectively, so `kioku-core`'s bounds and mina's future bounds still admit them.

Before the release commit, add to the verification one build per effectful line inside the dev shell, as `c26db8c` did: `--constraint='effectful==2.6.*'` and `--constraint='effectful==2.7.*'`. With the user's approval, the skill commits (`chore(release): …` with the `mori://` trailers), tags, pushes and uploads in its dependency order.

Acceptance: `curl` returns 200 for each new version on Hackage, and the new `shikumi.cabal` on Hackage shows `effectful >=2.6 && <2.8`.

### Milestone 2: keiro 0.19.0.1

In `/Users/shinzui/Keikaku/bokuno/keiro`, edit exactly these dependency lines. `cabal-gild` keeps one dependency per line, so each edit is one line; keep the file's existing column alignment.
- `keiro/keiro.cabal`: every `effectful >=2.6 && <2.7` becomes `effectful >=2.6 && <2.8`, and every `effectful-core >=2.6 && <2.7` becomes `effectful-core >=2.6 && <2.7 || >=2.7.1.1 && <2.8`. Apply this to every stanza that carries the bound (library, test suite, benchmark).
- `keiro-ops/keiro-ops.cabal`: the same two edits.
- `keiro-pgmq/keiro-pgmq.cabal`: the `effectful-core` edit only. Do not touch `pgmq-effectful >=0.6 && <0.7`.
- `keiro-test-support/keiro-test-support.cabal`: the `effectful` edit.
- Leave the unbounded `effectful-core` in `keiro-dsl` and the unpublished `jitsurei` alone.

Add under `## [Unreleased]` in the root `CHANGELOG.md` and in the four packages' `CHANGELOG.md` files, under "Other Changes": "Admit effectful 2.7 (`effectful <2.8`; `effectful-core >=2.7.1.1 && <2.8`, excluding 2.7.0.0–2.7.1.0 as kiroku-store and shibuya-core do). effectful 2.6 remains supported. Bounds only; no source changed."

Build against both effectful lines (Concrete Steps). Commit as `build(deps): admit effectful 2.7 alongside 2.6` with the `mori://` trailers. Then run the keiro release skill (`/release patch`, or delegate to the "keiro-release" session). It presents 0.19.0.1 to the user, bumps all seven versions and internal bounds, runs `just corpus-regen`, commits `chore(release): 0.19.0.1`, runs `just verify` and `nix flake check` on the clean tree, and records "no blueprint edge: widening only". After the user approves, it tags, pushes, uploads in order and creates the GitHub release.

Acceptance: all seven `https://hackage.haskell.org/package/<pkg>-0.19.0.1` pages return 200, and Hackage's `keiro-0.19.0.1/keiro.cabal` shows the new ranges.

**If keiro goes major.** The keiro skill or the user may decide on 0.20.0.0 instead of 0.19.0.1. Then:
- Milestone 3 must also move every `keiro`, `keiro-core`, `keiro-migrations`, `keiro-pgmq` and `keiro-test-support` bound in kioku's cabal files, and the `keiro-pgmq ^>=0.19.0.0` constraint in `kioku/cabal.project`, to `^>=0.20`, and release kioku as 0.9.0.0.
- keiro must add a `blueprints/keiro-upgrade` edge 0.19.0.0 → 0.20.0.0 saying consumers only move bounds, and kioku must decide on a matching `kioku-upgrade` edge.
- Record in the MasterPlan's Surprises and Decision Log, and in Interfaces and Dependencies below, that plans 11–13 must lift the consumers' bounds: `keiro* ^>=0.19` → `^>=0.20` in rei, mori and mori-rei-app, and `kioku-* ^>=0.8` → `^>=0.9` in rei and mori.
- The acceptance commands then use 0.20.0.0 and 0.9.0.0 in place of 0.19.0.1 and 0.8.0.1.

### Milestone 3: kioku 0.8.0.1

Start only when Milestones 1 and 2 are live on Hackage. Run `cabal update` first, so kioku's solve can see them. In `/Users/shinzui/Keikaku/bokuno/kioku`:
- `kioku-core/kioku-core.cabal` library: `effectful >=2.5 && <2.7` → `effectful >=2.5 && <2.8`, and `effectful-core >=2.5 && <2.7` → `effectful-core >=2.5 && <2.7 || >=2.7.1.1 && <2.8`.
- `kioku-core/kioku-core.cabal` test suite: give its unbounded `effectful >=2.5` and `effectful-core >=2.5` the same ranges, so the suite cannot solve a regressed effectful-core.
- `kioku-cli/kioku-cli.cabal`: `effectful >=2.5 && <2.7` → `effectful >=2.5 && <2.8`.
- Leave the `shikumi ^>=0.4.0.0`, `shikumi-trace ^>=0.3.0.0`, `keiro ^>=0.19` and `baikai-effectful ^>=0.4.0.1` bounds as they are. They already admit the new releases, and whether 2.7 or 2.6 is solved decides which one is chosen.

Add the same changelog text as keiro to the root and the two packages' `[Unreleased]` sections. Build against both effectful lines, then commit `build(deps): admit effectful 2.7 alongside 2.6`. Then run the kioku release skill (`/release patch`, or delegate to the "kioku-keiro-upgrade" session). It proposes 0.8.0.1, bounds all 16 internal sites at the new version, runs `cabal test all` with PostgreSQL up and confirms all four suites, runs `nix flake check`, and after the user approves, commits `chore(release): 0.8.0.1`, tags `v0.8.0.1`, pushes, and uploads kioku-api → kioku-migrations → kioku-core → kioku-cli → kioku-migrate.

Acceptance: the five `…-0.8.0.1` Hackage pages return 200, and the effectful 2.7 build log in the Concrete Steps shows `keiro-0.19.0.1` and `shikumi-0.4.0.1` (or whatever Milestone 1 released) taken from Hackage.

### Milestone 4: refresh this repository's channel

In `/Users/shinzui/Keikaku/bokuno/haskell-nix`, with `flake.lock` and `packages/first-party-lock.json` committed:
1. Preview with `refresh --family keiro --family kioku --family shikumi --dry-run`. Selecting shikumi also refreshes baikai, because both are in the `shikumi-baikai` group.
2. Apply the refresh, running it in the background and waiting for it to exit.
3. Run `just validate`, the `first-party-versions` flake check, and `just check-online keiro` (and the same for kioku and shikumi).
4. Commit `chore(cohort): refresh keiro, kioku and shikumi onto their effectful 2.7 releases` with this repository's trailers.

Do not push without the user's go-ahead. The commit is enough for plan 8, which resolves inside this repository.

Acceptance: the `default` set's selected keiro, kioku and shikumi snapshots carry `hackage.version` 0.19.0.1, 0.8.0.1 and the new shikumi versions (jq in Concrete Steps), and the version check passes.

### Milestone 5: acceptance solve and application compile report

Build a scratch Cabal project outside every repository, containing a stub package that depends on every first-party library the five applications use, and dry-run it:
- It must resolve `effectful` ≥ 2.7.1.0 and `effectful-core` ≥ 2.7.1.1 with no `allow-newer` naming either.
- A negative control adds `--constraint='keiro==0.19.0.0'` and must fail, naming keiro's effectful bound.

Then export each application from its current `HEAD` with `git archive` into a scratch directory. Force effectful 2.7 through a `cabal.project.local`, lift only the application's own effectful caps with `allow-newer` (scratch only; plans 11 and 12 lift them for real), and run a full `cabal build all`. Do this for rei, mori, mori-app and mori-rei-app. For mina, do a dry run only and record that it stays capped until plan 13. For reiko, record "no effectful dependency".

Record each application's result (builds, or the failing modules and their GHC errors) in Outcomes & Retrospective and in the MasterPlan's Surprises & Discoveries, for plans 11–13. Finally, update the MasterPlan's registry row and Progress for EP-15.


## Concrete Steps

Milestone 0: survey the latest Hackage bounds (read-only; run from any directory):

```bash
for p in keiro keiro-ops keiro-pgmq keiro-test-support kioku-core kioku-cli shikumi shikumi-trace shikumi-cache shikumi-tools effectful effectful-core; do
  v=$(curl -s -H 'Accept: application/json' "https://hackage.haskell.org/package/$p/preferred" \
      | python3 -c 'import sys,json; d=json.load(sys.stdin)["normal-version"]; print(sorted(d,key=lambda s:tuple(map(int,s.split("."))))[-1])')
  echo "$p $v :: $(curl -s "https://hackage.haskell.org/package/$p-$v/$p.cabal" | grep -E '^\s*,?\s*effectful(-core)?\b' | tr -s ' ' | tr '\n' ';')"
done
```

The expected output on 2026-09-26, before any release:

```text
keiro 0.19.0.0 :: , effectful >=2.6 && <2.7; , effectful-core >=2.6 && <2.7;
kioku-core 0.8.0.0 :: , effectful >=2.5 && <2.7; , effectful-core >=2.5 && <2.7; ...
shikumi 0.4.0.0 :: , effectful >=2.5 && <2.7; ...
effectful 2.7.1.0 :: ...
effectful-core 2.7.1.2 :: ...
```

Check the three repositories:

```bash
for d in shikumi keiro kioku; do
  r=/Users/shinzui/Keikaku/bokuno/$d
  echo "$d $(git -C $r rev-parse --short HEAD) $(git -C $r status -sb | head -1)"
  git -C $r describe --tags --exact-match 2>/dev/null
done
```

Milestones 2 and 3: prove the widened bounds against both effectful lines. From the repository root, inside its dev shell, run the two builds one after the other, never in parallel:

```bash
cd /Users/shinzui/Keikaku/bokuno/keiro      # or /Users/shinzui/Keikaku/bokuno/kioku
nix develop -c cabal update
nix develop -c cabal build all --enable-tests --constraint='effectful-core==2.6.*' 2>&1 | tee "$S/build-2.6.log"; echo "EXIT=${PIPESTATUS[0]}" | tee -a "$S/build-2.6.log"
nix develop -c cabal build all --enable-tests --constraint='effectful-core>=2.7.1.1' 2>&1 | tee "$S/build-2.7.log"; echo "EXIT=${PIPESTATUS[0]}" | tee -a "$S/build-2.7.log"
jq -r '."install-plan"[] | select(."pkg-name"|test("^effectful")) | "\(."pkg-name") \(."pkg-version")"' dist-newstyle/cache/plan.json | sort -u
```

Here `$S` is a scratch directory, for example `S=$(mktemp -d)`. Both logs must end with `EXIT=0`. After the second build, the `jq` line must print:

```text
effectful 2.7.1.0
effectful-core 2.7.1.2
```

It may print a newer 2.7 if one is uploaded. For kioku, also check that the 2.7 plan takes `keiro` and `shikumi` from Hackage at their new versions:

```bash
jq -r '."install-plan"[] | select(."pkg-name"|test("^(keiro|shikumi)")) | "\(."pkg-name") \(."pkg-version") \(."pkg-src".type)"' dist-newstyle/cache/plan.json | sort -u
```

After the releases, confirm each upload is live:

```bash
for p in keiro-core keiro keiro-pgmq keiro-migrations keiro-test-support keiro-dsl keiro-ops; do
  echo "$p $(curl -s -o /dev/null -w '%{http_code}' https://hackage.haskell.org/package/$p-0.19.0.1)"; done
for p in kioku-api kioku-migrations kioku-core kioku-cli kioku-migrate; do
  echo "$p $(curl -s -o /dev/null -w '%{http_code}' https://hackage.haskell.org/package/$p-0.8.0.1)"; done
```

Every line must end in `200`.

Milestone 4, from `/Users/shinzui/Keikaku/bokuno/haskell-nix`:

```bash
git status --short flake.lock packages/first-party-lock.json    # must print nothing
nix run .#haskell-nix-update -- refresh --family keiro --family kioku --family shikumi --dry-run
nix run .#haskell-nix-update -- refresh --family keiro --family kioku --family shikumi
just validate
nix build --no-link .#checks.aarch64-darwin.first-party-versions
just check-online keiro; just check-online kioku; just check-online shikumi
```

Then list the default set's selected Hackage versions for the three families:

```bash
jq -r '
  . as $l
  | [$l.packageSets[] | select(.name=="default") | .groups[]] as $sel
  | $sel[] | . as $g
  | ($l.groupSnapshots[] | select(.group==$g.group and .generation==$g.generation) | .families[]) as $f
  | $l.familySnapshots[] | select(.family==$f.family and .generation==$f.generation)
  | .packages[] | select(.name|test("^(keiro|kioku|shikumi)")) | "\(.name) \(.hackage.version)"
' packages/first-party-lock.json | sort
```

The output must show `keiro 0.19.0.1`, `kioku-core 0.8.0.1`, `shikumi 0.4.0.1` (or the versions actually released) and so on. Commit:

```bash
git add flake.lock packages/first-party-lock.json
git commit -F - <<'EOF'
chore(cohort): refresh keiro, kioku and shikumi onto their effectful 2.7 releases

Select keiro 0.19.0.1, kioku 0.8.0.1 and the shikumi patch releases (with
baikai, through the shikumi-baikai group) in the default package set. Each
admits effectful 2.7 alongside 2.6, so the Rei family cohort can resolve
effectful 2.7 without allow-newer.

MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
```

Milestone 5, the acceptance solve. Run `cabal update` first and note the reported index-state `<T>`; it must be later than the last upload.

```bash
S=$(mktemp -d); mkdir -p "$S/ep15-accept/stub" && cd "$S/ep15-accept"
cat > stub/ep15-stub.cabal <<'EOF'
cabal-version: 3.0
name:          ep15-stub
version:       0
library
  default-language: GHC2021
  build-depends:
    base,
    keiro, keiro-core, keiro-ops, keiro-pgmq, keiro-migrations, keiro-test-support,
    kioku-core, kioku-api, kioku-migrations, kioku-cli,
    shikumi, shikumi-trace, shikumi-cache, shikumi-trace-otel,
    baikai, baikai-claude, baikai-openai, baikai-effectful, baikai-kit, baikai-trace-otel,
    kiroku-store, kiroku-store-migrations,
    shibuya-core, shibuya-kiroku-adapter, shibuya-pgmq-adapter,
    pgmq-core, pgmq-effectful, pgmq-hasql, pgmq-migration,
    pg-migrate, settei, relay-pagination, openapi-hs, servant-openapi-hs, keiki
EOF
cat > cabal.project <<'EOF'
packages: stub
with-compiler: ghc-9.12.4
index-state: hackage.haskell.org <T>
constraints: crypton >= 1.1, http-client-tls >= 0.4
-- Carried from mori://shinzui/rei cabal.project; none concerns effectful.
allow-newer: claude:http-client-tls, baikai-kit:crypton, kiroku-cli:http-client-tls
EOF
cabal build all --dry-run
jq -r '."install-plan"[] | select(."pkg-name"|test("^(effectful|keiro$|kioku-core|shikumi$|baikai-effectful)")) | "\(."pkg-name") \(."pkg-version")"' dist-newstyle/cache/plan.json | sort -u
grep -n 'allow-newer' cabal.project | grep -c effectful     # must print 0
cabal build all --dry-run --constraint='keiro==0.19.0.0' --constraint='effectful-core>=2.7.1.1'; echo "control exit $?"
```

Replace `<T>` with the timestamp from `cabal update`. If the solve reports a conflict unrelated to effectful, copy the matching entry from Rei's `cabal.project` together with its comment. Never add an effectful entry. The expected output:

```text
baikai-effectful 0.4.0.2
effectful 2.7.1.0
effectful-core 2.7.1.2
keiro 0.19.0.1
kioku-core 0.8.0.1
shikumi 0.4.0.1
0
... rejecting: keiro-0.19.0.0 ... (conflict: ... effectful-core ...)
control exit 1
```

Application compile report. Repeat for each application in a fresh scratch directory. Never build in the application's own checkout.

```bash
app=rei; src=$(mori path mori://shinzui/$app | tail -1)     # also mori, mori-app, mori-rei-app
W=$(mktemp -d); git -C "$src" archive HEAD | tar -x -C "$W"; cd "$W"
cat > cabal.project.local <<'EOF'
index-state: hackage.haskell.org <T>
constraints: effectful >= 2.7.1.0, effectful-core >= 2.7.1.1
-- Scratch only: lift this application's own effectful caps (plans 11/12 lift them for real).
allow-newer: mori-core:effectful, mori-core:effectful-core, mori-cli:effectful, mori-cli:effectful-core,
             mori-api:effectful, mori-api:effectful-core, mori-app:effectful, mori-app:effectful-core,
             mori-rei-app:effectful, mori-rei-app:effectful-core
EOF
cabal build all 2>&1 | tee "$W/build.log"; echo "EXIT=${PIPESTATUS[0]}" | tee -a "$W/build.log"
grep -nE '^[^ ].*\.hs:[0-9]+:[0-9]+: error' "$W/build.log" | sort -u
```

The `allow-newer` entries name only the applications' own packages, never a library. Run these builds one at a time, in the background, and wait for each to exit. For mina, run only `cabal build all --dry-run` with the same `constraints:` line; expect it to fail on `shikumi-0.3.0.3` (`effectful >=2.5 && <2.7`) or `baikai-effectful-0.4.0.0` (`effectful-core ^>=2.6`), and record that as plan 13's work.


## Validation and Acceptance

The review requirements above are additional completion gates, including the assigned update-isolation, manifest and cache evidence. Historical runtime-closure/version tables are diagnostic evidence only; they cannot replace those gates.

The plan is accepted when all of the following hold. Record each observation in Progress and Outcomes.

1. Hackage lists new releases that admit effectful 2.7. Each version below returns HTTP 200, and its `.cabal` file shows an upper bound of `<2.8`:
   - `keiro-core`, `keiro`, `keiro-pgmq`, `keiro-migrations`, `keiro-test-support`, `keiro-dsl` and `keiro-ops` at 0.19.0.1;
   - `kioku-api`, `kioku-migrations`, `kioku-core`, `kioku-cli` and `kioku-migrate` at 0.8.0.1;
   - `shikumi`, `shikumi-trace`, `shikumi-cache` and `shikumi-tools` at their new patch versions.

   Each keiro and kioku release was built and tested against both effectful 2.6 and 2.7 (two `EXIT=0` logs per repository), and passed its skill's full gate: `just verify` and `nix flake check` for keiro, `cabal test all` over all four suites and `nix flake check` for kioku, and the shikumi gate. Each has an annotated tag pushed to GitHub. All of this happened only after the user's recorded approval.
2. This repository's `default` package set selects those versions (the jq listing), `just validate` and the `first-party-versions` check pass, and the refresh is committed locally with the three trailers.
3. The scratch acceptance project resolves `effectful` ≥ 2.7.1.0 and `effectful-core` ≥ 2.7.1.1, with zero `allow-newer` entries naming effectful. The same solve with `keiro==0.19.0.0` fails on keiro's effectful bound, which shows the new release is what makes 2.7 reachable.
4. Outcomes & Retrospective lists, per application, whether it compiles against effectful 2.7 in scratch and, if not, the failing modules. The MasterPlan's Surprises & Discoveries has the same summary for plans 11–13. Research predicts none of the 2.7 breaking changes are used, so rei, mori, mori-app and mori-rei-app are expected to compile once their own bounds are lifted. Deprecation warnings are acceptable; errors are not.


## Idempotence and Recovery

- **Bound edits and scratch builds** are repeatable; rerunning them changes nothing further.
- **Hackage uploads are irreversible,** and every release skill gates them behind the user's approval. If an upload fails partway, stop publishing that repository's dependents, as each skill instructs. A version already uploaded cannot be reused. If a published package turns out broken, fix forward with the next patch version, and use a Hackage metadata revision only to tighten a bound as a stopgap.
- **A release commit that was made but not tagged or pushed** is resumed, not re-bumped. kioku's skill step 0 describes this; apply the same rule to keiro and shikumi.
- **A tag pushed before its upload** stays. Upload from that tag rather than re-tagging.
- **The refresh** rolls back its own writes on failure. If it is interrupted, wait until no `haskell-nix-update` process remains, then restore the two managed files with `git checkout -- flake.lock packages/first-party-lock.json` and rerun. Never edit or restore `flake.lock` while a refresh is running.
- **Commit ordering in this repository:** commit each successful refresh before starting another mutating command, because the dirty-file guard refuses otherwise.
- **Scratch directories** live under a `mktemp -d` path and can be deleted at any time. Application checkouts are never modified.


## Interfaces and Dependencies

**Produced for plan 8** (`docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`): Hackage releases whose bounds admit `effectful` ≥ 2.7.1.0 and `effectful-core` ≥ 2.7.1.1. Plan 8's floor conflict for `baikai-effectful` 0.4.0.2 therefore resolves through ADR-16's first option, a newer release of the capping library, and plan 8 must not add the `allow-newer: keiro:effectful, … kioku-core:effectful-core` entries its draft describes. The versions and ranges:
- `keiro`, `keiro-ops`: `effectful >=2.6 && <2.8`, `effectful-core >=2.6 && <2.7 || >=2.7.1.1 && <2.8`;
- `keiro-pgmq`: the effectful-core range only;
- `keiro-test-support`: the effectful range only;
- `kioku-core`: `effectful >=2.5 && <2.8`, `effectful-core >=2.5 && <2.7 || >=2.7.1.1 && <2.8`;
- `kioku-cli`: `effectful >=2.5 && <2.8`;
- the shikumi packages: `effectful >=2.6 && <2.8`.

The freeze should record `effectful` 2.7.1.0 (or newer) and `effectful-core` 2.7.1.2 (or newer), and with effectful 2.7 comes `strict-mutable-base` ≥ 2.0.0.0.

**Produced for plan 9:** the default package set's first-party snapshots at the new versions. Nix's own `effectful`, `effectful-core` and `strict-mutable-base` remain nixpkgs' 2.6.1.0 and 1.1.0.0 until plan 9 generates them from the freeze. The libraries' retained 2.6 range keeps them valid in the meantime.

**Handed to the consumer plans.** Each application's own effectful bounds must move to admit 2.7:
- **Plan 11** (`docs/plans/11-adopt-the-shared-package-set-in-rei-and-mori-rei-app.md`): `mori://shinzui/mori-rei-app`'s `mori-rei-app.cabal` (`effectful ^>=2.6`, `effectful-core ^>=2.6`, library and test suite) and `mori://shinzui/mori-app`'s `mori-app/mori-app.cabal` (the same, library and test suite), which mori-rei-app builds from source. Rei's `rei-core`, `rei-cli` and `rei-api` have no effectful bound and need nothing.
- **Plan 12** (`docs/plans/12-adopt-the-shared-package-set-in-mori.md`): `mori-core`, `mori-cli` and `mori-api` declare `effectful ^>=2.5 || ^>=2.6` and `effectful-core ^>=2.5 || ^>=2.6`. mori's existing `allow-newer: hasql-effectful:effectful, hasql-effectful:effectful-core` still covers its Git-pinned `hasql-effectful`.
- **Plan 13** (`docs/plans/13-bring-mina-and-reiko-up-to-the-shared-package-set.md`): mina reaches effectful 2.7 only by moving `shikumi ^>=0.3.0.2`, `shikumi-trace ^>=0.2.0.2` and `baikai ^>=0.6.0.0` to the shikumi 0.4 / baikai 0.7 cohort, since `shikumi` 0.3.0.3 caps `effectful <2.7` and `baikai-effectful` 0.4.0.0 caps `effectful-core ^>=2.6`. reiko has no effectful dependency.
- **If keiro goes major** (0.20.0.0, with kioku 0.9.0.0): plans 11–13 additionally lift `keiro*`/`keiro-* ^>=0.19` to `^>=0.20` (rei, mori, mori-rei-app) and `kioku-* ^>=0.8` to `^>=0.9` (rei, mori), and follow the `keiro-upgrade`/`kioku-upgrade` blueprint edges.

**External services and tools:**
- Hackage: uploads need the user's credentials, and each package's maintainer rights.
- GitHub: `shinzui/keiro`, `shinzui/kioku` and `shinzui/shikumi`, for tags and releases through `gh`.
- Each library's `nix develop` shell, which provides GHC 9.12.4 and cabal-install 3.16.1.0.
- process-compose-managed PostgreSQL, for the keiro and kioku suites.
- This repository's `haskell-nix-update` app.
- Mori, to locate repositories: `mori registry show shinzui/<project> --full`, `mori path <uri>`.


## Revision Notes

- 2026-10-04: MasterPlan review for reducing change time: clarified shared ownership and acceptance, added the applicable targeted-update/build-identity/cache contracts, and corrected historical assumptions. No implementation completion is claimed.
