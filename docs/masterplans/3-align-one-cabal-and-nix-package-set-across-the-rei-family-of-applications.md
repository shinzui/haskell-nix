---
id: 3
slug: align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
title: "Align one Cabal-and-Nix package set across the Rei family of applications"
kind: master-plan
created_at: 2026-09-26T22:15:56Z
intention: "intention_01m3fw8cpte9xtje3e5j7f2ng2"
provenance:
  created_by:
    model: "claude-opus-5-5"
    harness: "claude-code"
    at: 2026-09-26T22:15:56Z
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
      at: 2026-10-05T14:23:13Z
      mode: "implement"
      note: "Select EP-15 and record current release prerequisites."
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-08T04:24:34Z
      mode: "implement"
      note: "Resume EP-17 as first eligible unfinished child"
  reviews:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-04T13:51:42Z
      verdict: "changes-requested"
      note: "Original review found version-only completion lacked update-isolation/cache proof and shared guard ownership; applied findings in update."
---

# Align one Cabal-and-Nix package set across the Rei family of applications

This MasterPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Vision & Scope

Five Haskell applications make up the Rei family, each identified here by its Mori project:

- `mori://shinzui/rei` (the time-management system, with `rei-core`, `rei-api-contract`, `rei-api-client`, `rei-cli` and `rei-api`; re-inventory owned packages at implementation time)
- `mori://shinzui/mori` (the project registry)
- `mori://shinzui/mori-rei-app` (the webhook daemon linking the two)
- `mori://shinzui/reiko` (a web companion that talks to Rei only through its CLI)
- `mori://shinzui/mina` (a tool that drives the `rei` and `mori` CLIs)

They are deployed together from `mori://shinzui/dotfiles.nix`, and each builds in two ways:

- **Cabal:** a `cabal.project` `index-state` plus the bounds in each `*.cabal` file, solved against Hackage.
- **Nix:** this repository's channel, which layers first-party family snapshots and a patch registry over nixpkgs' `haskell.packages.ghc9124`.

The original baseline showed unguarded disagreement. On 2026-09-26 Rei's deployed Nix closure (`rei-cli` store path `p1c3d7z5…`, built from Rei `880093cc` on this repository's `4cabd105`) differed from Rei's own Cabal plan in 73 of the 353 packages the two share.

- **First-party:**
  - `shibuya-pgmq-adapter`: Nix 0.16.0.0, jailbroken onto `shibuya-core` 0.10, against Cabal 0.16.1.0.
  - `baikai-effectful`: Nix 0.4.0.2 against Cabal 0.4.0.1.
- **Third-party, mostly Nix older:**
  - `hasql`: Nix 1.10.2.4 vs Cabal 1.10.3.7
  - `tls`: 2.3.1 vs 2.4.6
  - `warp`: 3.4.9 vs 3.4.16
  - `aeson`: 2.2.4.1 vs 2.2.5.1
  - `sbv`: 11.7 vs 14.8
  - the crypton family: crypton 1.1.2 vs 1.1.5
- **A few Nix newer:** `brick` 2.9 vs 2.6, `vty` 6.4 vs 6.2.

Version alignment removes this particular difference between the tested and shipped dependency graphs. It does not by itself prove identical flags, sources, or runtime behavior; the consumer plans retain tests and exact-binary release rehearsals.

The original 2026-09-26 inventory also found these differences; refresh it from recorded contributor revisions before solving:
- **Channel revision:** rei, mori and mori-rei-app are on channel `4cabd105`; reiko and mina on `b88d3173`. The deployed mori in dotfiles is locked at `018d1e32`.
- **Local overlays:** each repository's `nix/haskell-overlay.nix` overrides shared packages differently, so identical channel pins still yield different derivations. mori-rei-app replaces `wai-app-static` with 3.2.1 and jailbreaks `servant-server`, which changed the hash of everything above them up to `rei-core`.
- **Versions:** mina is a whole cohort behind (baikai 0.6, shikumi 0.3, no `index-state`), and reiko's `index-state` is 2026-06-01.

After this initiative:

- One shared package set, owned by this repository, holds a single version of every Haskell package the five applications use. It is recorded as one Cabal freeze file whose versions are resolved upward and never downward. All five `cabal.project` files import that freeze. A retained `keiro-runtime` generation is projected from the same solve; applications compose their own selections and packages onto it in one Haskell scope, with guarded runtime dependency ownership.
- This repository's Nix set is generated from the same freeze. Evaluating any frozen package's `.version` in the channel returns the frozen version. A `nix flake check` version guard fails when it would not, and a per-application check fails when a Cabal plan leaves the freeze.
- Shared overrides live in the channel, not in consumer overlays. Consumer overlays define only their own packages. mori-rei-app consumes `rei-core` from Rei's flake instead of rebuilding it, and dotfiles makes every application follow one channel revision.
- The channel keeps parsing current Cabal files without per-package `cabal-version` patches. On the pinned nixpkgs, the path the channel actually uses (`callCabal2nix`/`callHackageDirect`) already accepts `cabal-version` up to 3.16. A check fails the day that stops being true.

Two terms used throughout:
- **Cohort:** the set of package versions solved together.
- **Upgrade-only:** when the two sides disagree, the older version moves up to the newer one. A package never moves below the highest version any of the five applications currently selects under either build system.

**In scope:**
- this repository's channel, patch registry, updater and checks;
- the reusable Keiro runtime set, exact source/configuration records, retained projections and runtime-plus-application composition API;
- the five applications' `cabal.project`, bounds, flake inputs and overlays;
- the dotfiles inputs and update recipes;
- source changes an application needs to compile against newer versions.

**Out of scope:**
- switching to IOG's haskell.nix;
- moving nixpkgs to a newer revision (research on 2026-09-26 showed nixpkgs-unstable still ships hasql 1.9.3.1 and tls 2.1.8, so it does not close the gap);
- aarch64-linux;
- publishing any first-party release not required by a version move.

**Persistent-database rule, inherited from the Keiro 0.19 adoption:**
- Kiroku 0.9 requires Kiroku migration `0012` before any 0.9 process appends, and a Kiroku 0.8 process fails every append after it. There is no rolling deploy.
- Rei's global database (`host=/Users/shinzui/.local/state/postgresql dbname=rei`) received `0012` on 2026-09-26.
- Mori's global database (`dbname=mori`) received `0012` later the same day (11.9 s for 526,818 `$all` rows, 0 mismatches, verify clean). Mori `f3c5fa4b` + `bf28e026` is deployed, and `mori-automate` and mina-web's `mori` both run `mori-cli` `35dr5zq5…` on kiroku-store 0.9.0.1. So no plan in this initiative needs a Kiroku schema cutover. Every deploy is an ordinary binary swap, though the stop-writers rule still governs any future Kiroku migration.
- Any child plan that deploys a Kiroku writer must follow the stop-writers cutover:
  1. stop the writers;
  2. back up the database;
  3. `up`, then `VACUUM (ANALYZE) kiroku.stream_events`;
  4. start only 0.9 builds.


The cohort covers direct and transitive third-party dependencies as well as selected first-party libraries, including the library contributor `mori://shinzui/mori-app`. Package names used by several applications receive one version; an application need not add dependencies it does not use. Re-inventory every owned package and every supported component/flag configuration: Rei now has five local packages, and historical deletion counts are not an exhaustive current inventory.

