---
id: 8
slug: resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications
title: "Resolve one upgrade-only cohort freeze for the Rei family of applications"
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
      at: 2026-10-04T14:06:33Z
      mode: "discuss"
      note: "Record the user-confirmed essential Keiki membership in the proposed Keiro runtime baseline and cohort inventory/acceptance."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-05T19:24:30Z
      mode: "implement"
      note: "Begin contributor inventory after completing EP-15 releases and shared channel refresh."
  reviews:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-04T13:51:42Z
      verdict: "changes-requested"
      note: "Original review found no targeted-update impact contract and contradictory effectful/index-state prose; applied findings in update."
---

# Resolve one upgrade-only cohort freeze for the Rei family of applications

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Five Haskell applications (Rei, Mori, mori-rei-app, reiko and mina) are deployed together, but each one picks its own version of every library it uses, and each picks a different version again when it is built with Nix instead of Cabal. Nothing records one agreed version per package, so nothing can notice when the build that is tested and the build that ships diverge. On 2026-09-26 Rei alone disagreed with its own Nix build in 73 of 353 packages.

After this plan, this repository (`mori://shinzui/haskell-nix`) contains one file, `cabal/cohort.freeze`, that names exactly one version of every Hackage package any of the five applications needs, solved together by Cabal with GHC 9.12.4. It also contains a command that proves the file obeys the rule the user set for this initiative: **upgrade only**. No package in the freeze may be older than the newest version any of the five applications selects today, under either Cabal or Nix. The same command lists every version bound, by repository and file, that stops an application from accepting a frozen version, so the consumer plans (11, 12 and 13 in the MasterPlan) know exactly which bounds to lift.

To see it working, run these from the repository root:

```bash
just cohort-report   # prints the upgrade report; exits 0 only when there are zero downgrades
just cohort-check    # proves Cabal can build a plan from the freeze alone
```

The report ends with a summary line of the form `downgrades: 0`, a list of capping bounds such as `brick: mori://shinzui/rei rei-cli/rei-cli.cabal ^>=2.6 excludes 2.9`, and `cabal build --dry-run` of a project that imports only the freeze succeeds.

The cohort also carries one target the user set on 2026-09-26 on top of upgrade-only: **effectful 2.7 everywhere**. The freeze selects `effectful` at 2.7.1.0 and `effectful-core` at 2.7.1.1 or later, with no `allow-newer` bridging any library that still caps them below 2.7. That is only solvable because plan 15 (`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`) first releases new versions of the first-party libraries that capped `effectful` (keiro, keiro-ops, keiro-pgmq, keiro-test-support, kioku-core, shikumi, shikumi-trace and shikumi-cache) and refreshes this channel with them. This plan therefore starts only after plan 15's releases are on Hackage and in the channel.

Nothing in this plan changes any application, any deployed binary or any database. It writes only inside this repository. Plan 9 turns the freeze into the Nix package set; plans 11 to 13 make the applications import it.


## Review requirements (2026-10-04)

Plan 16 (`docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md`) is now the explicit runtime delivery workstream. This plan retains ownership of the single solver, freeze parser, upgrade-only and targeted-impact report. Accept runtime component roots and source/configuration inputs supplied by plan 16, including packages absent from the initial five-application union. Plan 16 invokes these existing commands to extend the cohort coherently rather than introducing a second solve. Subsequent app-only solves retain the selected runtime projection as exact constraints; conflicts report the required explicit runtime update. Record runtime ownership in the impact report. This plan does not depend on plan 16: its initial coherent cohort/tooling is a prerequisite of that later publication.

The user confirmed that `mori://shinzui/keiki` is essential to the Keiro runtime baseline now delivered by plan 16. Explicitly inventory its dependency edges and required JSON codec, and retain their versions and selected family snapshot in the coherent cohort. The initially listed runtime roots are not an exhaustive dependency inventory. Catalog topology changes remain separate migration work; plan 16 represents non-catalog components in retained source records.

Follow [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md): ordinary application edits retain the cohort and toolchain pins. Matching versions alone is insufficient evidence of reused builds. Historical input revisions, package counts and deletion lists below are starting observations; refresh them from recorded contributor revisions.

Add `just cohort-update +PACKAGES` to the existing updater. It reads the previous freeze and a recorded index-state, holds unrelated versions fixed, and reports the dependency constraints requiring transitive unlocks before widening the request. Preserve upgrade-only. Do not advance index-state, toolchain or every contributor HEAD implicitly. Emit a deterministic impact report covering versions, sources, Cabal revisions and policy, with reverse dependency paths to affected applications and library/test/benchmark components. Stage the inventory, source manifest and freeze together; plan 9 generates the Nix layer from that staged result. Regeneration with the same recorded inputs must be byte-identical, including comments.

Inventory every current local package, not a hard-coded three-package Rei list: Rei now includes `rei-api-contract` and `rei-api-client`. Include test, benchmark and build-tool dependencies and supported flag configurations. A union stub solves candidate versions; real consumer plans must still resolve with their own flags. Record non-Hackage source identities in `cabal/cohort-sources.json`, separately from version-only constraints, including intentional differences such as the Dhall fork. Use distinct historical policy floors: `effectful >=2.7.1.0`, `effectful-core >=2.7.1.1`; re-verify released versions when executing.

This plan owns the shared model/freeze parser, CLI inventory/update/report dispatch and aggregate `just cohort-check`. Plan 9 extends them rather than introducing a second parser or redefining the recipe. Acceptance adds a targeted-update fixture that preserves unrelated pins, reports a necessary transitive unlock, and lists affected components; an unchanged-input rerun produces no diff. Freeze normalization retains exactly one selected index-state and drops flags. Full broad regeneration remains available as an explicitly requested cohort refresh.

## Progress

- [ ] Targeted dependency update preserves unrelated pins and reports affected application components

