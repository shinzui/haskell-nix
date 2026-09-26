---
id: 12
slug: adopt-the-shared-package-set-in-mori
title: "Adopt the shared package set in mori"
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

# Adopt the shared package set in mori

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Mori (`mori://shinzui/mori`) is the project registry that every other application in the Rei family reads, and its automation daemon runs on this machine around the clock. Today mori is built two different ways that disagree. `cabal build` solves its dependencies from Hackage, while `nix build` (which produces the binary that actually ships) takes them from this repository's channel plus about thirty hand-written overrides in mori's own `nix/haskell-overlay.nix`. Nothing compares the two, so mori's tests do not run against the same package versions as the deployed daemon. Mori's own flake even builds on a different nixpkgs (`4df1b885`) from the one the deployed build uses (`d5dfd8e6`).

After this plan:

- mori's `cabal.project` imports the shared cohort freeze, `cabal/cohort.freeze` in this repository (`mori://shinzui/haskell-nix`), pinned to the same commit as mori's `flake.lock`.
- mori's Nix build takes every shared package from this repository's channel. Its overlay defines only mori's own packages plus one documented mori-only source pin.
- mori's flake pins the same `haskell-nix-dev` (`206ecd25`, nixpkgs `d5dfd8e6`) as rei and mina.
- A single `just cohort-check` command in mori proves that the Cabal plan and the built Nix closure contain the frozen versions.

The deployed daemon, the `mori` CLI on `PATH`, and the `mori` that `mina web` and the Rei watchdog run are then one binary. It is built from those versions and runs against a mori database on Kiroku migration `0012`.

**How to see it working.**
- `just cohort-check` in the mori checkout prints no differences.
- `nix-store -qR` of the new dotfiles system closure contains exactly one `mori-cli-6.0.0.0` store path, the one mori's own `nix build` produces.
- After the user activates dotfiles, the `mori automate daemon` process's executable (seen with `lsof`) is that path.
- The first scheduled ingest appends events whose `$all` rows carry a non-null `category`.

**The database risk.** The deploy is the part that can hurt real data. Mori's global database (`host=/Users/shinzui/.local/state/postgresql dbname=mori`, about 526,800 events) was still at Kiroku migration `0011` when this plan was written.
- Kiroku 0.9, which mori adopted at mori commit `f3c5fa4b`, needs migration `0012` before any 0.9 process appends.
- After `0012`, any Kiroku 0.8 process fails every append.
- So unless another session has already done it, this plan's deploy *is* the stop-writers cutover of that database.

Milestone 5 establishes which case holds before anything is touched.


## Progress

- [ ] M0: Confirm preconditions: plans 9 and 10 complete at a haskell-nix revision `R`, mori working tree clean, and plan 11's extension convention read (or its absence recorded).
- [ ] M0: Capture the baseline: mori's current Cabal plan versions, the current overlay entry list, and the current deployed mori store path.
- [ ] M1: Add the `import:` of `cabal/cohort.freeze` at `R` to mori's `cabal.project` and reconcile `index-state`.
- [ ] M1: Remove version-only `constraints:` the freeze subsumes (`crypton >= 1.1`, `http-client-tls >= 0.4`, `random < 1.3`) and keep the flag stanzas.
- [ ] M1: Remove the `openapi-hs`, `servant-openapi-hs`, `servant-health` `source-repository-package` pins (Hackage releases now cover them).
- [ ] M1: Re-justify or delete each `allow-newer` entry per ADR-16 (`haxl:time` expected dead; `proto-lens*` tested by removal; `hasql-effectful:*` checked against a newer tan-effectful revision).
- [ ] M1: Lift every mori bound that plan 8's upgrade report names; fix compile breaks.
- [ ] M1: `cabal build all`, `cabal test all`, `just check-openapi` green; commit.
- [ ] M2: Pin `haskell-nix` to `R` and `haskell-nix-dev` to `206ecd25`, follow its `flake-parts`/`treefmt-nix`/`pre-commit-hooks`, drop the flake-parts workaround and the three OpenAPI source inputs; relock.
- [ ] M2: Delete every shared override from `nix/haskell-overlay.nix` per plan 10's deletion list, including the `shibuya-pgmq-adapter` 0.16.1.0 override after proving the channel supplies 0.16.1.0.
- [ ] M2: Drop `doJailbreak` from mori's own five packages so `configure` enforces mori's bounds again.
- [ ] M2: Expose `legacyPackages.<system>.haskellPackages`; `nix build .#mori` and `nix flake check` green; commit.
- [ ] M3: Export `mori-types` and `mori-schema-pin` as a flake Haskell extension (plan 11's shape, or the default shape defined here); prove it composes on a bare channel set; commit.
- [ ] M4: Add `just cohort-check` (freeze rev equals lock rev; Cabal plan and Nix closure equal the freeze); run it clean; amend mori ADR-24; `just check-adr`; commit.
- [ ] M5: Establish the cutover state read-only: mori DB Kiroku ledger row, deployed mori revision, mori history. Record Case A, B or C.
- [ ] M5: Clone rehearsal with the exact candidate: migrations on a restored clone, self-test, `verify`, full replay audit with the Nix-built binary.
- [ ] M6: With the user's go-ahead, push mori; in dotfiles `nix flake update mori` only; `./bin/build.sh`; confirm one `mori-cli` in the closure.
- [ ] M6 (Case B only): With the user's go-ahead, stop every writer, back up and verify, `up`, `VACUUM (ANALYZE) kiroku.stream_events`, strict `verify`.
- [ ] M6: User activates with `sudo ./bin/darwin-rebuild-sungkyung.sh`; verify agents, binaries, logs, and new appends with `category`; commit the dotfiles lock and the evidence.
- [ ] Distill: update mori ADR-24 (done in M4), record outcomes here, and update the MasterPlan's registry row and Progress.


## Surprises & Discoveries

These were found while drafting on 2026-09-26. Re-verify each at execution time.

- Observation: mori's own flake builds on a different nixpkgs from its deployed build.
  - mori's `flake.nix` leaves `haskell-nix-dev` unpinned, and `flake.lock` locks it at `af29a486`, whose nixpkgs is `4df1b885`.
  - dotfiles makes mori follow its root `haskell-nix-dev` (`206ecd25`, nixpkgs `d5dfd8e6`). So `nix build` inside the mori checkout does not build what ships.
  - The old `af29a486` has no `flake-parts` input, which is why mori's flake carries `haskell-nix.inputs.flake-parts.follows = "flake-parts"`.
  - Evidence: `jq '.nodes["haskell-nix-dev"].locked.rev' flake.lock` gives `af29a4869ca87aea3eb3e9d6164e24f571412527`, and `.nodes.nixpkgs.locked.rev` gives `4df1b885d76a54e1aa1a318f8d16fd6005b6401f`.
- Observation: mori `f3c5fa4b` ("adopt the Keiro 0.19 / Kiroku Store 0.9 cohort") is now on `origin/master` (`git status -sb` shows `master...origin/master`). The working tree still carries an uncommitted edit to `nix/haskell-overlay.nix` from the session that owns that work. It removes the Cabal-version-lowering helper and switches the `shibuya-pgmq-adapter` override to plain `callHackageNoCheck` with the unpacked hash `sha256-8yXtZ/qufiD4QdO1BtrxTIJWYfT8WbxkIMDA9a2svfI=`.
- Observation: Several `cabal.project` exceptions look stale against mori's own current plan (`dist-newstyle/cache/plan.json`, 2026-09-26):
  - `servant-multipart-client` is now 0.13.0, so the comment justifying `random < 1.3` (a `< 0.13` client) no longer holds.
  - `haxl` is absent from the plan, so `allow-newer: haxl:time` lifts nothing.
  - The three OpenAPI source pins resolve to 5.0.0, 5.1.0 and 0.1.0.0, the same releases Rei takes from Hackage at the same `index-state`.
- Observation: Several overlay entries duplicate or contradict the channel at `4cabd105`:
  - Duplicates: `hasql-notifications` 0.2.5.0 and the 13 `hs-opentelemetry-*` 1.0.0.0 packages plus `semantic-conventions` 1.40.0.0 use the same hashes as `patches/hasql-notifications/0.2.nix` and `patches/hs-opentelemetry/1.40.nix`.
  - Double patch: `blake3` is already patched portably by `patches/blake3/portable.nix`, and mori patches it again.
  - Dead entry: `link-canonical` is not a dependency of any mori package.
  - Nix/Cabal mismatch: `thread-utils-context` is pinned at 0.4.1.0 while Cabal selects 0.4.1.1.
  - Redundant: `hw-kafka-client` 5.3.0 is already the nixpkgs version (`nix eval github:NixOS/nixpkgs/d5dfd8e6#haskell.packages.ghc9124.hw-kafka-client.version` prints `5.3.0`).
- Observation: Three launchd agents run the `mori` CLI against the mori database, not just the daemon. All three take `mori` from the same dotfiles package `pkgs.mori`.
  - `com.shinzui.mori-automate` execs `${pkgs.mori}/bin/mori automate daemon`.
  - `com.shinzui.mina-web` puts `${pkgs.mori}/bin` first on `PATH` with `MORI_PG_CONNECTION_STRING` set.
  - `com.shinzui.rei-watchdog` runs `rei-doctor` every 300 s. Its `PATH` contains `pkgs.mori`, it runs `mori app deliveries`, and it can `kickstart` `com.shinzui.mori-automate` back to life.
  - Consequence: one `nix flake update mori` in dotfiles changes all three plists at once.
- Observation: mori's migration runner (`cabal run mori-core:mori-migrations`, pg-migrate 1.2's CLI) has `plan`, `status`, `verify`, `list`, `check`, `up`, `repair` and `new`, but no `preflight`. Its `up` runs its own legacy-history preflight (`assertLegacyHistoryImported`) before applying. `status` is therefore the read-only preflight here.
- Observation: The consumers pin old mori sources, so a mori-exported extension cannot be forced on them by this plan:
  - mori-rei-app pins mori at `32882f2d` (`mori-types` 5.0.0.0, with a `^>=5.0` bound). mori HEAD has `mori-types` 6.0.0.0.
  - mina pins `mori-schema-pin` at `7af02c55`, and a coupling test in `mina-core/test/Mina/Mori/CatalogSpec.hs` fixes the pinned SHA.