The reusable Keiro runtime baseline delivered by plan 16 must include `mori://shinzui/keiki`, which the user confirmed is essential on 2026-10-04. Its membership also includes `mori://shinzui/keiro`, `mori://shinzui/kiroku`, `mori://shinzui/shibuya`, `mori://shinzui/pgmq-hs`, `mori://shinzui/settei`, `mori://shinzui/pg-migrate` and the maintained fork `mori://shinzui/hw-kafka-client`. Plan 8 must explicitly inventory Keiki's dependency edges and include its required packages in the solved cohort. Plan 16 now owns the named runtime set, retained version/source/policy records and guarded runtime-plus-application composition. It preserves the current first-party catalog and complete-selection API, representing non-catalog components in the runtime manifest. Creating a dedicated runtime baseline and adopting it in consumer plans are required MP-3 outcomes; implementation remains Not Started.

## Decomposition Strategy

The work falls into four phases.

- **Phase 0 (upstream releases):** plan 15 releases the first-party libraries that still cap `effectful` below 2.7, so the cohort can take effectful 2.7 everywhere.
- **Phase 1 (this repository and disposable verification fixtures):** build the shared cohort, publish the reusable Keiro runtime set and prove composition/cache reuse.
- **Phase 2 (one plan per consumer):** adopt the set in each consumer.
- **Phase 3 (dotfiles):** deploy it and keep it true.

Each child plan leaves an independently observable result, including a retained runtime generation with equal dependency identities in two composed fixture applications: a freeze file and its upgrade-only report; a channel whose `.version` values equal the freeze; a consumer overlay with no shared overrides; an application whose fresh Cabal plan equals the freeze and whose structured Nix build manifest proves the versions used by its actual executable; a dotfiles lock with one channel revision.

Phase 1 is split in four because the concerns are separable.
- **Resolving the cohort** (plan 8) is a Cabal solving problem.
- **Generating Nix from it** (plan 9) is a Nix evaluation problem. It also adds the check that the channel still parses `cabal-version` 3.14 and 3.16. No `cabal2nix` rebuild is needed (see Surprises & Discoveries).
- **Moving consumer overrides into the channel** (plan 10) is a registry-ownership problem that plan 9's guard cannot see, because those overrides live in other repositories.
- **Publishing the reusable Keiro runtime baseline** (plan 16) defines retained runtime ownership, source/configuration policy and guarded application composition, using plans 8–10's shared tools. Its output is demonstrated with two disposable consumers before real application adoption.

Phase 2 is split by consumer, because each has a different risk.
- **Plan 11, rei and mori-rei-app:** they share a Kiroku database and a `rei-core` dependency. mori-rei-app must stop rebuilding `rei-core`, so the two move together.
- **Plan 12, mori:** it owns a second Kiroku database. Its `0012` cutover is complete; adoption is a binary swap with an exact-binary rehearsal.
- **Plan 13, mina and reiko:** neither links Kiroku, but mina is a full cohort behind and must be upgraded in source.

Phase 3 (plan 14) comes last because it is the only place all five meet: the dotfiles lock, the update recipes, and the deploy-time closure check.

**Alternatives considered:**
- **Generate a Cabal freeze from the Nix set.** Rejected, because it would move Cabal down to hasql 1.9-era versions and violates upgrade-only.
- **Bump nixpkgs.** Rejected as insufficient, since nixpkgs-unstable is no closer.
- **Adopt haskell.nix,** which makes Cabal and Nix equal by construction through `plan-to-nix`. Rejected: it would replace this repository's family snapshots, patch registry and cache-identity checks, and move five flakes onto another overlay and cache ecosystem. That is too much change for a guarantee a generator plus an evaluation check provides.
- **A compatibility solver in this repository.** Already rejected by `docs/masterplans/2-decouple-first-party-upgrades-with-composable-package-sets.md`; Cabal remains the solver.

**Relevant ADRs:**

- `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md`: one Nixpkgs fixed point with one version per package name, immutable snapshots, and no solver. This initiative keeps all three. The freeze is Cabal's output, not a solver inside Nix.
- [ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md): retained runtime ownership, exact source/configuration projections and guarded application composition. Plan 16 supplies implementation evidence.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort adoption"): Cabal and Nix select the cohort by different mechanisms, and adopting a release means changing and proving both. This initiative turns that rule into a check.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-16` ("Prefer moving a pin to lifting a bound"): applies whenever an application's bound caps an upgrade. Move the bound, don't `allow-newer` it, unless the ADR's documented conditions hold.
- `mori://shinzui/mori/okf/adrs/concepts/ADR-24` ("Source first-party Haskell packages from the shared overlay"): consumers must not shadow the channel with local pins. Plan 10 extends it to shared third-party packages.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-26` ("A replay audit must replay the code that ships") and `mori://shinzui/rei/okf/adrs/concepts/ADR-31` ("Gate runtime releases on restored history and observed delivery"): any deploy of a Kiroku writer is proven with the exact shipped binary on a restored clone.
- `mori://shinzui/haskell-nix/okf/improvement-requests/concepts/IR-2` ("Provide a coherent modern CLI and WAI dependency cohort", proposed): asks for aeson 2.2.5.1, generic-lens 2.3, wai 3.2.5 and warp 3.4.16. Plan 9 satisfies it.


## Exec-Plan Registry

| # | Title | Path | Hard Deps | Soft Deps | Status |
|---|-------|------|-----------|-----------|--------|
| 15 | Release the first-party libraries on effectful 2.7 | docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md | None | None | Complete |
| 8 | Resolve one upgrade-only cohort freeze for the Rei family of applications | docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md | EP-15 | None | Complete |
| 17 | Upgrade every ephemeral PostgreSQL consumer to stable cleanup roots | docs/plans/17-upgrade-every-ephemeral-postgresql-consumer-to-stable-cleanup-roots.md | None | EP-8, EP-9, EP-10 | In Progress |
| 9 | Generate the Nix package set from the cohort freeze and guard version parity | docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md | EP-8 | None | In Progress |
| 10 | Own the shared third-party overrides in the channel instead of consumer overlays | docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md | None | EP-9 | Complete |
| 16 | Create the Keiro runtime package set and compose applications on it | docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md | EP-9, EP-10 | None | Not Started |
| 11 | Adopt the shared package set in rei and mori-rei-app | docs/plans/11-adopt-the-shared-package-set-in-rei-and-mori-rei-app.md | EP-9, EP-10, EP-16 | None | Not Started |
| 12 | Adopt the shared package set in mori | docs/plans/12-adopt-the-shared-package-set-in-mori.md | EP-9, EP-10, EP-16 | EP-11 | In Progress |
| 13 | Bring mina and reiko up to the shared package set | docs/plans/13-bring-mina-and-reiko-up-to-the-shared-package-set.md | EP-9, EP-10, EP-16 | None | Not Started |
| 14 | Deploy one channel revision from dotfiles and guard closure parity | docs/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity.md | EP-11, EP-12, EP-13 | None | Not Started |

Status values: Not Started, In Progress, Complete, Cancelled.
EP-12's current work is its explicitly independent Hasql-vendoring Milestone 1; cohort/runtime adoption still waits for its hard dependencies. On 2026-10-05 the user requested parallel execution: EP-10, EP-12 M1 and the relay compatibility release run concurrently with EP-8. EP-16's read-only runtime inventory is preparation, not completion of its prerequisite-dependent implementation.
EP-9's current work is its explicitly independent Cabal-format guard and fixture-based parser/generator preparation. Its Context already permits these additive milestones before EP-8 finishes. Activating the generated layer and completing EP-9 still require EP-8 acceptance; no aggregate gate is waived.
Hard Deps and Soft Deps reference other rows by their # prefix (e.g., EP-8). This repository numbers ExecPlans globally, so this MasterPlan's children are 8 through 17. Plan 15 was added on the user's decision to move the whole family to effectful 2.7; it runs first. Plan 17 adds the user's later cross-project ephemeral PostgreSQL cleanup migration.