- [x] (2026-10-05) Prerequisite: plan 15 is Complete; its releases (keiro, keiro-ops, keiro-pgmq, keiro-test-support, kioku-core, shikumi, shikumi-trace, shikumi-cache) are on Hackage and in the channel's `default` package set; record their versions and the channel revision in Surprises & Discoveries.
- [x] (2026-10-05) Milestone 1: added `cabal/contributors.json` naming the five applications and the `mori-app` library at recorded revisions (with `hasql-effectful` in mori's `excludedDependencies`).
- [x] (2026-10-05) Milestone 1: added the `cohort` command group to `cli/haskell-nix-update` with the `inventory` subcommand and its unit tests.
- [x] (2026-10-05) Milestone 1: added the `cohort-inventory` just recipe (scratch copies, fresh `cabal build all --dry-run`, Nix channel evaluation, deployed closure query).
- [x] (2026-10-05) Milestone 1: `just cohort-inventory` exits 0; the six fresh Cabal inventories and pinned Nix inventory are recorded with their source/configuration inputs and committed in this checkpoint.
- [x] (2026-10-05) Milestone 2: wrote `cabal/policy-floors.json` with distinct effectful 2.7.1.0 / core 2.7.1.1 policy floors. Observed core 2.7.1.2 raises the effective solve floor further.
- [x] (2026-10-05) Milestone 2: added and tested `cohort stub`, generating the union Cabal package and 337 upgrade-only floors. A cap keeps its package in the stub rather than deleting the dependency.
- [ ] Milestone 2: write `cabal/common.config`, `cabal/cohort.project` and `cabal/check.project`; choose and record the index-state (at or after plan 15's last upload).
- [ ] Milestone 2: carry the applications' constraints and `allow-newer` entries into `cabal/common.config` with their ADR-16 justifications, except `hasql-effectful:*` and the `tan-effectful` pin (mori vendors the module in plan 12) and `baikai-trace-otel:streamly-core` (mina drops its Git streamly); then prune the ones the solve does not need.
- [ ] Milestone 2: resolve every floor conflict without any `allow-newer` on `effectful` or `effectful-core`, and record each resolution in the Decision Log.
- [ ] Milestone 2: add the `cohort-resolve` recipe, run it, and commit `cabal/cohort.freeze`.
- [ ] Milestone 3: add the `cohort report` subcommand and its unit tests (downgrade, cap, first-party lag, source pin, boot package).
- [ ] Milestone 3: add the `cohort-report` recipe, run it, and commit `cabal/cohort-report.txt` showing zero downgrades.
- [ ] Milestone 4: add the `cohort-check` and `cohort` recipes; prove `cabal build --dry-run` of `cabal/check.project` succeeds and its plan equals the freeze.
- [ ] Milestone 4: prove idempotence (a second `just cohort` leaves `git status` clean) and that `just flake-check` and `just fmt-check` pass.
- [ ] Milestone 4: write `docs/adr/2-resolve-the-rei-family-cohort-upgrade-only.md`, update the MasterPlan's Progress and Exec-Plan Registry rows for EP-8, and fill Outcomes & Retrospective.


## Surprises & Discoveries

- 2026-10-05: Parallel implementation corrected deployed package role classification using actual Haskell builder phase metadata; native zlib, compiler GHC and Rust vendor artifacts no longer raise Haskell dependency floors. All five recorded graphs reproduce corrected maps and three regression tests pass. Targeted updates capture complete input bytes and file membership and use staged inputs for reports; six Python regression tests pass. The updater now canonicalizes component identities, validates actual compiler provenance and vetoes unrelated identity changes before promotion; all 85 updater tests pass. A fresh published-package solve succeeds with 448 manifest packages, Effectful 2.7.1.0/core 2.7.1.2 and the fixed Cmark source. Acceptance remains pending: its report still identifies the missing postgresql-libpq-pkgconfig 0.11 floor, exception pruning and the remaining freeze gates. These candidate artifacts are not an accepted freeze.



- Observation (2026-10-05 inventory): all six recorded current-revision exports solve with tests and benchmarks enabled. External package counts are Rei 413, Mori 383, mori-rei-app 365, Mina 291, mori-app 220 and Reiko 166. The pinned channel maps 451 names with no evaluation errors; Keiki and its JSON codec are both 0.9.1.0, Keiro is 0.19.0.1, Kioku-core is 0.8.0.1 and Shikumi is 0.4.1.0. Dotfiles derivation metadata records 192–368 matching package names per application, as diagnostic build-time selections rather than proof of final static-link parity. `just cohort-inventory` exited 0; log `/tmp/mp3-ep8-cohort-inventory.log`. Rei requires `liblzma` through pkg-config; a dedicated pinned inventory shell includes native inputs without changing contributor code. Generated Rei/Mori DSL conformance packages are included. Mina's current revision already admits the new Shikumi releases, so September-era cap assumptions must not be reused. Initial updater tests pass all 69 cases, including four inventory tests; final full checks follow the remaining milestones.

- Observation (2026-10-05 implementation): EP-15 completed all release and channel gates. Channel lock commit `d4ca4eb` selects Keiro 0.19.0.1, Kioku 0.8.0.1, Shikumi/tools 0.4.1.0, cache 0.2.0.1 and trace 0.3.0.1. Hackage acceptance solves effectful 2.7.1.0/core 2.7.1.2 without effectful overrides at index-state `2026-10-05T18:43:07Z`. Nix effectful remains its existing version until plan 9; this does not block the Cabal cohort. Contributor revisions and manifests will be inventoried afresh.

These were found while writing the plan (2026-09-26) and shape it. Re-verify them when you start.

- Observation: `baikai-effectful` 0.4.0.2, which the Nix channel builds today, requires `effectful-core ^>=2.7`, but `keiro`, `keiro-ops` and `keiro-pgmq` 0.19.0.0 declare `effectful-core >=2.6 && <2.7` and `kioku-core` 0.8.0.0 declares `effectful-core >=2.5 && <2.7`. No released `keiro` or `kioku-core` admits 2.7. Cabal therefore cannot reach the upgrade-only floor for `baikai-effectful` without lifting those library bounds. Nix builds 0.4.0.2 against `effectful-core` 2.6.1.0 only because this repository jailbreaks every first-party package (a jailbreak deletes a package's version bounds before building). The 0.4.0.2 changelog says the release changes nothing except that bound.
  Evidence:

  ```text
  $ nix eval ... hp.baikai-effectful.version hp.effectful-core.version
  "0.4.0.2" "2.6.1.0"
  keiro-0.19.0.0:        effectful-core >=2.6 && <2.7
  kioku-core-0.8.0.0:    effectful-core >=2.5 && <2.7
  baikai-effectful-0.4.0.2 changelog: "Requires effectful-core ^>=2.7 (was ^>=2.6). No API change"
  ```

  Resolution (user decision, 2026-09-26): not an `allow-newer`. Plan 15 releases new versions of those libraries that admit `effectful >=2.7.1.0` / `effectful-core >=2.7.1.1`, and this plan solves against them, so `baikai-effectful` 0.4.0.2 resolves without lifting any bound. The already-compatible Hackage releases are `kiroku-store` 0.9.0.1, `shibuya-core` 0.10 and the shibuya adapters, `pgmq-effectful` 0.6.1.1 and `baikai-effectful` 0.4.0.2. `kiroku-store` and `shibuya` exclude `effectful` 2.7.0.0 to 2.7.1.0 because of a performance regression, which is why the family's `effectful-core` floor is 2.7.1.1 rather than 2.7 (`effectful`'s is 2.7.1.0, its newest release).

- Observation: mina selects `streamly` 0.12.0 and `streamly-core` 0.4.0 from a Git `source-repository-package` (`https://github.com/shinzui/streamly-project` at `f8e33b56`). Neither version exists on Hackage, whose newest are 0.11.1 and 0.3.1. mina's Nix build does not use that pin, so the mina binary that ships already links the Hackage-line `streamly`. A floor of 0.12.0 could never be satisfied by a Hackage solve. Resolution (user decision, 2026-09-26): mina drops the Git pin and takes `streamly`/`streamly-core` from Hackage (0.11.1 / 0.3.1, or whatever the freeze selects) in plan 13, and drops `allow-newer: baikai-trace-otel:streamly-core`, which existed only for the Git `streamly-core` 0.4.0.

- Observation: Hackage already carries `aeson` 2.3.2.0, `brick` 3.0 and `vty` 6.6. A scratch stub package that depended on `aeson`, `brick ^>=2.6` and `vty` with no other bounds resolved `aeson ==2.3.2.0` and `vty ==6.6`, while every application resolves `aeson` 2.2.5.1. A stub without the applications' bounds would jump major versions the applications cannot compile against.

- Observation: `cabal freeze` output is more than version lines. It also writes flag assignments (`aeson +ordered-keymap`), an `active-repositories:` line and an `index-state:` line. A file named `<project-file>.freeze` beside a project file is loaded automatically, so a leftover freeze silently constrains the next solve.

  ```text
  constraints: any.OneTuple ==0.4.3,
               OneTuple +base-ge-4-15 +base-ge-4-16,
  ...
  index-state: hackage.haskell.org 2026-09-26T18:09:31Z
  ```

- Observation: cabal-install 3.16.1.0 refuses an `index-state` newer than the newest entry in the local Hackage index (the "Cabal-7159" error). Tested in a scratch project:

  ```text
  Error: [Cabal-7159]
  Latest known index-state for 'hackage.haskell.org' (2026-09-26T20:00:08Z) is older than the requested index-state (2026-12-01T00:00:00Z).
  Run 'cabal update' or set the index-state to a value at or before 2026-09-26T20:00:08Z.
  ```

- Observation: Rei's `brick` 2.6 and `vty` 6.2 come from Rei's own bounds, `brick ^>=2.6` at `rei-cli/rei-cli.cabal` line 345 and `vty ^>=6.2` at line 379 (Rei `880093cc`). The Nix channel ships `brick` 2.9 and `vty` 6.4, so both bounds cap the cohort.

- Observation: evaluating package versions from this repository's channel is fast (about 17 seconds) with `builtins.getFlake` on a pinned `git+file` revision and the `overlays.github` overlay. On `4cabd105` it returned `aeson 2.2.4.1`, `hasql 1.10.2.4`, `brick 2.9`, `vty 6.4`, `vty-crossplatform 0.4.0.0`, `shibuya-pgmq-adapter 0.16.0.0`, `keiro 0.19.0.0`.


## Decision Log

- Decision (implementation, 2026-10-05): retain the three existing scoped `dhall-json` exceptions from `mori://shinzui/mori-rei-app`, which were omitted from the first combined configuration. `settei-dhall` is an unconditional library dependency; an earlier diagnosis calling this an inactive branch was wrong. All six recorded contributors currently have only unconditional declared bounds. Candidate compilation of dhall-json against the coherent solve is still required.

- Decision (implementation, 2026-10-05): the observed `mori://shinzui/mori-app` plan raises the http-api-data floor to 0.7. Both core and Servant packages in `mori://shinzui/relay-pagination` 0.1.1.0 cap it below 0.7. Prepare a shared 0.1.1.1 bounds-only release: scratch builds and all five suites pass with 0.6.3 and 0.7; formatting and host Nix checks pass. Publication remains pending. Claude 1.5.0 has the same cap; current registry shows no newer release. Its candidate scoped exception requires compiling that library against the selected cohort before acceptance.

- Observation (implementation, 2026-10-05): a disposable combined solve with the prepared relay packages and candidate exceptions selects 447 package names, effectful 2.7.1.0/core 2.7.1.2, Keiki/JSON codec 0.9.1.0, brick 3.0 and vty 6.6. This proves the candidate solver input, not a published canonical freeze or consumer compatibility. Shared model/parser/report tests pass (81 tests), including targeted pin isolation, runtime ownership guard and transitive component impact for metadata/flag/policy changes. Final CLI wiring and end-to-end targeted-update acceptance remain in progress.

- Observation (implementation, 2026-10-05): the staged targeted-update runner now retains exact unrelated versions and the recorded index-state, rejects an inconsistent runtime projection, and checks contributor inventories and the first-party lock for concurrent changes before promotion. Resolve, report, freeze-only check and aggregate recipes are wired. Python syntax checks pass and the shared Haskell tests remain at 81 passing; these are implementation checkpoints, with real freeze-only and targeted-update acceptance still pending Relay publication. The disposable candidate compiles Claude 1.5.0 and Dhall JSON 1.7.12 against the selected newer dependencies. Exception pruning remains under investigation and no pruned configuration has been accepted.

- Observation (implementation, 2026-10-05): Relay's four 0.1.1.1 packages, documentation and GitHub release are published at commit `736fea1c508ba978da90e714e9581558915f5534` in `mori://shinzui/relay-pagination`. All 14 release gates passed, with 133 tests on each http-api-data compatibility line. The complete signed Hackage index is `2026-10-05T22:39:44Z`; the initial cohort records that cutoff. The published solve succeeds with Effectful 2.7.1.0/core 2.7.1.2. Fresh cache isolation is required: changes in imported configuration were not reflected in the existing cached solve. The broad runner now preserves and rotates its old cache before solving, and passes the recorded index explicitly. Staged targeted updates already use fresh directories.

- Observation (implementation, 2026-10-05): pre-existing Cabal records include third-party libraries exposed by the updater shell, not just compiler boot packages. The parser now queries the stock compiler package database; the captured `cabal/compiler-boot-packages.json` records GHC 9.12.4. Reclassifying the six existing exports changes only source classifications, retaining revisions, versions, flags and identities. Explicitly excluded packages no longer raise floors. Previously installed transitive libraries retain their floors as roots even when a newer parent replaces their implementation. All 82 updater tests pass, including the installed-library and exclusion regressions. The corrected inventory also reveals native `zlib` wrongly entering deployed Haskell floors through basename matching; metadata-role correction is in progress, so no zero-downgrade acceptance is claimed yet.

- Decision (implementation, 2026-10-05): retain the public thread-safe CMark fork at `a9014e8c4974d636e7c8f85cd97812905d217faf`, owned by `mori://shinzui/cmark-gfm-hs`, in the coherent source policy. The unchanged Hackage 0.2.6 has a reproduced concurrent-registration abort in `mori://shinzui/mori`; the upstream fork guards registration with an MVar. Registry, release-tag and exact source/hash evidence were verified. Matching Nix source policy is an EP-9 handoff before consumer adoption. Mori's independent vendoring preparation retains its original selectors and records the failure and passing retry.

- Decision (runtime plan, 2026-10-04): adopt the plan-16 integration contract above. It owns retained runtime selection/composition, while this plan retains its existing solver/generation/policy/consumer/deployment responsibility. Consumer plans 11–13 require runtime delivery before adoption; preparatory shared tools do not depend on consumers.

- Decision (discussion, 2026-10-04): explicitly include required Keiki packages and their dependency edges in the runtime inventory and cohort acceptance. This records the user's essential-runtime membership clarification without introducing a new package-set API.

- Decision (2026-10-04 review update): adopt the Review requirements above and ADR 5's update-isolation/build-evidence contract. Historical closure-only acceptance, fixed package counts and duplicated comparison implementations are superseded where noted. Preserve the agreed advisory fleet guard and effectful migration policy. Implementation evidence remains pending.

- Decision: The cohort is a separate Cabal project in a new top-level `cabal/` directory, with its own project files `cabal/cohort.project` and `cabal/check.project`, never the repository's root `cabal.project`.
  Rationale: The root `cabal.project` builds the updater (`cli/haskell-nix-update`) and must not be disturbed. A custom project file name also makes `cabal freeze` write `cohort.project.freeze`, which the recipe renames, so no stray freeze constrains the next solve.
  Date: 2026-09-26

- Decision: The cohort is solved through a generated stub package, `rei-family-cohort`, whose `build-depends` is the union of the direct dependencies (every component, including test suites, benchmarks and `build-tool-depends`) of six contributors: the five applications plus the `mori://shinzui/mori-app` library that mori-rei-app pins from source. The contributors' own packages are excluded (`rei-core`, `rei-cli`, `rei-api`, `mori-core`, `mori-cli`, `mori-api`, `mori-types`, `mori-schema-pin`, `mori-rei-app`, `mori-app`, `reiko-core`, `reiko-cli`, `mina-core`, `mina-cli`).
  Rationale: A stub is the only way to ask Cabal for one plan that serves all five applications. Excluding the applications themselves keeps their unreleased source out of the solve; their dependencies still enter through the union.
  Date: 2026-09-26

- Decision: For each package, the stub's version range is the intersection of the ranges the contributors declare **that admit the package's floor**. A declared range that excludes the floor is left out of the stub and reported as a cap. The floor is the highest version any contributor selects today (see the next decision).
  Rationale: Keeping the admitting bounds stops the solver from jumping to majors nobody has compiled against (`aeson` 2.3, `brick` 3.0). Dropping only the excluding bounds is exactly the upgrade-only rule: the floor wins over a cap, and the cap becomes work for plans 11 to 13.
  Date: 2026-09-26

- Decision: The floor of a package is the maximum of (a) the version in each contributor's freshly produced Cabal `plan.json`, (b) the `.version` this repository's channel evaluates for it in `haskell.packages.ghc9124` with the default package set applied through `overlays.github`, and (c) the version in each deployed application's Nix derivation closure from `mori://shinzui/dotfiles.nix`. Floors are enforced inside the solve by a generated `cabal/floors.config`, and checked again afterwards by the report.
  Rationale: (a) and (b) are the two build systems named by the MasterPlan. (c) adds the Nix builds that actually ship, which differ from (b) through consumer overlays and older channel revisions (reiko and mina are on channel `b88d3173`). Enforcing floors in the solver makes a violation a solve failure with Cabal's own explanation, instead of a surprise in the report.
  Date: 2026-09-26

- Decision: A version selected from a `source-repository-package` that does not exist on Hackage does not raise a floor. The report lists it in a "source pins" section. This covers mina's `streamly` 0.12.0 and `streamly-core` 0.4.0.
  Rationale: The freeze is a Hackage solve pinned by `index-state`; a Git-only version cannot be written as `any.<pkg> ==<ver>` against Hackage. mina's shipped Nix build already uses Hackage-line `streamly`, so mina dropping the pin makes its Cabal build match what ships. The user confirmed on 2026-09-26 that plan 13 drops the pin (see the user-decisions entry below).
  Date: 2026-09-26

- Decision: Packages that exist only as source pins (`typeid-hs-sql` and `typeid-hs-pg-migrate` from `https://github.com/topagentnetwork/typeid-hs` at `7164a74c`) are carried into `cabal/common.config` as `source-repository-package` blocks so their dependencies are solved, and are left out of the freeze. A package that exists on Hackage but that an application pins from a fork (`dhall` in mori, `openapi-hs`, `servant-openapi-hs`, `servant-health` in mori, `streamly` in mina) is taken from Hackage; only when the Hackage release cannot satisfy the floors is the fork carried as well, with a comment saying why. `hasql-effectful` (mori's `tan-effectful` pin) is neither: it is excluded from the cohort entirely, because plan 12 vendors the module into `mori-core` as Rei already did (see the user-decisions entry below).
  Rationale: The freeze feeds plan 9's Nix generator, which pins Hackage releases; source pins are identified by their Git tag instead. Preferring Hackage matches `mori://shinzui/rei/okf/adrs/concepts/ADR-16`'s preference for released versions. `typeid-hs` became public on 2026-09-26 (anonymous `git ls-remote https://github.com/topagentnetwork/typeid-hs` works, HEAD `7164a74c`), so plan 10 moves its two packages into the Nix channel; it is still not on Hackage, so the Cabal side keeps the `source-repository-package` block here and in every consumer.
  Date: 2026-09-26

- Decision: `cabal/cohort.freeze` holds one `index-state: hackage.haskell.org <T>` line followed by the `any.<pkg> ==<version>` constraints of `cabal freeze` output, sorted, under a comment header that records the compiler, the haskell-nix revision and the regeneration command. Flag lines and `active-repositories:` are dropped. (Revised 2026-09-26 during MasterPlan reconciliation: the `index-state:` line is kept.) GHC boot packages (`base`, `ghc-prim`, `rts` and the rest) stay.
  Rationale: The MasterPlan defines the file as version constraints. Flags are each application's build policy (Rei disables `dhall`'s `use-http-client-tls` flag while mori's fork enables it), The `index-state:` line is kept on purpose: plan 13 proved in a scratch copy that cabal-install 3.16.1.0 honours an `index-state` from an imported file, so every consumer removes its own `index-state` and takes it from the freeze. The freeze is then the single place the Rei family's index-state is set, and an application's unfrozen dependencies cannot resolve against a different snapshot. Boot package lines are harmless with a fixed GHC and document the compiler.
  Date: 2026-09-26

- Decision: Write the tooling in Haskell, as a `cohort` command group (`inventory`, `stub`, `report`) in the existing updater `cli/haskell-nix-update`, and keep only process orchestration (Git export, `cabal`, `nix`) in just recipes.
  Rationale: The repository's tooling is that Haskell program plus one awk script; there is no Python anywhere. The updater already depends on the `Cabal` library, which parses `.cabal` files and implements the exact version-range semantics the report needs (`withinRange`, `intersectVersionRanges`), plus `aeson` for `plan.json` and tasty tests that `nix flake check` already runs (`checks.haskell-nix-update`). A Python script would re-implement Cabal's version ordering by hand.
  Date: 2026-09-26

- Decision: Each application is inventoried at its current default-branch HEAD, recorded in `cabal/contributors.json`: rei `880093cc`, mori `f3c5fa4b` (local, not pushed), mori-rei-app `2acd4ed4`, reiko `4f98ba91`, mina `6a4b3f9d`, mori-app `30aca6e3`. Deployed revisions contribute through the Nix deployed closures instead.
  Rationale: HEAD is where plans 11 to 13 start. mori's HEAD carries the Keiro 0.19 adoption that its deploy will ship.
  Date: 2026-09-26

- Decision: A floor that the solve cannot reach because a **library** (not an application) caps it is resolved in the order of `mori://shinzui/rei/okf/adrs/concepts/ADR-16`: a newer release of the capping library, then a package-qualified `allow-newer` in `cabal/common.config` carrying all four of ADR-16's justifications, backed by compiling the capped library against the new version inside the cohort project. If neither applies, stop and ask the user; never lower the floor on your own. (Revised 2026-09-26 by the user decisions below: the `allow-newer` step is not available for `effectful` or `effectful-core`. A library that still caps them below 2.7.1.1 needs a release, from plan 15 for a first-party library or from its upstream for a third-party one; if none exists, stop and ask the user.)
  Rationale: Upgrade-only is the user's rule and lowering a floor is an exception only the user may grant. ADR-16 is the family's existing contract for lifting a bound.
  Date: 2026-09-26

- Decision: First-party packages must agree between `packages/first-party-lock.json` and the freeze. For every package in a snapshot the `default` package set selects, the report compares the snapshot's `hackage.version` (and its GitHub-channel `version`) with the freeze. A snapshot version newer than the freeze is a downgrade and fails the report. A freeze version newer than the snapshot is reported as "first-party lag" for plan 9 to refresh, and does not fail this plan.
  Rationale: Plan 9 owns moving the Nix side, including the lock. This plan must still refuse a freeze that would drag a first-party package down.
  Date: 2026-09-26

- Decision: Record the upgrade-only rule and its report in a new ADR, `docs/adr/2-resolve-the-rei-family-cohort-upgrade-only.md`, in the repository's existing plain filesystem convention (title, `Status:`, `Date:`, Context, Decision, Alternatives and consequences, Validation), without OKF frontmatter.
  Rationale: `docs/adr/` is not an OKF bundle here (`mori.dhall` declares bundles only for `docs/improvement-requests`, `docs/user` and `docs/guides`), and the MasterPlan assigns this ADR to plan 8.
  Date: 2026-09-26

- Decision (user decisions, 2026-09-26): five choices the user made after this plan was drafted, applied throughout.
  1. **effectful 2.7 everywhere, with no `allow-newer` bridge.** The cohort's floors are `effectful` 2.7.1.0 and `effectful-core` 2.7.1.1, written in a hand-maintained `cabal/policy-floors.json` and enforced like every other floor. The earlier default for `baikai-effectful` (an `allow-newer: keiro:effectful, keiro:effectful-core, keiro-ops:effectful, keiro-ops:effectful-core, keiro-pgmq:effectful-core, kioku-core:effectful, kioku-core:effectful-core` proven by compiling those libraries against 2.7) is withdrawn, together with its open question. Plan 15 releases keiro, keiro-ops, keiro-pgmq, keiro-test-support, kioku-core, shikumi, shikumi-trace and shikumi-cache on `effectful >=2.7.1.0` / `effectful-core >=2.7.1.1` and refreshes the channel; this plan hard-depends on plan 15 and runs its resolution only after those releases are on Hackage and in the channel. The `effectful-core` floor is 2.7.1.1, not 2.7, because `kiroku-store` 0.9.0.1 and `shibuya` exclude 2.7.0.0 to 2.7.1.0 for a performance regression. The upgrade report treats `effectful` 2.7 as the target: a frozen `effectful` below 2.7.1.0 or `effectful-core` below 2.7.1.1 is a downgrade.
  2. **mina uses `streamly` from Hackage.** mina's Git pin (`streamly-project` `f8e33b56`, `streamly` 0.12.0 / `streamly-core` 0.4.0) is dropped in plan 13 in favour of the Hackage line the freeze selects, and `allow-newer: baikai-trace-otel:streamly-core` is not carried into `cabal/common.config`. This is no longer an open question.
  3. **`typeid-hs` is public.** Plan 10 moves `typeid-hs-sql` and `typeid-hs-pg-migrate` into the Nix channel and consumers drop their overlay entries and `typeid-hs-src` inputs. Because `typeid-hs` is not on Hackage, the `source-repository-package` block at `7164a74c` stays in `cabal/common.config` and in every consumer's `cabal.project`.
  4. **`hasql-effectful` leaves the cohort.** Only mori uses it, and plan 12 vendors it into `mori-core` as Rei already did. So `hasql-effectful:effectful`, `hasql-effectful:effectful-core` and the `tan-effectful` source pin are not carried into `cabal/common.config`, and `hasql-effectful` is listed in mori's `excludedDependencies` in `cabal/contributors.json` so mori's current `build-depends` on it does not enter the stub (Hackage's `hasql-effectful` is an older, incompatible API that would otherwise drag in its own `effectful` cap).
  5. **The dotfiles guard of plan 14 is relaxed.** Different channel revisions across applications only warn; the deploy fails only when an application's closure differs from the freeze its own pinned channel revision publishes. Nothing in this plan assumed a fleet-wide revision check, but the freeze header's `haskell-nix` revision is what that guard reads, so it must stay accurate.
  Rationale: The user resolved the two open questions this plan carried and removed two exceptions the drafts assumed. Releasing real versions (plan 15) is ADR-16's first remedy, so the cohort no longer needs a documented bound lift that every consumer would have to repeat.
  Date: 2026-09-26


## Outcomes & Retrospective

Implementation is In Progress. EP-15 is Complete, all six contributor solves and the pinned Nix inventory pass, and the inventory CLI has meaningful parser tests. The solver/freeze, upgrade and targeted-impact report, coherent source manifest and final acceptance remain unfinished.

The two open questions carried from authoring were resolved by the user on 2026-09-26 (see the user-decisions entry in the Decision Log):

- The `baikai-effectful` 0.4.0.2 floor is met by new first-party releases on `effectful` 2.7 (plan 15), not by an `allow-newer` and not by freezing 0.4.0.1.
- mina's Git-pinned `streamly` 0.12.0 / `streamly-core` 0.4.0 is dropped by plan 13 in favour of the Hackage line; it stays excluded from the floors and is listed under "source pins" in the report as a retired pin.


## Context and Orientation

This section explains everything the plan relies on. Read it once before starting.

**This repository.** `mori://shinzui/haskell-nix`, checked out at `/Users/shinzui/Keikaku/bokuno/haskell-nix` (the path any other machine uses comes from `mori path mori://shinzui/haskell-nix | tail -1`). It publishes a Nix "channel", meaning a Nix flake whose library adds first-party Haskell packages and fixes on top of nixpkgs' `haskell.packages.ghc9124` package set (the set of Haskell packages built with GHC 9.12.4). The pieces you will touch or read:

- `flake.nix` defines `overlays.github` (the default package set with first-party packages from GitHub sources), `overlays.hackage`, the `lib` functions, the updater app and the `devShells.default` that contains `cabal`, `jq` and `just`.
- `packages/first-party-lock.json` is the lock of first-party package snapshots. It has `familySnapshots` (each with `family`, `generation`, and `packages`, where every package has a `name`, a GitHub-source `version` and a `hackage` object with its Hackage `version`), `groupSnapshots`, and `packageSets`. The `default` package set selects, for example, `shibuya` generation 2 and `shikumi-baikai` generation 4. To list the default set's first-party versions, follow each `packageSets[name=="default"].groups[]` entry to its group snapshot and then to the family snapshots it names.
- `overlays/registry.nix` and `patches/*` hold hand-written third-party version pins and build fixes. Plan 9 replaces the version pins with a layer generated from this plan's freeze; this plan only reads them indirectly through Nix evaluation.
- `cli/haskell-nix-update/` is the updater, a Haskell program (`haskell-nix-update.cabal`, library modules under `src/HaskellNix/Update/`, tasty tests under `test/`). Its CLI parser is `src/HaskellNix/Update/Cli.hs` (`Command`, `commandParser`, `runCli`); process execution goes through `ProcessRunner` and `runChecked` in `src/HaskellNix/Update/Process.hs`; errors are `UpdateError` from `src/HaskellNix/Update/Types.hs`. It already depends on `Cabal`, `aeson`, `containers`, `process`, `text` and `optparse-applicative`. `checks/default.nix` builds it as `checks.<system>.haskell-nix-update`, which runs its test suite.
- `justfile` holds the maintenance recipes; `cli := "nix run --print-build-logs .#haskell-nix-update --"` invokes the updater.
- The root `cabal.project` contains only `packages: cli/haskell-nix-update` and `tests: True`.
- `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` is the only local ADR.

**Terms.**

- *Cabal project and `index-state`.* A `cabal.project` file tells cabal-install which local packages to build and how. Its `index-state:` field fixes the moment in Hackage's history the solver may see, so the same project resolves the same versions on any day. cabal-install 3.16.1.0 is used everywhere; GHC is 9.12.4.
- *Solver and plan.* Cabal's dependency solver picks one version per package that satisfies every bound. `cabal build all --dry-run` runs the solver without building and writes the result to `dist-newstyle/cache/plan.json`, whose `install-plan` array lists every package with `pkg-name`, `pkg-version` and `pkg-src.type` (`repo-tar` for a Hackage release, `source-repo` for a Git pin, `local` for a project package; boot packages that come with GHC have `type: "pre-existing"`).
- *Freeze file.* `cabal freeze` writes the solved versions as a `constraints:` list (`any.aeson ==2.2.5.1`) that another project can `import:` to reproduce the plan.
- *Bound, cap and floor.* A bound is the version range a package declares for a dependency in its `.cabal` file (`brick ^>=2.6` means `>=2.6 && <2.7`). A *cap* in this plan is a bound that excludes the version the cohort needs. A *floor* is the lowest version the cohort may choose for a package: the highest version any application selects today under Cabal or Nix.
- *Cohort and upgrade-only.* The cohort is the set of package versions solved together for all five applications. Upgrade-only means every cohort version is at or above its floor.
- *`allow-newer`.* A `cabal.project` field that tells the solver to ignore a package's upper bound on one dependency (`claude:http-client-tls`). `mori://shinzui/rei/okf/adrs/concepts/ADR-16` governs when the family may use it.
- *`source-repository-package`.* A `cabal.project` block that builds a package from a Git revision instead of Hackage.
- *`.version` in Nix.* Every Haskell derivation in a Nix package set has a `version` attribute; `nix eval` reads it without building anything.
- *Jailbreak.* A Nix override (`doJailbreak`) that deletes a package's version bounds before building. This repository jailbreaks every first-party package, which is how Nix can build combinations Cabal would reject.

**The five applications**, each identified by its Mori project and located on disk with `mori path <uri> | tail -1`:

- `mori://shinzui/rei` at `880093cc`: packages `rei-core`, `rei-cli`, `rei-api`. `cabal.project` has `index-state: 2026-09-26T18:09:31Z`, `with-compiler: ghc-9.12.4`, a `typeid-hs` source pin (`7164a74c`, subdirs `typeid-hs-sql` and `typeid-hs-pg-migrate`), `constraints: crypton >= 1.1, http-client-tls >= 0.4, dhall -use-http-client-tls, blake3 -avx512 -avx2 -sse41 -sse2`, and six justified `allow-newer` entries (`fuzzyfind:containers`, `link-canonical:http-client-tls`, `link-canonical:generic-lens`, `kiroku-cli:http-client-tls`, `claude:http-client-tls`, `baikai-kit:crypton`). Its bounds include `brick ^>=2.6` and `vty ^>=6.2` in `rei-cli/rei-cli.cabal`.
- `mori://shinzui/mori` at `f3c5fa4b` (committed locally, not pushed; another session owns mori's deploy, so only read it): packages `mori-core`, `mori-cli`, `mori-api`, `mori-types`, `mori-schema-pin`. Same index-state. Source pins for `openapi-hs` (`06fc1171`, the 5.0.0 release tag), `servant-openapi-hs` (`181ca609`), `servant-health` (`c70bffdd`), `hasql-effectful` from `tan-effectful` (`5e081ad8`), `typeid-hs` (`7164a74c`) and a `dhall-haskell` fork (`03b40e85`, for an `http-client-tls` flag bound). `constraints: crypton >= 1.1, http-client-tls >= 0.4, random < 1.3`, flag blocks for `blake3` and `postgresql-libpq +use-pkg-config`, and `allow-newer` for `proto-lens:base`, `proto-lens:ghc-prim`, `proto-lens:deepseq`, `proto-lens-runtime:base`, `baikai-kit:crypton`, `hasql-effectful:effectful`, `hasql-effectful:effectful-core`, `claude:http-client-tls`, `haxl:time`, `kiroku-cli:http-client-tls`. The mori test fixtures under `mori-core/test/fixtures/` contain `.cabal` files that are not packages; ignore them. The `tan-effectful` pin and the two `hasql-effectful:*` `allow-newer` entries are retired by plan 12, which vendors the module; this plan excludes `hasql-effectful` from the solve.
- `mori://shinzui/mori-rei-app` at `2acd4ed4`: package `mori-rei-app`. Same index-state; source pins for `mori-app` (`30aca6e3`), `mori-types` (`32882f2d`), `rei-core` (`880093cc`) and `typeid-hs`; constraints and `allow-newer` identical to Rei's.
- `mori://shinzui/reiko` at `4f98ba91`: packages `reiko-core`, `reiko-cli`. `index-state: 2026-06-01T00:17:45Z`, no pins, constraints or `allow-newer`. It has no `dist-newstyle/cache/plan.json` at all.
- `mori://shinzui/mina` at `6a4b3f9d`: packages `mina-core`, `mina-cli`. **No `index-state` and no `with-compiler`.** Source pins for `mori-schema-pin` (mori `7af02c55`) and `streamly`/`streamly-core` (`streamly-project` `f8e33b56`); `allow-newer: baikai-trace-otel:streamly-core`; a `blake3` flag block. Bounds are a whole cohort behind: `baikai ^>=0.6.0.0`, `baikai-trace-otel ^>=0.4.0.0`, `shikumi ^>=0.3.0.2`, `shikumi-trace ^>=0.2.0.2`. Its `plan.json` is stale (2026-09-17). The user decided that plan 13 drops the streamly pin and the `baikai-trace-otel:streamly-core` entry.
- The library `mori://shinzui/mori-app` at `30aca6e3` (package at `mori-app/mori-app.cabal`) is not an application but is built into mori-rei-app from source, so its bounds are inventoried too.

All five are deployed by `mori://shinzui/dotfiles.nix` (`/Users/shinzui/.config/dotfiles.nix`), whose darwin configuration exposes packages such as `.#darwinConfigurations.SungkyungM1X.pkgs.rei` and `.pkgs.mori-rei-app`. Rei, mori-rei-app and mori's deployed build use this channel at `4cabd105` or `018d1e32`; reiko and mina use `b88d3173`.

**The gap this plan measures.** On 2026-09-26 Rei's Nix build and its Cabal plan differed in 73 packages. Most had Nix older (`hasql` 1.10.2.4 against 1.10.3.7, `tls` 2.3.1 against 2.4.6, `aeson` 2.2.4.1 against 2.2.5.1, `sbv` 11.7 against 14.8). A few had Nix newer: `brick` 2.9 against 2.6, `vty` 6.4 against 6.2, `baikai-effectful` 0.4.0.2 against 0.4.0.1. `vty-crossplatform` was 0.4.0.0 in Nix and 0.5.0.0 in Cabal. First-party: `shibuya-pgmq-adapter` 0.16.0.0 in Nix against 0.16.1.0 in Cabal.

**The effectful 2.7 target and plan 15.** `effectful` is the effect-system library every application uses (split into `effectful-core`, the core, and `effectful`, which adds the standard effects). Every application selects 2.6.x today. The user decided on 2026-09-26 that the whole family moves to `effectful` 2.7.1.0 or later and `effectful-core` 2.7.1.1 or later, with no `allow-newer` anywhere to get there. Some Hackage libraries already admit it: `kiroku-store` 0.9.0.1, `shibuya-core` 0.10 and the shibuya adapters, `pgmq-effectful` 0.6.1.1, and `baikai-effectful` 0.4.0.2 (which requires `effectful-core` 2.7). The first-party libraries that capped it below 2.7 (keiro, keiro-ops, keiro-pgmq, keiro-test-support 0.19.0.0; kioku-core 0.8.0.0; the shikumi 0.4 family's shikumi, shikumi-trace and shikumi-cache) are re-released by plan 15, `docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`, which also refreshes `packages/first-party-lock.json` so the channel's `default` set selects the new versions. The `effectful-core` floor is 2.7.1.1 because `kiroku-store` and `shibuya` exclude 2.7.0.0 to 2.7.1.0 for a performance regression. This plan cannot start until plan 15's Progress shows its releases published and the channel refreshed; read the released version numbers from plan 15's Outcomes & Retrospective.

**Sources that changed status on 2026-09-26.** `https://github.com/topagentnetwork/typeid-hs` is now public, so plan 10 carries `typeid-hs-sql` and `typeid-hs-pg-migrate` in the channel; Cabal still needs the `source-repository-package` at `7164a74c` because the packages are not on Hackage. mori's `hasql-effectful` (from the private `tan-effectful` repository) is being vendored into `mori-core` by plan 12, so it leaves the cohort.

**Relevant ADRs.**

- `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` fixes one Nixpkgs package scope with one version per package name, immutable first-party snapshots, and no dependency solver inside this repository. This plan keeps all three: Cabal is the solver, and the freeze is Cabal's output stored as data.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-16` ("Prefer moving a pin to lifting a bound"): when a dependency caps a cohort, first take the dependency's current release, then move a source pin, then consume from the shared overlay, and only then use a package-qualified `allow-newer`. Each `allow-newer` entry must state, next to it, (1) which bound it lifts and who declared it, (2) why the breakage does not reach the consumer, (3) the evidence that was run, and (4) the release that retires it. Never a blanket `allow-newer`.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort adoption"): Cabal and Nix select versions by different mechanisms, and a cohort is adopted only when both move. This plan produces the Cabal half as data that plan 9 turns into the Nix half.
- `mori://shinzui/mori/okf/adrs/concepts/ADR-24` ("Source first-party Haskell packages from the shared overlay"): consumers must not shadow the channel with local pins. It is why the report lists application source pins that shadow a Hackage package.
- `mori://shinzui/haskell-nix/okf/improvement-requests/concepts/IR-2` (proposed) asks for `aeson` 2.2.5.1, `generic-lens` 2.3, `wai` 3.2.5 and `warp` 3.4.16; the cohort should contain at least those, which the report makes visible.

**Operating rules for whoever implements this.** Never search or read `/nix/store` or `/`; query known paths with `nix eval`, `nix-store -qR` and `nix path-info`. This plan never writes to another repository, never pushes, never deploys and never touches a database. Read the applications only through `git archive` exports into a scratch directory. Do not run two cabal builds in the same `dist-newstyle` at once. Quote heredoc delimiters (`<<'EOF'`). Commit on the current branch with Conventional Commits and these trailers:

```text
MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```


## Plan of Work

The work has four milestones. Each ends in a commit and can be verified on its own.

### Milestone 1: inventory what every application selects today

At the end of this milestone the repository contains a committed, reproducible snapshot of what the five applications and `mori-app` use: for each one, every package version in a freshly solved Cabal plan and every version bound it declares; plus the versions this channel's Nix set evaluates, and the versions in each deployed Nix closure. Nothing is solved yet.

Create `cabal/contributors.json`. It is an array of objects with the fields `name` (for example `rei`), `mori` (`mori://shinzui/rei`), `revision` (full 40-character commit), `role` (`application` or `library`), `ownPackages` (the package names that repository defines, excluded from the stub), `excludedDependencies` (dependencies a later plan removes from that repository and that must not enter the stub, each with a reason; only mori's `hasql-effectful`, "vendored into mori-core by plan 12", today; empty elsewhere), `cabalFiles` (repository-relative paths of the `.cabal` files to read bounds from; for mori list only the five package files, not the test fixtures), `indexStateOverride` (null, or a timestamp to pass on the command line when the repository sets none; mina uses the cohort's index-state, see Milestone 2) and `deployedAttr` (the attribute under `darwinConfigurations.SungkyungM1X.pkgs` in dotfiles, or null for `mori-app`). Fill the six entries from Context and Orientation, resolving each short revision to its full hash with `git -C "$(mori path <uri> | tail -1)" rev-parse <short>`. Confirm each `deployedAttr` by evaluating its `drvPath` (see Concrete Steps); if an attribute does not exist, find the right name in the dotfiles repository's overlay and record it.

Add a new module group to the updater:

- `src/HaskellNix/Update/Cohort/Types.hs`: the data types listed in Interfaces and Dependencies, with aeson instances.
- `src/HaskellNix/Update/Cohort/Inventory.hs`: `readPlanVersions` parses a `plan.json` into a map from package name to `(Version, PackageSource)`, where `PackageSource` is `Hackage` for `repo-tar`, `SourcePin` for `source-repo`, `Boot` for `pre-existing`, and `local` entries are skipped. `readDeclaredBounds` parses each listed `.cabal` file with `Distribution.PackageDescription.Parsec.parseGenericPackageDescription` and walks every component's condition tree (library, sub-libraries, executables, test suites, benchmarks, all conditional branches) collecting each `build-depends` entry and each `build-tool-depends` package as a `DeclaredBound` with the file path and component name. `readProjectConstraints` reads the `constraints:` field of the repository's `cabal.project` and keeps the entries that are version constraints (`random < 1.3`, `crypton >= 1.1`), parsing each with Cabal's `Dependency` parser and ignoring flag entries (`dhall -use-http-client-tls`); these become `DeclaredBound`s with component `cabal.project constraints`.
- `HaskellNix.Update.Cli` gains `Cohort CohortCommand` with a subcommand `inventory --contributor <name> --source <dir> --plan <plan.json> --out <file>` that combines the three readers for one contributor into `cabal/inventory/<name>.json`, and `inventory-nix --names <file> --channel <file> [--deployed <name>=<file> ...] --out <file>` that merges already-produced Nix version maps (see below) into `cabal/inventory/nix.json`.

Add the recipe `cohort-inventory` to `justfile` as a bash recipe (the `status` recipe shows the style). For each contributor it:

1. Creates a scratch directory under `${TMPDIR:-/tmp}` and exports the recorded revision into it with `git -C "$(mori path <uri> | tail -1)" archive --format=tar <revision> | tar -x -C <scratch>/<name>`. This reads the repository without changing it (no worktree, no checkout, no build products in the repository).
2. Runs `cabal build all --dry-run` in the export (adding `--index-state=<indexStateOverride>` when set). For `mori-app`, whose repository has its own `cabal.project`, do the same. The export gets its own `dist-newstyle`, and this writes a fresh `dist-newstyle/cache/plan.json` there. The source pins are fetched over the network into cabal's cache, which is not a repository.
3. Runs `{{cli}} cohort inventory` on that export and plan.

Then, for Nix:

4. It writes the union of package names from all six inventories to a scratch `names.json` and evaluates the channel's versions at this repository's committed `HEAD` with the expression in Concrete Steps. Each name maps to its `.version`, or `null` when the attribute is missing or is `null` (boot packages such as `base` are `null` in nixpkgs), or the string `"<error>"` when evaluation throws.
5. For each contributor with a `deployedAttr`, it evaluates `drvPath` in dotfiles, runs `nix-store -qR <drv>`, keeps lines ending in `.drv`, strips the 32-character hash prefix and the `.drv` suffix, splits `<name>-<version>` at the last `-` that is followed by a digit, and keeps only names present in `names.json`. `nix-store -qR` on a derivation lists its whole build-time dependency tree without building or reading store contents.
6. Runs `{{cli}} cohort inventory-nix` to write `cabal/inventory/nix.json` with the channel revision, the dotfiles revision, the system, and the version maps.

Acceptance: `just cohort-inventory` writes `cabal/inventory/{rei,mori,mori-rei-app,reiko,mina,mori-app,nix}.json`; `jq '.packages | length'` on each application file is in the hundreds (Rei's current plan has 477 entries including local ones); `jq '.packages.brick.version' cabal/inventory/rei.json` is `"2.6"`; `jq '.channel.brick' cabal/inventory/nix.json` is `"2.9"`; `jq '[.bounds[] | select(.package=="brick")]' cabal/inventory/rei.json` shows `^>=2.6` in `rei-cli/rei-cli.cabal`. Commit with `feat(cohort): inventory the Rei family's Cabal and Nix versions`.

### Milestone 2: solve the cohort and commit the freeze

At the end of this milestone `cabal/cohort.freeze` exists and was produced by Cabal from a project that enforces every floor.

First write `cabal/policy-floors.json` by hand. It is a JSON array of `{ "package", "floor", "reason" }` objects holding floors the user set as policy rather than floors observed in an inventory. Today it has two entries, `effectful` with floor `2.7.1.0` and `effectful-core` with floor `2.7.1.1`, each with the reason "user decision 2026-09-26: effectful 2.7 everywhere; 2.7.0.0 to 2.7.1.0 excluded by kiroku-store and shibuya for a performance regression". Only the user may add or lower an entry.

Add `src/HaskellNix/Update/Cohort/Stub.hs` and the subcommand `cohort stub --inventory cabal/inventory --lock packages/first-party-lock.json --policy-floors cabal/policy-floors.json --out-dir cabal`. It:

1. Computes floors with `floorVersions`: for every package, the maximum over each application inventory's `Hackage`-sourced version, the channel version, every deployed version and any policy floor. A `SourcePin` version counts only if the same version also appears as a Hackage release in some other inventory (that is how a release-tag pin such as mori's `openapi-hs` 5.0.0 still counts); a Git-only version such as mina's `streamly` 0.12.0 does not. `Boot` packages get no floor. First-party packages also take the `default` set's `hackage.version` from the lock as a floor source; after plan 15 that already names the new keiro, kioku-core and shikumi releases.
2. Computes stub bounds with `stubBounds`: for each dependency name in the union of all contributors' `DeclaredBound`s, minus every contributor's `ownPackages` and `excludedDependencies`, intersect the declared ranges that contain the floor (`withinRange`) and drop the ones that do not. Dropped ranges are returned as `Cap`s. A package with no floor keeps the intersection of all its ranges.
3. Writes `cabal/rei-family-cohort/rei-family-cohort.cabal` (a `cabal-version: 3.4` package named `rei-family-cohort`, version `0`, with an empty library whose `build-depends` lists every dependency with its computed range, sorted by name, and a `build-tool-depends` list built the same way) and `cabal/floors.config` (a `constraints:` list with one `any.<pkg> >=<floor>` line per floored package, sorted). Both files start with a comment saying they are generated and naming the command.

Hand-write three project files in `cabal/`:

- `cabal/common.config`: `with-compiler: ghc-9.12.4`, the `index-state:` (chosen below), `tests: False`, the `typeid-hs` `source-repository-package` block, any fork pins the solve proves necessary, the carried `constraints:` and the carried `allow-newer:` with their justifications. Start by copying, in this order and with their comments, Rei's constraints and six `allow-newer` entries (mori-rei-app's are identical), then mori's extra ones (`random < 1.3`, the four `proto-lens` entries, `haxl:time`). Do not copy mori's `hasql-effectful:effectful` and `hasql-effectful:effectful-core` entries or its `tan-effectful` `source-repository-package`: plan 12 vendors `hasql-effectful` into `mori-core`, so it is not in the cohort. Do not copy mina's `baikai-trace-otel:streamly-core` either: it existed only for the Git `streamly-core` 0.4.0 that plan 13 drops, and `baikai-trace-otel` 0.4.0.1 already admits the Hackage `streamly-core` 0.3.x. Never add any `allow-newer` entry whose right-hand side is `effectful` or `effectful-core`. Prefix each copied comment with the repository it came from as a `mori://` URI, because a reader of this repository cannot open the other repository's relative paths. Keep flag constraints (`dhall -use-http-client-tls`, the `blake3` flags) and the `package blake3` and `package postgresql-libpq` blocks, because flags can change which versions solve.
- `cabal/cohort.project`: `packages: rei-family-cohort`, `import: common.config`, `import: floors.config`.
- `cabal/check.project`: `packages: rei-family-cohort`, `import: common.config`, `import: cohort.freeze`. It has no floors, so it proves the freeze alone reproduces the plan.

Add `cabal/dist-newstyle/` and `cabal/*.project.freeze` to `.gitignore`.

Choose the index-state. Run `cabal update` (this updates cabal's own index cache in your home directory, not a repository) and read the line `The index-state is set to <T>.`; `<T>` is the newest entry in your local Hackage index. Use `<T>` in `cabal/common.config`. It is automatically at or after the upload of every floor version, because every floor version was solved from, or published to, that same index. Never type a later timestamp: Cabal refuses an index-state newer than its newest index entry with error `[Cabal-7159]` (see Surprises), and a machine whose index is older than `<T>` must run `cabal update` before it can solve. Also use `<T>` as mina's `indexStateOverride` and rerun `just cohort-inventory` for mina, because a project without an index-state selects whatever the local index holds. `<T>` must be later than the Hackage upload of every plan 15 release; confirm with `cabal list --simple-output keiro kioku-core shikumi` (after `cabal update`) that the new versions are visible, and if they are not, stop, because plan 15 is not finished. Record `<T>` in the Decision Log.

Prune the carried entries. For each carried `allow-newer` entry and version constraint, remove it, run the dry-run solve, and put it back if the solve fails or the solved versions change. Rei's plan 228 used the same test to delete six entries. Leave an entry out only when the solve is identical without it, and note the removals in a comment in `cabal/common.config`.

Resolve floor conflicts. Run `cabal build all --dry-run --project-file=cohort.project` from `cabal/`. When it fails, Cabal prints the conflict set, for example `rejecting: baikai-effectful-0.4.0.2 (conflict: keiro => effectful-core>=2.6 && <2.7)`. Classify each conflict:

- If the capping bound belongs to a contributor, `stubBounds` has already dropped it, so this cannot fail the solve. It appears in the report as a cap for plans 11 to 13.
- If a Hackage library caps the floor, walk ADR-16's order. First check Hackage for a newer release of the capping library whose bound admits the floor, and if one exists, stop there: its floor moves up with it. Otherwise add a package-qualified `allow-newer` to `cabal/common.config` with ADR-16's four statements, and produce the evidence by compiling the capped library inside the cohort project: `cabal build <capped-package> --project-file=cohort.project` from `cabal/`. This builds only that package and its dependencies into `cabal/dist-newstyle`, which is git-ignored. If it does not compile, remove the entry, stop, and ask the user, recording the question in Outcomes & Retrospective.
- The exception is `effectful` and `effectful-core`: the user ruled out any `allow-newer` for them. If a conflict names a library that caps `effectful` below 2.7.1.0 or `effectful-core` below 2.7.1.1 (for example `rejecting: effectful-core-2.7.1.1 (conflict: keiro => effectful-core>=2.6 && <2.7)`), the solve is seeing a pre-plan-15 release. First confirm the index-state is after plan 15's uploads and the stub's first-party floors name plan 15's versions. If the capping library is first-party and plan 15 did not release it, stop and hand it to plan 15 (record it in plan 15's Surprises and in this plan's Outcomes). If it is third-party with no admitting release, stop and ask the user. The formerly known case, `baikai-effectful` 0.4.0.2 requiring `effectful-core` 2.7, disappears once plan 15's releases are selected, and no entry is needed for it.

Add the recipe `cohort-resolve`. It runs `{{cli}} cohort stub ...`. Then, from `cabal/`, it deletes any leftover `cohort.project.freeze` and runs `cabal freeze --project-file=cohort.project`. It then runs `{{cli}} cohort normalise-freeze --in cohort.project.freeze --out cohort.freeze --index-state <T> --haskell-nix-rev "$(git rev-parse HEAD)"` and deletes `cohort.project.freeze`. `normalise-freeze` writes the `index-state: hackage.haskell.org <T>` line, keeps only `any.<pkg> ==<ver>` constraints and drops the source-pinned packages that `common.config` declares. It sorts them and writes the header comment described in the Decision Log.

Acceptance: `cabal/cohort.freeze` exists, has one `any.` line per package and no flag lines, and `grep -c '^ *any\.' cabal/cohort.freeze` equals the number of non-local packages in `cabal/dist-newstyle/cache/plan.json` minus the source-pinned ones. Commit with `feat(cohort): resolve the Rei family cohort freeze`.

### Milestone 3: the upgrade-only report

At the end of this milestone the report exists, is committed, and shows zero downgrades.

Add `src/HaskellNix/Update/Cohort/Report.hs` and the subcommand `cohort report --freeze cabal/cohort.freeze --inventory cabal/inventory --lock packages/first-party-lock.json --contributors cabal/contributors.json --policy-floors cabal/policy-floors.json [--out cabal/cohort-report.txt]`. It reads the freeze and the inventories, recomputes floors with the same `floorVersions`, and produces a `Report`:

- **Downgrades** (failures): every frozen package whose version is below its floor, naming each source that is higher (for example `hasql 1.10.2.4 < floor 1.10.3.7 from rei (cabal), mori (cabal)`). Policy floors count here, so a frozen `effectful` below 2.7.1.0 or `effectful-core` below 2.7.1.1 is reported as, for example, `effectful-core 2.6.1.0 < floor 2.7.1.1 from policy (effectful 2.7 everywhere)`. A floored package that is missing from the freeze is also a failure, unless no contributor's plan still contains it and it has no policy floor.
- **Targets**: one line per policy floor with the frozen version, for example `effectful 2.7.1.0 (target >=2.7.1.0: user decision 2026-09-26)`, so the effectful 2.7 target is visible even when it passes.
- **First-party agreement**: for each package in the `default` set's snapshots, compare the snapshot's `hackage.version` and GitHub `version` with the freeze. If the snapshot is higher than the freeze, that is a downgrade. If the freeze is higher, report it as "first-party lag", which plan 9 must refresh. If the package is not frozen, report it as "not used by the Rei family".
- **Caps**: every `DeclaredBound` whose range excludes the frozen version, as `<package> <frozen>: <mori uri> <file> [<component>] <range>`. For example: Rei's `brick ^>=2.6` and `vty ^>=6.2`; the `effectful ^>=2.6` and `effectful-core ^>=2.6` bounds in `mori://shinzui/mori-app` `mori-app/mori-app.cabal` and `mori://shinzui/mori-rei-app` `mori-rei-app.cabal`; any `keiro ^>=0.19` or `kioku-core ^>=0.8` bound that plan 15's release numbers fall outside; mina's `baikai ^>=0.6.0.0`, `shikumi ^>=0.3.0.2` and the rest of its baikai/shikumi family; mori's `random < 1.3`, if `random` moves; any `hasql ^>=1.9 || ^>=1.10` or `servant ^>=0.20` that no longer admits the frozen version. Bounds on an `excludedDependencies` package are not caps; they are listed once under "Excluded".
- **Upgrades per application**: for each contributor, the packages whose frozen version is above its current Cabal version. This is informational, for plans 11 to 13; expect `effectful` and `effectful-core` in every application's list.
- **Nix upgrades**: the packages whose frozen version is above the channel version. This is informational, for plan 9 (expect `hasql`, `tls`, `aeson`, `warp`, `sbv`, the crypton family, `vty-crossplatform`, `shibuya-pgmq-adapter`, and `effectful`/`effectful-core` unless plan 15's channel refresh already moved them).
- **Source pins**: every `SourcePin` in any inventory, with its repository, and whether the freeze contains the same version from Hackage, a different version, or none. Mina's `streamly` appears here marked "retired by plan 13 (user decision 2026-09-26)", along with mori's `dhall` fork, `openapi-hs`, `servant-openapi-hs` and `servant-health`, and the `typeid-hs` pin every application keeps.
- **Excluded**: each contributor's `excludedDependencies` with its reason (mori's `hasql-effectful`, "vendored into mori-core by plan 12").
- **Boot packages**: listed once, with the versions GHC 9.12.4 provides.

`renderReport` writes deterministic, sorted plain text ending in a summary line such as `packages: 489  downgrades: 0  caps: 14  first-party lag: 2  source pins: 9`. The command exits with status 1 when downgrades are non-zero, and 0 otherwise. Unit tests in `test/CohortTest.hs` (added to `other-modules` of the test suite in `haskell-nix-update.cabal`) cover: a floor taken from each of the three sources; a policy floor (`effectful-core` 2.7.1.1) raising a floor and failing the report when the freeze has 2.6.1.0; an excluded dependency (`hasql-effectful`) kept out of the stub and the caps; a Git-only source pin not raising a floor; a cap detected and a range that admits the floor kept; a downgrade failing; a first-party snapshot above the freeze failing; freeze normalisation dropping flags and `active-repositories`, while retaining one selected `index-state` line; and `plan.json` parsing of all four source types. Small JSON and freeze fixtures go under `test/fixtures/cohort/` and are added to `data-files`.

Add the recipe `cohort-report`, which runs the subcommand with `--out cabal/cohort-report.txt` and then prints the file. Commit the report with the freeze.

Acceptance: `just cohort-report` exits 0, and its last line has `downgrades: 0`. Point `--freeze` at a scratch copy of the freeze with `aeson` lowered to `2.2.4.1`: the command exits 1 and names `aeson`. The caps section names `rei-cli/rei-cli.cabal` for `brick` and `vty`. Commit with `feat(cohort): report upgrade-only violations and capping bounds`.

### Milestone 4: acceptance, regeneration and the ADR

At the end of this milestone one command regenerates everything and is idempotent. The freeze alone is proven to reproduce the plan, and the upgrade-only rule is written down as an ADR.

Add two recipes: `cohort-check`, which runs `cabal build all --dry-run --project-file=check.project` in `cabal/` and then compares the resulting `plan.json` with the freeze (see Validation); and `cohort`, which runs `cohort-inventory`, `cohort-resolve`, `cohort-report` and `cohort-check` in that order. Give every recipe a one-line comment, which `just --list` shows.

Write `docs/adr/2-resolve-the-rei-family-cohort-upgrade-only.md` in ADR 1's format. It records:

- the decision (one freeze solved by Cabal for the whole family, floors from both build systems and the deployed closures, the floor beats any cap, caps are lifted by the owning application);
- the rejected alternatives (freezing from Nix, which moves Cabal down; an unbounded stub, which jumps majors; a solver inside this repository, already rejected by ADR 1);
- policy floors (`cabal/policy-floors.json`, set only by the user; today `effectful` >=2.7.1.0 / `effectful-core` >=2.7.1.1 with no `allow-newer` bridge, met by plan 15's releases);
- the exception procedure (ADR-16 order, no `allow-newer` on a policy-floored package, and user consent to lower any floor);
- the validation (`just cohort-report` and `just cohort-check`).

Update the MasterPlan's Progress items for EP-8 and its Exec-Plan Registry status. Fill Outcomes & Retrospective. Commit with `docs(adr): record the upgrade-only cohort rule`.


## Concrete Steps

All commands run from the repository root `/Users/shinzui/Keikaku/bokuno/haskell-nix` unless a `cd` is shown. Enter the development shell first so `cabal`, `jq` and `just` match the repository's pins:

```bash
nix develop
```

Before anything else, confirm plan 15 is done: its row in the MasterPlan's Exec-Plan Registry says Complete, its releases are visible on Hackage, and the channel's `default` set carries them and `effectful-core` 2.7:

```bash
grep -n '^| 15 ' docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
cabal update
cabal list --simple-output keiro keiro-ops keiro-pgmq keiro-test-support kioku-core shikumi shikumi-trace shikumi-cache | sort -V | tail -20
nix eval --impure --json --expr '
  let flake = builtins.getFlake "git+file://'"$PWD"'?rev='"$(git rev-parse HEAD)"'";
      pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; overlays = [ flake.overlays.github ]; };
      hp = pkgs.haskell.packages.ghc9124;
  in map (n: hp.${n}.version) [ "keiro" "kioku-core" "shikumi" "effectful-core" ]'
```

The Hackage listing must include the versions plan 15's Outcomes name, and the channel must report them (and an `effectful-core` of 2.7.1.1 or later if plan 15's refresh moved it; otherwise plan 9 moves it and the report's "Nix upgrades" section lists it). If not, stop: this plan's hard dependency is unmet.

While developing the `cohort` subcommands, run the updater from source for fast iteration, and its tests:

```bash
cabal run -v0 haskell-nix-update -- cohort --help
cabal test haskell-nix-update-test
```

Export one application without modifying it, and solve it fresh (this is what `cohort-inventory` does for each contributor):

```bash
scratch=$(mktemp -d "${TMPDIR:-/tmp}/cohort-inventory.XXXXXX")
repo=$(mori path mori://shinzui/reiko | tail -1)
mkdir -p "$scratch/reiko"
git -C "$repo" archive --format=tar 4f98ba91 | tar -x -C "$scratch/reiko"
(cd "$scratch/reiko" && cabal build all --dry-run)
jq '[.["install-plan"][] | select(.["pkg-src"].type=="repo-tar")] | length' "$scratch/reiko/dist-newstyle/cache/plan.json"
git -C "$repo" status --short   # must print nothing new: the repository was only read
```

Evaluate the channel's versions for a list of names (the recipe writes `names.json`; the path must be absolute because of `--impure`):

```bash
rev=$(git rev-parse HEAD)
nix eval --impure --json --expr '
  let
    flake = builtins.getFlake "git+file://'"$PWD"'?rev='"$rev"'";
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ flake.overlays.github ];
    };
    hp = pkgs.haskell.packages.ghc9124;
    names = builtins.fromJSON (builtins.readFile '"$scratch"'/names.json);
    versionOf = n:
      let r = builtins.tryEval (if hp ? ${n} && hp.${n} != null then hp.${n}.version else null);
      in if r.success then r.value else "<error>";
  in builtins.listToAttrs (map (n: { name = n; value = versionOf n; }) names)' > "$scratch/nix-channel.json"
```

Expected (excerpt, on channel `4cabd105`):

```json
{"aeson":"2.2.4.1","baikai-effectful":"0.4.0.2","brick":"2.9","effectful-core":"2.6.1.0","hasql":"1.10.2.4","vty":"6.4"}
```

Query one deployed closure (read-only; nothing is built or read from the store):

```bash
dotfiles=$(mori path mori://shinzui/dotfiles.nix | tail -1)
drv=$(nix eval --raw "$dotfiles#darwinConfigurations.SungkyungM1X.pkgs.rei.drvPath")
nix-store -qR "$drv" | grep '\.drv$' | sed -E 's#^.*/[a-z0-9]{32}-##; s#\.drv$##' | head
```

Choose the index-state:

```bash
cabal update
```

```text
Package list of hackage.haskell.org has been updated.
The index-state is set to 2026-09-26T20:00:08Z.
```

Solve and freeze (what `cohort-resolve` runs after `cohort stub`):

```bash
cd cabal
rm -f cohort.project.freeze
cabal build all --dry-run --project-file=cohort.project
cabal freeze --project-file=cohort.project
```

```text
Resolving dependencies...
Wrote freeze file:
.../haskell-nix/cabal/cohort.project.freeze
```

A failed solve shows the conflict to classify. Rerun with `-v2` for the full conflict set, and test a hypothesis with `--constraint`, for example `cabal build all --dry-run --project-file=cohort.project --constraint='kioku-core==<plan 15 version>'` to see whether a conflict disappears once plan 15's release is forced.

Regenerate everything and review:

```bash
just cohort
git status --short cabal/
git diff --stat
```

Commit, for example after Milestone 2:

```bash
git add cabal/ .gitignore justfile cli/haskell-nix-update
git commit -F - <<'EOF'
feat(cohort): resolve the Rei family cohort freeze

Solve one GHC 9.12.4 plan for rei, mori, mori-rei-app, reiko and mina
through a generated stub, with every upgrade-only floor enforced.

MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
```


## Validation and Acceptance

The inventory and resolved cohort must include the required Keiki packages, including the JSON codec used by Keiro, with their reverse dependency paths. Their Nix first-party snapshot versions must agree with the freeze under the same existing parity contract as the other runtime libraries.

The review requirements above are additional completion gates, including the assigned update-isolation, manifest and cache evidence. Historical runtime-closure/version tables are diagnostic evidence only; they cannot replace those gates.

The plan is complete when all of the following hold on a clean checkout.

1. `just cohort-report` exits 0. Its output has a `DOWNGRADES` section reading `(none)` and ends with a summary line containing `downgrades: 0`. The committed `cabal/cohort-report.txt` is identical to the output (`git diff --exit-code cabal/cohort-report.txt`).

2. The report proves itself on a bad input. Copy the freeze to a scratch file, change `any.aeson ==2.2.5.1` to `any.aeson ==2.2.4.1`, and run the report against the copy. It exits 1 and prints a line naming `aeson` and its floor sources:

   ```bash
   sed 's/any\.aeson ==[0-9.]*/any.aeson ==2.2.4.1/' cabal/cohort.freeze > "$TMPDIR/bad.freeze"
   nix run .#haskell-nix-update -- cohort report --freeze "$TMPDIR/bad.freeze" --inventory cabal/inventory --lock packages/first-party-lock.json --contributors cabal/contributors.json --policy-floors cabal/policy-floors.json; echo "exit=$?"
   ```

   ```text
   aeson 2.2.4.1 < floor 2.2.5.1 from mina (cabal), mori (cabal), mori-rei-app (cabal), rei (cabal)
   ...
   exit=1
   ```

3. `just cohort-check` succeeds: `cabal build all --dry-run --project-file=check.project`, which imports only the freeze and has no floors, resolves, and every non-local package in its `plan.json` has exactly the frozen version. The recipe's comparison prints nothing on success:

   ```bash
   cd cabal
   jq -r '.["install-plan"][] | select(.["pkg-src"].type=="repo-tar" or .type=="pre-existing") | "\(.["pkg-name"]) \(.["pkg-version"])"' dist-newstyle/cache/plan.json | sort -u > "$TMPDIR/plan.txt"
   sed -nE 's/^[[:space:]]*(constraints:)?[[:space:]]*any\.([^ ]+) ==([^,]+),?$/\2 \3/p' cohort.freeze | sort -u > "$TMPDIR/freeze.txt"
   diff "$TMPDIR/plan.txt" "$TMPDIR/freeze.txt"
   ```

4. The report's caps section lists `brick` and `vty` against `mori://shinzui/rei` `rei-cli/rei-cli.cabal`, and mina's `baikai` and `shikumi` family bounds against `mori://shinzui/mina`. Every cap names a repository URI, a file and a range.

5. The freeze contains at least the IR-2 versions: `aeson >=2.2.5.1`, `generic-lens >=2.3`, `wai >=3.2.5`, `warp >=3.4.16`, checked with `grep -E 'any\.(aeson|generic-lens|wai|warp) ' cabal/cohort.freeze`.

6. The effectful 2.7 target holds with no bridge. The freeze has `effectful` at 2.7.1.0 and `effectful-core` at 2.7.1.1 or later, and plan 15's first-party releases; `cabal/common.config` has no `allow-newer` naming `effectful` or `effectful-core`, and none of the retired entries:

   ```bash
   grep -E 'any\.(effectful|effectful-core|keiro|keiro-ops|keiro-pgmq|keiro-test-support|kioku-core|shikumi|shikumi-trace|shikumi-cache|baikai-effectful) ' cabal/cohort.freeze
   grep -vE '^[[:space:]]*--' cabal/common.config | grep -nE 'effectful|streamly'; echo "matches=$?"
   ```

   The first command shows `effectful ==2.7.x` at 2.7.1.0 or later and `effectful-core ==2.7.x` at 2.7.1.1 or later, `baikai-effectful ==0.4.0.2` and the plan 15 versions. The second ignores comment lines (which may explain the retirements), prints nothing and ends with `matches=1`. The report's "Targets" section lists `effectful` and `effectful-core` as met.

7. `cabal test haskell-nix-update-test` passes, including the new cohort tests. `just flake-check` passes, which also builds `checks.<system>.haskell-nix-update` and runs the same tests through Nix. `just fmt-check` passes.

8. Idempotence: with no input changes, a second `just cohort` leaves `git status --short` empty.

9. No other repository changed: `git -C "$(mori path <uri> | tail -1)" status --short` is unchanged from before the plan for all six contributors.


## Idempotence and Recovery

Every recipe can be rerun. `cohort-inventory` writes only to a fresh scratch directory and to `cabal/inventory/`, and exports repositories with `git archive`, which never changes them. The one exception to "read only" outside this repository is `cabal update`, which refreshes cabal's index cache in your home directory. `cohort-resolve` deletes any leftover `cabal/cohort.project.freeze` before solving, so a previous run can never constrain the next. It overwrites the generated stub, floors and freeze. Rerunning with unchanged inventories and index-state yields byte-identical files, because every generated list is sorted and the header records only inputs, never the time of day.

If a solve fails halfway, nothing committed has changed. Fix `cabal/common.config` or record the question, and rerun. If a regeneration produces an unwanted freeze, `git checkout -- cabal/` restores the last committed state. If an application moves on while you work, update its `revision` in `cabal/contributors.json` and rerun `just cohort-inventory`. The report then reflects the new floor, because floors only rise.

`cabal build <package> --project-file=cohort.project`, used for `allow-newer` evidence, builds into `cabal/dist-newstyle/`, which is git-ignored and can be deleted at any time. Never run it at the same time as another cabal command in the same directory.


## Interfaces and Dependencies

Runtime integration: Plan 16 (`docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md`) is now the explicit runtime delivery workstream. This plan retains ownership of the single solver, freeze parser, upgrade-only and targeted-impact report. Accept runtime component roots and source/configuration inputs supplied by plan 16, including packages absent from the initial five-application union. Plan 16 invokes these existing commands to extend the cohort coherently rather than introducing a second solve. Subsequent app-only solves retain the selected runtime projection as exact constraints; conflicts report the required explicit runtime update. Record runtime ownership in the impact report. This plan does not depend on plan 16: its initial coherent cohort/tooling is a prerequisite of that later publication.

The updater (`cli/haskell-nix-update`) gains these modules, all listed in `exposed-modules` of `haskell-nix-update.cabal`. They use only packages it already depends on: `Cabal` for `PackageName`, `Version`, `VersionRange`, `withinRange`, `intersectVersionRanges`, `simplifyVersionRange` and `parseGenericPackageDescription`; `aeson`; `containers`; `text`; `bytestring`; `filepath`; `optparse-applicative`.

In `HaskellNix.Update.Cohort.Types`:

```haskell
data ContributorRole = Application | Library

data Contributor = Contributor
  { name :: !Text
  , mori :: !Text                       -- e.g. "mori://shinzui/rei"
  , revision :: !Text                   -- full commit hash
  , role :: !ContributorRole
  , ownPackages :: ![PackageName]
  , excludedDependencies :: ![(PackageName, Text)]   -- dependency and reason, kept out of the stub
  , cabalFiles :: ![FilePath]
  , indexStateOverride :: !(Maybe Text)
  , deployedAttr :: !(Maybe Text)
  }

data PackageSource = Hackage | SourcePin | Boot

data DeclaredBound = DeclaredBound
  { package :: !PackageName
  , range :: !VersionRange
  , file :: !FilePath                   -- repository-relative
  , component :: !Text                  -- "library", "test:rei-core-test", "cabal.project constraints"
  }

data Inventory = Inventory
  { contributor :: !Contributor
  , indexState :: !(Maybe Text)
  , packages :: !(Map PackageName (Version, PackageSource))
  , bounds :: ![DeclaredBound]
  }

data NixInventory = NixInventory
  { channelRevision :: !Text
  , dotfilesRevision :: !(Maybe Text)
  , system :: !Text
  , channel :: !(Map PackageName (Maybe Version))
  , deployed :: !(Map Text (Map PackageName Version))   -- keyed by contributor name
  }

data FloorSource = CabalPlan !Text | NixChannel | NixDeployed !Text | FirstPartyLock | PolicyFloor !Text   -- reason

data PolicyFloorEntry = PolicyFloorEntry { package :: !PackageName, floorVersion :: !Version, reason :: !Text }   -- cabal/policy-floors.json

data Floor = Floor { version :: !Version, sources :: ![FloorSource] }

data Cap = Cap { bound :: !DeclaredBound, contributor :: !Text, needed :: !Version }
```

In `HaskellNix.Update.Cohort.Inventory`:

```haskell
readPlanVersions :: FilePath -> IO (Either UpdateError (Map PackageName (Version, PackageSource)))
readDeclaredBounds :: FilePath -> [FilePath] -> IO (Either UpdateError [DeclaredBound])
readProjectConstraints :: FilePath -> IO (Either UpdateError [DeclaredBound])
```

In `HaskellNix.Update.Cohort.Stub`:

```haskell
floorVersions :: [Inventory] -> NixInventory -> Map PackageName Version -> [PolicyFloorEntry] -> Map PackageName Floor
stubBounds :: Map PackageName Floor -> [Inventory] -> (Map PackageName VersionRange, [Cap])
renderStubCabal :: Map PackageName VersionRange -> Map PackageName VersionRange -> Text
renderFloors :: Map PackageName Floor -> Text
```

The third argument of `floorVersions` holds the first-party `hackage.version`s of the `default` package set, read with the existing `HaskellNix.Update.PackageLock` decoder; the fourth is `cabal/policy-floors.json`. `stubBounds` drops every contributor's `ownPackages` and `excludedDependencies`. The two arguments of `renderStubCabal` are the library dependencies and the build-tool dependencies.

In `HaskellNix.Update.Cohort.Freeze`:

```haskell
normaliseCabalFreeze :: Text -> Either UpdateError (Map PackageName Version)
parseCohortFreeze :: Text -> Either UpdateError (Map PackageName Version)
renderCohortFreeze :: FreezeHeader -> Map PackageName Version -> Text

data FreezeHeader = FreezeHeader
  { indexState :: !Text, compiler :: !Text, haskellNixRevision :: !Text, command :: !Text }
```

In `HaskellNix.Update.Cohort.Report`:

```haskell
data Report = Report
  { downgrades :: ![(PackageName, Version, Floor)]
  , caps :: ![Cap]
  , firstPartyLag :: ![(PackageName, Version, Version)]
  , applicationUpgrades :: !(Map Text [(PackageName, Version, Version)])
  , nixUpgrades :: ![(PackageName, Maybe Version, Version)]
  , sourcePins :: ![(Text, PackageName, Version, Maybe Version)]
  , targets :: ![(PolicyFloorEntry, Maybe Version)]        -- policy floor and frozen version
  , excluded :: ![(Text, PackageName, Text)]               -- contributor, dependency, reason
  , bootPackages :: !(Map PackageName Version)
  }

cohortReport :: Map PackageName Version -> [Inventory] -> NixInventory -> PackageLock -> [PolicyFloorEntry] -> Report
renderReport :: Report -> Text
reportFailed :: Report -> Bool   -- True iff downgrades is non-empty
```

`HaskellNix.Update.Cli` gains `Cohort !CohortCommand` with `CohortInventory`, `CohortInventoryNix`, `CohortStub`, `CohortNormaliseFreeze` and `CohortReport` constructors. A failure is returned as `Left UpdateError`, so `runCli` prints it and exits non-zero as it already does. A report with downgrades prints the report and then exits 1.

External commands: `git archive` (read-only export), `cabal` 3.16.1.0 with GHC 9.12.4 from the development shell, `nix eval` and `nix-store -qR` (evaluation and derivation-graph queries only), `mori path` to locate checkouts. No new Haskell or Nix dependency is added.

The files this plan leaves in the repository:

- `cabal/contributors.json`
- `cabal/policy-floors.json` (hand-written; user-set floors, today `effectful` 2.7.1.0 / `effectful-core` 2.7.1.1)
- `cabal/inventory/*.json`
- `cabal/common.config`
- `cabal/cohort.project`
- `cabal/check.project`
- `cabal/floors.config` (generated)
- `cabal/rei-family-cohort/rei-family-cohort.cabal` (generated)
- `cabal/cohort.freeze` (generated; the MasterPlan's integration point, which only this plan's regeneration command may edit)
- `cabal/cohort-report.txt` (generated)
- the new updater modules and tests
- the `cohort*` just recipes
- `docs/adr/2-resolve-the-rei-family-cohort-upgrade-only.md`

Plan 15 (`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`) is a hard dependency: it supplies the first-party releases on `effectful >=2.7.1.0` / `effectful-core >=2.7.1.1` on Hackage and in the channel's `default` set, without which the policy floors cannot be solved. Plan 9 consumes `cabal/cohort.freeze` and the "Nix upgrades" and "first-party lag" sections. Plans 11 to 13 consume the "Caps", "Upgrades per application", "Source pins" and "Targets" sections, and import the freeze pinned to a haskell-nix commit. They delete their own `index-state` and take it from the freeze's `index-state:` line. They must compile against `effectful` 2.7, and none of them may add an `allow-newer` on `effectful` or `effectful-core`.


## Revision Notes

- 2026-10-04 (discussion): Made the user's confirmed Keiki requirement explicit in inventory, dependency reporting and cohort acceptance; creation of a named runtime set remains proposed.

- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The freeze now keeps an `index-state: hackage.haskell.org <T>` line (with version constraints only and no flags), and every consumer takes its index-state from it. Plan 13 proved that an imported index-state is honoured, and plans 9, 11 and 12 read it from there.
- 2026-09-26 (user decisions): Applied five user decisions. (1) effectful 2.7 everywhere with no `allow-newer` bridge: removed the `baikai-effectful` `allow-newer` default, its build proof and its open question; added `cabal/policy-floors.json` with `effectful`/`effectful-core` >=2.7.1.1 (the floor `kiroku-store` 0.9.0.1 and `shibuya` use), a "Targets" report section and a `PolicyFloor` floor source; made plan 15 (first-party releases on effectful 2.7) a hard dependency with a precondition check. (2) mina's Git `streamly` pin is dropped in favour of Hackage (a user decision, no longer an open question), so `baikai-trace-otel:streamly-core` is not carried. (3) `typeid-hs` is public: the Cabal `source-repository-package` stays, while plan 10 moves the Nix side into the channel. (4) `hasql-effectful` leaves the cohort because plan 12 vendors it into mori-core: its two `allow-newer` entries and the `tan-effectful` pin are no longer carried, and a new `excludedDependencies` contributor field keeps it out of the stub. (5) Plan 14's guard only warns on channel-revision mismatches, which this plan did not depend on. Also corrected the stale Interfaces sentence that said the freeze carries no `index-state:` line. Reason: the user resolved this plan's open questions and removed exceptions the draft assumed.

- 2026-09-26 (MasterPlan coordination): Corrected the effectful floor. `effectful` has no 2.7.1.1 release (its newest is 2.7.1.0), so the floors are `effectful` 2.7.1.0 and `effectful-core` 2.7.1.1. Only `effectful-core` 2.7.0.0 to 2.7.1.0 are excluded by kiroku and shibuya for the performance regression. Plan 15's research found this.

- 2026-10-04: MasterPlan review for reducing change time: clarified shared ownership and acceptance, added the applicable targeted-update/build-identity/cache contracts, and corrected historical assumptions. No implementation completion is claimed.

- 2026-10-04 (runtime workstream): Added EP-16 integration, ownership and applicable acceptance; consumer adoption now requires the retained runtime set and composes application selections/packages onto it. Shared-tool preparation remains acyclic and the fleet advisory policy is preserved.