## Decision Log

- Decision: Import the freeze by an HTTPS `import:` pinned to the exact revision `R` locked in mori's `flake.lock`, and add a check that the two revisions are equal.
  Rationale: The MasterPlan's integration contract. A remote import has no content hash, so only a commit-pinned URL is reproducible. Tying it to the flake lock keeps Cabal and Nix on one cohort (`mori://shinzui/rei/okf/adrs/concepts/ADR-18`).
  Date: 2026-09-26
- Decision: Delete mori's version-only `constraints:` lines and keep its flag stanzas (`package blake3`, `package postgresql-libpq`).
  Rationale: The freeze pins exact versions that already satisfy `crypton >= 1.1` and `http-client-tls >= 0.4`, and makes `random < 1.3` moot (the freeze decides). A duplicate version constraint is either redundant or a conflict that makes the solve fail. Flags are not versions, and the freeze carries only `any.<pkg> ==<version>` lines.
  Date: 2026-09-26
- Decision: Keep three source pins in `cabal.project`:
  - `tan-effectful`/`hasql-effectful`. Nixpkgs' Hackage `hasql-effectful` 0.1.0.0 is a different, hasql-1.9-era source.
  - `typeid-hs`. Unpublished.
  - `dhall-haskell` `03b40e85` (dhall 1.42.3 with the relaxed `http-client-tls < 0.5` bound).

  Do not adopt Rei's `dhall -use-http-client-tls` flag.
  Rationale: ADR-16 remedy 2 (move a pin) beats lifting a bound. Turning off `use-http-client-tls` would remove TLS from Dhall remote imports. ADR-10 in mori limits only mori-schema URLs to the embedded copy, so other `https://` imports may still be in use, and dropping the flag is a behavior change this plan is not entitled to make. The freeze still pins dhall's version (1.42.3), so version parity holds even though Nix builds the Hackage 1.42.3 source. That source difference is recorded, not fixed here.
  Date: 2026-09-26
- Decision: `hasql-effectful` stays in mori's overlay as the single documented mori-only third-party source exception, unless plan 10 moved it into the channel.
  Rationale: Only mori uses it, it is not on Hackage at the needed revision, and a version-only freeze cannot express a git source. The MasterPlan's "consumer overlays define only their own packages" rule targets shared packages. This is not shared.
  Date: 2026-09-26
- Decision: Remove `doJailbreak` from `mori-types`, `mori-schema-pin`, `mori-core`, `mori-api` and `mori-cli` in the Nix build.
  Rationale: mori ADR-24's 2026-08-14 amendment records that jailbreaking mori's own packages let Nix link versions that violate mori's `.cabal` bounds with no signal. Once Nix equals the freeze and the freeze satisfies Cabal, the jailbreak hides nothing legitimate. Removing it turns every future drift into a `configure` failure that names the package. If a bound fails, fix the channel or the freeze, never the jailbreak.
  Date: 2026-09-26
- Decision: Export `mori-types` and `mori-schema-pin` as an additive flake output. Do not move mori-rei-app or mina onto it in this plan.
  Rationale: Plan 11 owns the convention, and plans 11 and 13 own those consumers. Both consumers pin older mori revisions for real reasons (a `^>=5.0` bound, and a schema-SHA coupling test), so switching them is their decision.
  Date: 2026-09-26
- Decision: The deploy moves only the `mori` input in dotfiles (`nix flake update mori`), never `just update-mori`.
  Rationale: `update-mori` is `_update-with-base`, which also moves `haskell-nix-dev` for every application. That has broken the Haskell closure before (the tls test failure of 2026-09-11). Moving the root channel input is plan 14's job.
  Date: 2026-09-26
- Decision: If the mori database is still at Kiroku `0011` when M5 runs, this plan performs the stop-writers cutover, including `com.shinzui.rei-watchdog` and `com.shinzui.mina-web` in the stop list. The `mori` CLI in the deployed closure moves to Kiroku 0.9 in the same activation.
  Rationale: The MasterPlan's persistent-database rule. Kiroku 0.8 cannot append after `0012` and there is no rolling deploy. All three agents take `pkgs.mori`, so one activation moves them together.
  Date: 2026-09-26


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

**Repositories.** This plan edits three repositories. It is written in, and progress is recorded in, this one (`mori://shinzui/haskell-nix`, checked out at `/Users/shinzui/Keikaku/bokuno/haskell-nix`).

- **`mori://shinzui/mori`**, checked out at `/Users/shinzui/Keikaku/bokuno/mori-project/mori`. The code changes. It has five Cabal packages:
  - `mori-types`: wire types, version 6.0.0.0.
  - `mori-schema-pin`: the pinned mori-schema commit and hashes, version 0.2.0.0.
  - `mori-core`: domain and event sourcing, including the `mori-migrations` executable.
  - `mori-cli`: the `mori` binary.
  - `mori-api`: the HTTP API.

  mori's instructions (`AGENTS.md`) require:
  - Conventional Commits on the current branch;
  - `nix fmt` before every commit;
  - `ExecPlan:` and `Intention:` trailers on plan-driven work.