## Dependency Graph

**Plan 17 is a user-requested extension (2026-10-06).** Retire ephemeral-pg 0.2 across registered first-party consumers and set stable per-effective-user temporary roots so startup sweeping works across sessions. Source/configuration migrations and patch-release gates run in parallel with shared Nix policy. Plans 8–10 retain solver/projection/policy ownership and incorporate the new release inputs before final acceptance; version agreement alone does not prove cleanup configuration. Plan 17's wider consumer audit supplements the initial Rei-family contributors without silently treating those extra applications as original cohort inputs.

**Plan 15 comes first.** On 2026-09-26 the user chose effectful 2.7 across the whole family, with no `allow-newer` bridge. These releases cap `effectful` below 2.7:
- `keiro`, `keiro-ops`, `keiro-pgmq` and `keiro-test-support` 0.19
- `kioku-core` 0.8
- `shikumi` 0.4, `shikumi-trace` 0.3 and `shikumi-cache` 0.2

Plan 15 releases versions that admit effectful 2.7 (floors: `effectful` 2.7.1.0, `effectful-core` 2.7.1.1), and refreshes the channel. The `effectful-core` floor matches `kiroku-store` 0.9 and `shibuya`, which exclude `effectful-core` 2.7.0.0 to 2.7.1.0 for a performance regression. `effectful` itself has no 2.7.1.1 release; its newest is 2.7.1.0. Already compatible: `kiroku-store` 0.9.0.1, `shibuya-core` 0.10, the shibuya adapters, `pgmq-effectful` 0.6.1.1, and `baikai-effectful` 0.4.0.2, which requires 2.7.

**Plan 8 hard-depends on plan 15**, because the freeze cannot select effectful 2.7 until those releases exist. Every other plan consumes plan 8's freeze file. Plan 8 resolves the cohort in its own Cabal project inside this repository, not inside any application. The applications' own caps are reported by plan 8 and lifted by the consumer plans.

**Plan 9's generated-layer activation hard-depends on plan 8.** It generates Nix entries from the accepted freeze, and its parity check compares the channel against that file. Its additive Cabal-format guard and fixture-based parser/generator milestones can proceed independently, as its Context and Orientation specifies. This preparation changes no selected package versions and does not establish channel parity.

**Plan 10 has no hard dependency** and can begin in parallel with plan 8. It inventories consumer overlays and moves shared overrides into this repository's registry. It soft-depends on plan 9: once plan 9 generates version pins, plan 10's entries must carry only build policy (jailbreak, tests, flags, source revisions), not versions. If plan 10 lands first, plan 9 converts its version pins. The two reconcile through the registry (see Integration Points).

**Plan 16 hard-depends on plans 9 and 10.** It captures the runtime from the coherent cohort and shared policy, exports the composition API, and proves it with disposable consumer fixtures. Read-only runtime inventory can begin earlier; completion does not depend on application ports or production deployment.

**Plans 11, 12 and 13 each hard-depend on plans 9, 10 and 16.** A consumer can import the freeze, select the retained runtime and delete its shared overrides only once the channel matches the freeze, carries shared policy and exposes the tested runtime composition API. The three are independent of each other and can proceed in parallel.
- Plan 12 soft-depends on plan 11: the mori-rei-app work in plan 11 decides how an application exports its Haskell extension for others to consume, and mori's `mori-types` consumers should reuse that shape.
- The mori database cutover is already complete, and is not an additional prerequisite. Plan 12 verifies the current migration state read-only before its ordinary deploy.

**Plan 14 hard-depends on plans 11, 12 and 13.** It moves the deployed dotfiles lock to one channel revision and turns on the deploy-time closure check. Doing that before every application is on the freeze would either fail the check or force a mixed deploy.


## Integration Points

**The cohort freeze file.**
- Defined by plan 8 at `cabal/cohort.freeze` in this repository. It holds one `index-state: hackage.haskell.org <T>` line, then one `any.<pkg> ==<version>` constraint per package, under a deterministic comment header naming the compiler and regeneration command; contributor revisions and update intent belong in the inventory/report, rather than a moving HEAD or timestamp in build inputs. It carries no flag assignments: flags such as `dhall -use-http-client-tls` and the `blake3` SIMD flags stay each application's own policy. Packages that exist only as source pins (the public, non-Hackage `typeid-hs` packages) are not in it.
- Every consumer deletes its own `index-state` and takes it from the freeze. Plan 13 proved in a scratch copy that cabal-install 3.16.1.0 honours an imported `index-state`.
- Plan 9 reads it to generate Nix.
- Plans 11, 12 and 13 import it from each application's `cabal.project`, pinned to the exact revision of this repository that the application's `flake.lock` pins. For example `import: https://raw.githubusercontent.com/shinzui/haskell-nix/<rev>/cabal/cohort.freeze`; cabal-install 3.16.1.0, which all five use, fetches remote imports. Never import `master`: a remote import has no content hash, so an unpinned one can change under a build.
- Only plan 8, or a later rerun of its regeneration command, may edit the file.

**The reusable Keiro runtime set.**
- Plan 16 owns `config/runtime-package-sets.json`, `packages/runtime-lock.json`, retained projections under `cabal/runtimes/keiro-runtime/<generation>/` and `generated/runtimes/keiro-runtime/<generation>.nix`, and `lib.mkRuntimePackageSet`/`lib.runtimePackageSets`.
- `lib.mkRuntimePackageSet` takes `runtime`, exact `generation`, source `channel`, explicit `applicationSelections` and build-configuration options. It combines retained runtime groups with the complete complementary application mapping before using the existing constructor. Missing groups/conflicting runtime ownership fail; no moving default fills selections. It returns normalized selections and the standard Haskell extension/overlay shape, composed with application-owned package recipes in one scope.
- The runtime roots include Keiki, Keiro, Kiroku, Shibuya, pgmq-hs, Settei, pg-migrate and the maintained Kafka fork, each identified above by its canonical project URI. Plan 16 inventories separate adapters and transitive dependencies. Non-catalog source components receive exact retained descriptors without a hidden schema-2 topology migration.
- Runtime version/source/configuration projections derive from plan 8's solve and plan 9's generator. If runtime roots add packages absent from the original application union, plan 16 supplies those inputs to the same existing solver/generator and upgrade report. There is no second unbounded solve. Existing runtime generations constrain subsequent app-only updates and retain captured policy; explicit runtime changes append a generation.
- Plan 10's ownership audit includes runtime-owned transitive packages and sources. Plans 11–13 select the published generation, import its source/configuration project alongside the complete cohort and add application recipes using the wrapper. Their actual executable manifests record the runtime identity and verified graph. Applications build only the components they use.
- Plan 16 proves runtime builds, cache publication/substitution and disposable integration scenarios. Plan 9 retains ownership of common generation/manifest/comparison/cache mechanisms; plan 14 compares actual system manifests and measures app-only reuse while preserving the advisory fleet guard.
- The shared solver/parser and source policy definitions remain owned by plans 8–10. Plan 16 extends those contracts and CLI dispatch for runtime orchestration rather than duplicating them. Application selectors and cohort/runtime projections move atomically in consumer adoption.