- **`mori://shinzui/dotfiles.nix`**, checked out at `/Users/shinzui/.config/dotfiles.nix`. The deployment. `./bin/build.sh` builds `.#darwinConfigurations.SungkyungM1X.system` into `result`, and `sudo ./bin/darwin-rebuild-sungkyung.sh` activates it. Only the user runs the `sudo` command.

**Terms.**
- **The shared package set** or **the channel**: the Haskell package overrides this repository publishes as `lib.haskellExtension`. A consumer composes it over `pkgs.haskell.packages.ghc9124` (GHC 9.12.4) in its `flake.module.nix`.
- **The cohort freeze**: `cabal/cohort.freeze` in this repository, written by plan 8 (`docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`). It is a Cabal `constraints:` file with one `any.<pkg> ==<version>` line per package: the single, upgrade-only version of every package any of the five applications uses.
- **The generated Nix version layer**: written by plan 9 (`docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md`). It makes the channel's `.version` of every frozen package equal the freeze. Plan 9 also owns the shared comparison tool: the flake app `cohort-compare` that plan 9 (`docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md`, Milestone 5) adds as `scripts/cohort-compare.sh`. Invoke it as `nix run "github:shinzui/haskell-nix/$R#cohort-compare" -- --freeze <file-or-https-url> (--plan-json <file> | --closure <store-path> | --closure-list <file>) [--ignore NAME]... [--all]`, where `$R` is the haskell-nix revision the application pins. It prints tab-separated `STATUS name freeze found` lines for `mismatch` (a frozen package at another version) and `unfrozen` (a package the freeze does not cover), then a summary, and exits 0 when there are none, 1 otherwise, 2 on a usage error. In `--closure` mode a frozen name passes if any store path of that name has the frozen version, so a C library sharing a Haskell package's name (C `zlib-1.3.1` beside Haskell `zlib-0.7.1.1`) is harmless.
- **Plan 10** (`docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md`) moves shared overrides that consumers kept locally into this repository's `overlays/registry.nix` and `patches/*`. Among them: `link-canonical`, `openapi-hs`, `servant-openapi-hs`, `servant-health`, the `relay-pagination` family, the `hs-opentelemetry` family, `kioku-core` library profiling, and the `typeid-hs` sources. It publishes a per-consumer deletion list.
- **Plan 11** (`docs/plans/11-adopt-the-shared-package-set-in-rei-and-mori-rei-app.md`) defines how an application's flake exports a Haskell extension that other flakes compose.
- **`R`**: the full 40-character haskell-nix commit this plan adopts. It must contain plans 9 and 10's work. If rei has already adopted the set under plan 11, prefer the same `R` as rei's `flake.lock`.
- **Kiroku**: the event store library. **Kiroku migration `0012`** (`kiroku-store-migrations` 0.6):
  - adds a `category` column to `kiroku.stream_events`;
  - backfills it on every `$all` row (rows with `stream_id = 0`);
  - adds `CHECK (stream_id <> 0 OR category IS NOT NULL)`.

  It runs in one transaction that blocks appends. A Kiroku 0.8 writer does not supply `category`, so after `0012` its every append fails on that CHECK loudly rather than writing bad rows. The migration file itself advises `VACUUM (ANALYZE) kiroku.stream_events` afterwards.
- **Writer**: any process that appends to the mori database.

**mori's build today** (HEAD `f3c5fa4b`).
- **`cabal.project`:**
  - `index-state: 2026-09-26T18:09:31Z`, `with-compiler: ghc-9.12.4`.
  - Six `source-repository-package` pins: `openapi-hs` `06fc1171`, `servant-openapi-hs` `181ca609`, `servant-health` `c70bffdd`, `tan-effectful` `5e081ad8` (subdir `hasql-effectful`), `typeid-hs` `7164a74c` (`typeid-hs-sql`, `typeid-hs-pg-migrate`), and `dhall-haskell` `03b40e85` (subdir `dhall`).
  - `constraints: crypton >= 1.1, http-client-tls >= 0.4, random < 1.3`.
  - `package blake3` and `package postgresql-libpq` flag stanzas.
  - Ten `allow-newer` entries: `proto-lens:base`, `proto-lens:ghc-prim`, `proto-lens:deepseq`, `proto-lens-runtime:base`, `baikai-kit:crypton`, `hasql-effectful:effectful`, `hasql-effectful:effectful-core`, `claude:http-client-tls`, `haxl:time`, `kiroku-cli:http-client-tls`.

  mori's list differs from Rei's:
  - Rei has `fuzzyfind:containers` and `link-canonical:*`, and uses `dhall -use-http-client-tls` instead of a dhall pin.
  - Both share `baikai-kit:crypton`, `claude:http-client-tls` and `kiroku-cli:http-client-tls`.

  mori's plan selects 345 non-local packages. Compared with Rei's plan, mori is ahead on `megaparsec` (9.8.3 vs 9.7.1) and `microlens` (0.5.0.0 vs 0.4.14.0). It also has 22 packages Rei does not use, among them `dhall`, `hasql-effectful`, `hw-kafka-client`, `okf-core`, `regex-tdfa` and `repline`.