**The generated Nix version layer.**
- Defined by plan 9 as a generated file in this repository, loaded by the package-set composition in `lib/mkFirstPartyPackageSet.nix`.
- Precedence: first-party snapshots in `packages/first-party-lock.json` still win for first-party packages, and must equal the freeze. The generated layer supplies every other frozen version. `overlays/registry.nix` and `patches/*` keep only build policy.
- Plan 10's entries must follow this split.

**`overlays/registry.nix` and `patches/*`.**
- Plans 9 and 10 both edit them. Plan 9 owns removing hand-written version pins (hasql, tls, crypton, `shibuya-pgmq-adapter` and the rest).
- Plan 10 owns the channel entries it adds, and its inventory of the five overlays decided what that means.
  - About three quarters of the 47 shared overrides only repeat what the channel already supplies (`openapi-hs`, `servant-openapi-hs` and `relay-pagination` are already families). Consumers just delete them.
  - The `kioku-core` profiling override is a no-op: identical `drvPath` with or without it. Consumers delete it.
  - Plan 10 adds `wai-app-static` 3.2.1, `servant-health` 0.1.0.0 and `generic-lens`/`generic-lens-core` 2.3.0.0 as version pins that plan 9 converts to policy, plus policy-only entries for `link-canonical`, `hw-kafka-client` and `servant-server`.
  - `kdl-hs` needs no entry: nixpkgs has 1.1.0, and mina's `^>=1.0` bound is lifted in plan 13.
  - `typeid-hs` is public (user decision, 2026-09-26; anonymous `git ls-remote` returns `7164a74c`). Plan 10 moves `typeid-hs-sql` and `typeid-hs-pg-migrate` into the channel at `7164a74c`, and consumers delete their overlay entries and `typeid-hs-src` flake inputs. The Cabal `source-repository-package` pin stays, because `typeid-hs` is not on Hackage.
  - `hasql-effectful` (from the still-private `tan-effectful`) is not a channel concern. Only mori uses it: 59 `mori-core` modules import `Effectful.Hasql`. Plan 12 vendors it into `mori-core` as rei already did (`rei-core/src/Rei/Infrastructure/Hasql/Effect.hs`), which removes the pin, the two `allow-newer` entries and the flake input.
  - The one remaining declared exception is mina's `mori-schema-pin` at mori `7af02c55`, because moving it changes the Dhall mina writes into other repositories.
  - Plan 10's `lib.auditConsumerOverlay` reports exactly each repository's deletion list.
- Whichever lands second rebases onto the other.

**The parity guards.**
- Plan 9 defines the channel-side check: a `nix flake check` that asserts every frozen package's `.version`.
- Plans 11 to 13 add a per-application check that compares `dist-newstyle/cache/plan.json` against the freeze.
- Plan 14 checks the structured manifest for each actual built executable against its own pinned freeze, and compares shared dependency identities. Runtime output closures can omit statically linked Haskell libraries and cannot establish Haskell version parity.
- Consumer apps alias their pinned channel's comparison app for lock resolution. Plan 9 owns `scripts/cohort-compare.sh`, exposed as the flake app `cohort-compare`. Its acceptance interface is `--freeze <file-or-url> (--plan-json <file> | --nix-manifest <file>) [--all]`, with `--compare-manifests <file> <file>` for identity comparison and `--resolve-channel-lock <file> --input-path <slash-separated-path>` for lock resolution. Comparison exits 0 on success, 1 on a mismatch/unfrozen/missing expected package or unverifiable evidence, and 2 on invalid usage. Legacy `--closure` and `--closure-list` modes may remain diagnostic only.
- The lock resolver starts at the lock's declared root, resolves string node references and recursive array `follows` paths, detects cycles/missing nodes, and returns the full locked channel revision. Consumers use it to verify that the Cabal import names exactly their own pinned channel; dotfiles additionally resolves the effective channel. No consumer duplicates this algorithm.
- Each consumer exports `packages.<system>.cohort-manifest`: a JSON artifact with schema version, system, compiler/toolchain/channel identities, actual executable root drv/output, and Haskell package records (name, version, package/component role, drv/output paths, source identity, Cabal metadata revision, flags and relevant build policy). Plan 9 owns the schema, construction helper and comparison fixtures. Construct it from the executable's actual composed Haskell scope and verify dependency edges against the root derivation graph using Nix metadata APIs; an unrelated channel lookup is insufficient. Do not infer packages by store basenames or traverse store files. Reject wrong versions even when another instance of the same name is correct; distinguish compiler packages and native build tools by role.
- Record non-Hackage source pins in `cabal/cohort-sources.json`, including exact revision, package subdirectory and any intentional Cabal/Nix source or flag difference with its reason and owner. Own local packages are declared separately. These declarations replace ad hoc `--ignore` acceptance shortcuts; exceptions do not silently exempt source identity from checking.
- Refresh Cabal plans with tests and benchmarks enabled for the supported configurations before comparison; report applicable flag differences. The freeze aligns versions, while manifests and exact-binary rehearsals establish the stronger build and release claims.

**Rei's exported Haskell extension.** Plan 11 defines how Rei's flake exports an extension that adds `rei-core`, so mori-rei-app composes it instead of calling `callCabal2nix` on `rei-src`. Plan 12 reuses the same shape if mori exports `mori-types`.

**The dotfiles channel input.** Plan 14 adds a root `haskell-nix` input to `mori://shinzui/dotfiles.nix` that the family applications follow by default, the way they already follow `haskell-nix-dev`. A single application can still be deployed off-channel for a hotfix.
- The guard is advisory about fleet-wide uniformity (user decision, 2026-09-26: the strict guard was too restrictive). Differing channel revisions across applications, and differing shared-library `drvPath`s, only warn.
- It fails when an application's proven build manifest differs from its own pinned freeze, or the evidence is missing/unverifiable. Fleet-wide revision and identity differences remain warnings; the alignment acceptance experiment requires equality where shared build inputs are intended to match.
- `haskell-nix-dev` stays as today (not pinned by revision in dotfiles).

- Plan 14 also replaces `_update-with-base`, which moves `haskell-nix-dev` on every application update, with recipes that move one application at a time.

**Routine changes and measured time savings.**

The goal is less repeated coordination and dependency compilation. Equal versions are a necessary baseline, not the completion test. Follow [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md) and the existing [cache research](../research/ci-cache-reuse-and-buck2-after-mp3.md).

- An application-only update changes that application's source pin. It retains the cohort, nixpkgs, compiler and toolchain locks. Shared dependencies with unchanged transitive inputs must retain their drv/output identities; unaffected application wrappers must also remain unchanged. Source filters include required licenses, generated inputs, vendor files and data, while excluding unrelated documentation and sibling source trees. Application revision stamps belong only in outputs that need them.
- A dependency update starts from the previous freeze and explicitly requested packages. Plan 8 adds `just cohort-update +PACKAGES`: solve with unrelated versions held fixed, report any necessary transitive unlocks before widening, and emit a deterministic impact report listing version/source/policy changes, reverse dependency paths and affected application components, including tests/benchmarks. The selected first-party snapshots, source manifest, freeze, generated layer and consumer selectors are updated coherently. A solver failure reports the conflict rather than silently refreshing everything. Deliberate broad cohort refresh remains a separate operation.
- A compiler/nixpkgs/toolchain update is explicit and carries a wider rebuild estimate. Neither application nor dependency update recipes advance it implicitly. Existing off-channel hotfixes remain available.
- Plan 9 builds and publishes the shared dependency outputs to the existing trusted binary cache, and checks its configured CI access before consumer rollout. Local successful builds are insufficient cache evidence.
- Plan 8 preserves the recorded pre-adoption inputs for the baseline experiments; plan 14 records before/after measurements on aarch64-darwin and x86_64-linux with a declared default package set, channel and compiler. Measure a repeated build, a documentation-only edit, an application leaf edit, a shared-library interface edit, a targeted dependency update and a deliberate base update. Separate evaluation, downloads, dependency compilation, application compilation/linking, and tests. Run a fresh CI worker without local dependency outputs and prove it substitutes the published shared outputs; record paths compiled unexpectedly. Use disposable checkouts and native/remote builders, without production activation.
- Acceptance requires unchanged shared dependency identities and zero avoidable shared dependency compilations for application-only edits, reuse across applications with equal inputs, and a targeted update report that explains all changed identities. Record elapsed times and residual bottlenecks; do not invent an unmeasured speedup or mark this initiative complete on version checks alone. Nix still recompiles a changed Haskell package; Cabal module-level incremental builds remain a separate development workflow.

**Shared implementation ownership.** Plan 8 owns the cohort model, freeze parser, inventory, update/report commands and aggregate `just cohort-check`. Plan 9 extends those modules for generation and owns `just cohort-generated-check`, manifests, lock resolution, parity and identity comparison. Plan 10 owns registry policy and overlay auditing. Plan 16 owns runtime membership, retained records and composition, reusing those tools; plans 11–13 select its exact generation, call the shared tools and export manifests; plan 14 orchestrates them without another parser. Plan 10's pre-adoption application builds are diagnostic: source incompatibilities belong to plans 11–13 and must not create a dependency cycle back into phase 1. All supported consumer builds pass before deployment.

**Cross-plan decisions that deserve ADRs**, to be written by the plan that makes each final:
- The upgrade-only rule and its report: plan 8, as `docs/adr/2-resolve-the-rei-family-cohort-upgrade-only.md`.
- The freeze file is the single source of truth for versions, and the channel is generated from it: plan 9, as `docs/adr/3-generate-the-channels-package-versions-from-the-cohort-freeze.md`.
- Consumer overlays may define only their own packages: plan 10, as `docs/adr/4-consumer-overlays-define-only-their-own-packages.md`. This extends `mori://shinzui/mori/okf/adrs/concepts/ADR-24`.
- Numbers 2–4 remain reserved for those child decisions. ADR 5 records routine update isolation/cache evidence; plan 14 reserves ADR 6 for its deploy guard. ADR 7 records retained runtime composition, with plan 16 responsible for implementation evidence.
- An application that depends on another application's library consumes that application's flake output (plan 11).


## Progress

- [x] (2026-10-07) EP-17: concurrent cross-session cleanup probe passes; Keiei/Meibo adopt narrow test-only backports while retaining production runtime unit identities; migration fixtures and upstream helper assertions pass.
- [ ] EP-17: finish Kizashi/codd-extras and remaining PGMQ/adapter/Kawa database suites, scoped Nix verification and final audit.

- [x] (2026-10-05) EP-15 Shikumi milestone: reuse Shikumi/tools 0.4.1.0; publish nine remaining patch releases with docs/tags/GitHub releases after both effectful-line tests and release gates pass
- [x] (2026-10-05) EP-15 Keiro compatibility preparation: bound widening committed locally; full builds with tests enabled pass on effectful 2.6 and 2.7

- [ ] EP-16: Publish an immutable Keiro runtime generation, exact Cabal/Nix/source projections and guarded application composition API
- [ ] EP-16: Prove two composed applications share runtime builds, explicit runtime upgrades preserve unrelated selections, and fresh workers substitute cached outputs

- [x] (2026-10-05) EP-8: Targeted dependency updates preserve unrelated pins and report affected applications/components; the real conflict fixture leaves all 76 inputs unchanged.
- [ ] EP-9: Structured manifests and recursive lock resolution reject false parity, including static-link and duplicate-version fixtures
- [ ] EP-9: Shared dependency outputs are published and available to configured CI workers
- [ ] EP-14: Recorded update-isolation and cache-reuse measurements meet the time-saving acceptance contract

- [x] (2026-10-05) EP-15: Release keiro, kioku-core and the shikumi family admitting effectful 2.7 (`effectful` 2.7.1.0+, `effectful-core` 2.7.1.1+), and refresh the channel
- [x] (2026-10-06) EP-8: all six fresh contributor solves and pinned Nix observations pass; cohort acceptance is complete.
- [x] (2026-10-05) EP-8: committed the 450-package upgrade-only freeze, complete source manifest and zero-downgrade report at `4e3a626`
- [x] (2026-10-06) EP-8: report identifies 37 consumer caps with files and component roles (30 in the earlier checkpoint).
- [x] (2026-10-06) EP-9: both source-channel paths parse Cabal 3.14/3.16; format guard passes in the full native gate.
- [ ] EP-9: Generate the Nix version layer from the freeze and retire hand-written version pins (including `shibuya-pgmq-adapter` 0.16.0.0)
- [ ] EP-9: Add the channel version-parity check and pass it in `nix flake check`
- [x] (2026-10-06) EP-10: inventory and move shared overrides into the channel; guarded recipes and consumer deletion handoff accepted at `074ea35`.
- [ ] EP-11: rei and mori-rei-app import the freeze, drop shared overrides, and mori-rei-app consumes Rei's `rei-core`
- [ ] EP-11: Deploy rei and mori-rei-app on the shared set
- [ ] EP-12: mori imports the freeze and drops shared overrides
- [ ] EP-12: Deploy mori on the shared set (an ordinary binary swap: the mori database received Kiroku `0012` on 2026-09-26)
- [ ] EP-13: mina moves to the current baikai and shikumi cohort and imports the freeze
- [ ] EP-13: reiko imports the freeze
- [ ] EP-14: dotfiles follows one channel revision, and the update recipes move one application at a time
- [ ] EP-14: The deploy-time closure parity check passes for all five applications


## Surprises & Discoveries

- Observation (2026-10-07, EP-17): Keiei/Meibo's legacy runtime can remain fixed while local test-only helpers admit ephemeral-pg 0.3.1 and stable UID roots. Fresh baseline/candidate solves retain all unrelated versions and production Keiro/Kiroku/PG-migrate unit identities. Mori's actual helper passes orphan reclamation plus concurrent live SQL connectivity across three TMPDIR sessions. Kizashi additionally exposes an unregistered codd-extras cleanup consumer. Its source and standalone Nix recipe join the audit; no original five-application cohort membership is added.

- Observation (2026-10-06, release cohort checkpoint): the published runtime cleanup patches and OKF 0.10 now enter the shared Cabal cohort at signed index `2026-10-06T21:15:24Z`. Replay and a second regeneration pass with identical artifacts: 450 selections, zero downgrades, 37 consumer caps and 19 source pins. All 445 previously frozen names remain; eight first-party versions and the HTTP/2 5.4.8 patch advance. Inventory channel/contributor revisions are preserved. EP-10's narrow Kioku 0.8.0.2/GHC 9.14.1 compiler workaround passes both native source-channel targets and 78 policy guards; the full matrix remains a required gate. EP-9 preparation can proceed read-only while that gate runs.