- **`flake.nix`:**
  - `haskell-nix` pinned to `4cabd105` (following `haskell-nix-dev`, `nixpkgs`, and mori's own `flake-parts`).
  - `haskell-nix-dev` unpinned (locked `af29a486`).
  - Its own `flake-parts` and `pre-commit-hooks` inputs.
  - Six non-flake source inputs: `tan-effectful-src`, `typeid-hs-src`, `mori-schema-src` `3522f4a5`, `openapi-hs-src`, `servant-openapi-hs-src`, `servant-health-src`.

  `flake.module.nix` builds `haskellPackages = pkgs.haskell.packages.ghc9124.override { overrides = composeExtensions (inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose pkgs) (import ./nix/haskell-overlay.nix { … }); }` and exposes only `packages.mori` and `packages.default` (both `mori-cli`). `nix/haskell.nix` builds the dev shell from `inputs.haskell-nix-dev.lib.${system}.mkDevShell`, which `206ecd25` also provides (checked with `nix eval`: `defaultGhc`, `ghcVersions`, `mkDevShell`).
- **`nix/haskell-overlay.nix`**, in file order:
  - `hasql-effectful`, `typeid-hs-sql`, `typeid-hs-pg-migrate`, `openapi-hs`, `servant-openapi-hs`, `servant-health` (from source inputs);
  - `blake3` (portable flags);
  - `link-canonical`, `hasql-notifications`, thirteen `hs-opentelemetry-*` 1.0.0.0 packages, `hs-opentelemetry-semantic-conventions` 1.40.0.0, `thread-utils-finalizers`, `thread-utils-context`, `hw-kafka-client` (all Hackage pins);
  - `kioku-core` (profiling disabled);
  - `shibuya-pgmq-adapter` 0.16.1.0, whose comment names this initiative as its retirement condition;
  - `relay-pagination`, `-conformance`, `-hasql`, `-servant` 0.1.1.0;
  - mori's own five packages, each `dontHaddock (dontCheck (doJailbreak (callCabal2nix …)))`. `mori-core` and `mori-cli` also stage `mori-schema-src` at `../schema` in `prePatch`, and `mori-cli` adds a `-DGIT_HASH` configure flag.

**mori's database and tools.**
- The global registry is `host=/Users/shinzui/.local/state/postgresql dbname=mori`, and `just migrate-prod <cmd>` runs `mori-migrations` against it.
- The local dev database is the socket `$PWD/db` inside `nix develop`, started with `just process-up`, and `just migrate <cmd>` runs against it.
- `scripts/validate-on-clone.sh` (recipes `rehearse-registry` and `rehearse-registry-selftest`) `pg_dump`s the registry read-only into a clone in the dev cluster, migrates the clone, and fails on any lost table or decreased row count.
- `scripts/capture-ground-truth.sh` records row counts.
- `mori ops … stream subscriptions --json` records checkpoints.
- `mori ops --json replay-audit --full` replays every stream.

mori's procedure is written in `mori://shinzui/mori` at `docs/operations/cohort-cutover-runbook.md` and `docs/operations/keiro-0-18-rollout.md` (artifact-level URIs pending). This plan repeats every step it needs.

**Writers of the mori database** (from `plutil -p ~/Library/LaunchAgents/*.plist` and `/Users/shinzui/.config/dotfiles.nix/home/{mori,mina,rei-doctor}.nix`):
- `com.shinzui.mori-automate` (`KeepAlive`, the daemon and sole automation executor, ADR-19);
- `com.shinzui.mina-web` (`KeepAlive`, `mina web --global`, which shells out to `mori`);
- `com.shinzui.rei-watchdog` (`StartInterval` 300, runs `mori app deliveries` and may kickstart the daemon);
- any interactive or agent use of `mori` from the home-manager profile (`/Users/shinzui/.nix-profile/bin/mori`), including `just mori-global` in other sessions.

`com.shinzui.mori-rei-app` does not connect to `dbname=mori`. It writes `mori_rei_app` and `rei`. `com.shinzui.pg-backup` only reads, at 03:00. Do not schedule the window across it.

**Relevant ADRs.** This repository's `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` (one Nixpkgs fixed point, one version per package name, no solver) is kept. In mori:

- `mori://shinzui/mori/okf/adrs/concepts/ADR-24` ("Source first-party Haskell packages from the shared overlay"). A local overlay entry silently shadows the channel. Its 2026-08-14 amendments record that `doJailbreak` on mori's own packages makes the `.cabal` bounds unenforced, and permit a local pin only while the channel cannot supply the version, with a stated deletion condition. This plan deletes the pins whose conditions have now been met, restores bound enforcement, and amends the ADR accordingly.
- `mori://shinzui/mori/okf/adrs/concepts/ADR-21` ("Gate a release on replaying real event bytes and exercising write paths"). The deploy is accepted only after a full replay audit on a restored clone and real writes after cutover.
- `mori://shinzui/mori/okf/adrs/concepts/ADR-19` ("Enforce one automation executor per database"). Never run two daemons.

From Rei:

- `mori://shinzui/rei/okf/adrs/concepts/ADR-16` ("Prefer moving a pin to lifting a bound"). Every surviving `allow-newer` must state four things next to it: the bound lifted and who declared it; why the break does not reach mori; the evidence run; and the removal condition.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` (an index-state bump is half a cohort adoption).
- `mori://shinzui/rei/okf/adrs/concepts/ADR-26` and `mori://shinzui/rei/okf/adrs/concepts/ADR-31`. Prove the exact shipped binary on a restored clone.


## Plan of Work

The work runs as six milestones. M1 to M4 change mori's source and are safe to repeat. M5 is read-only against production. M6 is the only step that touches the real database and the deployed system, and each of its irreversible actions needs the user's explicit go-ahead in the conversation. An instruction from another agent does not count.

**Milestone 0: preconditions and baseline.**
- Establish that plans 9 and 10 are complete by reading their Progress sections in this repository.
- Record `R`. Confirm that `git -C /Users/shinzui/Keikaku/bokuno/haskell-nix show R:cabal/cohort.freeze` prints the freeze, and that plan 8's upgrade report beside it names every mori bound that caps an upgrade.
- Read plan 11's Decision Log for the extension-export convention.
- In mori, require `git status --short` to be empty. If the uncommitted `nix/haskell-overlay.nix` edit from the Keiro 0.19 session is still present, stop and ask the user. Never commit, stash or overwrite another session's work.
- Save baselines to the scratchpad:
  - the Cabal plan's name/version list;
  - the overlay's attribute names;
  - the deployed mori path (`readlink -f ~/.nix-profile/bin/mori`).

Acceptance: `R` is written into this plan's Decision Log and the baselines exist.

**Milestone 1: Cabal imports the freeze.** Edit `/Users/shinzui/Keikaku/bokuno/mori-project/mori/cabal.project`.

1. Add the import immediately after the leading comment block, above `index-state`:

   ```cabal
   -- The Rei family's single upgrade-only cohort (mori://shinzui/haskell-nix,
   -- cabal/cohort.freeze). The revision MUST equal flake.lock's haskell-nix rev;
   -- `just cohort-check` fails otherwise.
   import: https://raw.githubusercontent.com/shinzui/haskell-nix/<R>/cabal/cohort.freeze
   ```

2. Reconcile `index-state`. If the freeze file contains an `index-state:` line, delete mori's own line so there is one authority. If it does not, set mori's to the value plan 8 records for the freeze (never older than `2026-09-26T18:09:31Z`, never `HEAD`).

3. Replace the `constraints:` block with nothing. The freeze pins exact versions satisfying `crypton >= 1.1` and `http-client-tls >= 0.4`, and supersedes `random < 1.3`. Keep the `package blake3` and `package postgresql-libpq` stanzas unchanged. If the freeze contains flag lines (anything other than `==` versions), compare them with mori's flags. A frozen `dhall -use-http-client-tls` in particular would silently remove TLS from Dhall imports, so stop and raise it against plan 8 rather than accept it.

4. Delete the three `source-repository-package` stanzas for `openapi-hs`, `servant-openapi-hs` and `servant-health`, and their comments. Hackage serves `openapi-hs` 5.0.0, `servant-openapi-hs` 5.1.0 and `servant-health` 0.1.0.0 inside the index-state, which is how Rei resolves them. Keep the `tan-effectful`, `typeid-hs` and `dhall-haskell` stanzas.

5. Work through `allow-newer` one entry at a time, deleting the entry and running `cabal build --dry-run all`:
   - `haxl:time`: expected removable (haxl is not in the plan).
   - `proto-lens:base`, `proto-lens:ghc-prim`, `proto-lens:deepseq` and `proto-lens-runtime:base`: remove each if the dry run still solves. If the frozen `proto-lens` 0.7.1.x still caps `base`, keep the entry with an ADR-16 four-part comment:
     - the bound: `proto-lens` declares `base < 4.21`, or whatever the error names, and `hs-opentelemetry-otlp` pulls it in;
     - why the break does not reach mori: only the generated OTLP message code is used, which compiles;
     - the evidence: `cabal build all` plus the OTLP exporter test in `mori-core`;
     - the removal: the first `proto-lens` release admitting GHC 9.12's `base`.
   - `hasql-effectful:effectful` and `:effectful-core`: first apply ADR-16 remedy 2. Check whether `topagentnetwork/tan-effectful` has a newer commit whose `hasql-effectful.cabal` admits the frozen `effectful`. If so, move both the Cabal tag and the flake input `tan-effectful-src` to it and delete the entries. Otherwise keep them with a four-part comment (the `effectful < 2.6` bound in `hasql-effectful`; mori uses only `Hasql.Effectful`'s session runner, whose API is unchanged in 2.6; evidence `cabal test mori-core-test`; removal when tan-effectful widens the bound).
   - `baikai-kit:crypton`, `claude:http-client-tls` and `kiroku-cli:http-client-tls`: keep. Their existing comments are the same claims Rei makes, and they already state the four parts.

6. Lift bounds. For each mori package named in plan 8's upgrade report, raise the bound in the named `.cabal` file (`mori-*/mori-*.cabal`) to admit the frozen version. Do not add `allow-newer` for mori's own bounds. Likely candidates to check first: `optparse-applicative >=0.19 && <0.20`, `regex-tdfa <1.4`, `transformers <0.7`, `filepath <1.6`, `megaparsec <10`, `dhall ^>=1.42`.

7. Build and fix. `cabal build all`, then `cabal test all`, then `just check-openapi`. Fix compile breaks in mori source only, keeping each fix minimal and recording it in Surprises & Discoveries. If `domain/*.keiro` or generated modules change, run `just keiro-gate`.

8. Run `nix fmt` and commit.

Acceptance: `cabal build all` and `cabal test all` pass. `jq` over `dist-newstyle/cache/plan.json` shows every non-local package at its frozen version (Concrete Steps shows the command).

**Milestone 2: Nix consumes the channel.**

1. Edit `flake.nix`:
   - `haskell-nix-dev.url = "github:shinzui/haskell-nix-dev/206ecd25bcb4a07581210bdae3e6f43c8fd179d8";`
   - `flake-parts.follows = "haskell-nix-dev/flake-parts";`, `pre-commit-hooks.follows = "haskell-nix-dev/pre-commit-hooks";` (replacing mori's own two inputs). `treefmt-nix.follows` stays.
   - `haskell-nix.url = "github:shinzui/haskell-nix/<R>";` keeping `inputs.haskell-nix-dev.follows` and `inputs.nixpkgs.follows`, and deleting `inputs.flake-parts.follows = "flake-parts"` together with its comment, whose stated removal condition this satisfies.
   - Delete the `openapi-hs-src`, `servant-openapi-hs-src` and `servant-health-src` inputs.
   - Delete `typeid-hs-src` only if plan 10 moved the `typeid-hs` packages into the channel.

2. Edit `flake.module.nix` to stop passing the deleted inputs to `./nix/haskell-overlay.nix`. Add `legacyPackages.haskellPackages = haskellPackages;` beside `packages.mori`, so versions can be evaluated with `nix eval .#legacyPackages.aarch64-darwin.haskellPackages.<pkg>.version`.

3. Edit `nix/haskell-overlay.nix`. Delete every entry on plan 10's deletion list for mori. If plan 10's list is silent on an entry, the expected result is:
   - **Delete:** `typeid-hs-sql` and `typeid-hs-pg-migrate` (if plan 10 moved them), `openapi-hs`, `servant-openapi-hs`, `servant-health`, `blake3`, `link-canonical`, `hasql-notifications`, all `hs-opentelemetry-*`, `thread-utils-finalizers`, `thread-utils-context`, `hw-kafka-client`, `kioku-core`, `shibuya-pgmq-adapter`, and the four `relay-pagination*` entries. Also delete the `callHackageNoCheck` helper once unused, and the long "Keiro/Kiroku/Shibuya/PGMQ/Kioku cohort" comment block.
   - **Keep:** `hasql-effectful` (with a comment naming it the one mori-only source exception and its deletion condition: a Hackage release admitting hasql 1.10), and mori's five packages.

   Before deleting `shibuya-pgmq-adapter`, evaluate the channel's version without the local entry and require `0.16.1.0`. That is the deletion condition its comment states.

4. Remove `doJailbreak` from the five mori packages (keep `dontCheck`, `dontHaddock`, `disableLibraryProfiling`, the `prePatch` staging and the `GIT_HASH` flag). If `configure` then fails on a bound, it names a package whose Nix version differs from the freeze. Fix that in the channel (plan 9's layer) or the freeze, and record it here. Do not re-add the jailbreak.

5. Run `nix flake lock` (it resolves only the changed inputs), `nix build .#mori`, and `nix flake check`. Moving nixpkgs from `4df1b885` to `d5dfd8e6` also changes the dev shell's `postgresql_18`, `rdkafka`, `redpanda-client` and `hurl`. Run `nix develop -c cabal test all` once more inside the new shell.

6. Run `nix fmt` and commit.

Acceptance:
- `nix build .#mori` succeeds.
- `nix eval` of `shibuya-pgmq-adapter.version` prints `0.16.1.0`.
- `grep -c '=' nix/haskell-overlay.nix` has fallen from about 35 attribute definitions to 6 or 7.

**Milestone 3: export mori's shared libraries.** If plan 11 defined an export shape, use it verbatim. Otherwise use this default, which mirrors how this repository exports its own extension (`lib.haskellExtension haskellLib pkgs`).

- Create `nix/mori-haskell-extension.nix`. It returns `haskellLib: pkgs: final: prev: { mori-types = …; mori-schema-pin = …; }`, each built as `haskellLib.dontHaddock (haskellLib.dontCheck (final.callCabal2nix "<name>" ../<name> { }))`. The relative path literal copies only that package directory into the store, so the derivation changes only when that package changes.
- In `flake.module.nix`, add a top-level `flake.lib.haskellExtension = import ./nix/mori-haskell-extension.nix;`.
- Make `nix/haskell-overlay.nix` take these two packages from the same file (for example `inherit (import ./mori-haskell-extension.nix haskellLib pkgs final prev) mori-types mori-schema-pin;`), so they are defined once.

Prove it composes on a bare channel set (Concrete Steps). Consumers adopt it in their own plans.

Acceptance: the evaluation prints `6.0.0.0` and `0.2.0.0`.

**Milestone 4: the per-application parity check and the ADR.**

1. Add a `cohort-check` recipe to mori's `justfile` (group `nix`) that does three things:
   - Extracts the revision from the `import:` line of `cabal.project` and from `jq -r '.nodes["haskell-nix"].locked.rev' flake.lock`, and fails if they differ.
   - Runs plan 9's comparison script (fetched with `nix run github:shinzui/haskell-nix/<R>#<script>` if plan 9 exposed it as a flake app, otherwise from the path plan 9 documents) against `dist-newstyle/cache/plan.json`.
   - Runs it against `nix-store -qR "$(readlink -f result)"`.

   Plan 9 owns the comparison logic, so do not re-implement it. Call it as the `cohort-compare` flake app described in Context and Orientation; keep the `jq` fallback in Concrete Steps only for a channel revision that predates plan 9's Milestone 5.

2. Amend mori ADR-24 (`docs/adr/0024-source-first-party-haskell-packages-from-the-shared-overlay.md`) with a dated amendment. The amendment says four things:
   - Shared third-party packages now come from the channel as well.
   - The version authority is `mori://shinzui/haskell-nix`'s `cabal/cohort.freeze`, imported by `cabal.project` at the flake-locked revision.
   - `doJailbreak` is removed from mori's own packages, so bounds are enforced again, which reverses the 2026-08-14 amendment's premise.
   - `hasql-effectful` is the remaining local exception.

   Advance its `timestamp`, add a `log.md` entry with `okf log add`, and run `just check-adr`.

3. Commit.

Acceptance: `just cohort-check` exits 0 and prints no differing package.

**Milestone 5: establish the cutover state and rehearse.** Everything here reads production only through `pg_dump` in read-only mode or read-only `psql` queries.

First determine the case:
- **Case A:** the mori database's Kiroku ledger row `0012` is `applied`, and the deployed `pkgs.mori` is a Kiroku 0.9 build. The deploy is an ordinary binary swap.
- **Case B:** the latest Kiroku row is still `0011`, and the deployed mori is `35f5943d` (Kiroku 0.8). The deploy is the stop-writers cutover.
- **Case C:** `0012` is applied but the deployed mori is still Kiroku 0.8. Every mori append is failing now. Stop this plan, tell the user immediately, and treat shipping a 0.9 mori as an incident fix.

Record the case, with the query output, in Surprises & Discoveries.

Then rehearse with the exact candidate:
- Build `nix build .#mori` from the committed candidate.
- Clone the registry into the dev cluster and apply `up` there, twice. The second run must change nothing.
- Run the self-test and `verify` on the clone.
- Run `mori ops --json replay-audit --full` against the clone with the Nix-built `result/bin/mori`, not a Cabal build (ADR-26, ADR-31).
- In Case B, time `0012` and the `VACUUM`; the 2026-09-26 rehearsal measured 12.3 s and 0.5 s.

Acceptance: the clone gate and self-test pass, `verify` reports `pending=0 unknown=0`, and the replay audit reports zero failures and zero divergences in every category.

**Milestone 6: deploy.**

1. With the user's go-ahead, push mori `master`.
2. In dotfiles, run `nix flake update mori` (only), then `./bin/build.sh`. Confirm the closure contains exactly one `mori-cli` store path, and that it equals mori's own `nix build` output.
3. Case B only, again with the user's go-ahead, run the cutover:
   - Stop every writer with `launchctl bootout`, in this order: watchdog, then mina-web, then daemon. Tell the user and other agent sessions not to run `mori` until activation completes.
   - Confirm `pg_stat_activity` shows no other session on `dbname=mori`.
   - Capture ground truth and checkpoints, then take and verify a backup.
   - Run `status`, `up` and a second `up` (which must be a no-op), then `VACUUM (ANALYZE) kiroku.stream_events`, then strict `verify`.
4. The user activates. Then verify:
   - every agent is loaded and running the new `mori-cli`;
   - today's daemon log shows subscriptions starting with their declared policies and no `23514`/`ck_stream_events_all_category` errors;
   - the first ingest appends `$all` rows with a `category`;
   - `mori.app_deliveries` does not re-deliver history.
5. Commit the dotfiles `flake.lock` alone (never the unrelated uncommitted files there), and commit the ground-truth captures and evidence in mori.

Acceptance: see Validation and Acceptance.


## Concrete Steps

Set these once per shell. `R` is the haskell-nix revision chosen in M0.

```bash
export R=<40-character haskell-nix commit>
export MORI=/Users/shinzui/Keikaku/bokuno/mori-project/mori
export HN=/Users/shinzui/Keikaku/bokuno/haskell-nix
export DOT=/Users/shinzui/.config/dotfiles.nix
export SCRATCH=<the session scratchpad directory>
export REG="host=$HOME/.local/state/postgresql dbname=mori"
```

**M0.** Run from any directory:

```bash
git -C "$HN" show "$R:cabal/cohort.freeze" | head -5
git -C "$HN" show "$R:cabal/cohort.freeze" | grep -v '==' | grep -v '^\s*--' | grep -v '^\s*$'   # flag or index-state lines, if any
git -C "$MORI" status --short          # must print nothing
jq -r '."install-plan"[] | select(."pkg-src".type=="repo-tar" or ."pkg-src".type=="source-repo") | "\(."pkg-name") \(."pkg-version")"' \
  "$MORI/dist-newstyle/cache/plan.json" | sort -u > "$SCRATCH/mori-plan-before.txt"
readlink -f ~/.nix-profile/bin/mori > "$SCRATCH/mori-deployed-before.txt"
```

**M1.** Run from `$MORI` inside `nix develop`. After editing `cabal.project`:

```bash
cabal build --dry-run all          # repeat after each allow-newer deletion
cabal build all
cabal test all
just check-openapi
jq -r '."install-plan"[] | select(."pkg-src".type=="repo-tar" or ."pkg-src".type=="source-repo") | "\(."pkg-name") \(."pkg-version")"' \
  dist-newstyle/cache/plan.json | sort -u > "$SCRATCH/mori-plan-after.txt"
curl -fsSL "https://raw.githubusercontent.com/shinzui/haskell-nix/$R/cabal/cohort.freeze" \
  | sed -nE 's/^[[:space:]]*(constraints:)?[[:space:]]*any\.([A-Za-z0-9-]+) ==([0-9.]+),?.*/\2 \3/p' | sort -u > "$SCRATCH/freeze.txt"
join <(sort "$SCRATCH/mori-plan-after.txt") "$SCRATCH/freeze.txt" | awk '$2 != $3'   # must print nothing
nix fmt
git add cabal.project mori-*/mori-*.cabal
git commit   # message below
```

Commit message:

```text
build(deps): import the Rei family cohort freeze

Import cabal/cohort.freeze from mori://shinzui/haskell-nix at the revision
flake.lock pins, drop version-only constraints the freeze subsumes, take the
OpenAPI 3.1 cohort and servant-health from Hackage, and re-justify each
remaining allow-newer per ADR-16.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/12-adopt-the-shared-package-set-in-mori
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

**M2.** Run from `$MORI`:

```bash
nix flake lock
jq -r '.nodes["haskell-nix-dev"].locked.rev, .nodes["haskell-nix"].locked.rev, .nodes.nixpkgs.locked.rev' flake.lock
# expect 206ecd25bcb4a07581210bdae3e6f43c8fd179d8, $R, d5dfd8e6...
nix eval --raw .#legacyPackages.aarch64-darwin.haskellPackages.shibuya-pgmq-adapter.version   # expect 0.16.1.0
nix build .#mori
nix flake check
nix develop -c cabal test all
nix fmt
git add flake.nix flake.lock flake.module.nix nix/haskell-overlay.nix
git commit   # "build(nix): consume the shared package set and drop shared overrides", same trailers
```

A `configure` failure after the jailbreak removal looks like the following, and names the package to fix in the channel:

```text
Error: Setup: Encountered missing or private dependencies:
megaparsec >=9.0 && <10
```

**M3.** Run from `$MORI`. Prove the extension composes on the channel alone:

```bash
nix eval --impure --expr '
  let f = builtins.getFlake (toString ./.);
      pkgs = f.inputs.nixpkgs.legacyPackages.aarch64-darwin;
      hl = pkgs.haskell.lib.compose;
      hp = pkgs.haskell.packages.ghc9124.override {
        overrides = pkgs.lib.composeExtensions
          (f.inputs.haskell-nix.lib.haskellExtension hl pkgs)
          (f.lib.haskellExtension hl pkgs);
      };
  in [ hp.mori-types.version hp.mori-schema-pin.version ]'
# expect [ "6.0.0.0" "0.2.0.0" ]
```

Commit as `feat(nix): export mori-types and mori-schema-pin as a Haskell extension` with the same trailers.

**M4.** The fallback comparison, used only if plan 9's script cannot be called. Run from `$MORI` after `nix build .#mori`:

```bash
nix-store -qR "$(readlink -f result)" \
  | sed -nE 's#^/nix/store/[a-z0-9]{32}-(.+)-([0-9][0-9.]*)$#\1 \2#p' | sort -u > "$SCRATCH/mori-closure.txt"
join "$SCRATCH/mori-closure.txt" "$SCRATCH/freeze.txt" | awk '$2 != $3'     # must print nothing
```

Then:

```bash
just cohort-check
just check-adr
git commit   # "build: check mori against the shared cohort freeze" and "docs(adr): ..." with trailers
```

**M5.** Establish the case, read-only. Run from `$MORI`:

```bash
PGOPTIONS='-c default_transaction_read_only=on' psql "$REG" -Atc \
  "SELECT migration, status, finished_at FROM pgmigrate.migrations WHERE component = 'kiroku' ORDER BY position DESC LIMIT 1;"
jq -r '.nodes.mori.locked.rev' "$DOT/flake.lock"     # 35f5943d... means Kiroku 0.8 is deployed
git -C "$MORI" log --oneline -15                     # look for a recorded 0012 rollout
```

On 2026-09-26 the query returned the `0011` row, which is Case B.

Rehearse. Run from `$MORI` with the dev cluster running (`just process-up`):

```bash
nix build .#mori && readlink -f result > "$SCRATCH/candidate-path.txt"
nix shell nixpkgs#postgresql_18 -c scripts/validate-on-clone.sh \
  --source-host "$HOME/.local/state/postgresql" --source-db mori \
  --clone-host "$PWD/db" --clone-db mori_clone_registry \
  --allow-projection-catalog-compaction \
  --migrate-cmd 'nix develop -c env MORI_PG_CONNECTION_STRING="$MORI_PG_CONNECTION_STRING" cabal run -v0 mori-core:mori-migrations -- up'
nix shell nixpkgs#postgresql_18 -c scripts/validate-on-clone.sh \
  --source-host "$HOME/.local/state/postgresql" --source-db mori \
  --clone-host "$PWD/db" --clone-db mori_clone_registry \
  --allow-projection-catalog-compaction --reuse-dump --self-test \
  --migrate-cmd 'nix develop -c env MORI_PG_CONNECTION_STRING="$MORI_PG_CONNECTION_STRING" cabal run -v0 mori-core:mori-migrations -- up'
```

Then recreate the clean clone by running the first command again, and continue:

```bash
CLONE="host=$PWD/db dbname=mori_clone_registry"
cabal run -v0 mori-core:mori-migrations -- verify --database-url "$CLONE"
MORI_PG_CONNECTION_STRING="$CLONE" ./result/bin/mori ops --json replay-audit --full > "$SCRATCH/replay-clone.json"
```

Read the self-test's own lines, not only its exit code:

```text
SELF-TEST run 1/2 (clean)          -> exit 0   as required
SELF-TEST run 2/2 (row deleted)    -> exit 1   as required, saw "DATA LOSS"
SELF-TEST PASS — the harness catches injected row loss.
```

If `verify` reports projection-catalog drift, follow the runbook's preview, `adopt --force` and double rebuild on the clone first, and record the exact group and fingerprints here.

**M6.** Only with the user's explicit go-ahead for each numbered action.

1. Push, then update and build dotfiles:

```bash
git -C "$MORI" push origin master
cd "$DOT" && nix flake update mori
jq -r '.nodes.mori.locked.rev' flake.lock          # must equal mori HEAD
./bin/build.sh
nix-store -qR result | grep -E -- '-mori-cli-[0-9]' | sort -u      # exactly one line
cat "$SCRATCH/candidate-path.txt"                                   # the same path
```

2. Case B: stop the writers. Run from any directory. Record each PID first, then boot the agent out and wait for that PID to exit. Never use `pkill` with a pattern.

```bash
for l in com.shinzui.rei-watchdog com.shinzui.mina-web com.shinzui.mori-automate; do
  pid=$(launchctl print "gui/$(id -u)/$l" 2>/dev/null | awk '/[[:space:]]pid = /{print $NF; exit}')
  echo "$l pid=${pid:-none}"
  launchctl bootout "gui/$(id -u)/$l" || true
  if [ -n "$pid" ]; then while kill -0 "$pid" 2>/dev/null; do sleep 1; done; fi
done
psql "$REG" -Atc "SELECT pid, application_name, backend_start, state, left(query,60) FROM pg_stat_activity WHERE datname = 'mori' AND pid <> pg_backend_pid();"
# must print nothing; wait and repeat if a short-lived CLI session appears
```

3. Case B: take the pre-cutover evidence and a verified backup. Run from `$MORI` inside `nix develop`:

```bash
scripts/capture-ground-truth.sh --label registry --host ~/.local/state/postgresql --db mori \
  --as-of "$(date -u +%F)" --out "docs/operations/ground-truth/registry-$(date -u +%F)-pre-kiroku-0012.md"
mori ops --database-url "$REG" --json stream subscriptions > "$SCRATCH/checkpoints-before.json"   # the deployed 0.8 mori, read-only use
mkdir -p .backups/kiroku-0012
B=.backups/kiroku-0012/mori-registry-$(date -u +%Y%m%dT%H%M%SZ).dump
PGOPTIONS='-c default_transaction_read_only=on' pg_dump -Fc --no-owner --no-acl "$REG" -f "$B"
pg_restore --list "$B" > /dev/null && shasum -a 256 "$B" | tee "$SCRATCH/backup.sha256"
```

4. Case B: migrate. Run from `$MORI`:

```bash
just migrate-prod status          # expect exactly one pending: kiroku 0012
just migrate-prod up
just migrate-prod up              # every entry already_applied
psql "$REG" -c 'VACUUM (ANALYZE) kiroku.stream_events;'
just migrate-prod status
just migrate-prod verify          # pending=0 unknown=0 issues=0, then "projection catalog: candidate group slices are compatible"
psql "$REG" -Atc "SELECT count(*) FROM kiroku.stream_events WHERE stream_id = 0 AND category IS NULL;"   # 0
```

If `up` fails partway, stop. Do not retry blindly, do not hand-apply SQL with `psql`, and see Idempotence and Recovery.

5. The user activates. The user runs this in `$DOT`:

```bash
sudo ./bin/darwin-rebuild-sungkyung.sh
```

6. Verify. Run from any directory:

```bash
for l in com.shinzui.mori-automate com.shinzui.mina-web com.shinzui.rei-watchdog; do
  launchctl print "gui/$(id -u)/$l" 2>/dev/null | grep -E '^\s*(state|pid) =' || echo "$l NOT LOADED"
done
pid=$(launchctl print "gui/$(id -u)/com.shinzui.mori-automate" | awk '/[[:space:]]pid = /{print $NF; exit}')
lsof -p "$pid" | grep -m1 -- '-mori-cli-'          # the candidate path
readlink -f ~/.nix-profile/bin/mori                 # the candidate path
grep "^$(date +%Y-%m-%d)T" ~/.mori/logs/automate.stderr.log | tail -50
grep "^$(date +%Y-%m-%d)T" ~/.mori/logs/automate.stderr.log | grep -E '23514|ck_stream_events_all_category' # nothing
psql "$REG" -Atc "SELECT se.stream_version, se.category, e.event_type, e.created_at FROM kiroku.stream_events se JOIN kiroku.events e USING (event_id) WHERE se.stream_id = 0 ORDER BY se.stream_version DESC LIMIT 5;"
```

An agent that was booted out and whose plist did not change is not reloaded by activation. Load it by hand:

```bash
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/<label>.plist
```

After the first scheduled ingest (every 600 s), repeat the last query. Rows above the pre-cutover head must show non-null categories such as `repository`. Then capture ground truth again (`…-post-kiroku-0012.md`) and compare checkpoints. No pre-existing checkpoint may move, and a new subscription must sit at the head, never at 0.

7. Commit.

```bash
cd "$DOT" && git add flake.lock && git commit   # "chore(mori): deploy the shared package set build", trailers as above
```

Commit the two ground-truth captures and a short rollout note under mori's `docs/operations/` with `docs(rollout): record Kiroku 0012 and shared package set deployment`.


## Validation and Acceptance

The plan is complete when all of the following are observed.

**In the mori checkout:**
- `just cohort-check` exits 0.
- Every non-local package in `dist-newstyle/cache/plan.json` equals its `cabal/cohort.freeze` version at `R`.
- Every name-version pair in `nix-store -qR` of `nix build .#mori` that is in the freeze equals it.
- `cabal test all` and `nix flake check` pass.
- `flake.lock` shows `haskell-nix-dev` `206ecd25bcb4a07581210bdae3e6f43c8fd179d8`, nixpkgs `d5dfd8e6…`, and `haskell-nix` `R`, which is the revision in `cabal.project`'s `import:`.

**In the overlay:** `nix/haskell-overlay.nix` defines only `hasql-effectful` (and `typeid-hs-*` if plan 10 left them to consumers) plus mori's five packages. None of mori's five packages is jailbroken.

**The extension:** the M3 evaluation prints `[ "6.0.0.0" "0.2.0.0" ]`.

**In the new dotfiles system closure:**
- `nix-store -qR result | grep -- '-mori-cli-'` prints exactly one path, and it equals mori's own `nix build` output.
- After activation, the executable of `com.shinzui.mori-automate`'s process (from `lsof`) and `~/.nix-profile/bin/mori` resolve into that path.
- `com.shinzui.mina-web` and `com.shinzui.rei-watchdog` are loaded, and their wrappers' `PATH` contains that path's `bin`. Check with `grep -o '/nix/store/[^:]*-mori/bin'` on the wrapper scripts named in their plists.

**On the mori database:**
- `just migrate-prod verify` reports `pending=0 unknown=0 issues=0` and compatible catalog slices.
- The Kiroku ledger's last row is `0012` `applied`.
- No `$all` row has a null `category`.
- Events appended after activation exist and carry a category.
- No pre-existing checkpoint moved.
- `mori.app_deliveries` did not grow for events older than the cutover.
- `mori ops --json replay-audit --full` against the live database after activation reports zero failures and zero divergences in every category (the ADR-21 gate).

**Beyond compilation:** a scheduled ingest completed and delivered its webhooks to mori-rei-app. `mina web`'s mori-backed pages load without errors in `~/.mina/logs/web.stderr.log` for today. `rei-doctor` reports no mori errors on its next run.


## Idempotence and Recovery

M1 to M4 are ordinary source edits in mori and can be repeated or reverted with `git revert`. `nix flake lock` changes only inputs whose URLs changed. If `cabal build --dry-run` fails after an `allow-newer` deletion, restore that one line; the failure is the evidence that the entry is still needed.

M5 never writes production. `pg_dump` runs with `default_transaction_read_only=on`, and every clone lives in the dev cluster. Rerun it at will, recreating the clean clone after a self-test. `.backups/` is git-ignored.

**M6 before `up`.** Nothing irreversible has happened. To abort, bring the old agents back with `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<label>.plist` for the daemon, mina-web and the watchdog, in that order. Leave the dotfiles lock uncommitted, or revert it with `git -C "$DOT" checkout flake.lock`.

**M6 during or after `up`, before activation.** `0012` runs in one transaction, so a failure rolls the whole migration back. Read `just migrate-prod status` before doing anything else. The pg-migrate ledger is forward-only: never apply or undo migration SQL by hand, and never edit `pgmigrate.migrations`.
- If `0012` applied, the Kiroku 0.8 agents must not return. Proceed to activation, which is the recovery.
- Restoring the verified backup is a last resort. It returns the database to its exact pre-cutover state; only in that case may the 0.8 agents restart. Restore into a fresh database with the staged procedure from mori's runbook (`pg_restore --section=pre-data`, pin the `typeid_*` functions' `search_path`, then `--section=data --section=post-data`), compare `scripts/capture-ground-truth.sh` row counts with the pre-cutover capture, and only then swap it in.

**After activation.** Recovery is roll-forward. Reverting the dotfiles `mori` input would bring back a Kiroku 0.8 binary that fails every append. If the new binary misbehaves:
- stop `com.shinzui.mori-automate` with `launchctl bootout`;
- fix forward in mori and redeploy with the same M6 steps (Case A form).

A reactor replaying history (`mori.app_deliveries` growing for old events) means stop the daemon at once, as the runbook's 2026-06-13 incident describes.

The activation boots out and re-bootstraps every agent whose plist changed. It has killed Rei's worker before, and `rei-watchdog` healed it in about 30 s. Check the Rei agents' state afterwards as well.


## Interfaces and Dependencies

**Inputs this plan consumes:**
- From plan 8: `cabal/cohort.freeze` at `R` (Cabal `constraints:` syntax, one `any.<pkg> ==<version>` per package), and its upgrade report naming mori's capping bounds.
- From plan 9: the channel's generated version layer (so `haskellPackages.<pkg>.version` equals the freeze) and the shared comparison script under `scripts/` in this repository.
- From plan 10: the channel-owned overrides and mori's deletion list.
- From plan 11 (soft): the extension export shape.

**Interfaces that exist in mori at the end:**
- `cabal.project` with `import: https://raw.githubusercontent.com/shinzui/haskell-nix/<R>/cabal/cohort.freeze`.
- `flake.nix` inputs `haskell-nix-dev` (rev-pinned `206ecd25`) and `haskell-nix` (rev-pinned `R`).
- `flake.module.nix` outputs:
  - `packages.<system>.mori` and `.default` (the `mori-cli` derivation);
  - `legacyPackages.<system>.haskellPackages` (the composed GHC 9.12.4 set);
  - `lib.haskellExtension :: haskellLib -> pkgs -> (final -> prev -> { mori-types, mori-schema-pin })`, system-independent. Consumers compose it after this repository's `lib.haskellExtension`, and both are applied with `pkgs.lib.composeExtensions`.
- `nix/mori-haskell-extension.nix`, the single definition of those two packages.
- A `just cohort-check` recipe.
- `docs/adr/0024-…` carrying the new amendment.

**Runtime interfaces the deploy relies on:**
- `mori-core:mori-migrations` (pg-migrate 1.2 CLI: `status`, `up`, `verify`, with `--database-url`), wrapped by `just migrate-prod`.
- `scripts/validate-on-clone.sh` and `scripts/capture-ground-truth.sh`.
- `mori ops --json replay-audit --full` and `mori ops --database-url <url> --json stream subscriptions`.
- The launchd labels `com.shinzui.mori-automate`, `com.shinzui.mina-web` and `com.shinzui.rei-watchdog`.
- dotfiles' `pkgs.mori` (`flake-modules/overlays.nix`, `hsBin "mori"`), which `home/mori.nix`, `home/mina.nix` and `home/rei-doctor.nix` all reference.

**Interaction with plans 11, 13 and 14.**
- Plan 13 deploys mina. mina does not link Kiroku; it runs `pkgs.mori`, which this plan moves. So mina's own deploy does not need to coincide with this one. But no mina build may bring a second `mori` executable onto its `PATH`: the one-`mori-cli` closure check above catches that.
- Plan 14 later replaces dotfiles' nested per-application `haskell-nix` inputs with one root input. This plan moves only the `mori` input.


## Revision Notes

- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The shared comparison tool is now plan 9's `cohort-compare` flake app with its exact interface. The freeze carries an `index-state:` line and no flags, so mori deletes its own `index-state`, and the `dhall -use-http-client-tls` flag concern does not arise.