- Observation (2026-10-06, EP-17): the user requires all ephemeral-pg consumers to move to 0.3.1 and stable-root cleanup. Configless wrappers still miss abandoned clusters even where Cabal already selects 0.3.1. Source audits find extra dependents absent from registry declarations; runtime helpers in Keiro/Kiroku/pg-migrate already comply. Main consumer/source migrations are underway, with patch releases for remaining Kioku/Relay/Shikumi gaps. Shomei needs the admitting pg-migrate 1.2 family. Host load above 430 prompted bounded, sequential owned build jobs; no global daemon setting changed. Full migration acceptance is pending recorded tests and selection refreshes.
- Observation (2026-10-06, later checkpoint): all three cleanup runtime releases are published and live-verified (ten source packages, nine documentation archives, 1,305 tests). Four additional consumer migrations pass 1,363 tests and are committed; the root consumer batch completes its targeted gates after Kafka-shell/test-enable retries. Koyomi's legacy migration composition and final shared release-input refresh remain pending. EP-10's Dhall GHC 9.14 repair passes native/Linux targets and 70 guards, but the full gate exposed an OKF/Baikai API mismatch. The user fixed and released OKF CLI/core 0.10.0.0; validated immutable channel generation 5 now selects those Hackage releases and the current GitHub scaffolding HEAD. New-source targeted compilation and the full retry remain pending, so neither child is marked complete.
- Observation (2026-10-06): Shibuya Core/Metrics 0.10.0.1 is published and verified in `mori://shinzui/shibuya`; its scoped channel refresh and live check pass. EP-8's refreshed stock inventory and Random policy now yield 450 selections, zero downgrades and Random 1.3.1. Exact released-source proofs justify three scoped non-Effectful exceptions; explicit roots retain three historical libraries. Freeze/source replay and byte-identical second regeneration pass. EP-10's scoped GHC 9.14 repairs pass native/Linux targets and 58 policy tests; its full check clears bootstrap and reaches a separate lens-family-core containers bound. Whole-child completion remains pending the full gate and final handoff.

- Observation (2026-10-05): the user upgraded Determinate to 3.23.0; the running Nix daemon reports 2.35.2. A freshly executed bootstrap reproducer now inherits finite NOFILE 1048576 and GNU patch 2.7.6 succeeds without the prior workaround. EP-10 resumes the full native flake gate. EP-8's explicit Random upgrade remains pending Shibuya publication and coherent regeneration; the daemon repair alone does not complete either child.

- Observation (2026-10-05 checkpoint): EP-8 now commits the published shared freeze at `4e3a626`: 450 selections, zero downgrades, Effectful 2.7.1.0/core 2.7.1.2, Keiki/JSON codec 0.9.1.0, complete Hackage source/metadata identities and retained public Cmark fix. Freeze-only replay, targeted unrelated-identity isolation, a negative downgrade check, five-exception pruning and byte-identical regeneration pass. EP-8 remains In Progress pending the targeted-conflict/fresh-inventory gates and the full Nix check. EP-10's policies pass native/Linux builds, 51 unit tests and the 58-test GHC 9.14 admitting-release target; broad Nix validation is blocked by a reproduced Darwin bootstrap GNU patch 2.7.6/unlimited-NOFILE daemon issue, not an unresolved Haskell dependency conflict. EP-12 M1 is independently verified and committed in its owning repository; adoption remains gated. No deployed application changes are claimed.

- Observation (EP-8, 2026-10-05): inventory now records current revisions and all local packages, including Rei's API contract/client and generated Rei/Mori conformance packages. All six scratch solves with tests/benchmarks enabled and pinned Nix metadata observations pass. Current Mina already admits the new Shikumi releases, superseding the September cap assumption. The recorded channel includes Keiki and its required JSON codec at 0.9.1.0. EP-8 is In Progress; freeze, source manifest, targeted-update/impact reporting and final acceptance remain pending.

- Observation (EP-15, 2026-10-05): current Hackage and upstream tags already provide Shikumi/Shikumi-tools 0.4.1.0 with effectful 2.7 bounds. Shikumi-cache/trace still cap below 2.7, as do Keiro 0.19 and Kioku 0.8. EP-15 is In Progress; release preparation starts with the nine remaining changed Shikumi packages, reusing the two compatible published versions. Shikumi publication is now complete at commit `c22efb9` in `mori://shinzui/shikumi`, with all nine sources/docs and GitHub releases verified. Keiro bound-widening commit `d790efb5` in `mori://shinzui/keiro` passed full builds with tests enabled on both effectful lines; the user approved Keiro 0.19.0.1; release commit `9b215c11` contains a provenance-only corpus regeneration, passed all clean-tree gates and both effectful-line test runs, and is pushed with seven annotated tags; all seven Hackage sources/docs and the non-draft GitHub release are verified live. Kioku compatibility builds and all four suites (467 tests per line) pass at local commit `4e16709` in `mori://shinzui/kioku`; its five-package 0.8.0.1 release is complete at `7c2f983`, with all sources/expected docs and its non-draft GitHub release verified. The channel refresh is committed locally at `d4ca4eb`, with flake validation, version checks, all online checks and immutable historical-snapshot checks passing. The full Hackage union solves effectful 2.7.1.0/core 2.7.1.2 without effectful overrides; the focused old Keiro control fails on its direct core cap. EP-15 is Complete and EP-8 is unblocked. Optional application diagnostics are deferred: Rei and mori-rei-app/mori-app to EP-11, Mori to EP-12, Mina and Reiko to EP-13. Reiko's current manifests declare no effectful dependency; no application compilation is claimed here.

- Observation (runtime planning, 2026-10-04): the existing constructor requires complete catalog selections, and several Kafka/adapter sources are not catalog families. Plan 16 adds a guarded runtime wrapper and exact non-catalog component records, preserving the schema-2 topology and historical selections.

- Observation (review, 2026-10-04): matching versions does not establish build identity or binary-cache availability. Runtime closures can omit static Haskell dependencies; the original guard could pass incomplete evidence. The local cache research records these limits. This revision assigns manifest/cache proof to plans 9 and 14.
- Observation (review, 2026-10-04): source inventories have moved since September. Rei has two additional local API packages, and consumers still have differing toolchain locks. Refresh recorded inputs before solving, rather than treating historical package counts as current.

- Observation (corrected 2026-09-26): The pinned nixpkgs' path the channel actually uses accepts `cabal-version` up to 3.16.
  - Evidence: `haskell.packages.ghc9124.callCabal2nix` on a dependency-free package evaluates for 3.12, 3.14 and 3.16. Only 3.18 fails, with "Unsupported cabal format version".
  - The first finding ("rejects 3.14") came from running the standalone top-level `cabal2nix` 2.21.3 binary, which is built with GHC 9.10.3 and which the channel never calls. Plan 9's drafter caught the error.
  - So the cabal-version lowering helpers in consumer overlays are unnecessary, and no `cabal2nix` rebuild is needed. Plan 9 adds a check that fails if 3.14 or 3.16 stops parsing.
  - Every cohort package today declares 3.12 or lower anyway: `shibuya-core` 0.10.0.0 and `shibuya-pgmq-adapter` 0.16.1.0 at 3.12; pg-migrate 3.8; pgmq, baikai, shikumi 3.4; keiro, kiroku, kioku 3.0.
  - Date: 2026-09-26
- Observation: `callHackageDirect` fetches with `fetchzip`, so its `sha256` is the hash of the unpacked source, not the tarball hash. For `shibuya-pgmq-adapter` 0.16.1.0 the correct value is `sha256-8yXtZ/qufiD4QdO1BtrxTIJWYfT8WbxkIMDA9a2svfI=`; `sha256-79Ad1+…` is the flat tarball hash.
  - A generator that emits `callHackageDirect` must compute `nix-prefetch-url --unpack` hashes. Alternatively, pin `all-cabal-hashes` and use `callHackage`, which needs no per-package hash.
  - Date: 2026-09-26
- Observation: Moving nixpkgs is not a shortcut. On 2026-09-26, nixpkgs-unstable (`74435dcd`) and nixos-unstable (`e94cb152`) ship the same hasql 1.9.3.1, tls 2.1.8, warp 3.4.9 and sbv 11.7 in `ghc9124` as the pin.
  - Only the force-pushed `haskell-updates` branch is close to Cabal, and even it differs (tls 2.4.3, warp 3.4.15, sbv 14.7).
  - Date: 2026-09-26
- Observation (plan 10's inventory): of 47 shared overrides across the five consumer overlays, about three quarters duplicate what the channel already supplies. They outlived their reason because a consumer overlay silently wins over the channel.
  - Rei's `openapi-hs`, `servant-openapi-hs` and `relay-pagination` pins date from channel `2e1ee913`, which predated those families.
  - rei's `openapi-hs` 5.0.0 and mori's `06fc1171` source pin are the same release.
  - Date: 2026-09-26
- Observation (plan 14's drafting): the deployed system already builds shared libraries twice. `rei-core` exists as `bbd8x2vj…` and `qd9xjsyi…`, and `kioku-core` and `baikai` differ between rei and mori-rei-app.
  - The dotfiles lock that deployed rei `880093cc` and mori-rei-app `2acd4ed4` was uncommitted. It was committed on 2026-09-26 as dotfiles `14e829b`, local and not pushed.
  - Date: 2026-09-26
- Observation (plan 8's drafting): `baikai-effectful` 0.4.0.2, which the Nix side ships, requires `effectful-core` 2.7. `keiro`, `keiro-ops`, `keiro-pgmq` 0.19 and `kioku-core` 0.8 all cap `effectful` below 2.7.
  - Nix builds it only because first-party packages are jailbroken.
  - Upgrade-only therefore needs either an `allow-newer` proven by compiling those four packages against `effectful` 2.7, or new keiro and kioku releases.
  - Date: 2026-09-26
- Observation: cabal-install 3.16.1.0 applies both a local-path and an HTTPS `import:` in `cabal.project`. Tested in a scratch project, where a local import of `constraints: aeson ==2.2.4.1` pinned aeson.
  - Date: 2026-09-26


## Decision Log

- Decision (2026-10-06, parallel execution): begin only EP-9's already specified independent format guard and fixture-based parser/generator work while EP-8/EP-10 aggregate acceptance continues. Preserve every full-matrix, cache, manifest, runtime and deployment gate. The verified freeze/source artifacts are available at `237d83c`; separate compiler failures in the current pre-projection package set do not prevent additive tools from being implemented. Registry status tracks this limited preparation, matching EP-12's independent milestone convention.

- Decision (user, 2026-10-05): upgrade the shared cohort and all consumers to random >1.3. EP-8 records a 1.3.1 floor and stages the refreshed stock inventory; a compatible Shibuya core/metrics patch release is required before accepting the new solve. EP-12 removes the obsolete Mori project cap during adoption. The prior committed freeze is a validated earlier checkpoint, not acceptance of this new policy.

- Decision (user request, 2026-10-05): run independent work concurrently. Keep EP-8's solver/model ownership with the primary agent, assign shared-policy/audit work to EP-10 and only independent Hasql vendoring to EP-12, and perform read-only EP-16 inventory before its prerequisites complete. The required relay compatibility release uses a separate worker and its repository release gates. Consumer adoption and runtime delivery retain their existing hard dependencies.

- Decision (user authorization, 2026-10-05): the user confirmed release authorization for all Keiro runtime projects. Keep repository-specific release skills and mandatory gates; do not repeat release approval requests already covered by this authorization.

- Decision (user request, 2026-10-04): add plan 16 to deliver the reusable Keiro runtime package set and application composition. Consumer plans 11–13 now depend on it. Preserve family independence, catalog topology and one Haskell scope; use retained runtime records for non-catalog components. ADR 7 records the durable contract.
  Rationale: the proposal must have owned deliverables and acceptance gates, so MP-3 cannot finish without the runtime foundation and actual consumer adoption.
  Date: 2026-10-04

- Decision (discussion, 2026-10-04): Keiki is a required member of the proposed Keiro runtime baseline and must be visible in the dependency inventory and resolved cohort.
  Rationale: the user confirmed Keiki is essential, and Keiro's source declares dependencies on Keiki and its JSON codec. Runtime membership must cover these dependencies as well as the initially listed families.
  Date: 2026-10-04

- Decision (review update, 2026-10-04): establish routine update isolation, structured build evidence, and measured cache reuse as completion criteria, while keeping the advisory fleet guard and per-application hotfix policy. ADR 5 records the durable decision. Plans 8 and 9 own shared update and comparison interfaces; consumer plans reuse them. Historical runtime-closure parity and documentation-only rebuild assumptions below are superseded.
  Rationale: alignment must remove unnecessary work during subsequent changes, not just make one initial version table agree.
  Date: 2026-10-04

- Decision: Host the initiative in `mori://shinzui/haskell-nix` rather than in any application.
  Rationale: The shared package set is this repository's product, and MasterPlans 1 and 2 already govern it here. Each consumer's work is described in a child plan here and carried out in that consumer's repository.
  Date: 2026-09-26
- Decision: Cabal's solved plan is the single source of truth for versions, recorded as one freeze file, and the Nix set is generated from it.
  Rationale: Cabal is already the solver, and ADR 1 forbids a solver in this repository. Generating Cabal constraints from Nix would downgrade Cabal. Generating Nix from Cabal satisfies upgrade-only with one generator and one evaluation check.
  Date: 2026-09-26
- Decision: Upgrade-only. For every package the target version is at least the highest version any of the five applications selects today under Cabal or Nix. Packages where Nix is ahead (brick, vty, baikai-effectful) move Cabal up, by lifting the application bound that caps them.
  Rationale: The user asked to upgrade the older side and never downgrade.
  Date: 2026-09-26
- Decision: Keep nixpkgs `d5dfd8e6`. Do not rebuild `cabal2nix` (this revises the first version of this decision).
  Rationale: Newer nixpkgs does not close the version gap. The channel's `callCabal2nix` path already parses `cabal-version` up to 3.16 (see Surprises & Discoveries), and building `cabal2nix` with GHC 9.12 would compile about 75 uncached packages for no benefit. Plan 9 keeps a GHC 9.12 `cabal2nix` build as a documented fallback for when 3.18 appears.
  Date: 2026-09-26
- Decision: Do not ship a one-off `shibuya-pgmq-adapter` 0.16.1.0 patch ahead of plan 9. Rei runs 0.16.0.0 until plan 11 deploys; mori keeps its local override, marked for retirement by plan 10.
  Rationale: The user chose the full alignment over the targeted fix. Rei's deployed worker starts and delivers on 0.16.0.0; the gap is a missing exactly-once dead-letter fix, not an outage.
  Date: 2026-09-26


- Decision (user, 2026-09-26): Move the whole family to effectful 2.7, with no `allow-newer` bridge. Add plan 15 to release the capping libraries, and make plan 8 hard-depend on it.
  Rationale: The user wants to migrate to effectful 2.7 everywhere. `baikai-effectful` 0.4.0.2 already requires it, and an `allow-newer` bridge would leave four first-party packages declaring bounds they do not honour.
  Date: 2026-09-26
- Decision (user, 2026-09-26): mina uses streamly from Hackage, and drops its `streamly-project` git pin (streamly 0.12.0 / streamly-core 0.4.0).
  Rationale: A git-only version cannot be frozen against Hackage, and mina's shipped Nix build already uses the Hackage line.
  Date: 2026-09-26
- Decision (user, 2026-09-26): `typeid-hs` is public, so it moves into the channel (plan 10). `hasql-effectful` is vendored into mori (plan 12), because only mori still uses it and its source repository is private.
  Rationale: This removes both private-source exceptions. The user believed `hasql-effectful` had been removed everywhere; that is true of rei, mori-rei-app and mori-app, but not mori.
  Date: 2026-09-26
- Decision (user, 2026-09-26): The dotfiles deploy guard only warns on fleet-wide revision and derivation differences. It fails only when an application's closure differs from its own pinned freeze. `haskell-nix-dev` is not pinned by revision in dotfiles.
  Rationale: The user judged the strict guard too restrictive: a hotfix to one application must not require moving all five.
  Date: 2026-09-26
- Decision: Reconcile the child plans' shared contracts after parallel drafting (2026-09-26).
  - The freeze carries an `index-state:` line and version constraints only, no flags. Consumers drop their own `index-state`. This revises plan 8's first draft, which dropped the line.
  - The parity tool is plan 9's `cohort-compare` flake app with the interface given in Integration Points. It replaces the `cohort-parity`, `$PARITY` and `<parity-app>` names the drafts used.
  - ADR numbers: 2 for plan 8, 3 for plan 9, 4 for plan 10.
  - Plan 10's declared overlay exceptions are the private `typeid-hs` and `hasql-effectful` sources, and mina's `mori-schema-pin`.
  Rationale: The seven child plans were drafted in parallel and each left placeholders for artifacts another plan defines. One authoritative contract in this MasterPlan, copied into each child, keeps every child self-contained and mutually consistent.
  Date: 2026-09-26


## Outcomes & Retrospective

Resumed checkpoint (2026-10-07): EP-17 remains In Progress. The live-retention acceptance and Keiei/Meibo legacy cleanup backports pass; PGMQ passes 100 tests, and the channel Linux ephemeral-pg target returns exit 0. Kizashi/codd-extras and remaining database suites are running. The shared cohort and accepted runtime channel remain unchanged. EP-9 follows EP-17 in registry order; no generated-layer/runtime/deployment completion is claimed.

Stopping checkpoint (2026-10-06, user request): EP-8 and EP-10 are Complete; EP-9 is In Progress and its hard prerequisite is satisfied. The full native Nix gate passed with exit 0 on immutable snapshot `3b2a593b77e700219283af92236f336e47255a63`; receipt `/tmp/mp3-ep10-native-full-check-3b2a593-20261006.log`. Formatting, shared overrides, Nix unit checks and package-set-default pass. All four compiler/source-channel cells report zero mismatches: GitHub 78 packages and Hackage 68 packages per compiler (GHC 9.12.4 and 9.14.1). Full Linux validation, generated-layer parity, consumer adoption and cache publication are separate later gates. Committed parser preparation is at `9a7283e`. The Haskell generator modules, tests and registrations pass all 107 helper tests and are included in the committed stopping checkpoint. Resume with the live generator and Nix layer. EP-17 legacy consumers remain unfinished. Pause further implementation for the day; no new authorization is needed to resume the previously approved scope.

Implementation checkpoint (2026-10-05): EP-15 is Complete. Shikumi's nine patches, Keiro's seven 0.19.0.1 packages and Kioku's five 0.8.0.1 packages are published with live sources/docs and non-draft GitHub releases; all repository release gates and both effectful-line checks passed. The scoped channel refresh is committed locally at `d4ca4eb`; historical snapshots and unrelated selections remain intact. The Hackage acceptance union solves on effectful 2.7.1.0/core 2.7.1.2 without effectful bound overrides, and a focused comparison rejects old Keiro on its direct core bound. Application diagnostics are deferred per the review to EP-11–13, with per-application status in EP-15. EP-8 is now implementable and the user requested continuing with it. All later children remain unfinished. No cohort/cache/deployment completion or measured speedup is claimed. ADR distillation found no new durable architecture decision; existing ADRs still govern.

Review outcome (2026-10-04): the initial review retained eight children in four phases. The subsequent runtime plan adds a ninth child in phase 1 and makes it a prerequisite of consumer adoption. The update adds observable contracts for direct/transitive dependency alignment, routine update isolation and remote cache reuse, and removes a potential phase-1/consumer build cycle. No software or deployment work was performed in this review; all implementation milestones and timing claims remain pending.


## Revision Notes

- 2026-10-04 (discussion): Recorded the user's confirmation that Keiki is essential to the proposed Keiro runtime set; made its inclusion explicit in scope and plan 8's inventory/acceptance. Runtime-set implementation remains a proposal.

- 2026-09-26: Reconciled after the seven child plans were drafted in parallel.
  - Corrected the `cabal-version` finding. The channel path parses up to 3.16; the "rejects 3.14" result came from the standalone binary. The `cabal2nix` rebuild was dropped.
  - Fixed the freeze format (`index-state:` line, no flags) and the `cohort-compare` tool contract.
  - Allocated ADR numbers 2 to 4.
  - Rewrote plan 10's scope to match its inventory (most overrides are duplicates to delete; private sources and mina's `mori-schema-pin` are declared exceptions).
  - Recorded the drafting discoveries: duplicated shared libraries in the deployed system, the `baikai-effectful` effectful cap, and the uncommitted dotfiles lock.
- 2026-09-26: Corrected the effectful floor: `effectful` 2.7.1.0 (it has no 2.7.1.1) and `effectful-core` 2.7.1.1. Plan 15's research found this.
- 2026-09-26: Applied the user's four decisions.
  - Added plan 15 (effectful 2.7 releases) as the first plan, with plan 8 hard-depending on it.
  - mina moves to Hackage streamly.
  - `typeid-hs` moves into the channel; mori vendors `hasql-effectful`.
  - The dotfiles guard now fails only on an application's own freeze mismatch and warns on fleet-wide differences.
  - Plans 8, 10, 11, 12, 13 and 14 were revised to match.
- 2026-09-26: The mori session completed mori's Kiroku `0012` cutover. Verified read-only: ledger at `0012`, the index present, and `mori-automate` and mina-web's PATH `mori` both on `mori-cli` `35dr5zq5…` (kiroku-store 0.9.0.1). Plan 12's deploy is therefore Case A, a binary swap, and plan 13 no longer has to worry about a Kiroku 0.8 `mori` on mina-web's PATH.

- 2026-10-04: Reviewed against reducing coordination and rebuild time. Added targeted updates, impact reporting, structured static-link-safe manifests, recursive lock resolution, cache publication and fresh-runner measurements; clarified direct/transitive and first-party alignment. Cascaded contracts to plans 8–15, corrected stale package/floor/database assumptions, and recorded ADR 5. Implementation remains Not Started.

- 2026-10-04 (runtime plan): Created EP-16 with four milestones for retained runtime records/projections, composition and verification. Added it to phase 1 and to consumer hard dependencies; clarified shared ownership and completion criteria across affected children, and recorded ADR 7. No runtime software or deployment is claimed complete.
