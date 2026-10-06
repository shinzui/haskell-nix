---
id: 17
slug: upgrade-every-ephemeral-postgresql-consumer-to-stable-cleanup-roots
title: "Upgrade every ephemeral PostgreSQL consumer to stable cleanup roots"
kind: exec-plan
created_at: 2026-10-06T17:37:49Z
intention: "intention_01m3fw8cpte9xtje3e5j7f2ng2"
master_plan: "docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md"
provenance:
  created_by:
    model: "gpt-6.1-sol"
    harness: "codex"
    at: 2026-10-06T17:37:49Z
  revisions:
    - model: "gpt-6.1-sol"
      harness: "codex"
      at: 2026-10-06T17:44:11Z
      mode: "implement"
      note: "Audit all registered consumers and stage stable-root source, release and Nix migrations"
---

# Upgrade every ephemeral PostgreSQL consumer to stable cleanup roots

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Retire ephemeral-pg 0.2 from all registered first-party consumers and their Nix recipes. Use published 0.3.1.0 and a stable per-effective-user temporary root so a later shell session can reclaim PostgreSQL clusters abandoned by a killed test consumer. Preserve live consumers, custom PostgreSQL settings, caches and permanent databases. This user-requested extension runs independently of the remaining package-set projection work; it supplies revised source/release inputs to plans 8 and 9.


## Progress

- [x] (2026-10-06) Locate upstream through Mori; verify published 0.3.1.0 metadata and peeled release tag `e38175c155c71a77284d3f4b321726755cdb1de8` against Hackage/GitHub.
- [x] (2026-10-06) Read the cleanup guide and source; search local ephemeral-pg, Seihou module and agent-template repositories for a dedicated migration. None was found in those scoped repositories.
- [x] (2026-10-06) Audit registered shinzui/tan source trees as well as reverse-dependency declarations; identify stale bounds, freezes, Nix recipes and configless/default-root starts.
- [x] (2026-10-06) Add an explicit shared policy floor of 0.3.1.0; the existing 450-package freeze satisfies it with zero downgrades.
- [x] (2026-10-06) Implement first batch: En, Kawa, Shiki, Shomei, Keiro benchmarks and Shibuya PGMQ adapter; 23 initial files, then required Shomei pg-migrate family alignment. Formatting parses all modified Haskell files. En/Kawa/Shiki/benchmark/adapter dependency solves select 0.3.1.0; Shomei solve is being repaired through admitting pg-migrate 1.2.
- [x] (2026-10-06) Implement second batch: Keiei/Kizashi/Meibo exact source pins; PGMQ aliasing fixture; Shibuya MessageDB adapter, MessageDB-HS, MLS and registration-service configuration/bounds. Formatting passes. Three adapter fixtures now also stop their owned server during normal resource teardown.
- [ ] Compile/test every changed consumer and verify stable-root behavior across different TMPDIR sessions, including killed-owner cleanup while retaining a live consumer.
- [ ] Regenerate MLS and Koyomi freezes through held-pin solves, preserving unrelated selections; update the old Koyomi index cutoff only as required to admit the release.
- [ ] Complete the shared/standalone Nix recipes and targeted Darwin/Linux checks. Channel guard tests currently pass 61 cases; full acceptance is pending.
- [ ] Publish gated Kioku 0.8.0.2, Relay 0.1.1.2 and Shikumi cache-postgres 0.1.3.2 compatibility patches through their release skills; refresh only their channel generations and the shared cohort afterward.
- [ ] Commit verified consumer changes with canonical trailers, push authorized repositories, update the session retrospective and final audit. Mori push/deployment remains a separate coordinated step.


## Surprises & Discoveries

- 2026-10-06: startup sweeping defaults to enabled, but its search is confined to `temporaryRoot`. With an unset root, per-session TMPDIR makes the feature miss prior abandoned instances. 0.3.1.0 exports the needed cached config-taking bracket.
- 2026-10-06: source scanning finds additional projects absent from declared reverse dependencies. Recorded Cabal selections were already 0.3.1 for Rei/Mori/mori-rei-app, but their startup helpers still used default roots. Version-only checks would miss the cleanup failure.
- 2026-10-06: Keiro, Kiroku and pg-migrate already have stable UID roots and 0.3.1 bounds; Kioku's migrated fixtures delegate to Keiro, so its remaining bare fixture should use the same root rather than introducing a new public Keiro API.
- 2026-10-06: Shomei's old pg-migrate-test-support 1.1 cap rejects ephemeral-pg 0.3. Published 1.2 is the admitting coherent family; its core/CLI/embed APIs are unchanged, while test support changes the public Config dependency and adds a stable default config. Update coupled Shomei bounds and Nix pins rather than lifting the old cap.
- 2026-10-06: a benchmark `all --enable-tests` solve activates tests in a source-pinned dependency whose test-support package is not included. Its executable-only solve with dependency tests disabled passes; preserve this distinction in validation claims.
- 2026-10-06: host load exceeded 430 during concurrent builds. Workers now run their owned jobs sequentially with Cabal `-j2`, Nix `--max-jobs 2 --cores 2`, and test RTS `-N2`; no daemon settings or unrelated user jobs are changed.


## Decision Log

- Decision (user, 2026-10-06): upgrade all projects to ephemeral-pg 0.3 and adopt the cleanup configuration. Require at least 0.3.1.0 because it exports `withCachedConfig`; use `<0.4` for consumer compatibility bounds.
- Decision (2026-10-06): use short `/tmp/ephpg-<project>-<effectiveUid>` roots, shared across a project's suites, preserving caller settings. Retain default-enabled sweeping. Existing stable helpers are reused; copied packaged helpers must select the same root.
- Decision (2026-10-06): keep unrelated dependency pins and user edits intact. Freeze updates use actual Cabal solves; never claim a manually edited version constraint proves compatibility. Minimal coupled pg-migrate updates are part of this migration.
- Decision (2026-10-06): ownership is divided among channel recipes, main family consumers, runtime library releases and the remaining first-party consumers. Only owning agents edit those paths; root owns shared policy, inventories and this living plan.


## Outcomes & Retrospective

Implementation is in progress. The shared freeze already selects 0.3.1.0, and staged source migrations now address the configuration problem rather than version strings alone. Consumer tests, actual held-pin freeze regeneration, runtime publications and channel acceptance remain required. No fleet-wide migration or deployment completion is claimed.


## Context and Orientation

The shared floor lives in `cabal/policy-floors.json`, the accepted selection in `cabal/cohort.freeze`, and Nix policy in `overlays/registry.nix`. [ADR 2](../adr/2-resolve-the-rei-family-cohort-upgrade-only.md) requires upgrade-only selection and records the stable-root configuration contract. No separate local cleanup ADR existed before this extension.

Upstream is `mori://shinzui/ephemeral-pg`; its guide is available through `mori://shinzui/ephemeral-pg/docs/guides`, project-relative path `temporary-roots-and-stale-cleanup.md` (artifact-level URI pending). `src/EphemeralPg.hs` exports Config, Database, StartError, withConfig, withCachedConfig and sweepStaleInstances. `src/EphemeralPg/Config.hs` defines temporaryRoot and sweepStaleOnStart. A temporary root is the allocation/sweep boundary, not the reusable initdb cache. Effective UID distinguishes developer and Nix sandbox users.

Runtime owners are `mori://shinzui/keiro`, `mori://shinzui/kiroku`, `mori://shinzui/kioku`, `mori://shinzui/shikumi`, `mori://shinzui/pg-migrate` and `mori://shinzui/relay-pagination`. Consumer owners include `mori://shinzui/rei`, `mori://shinzui/mori`, `mori://shinzui/mori-app`, `mori://shinzui/mori-rei-app`, `mori://shinzui/en`, `mori://shinzui/kawa`, `mori://shinzui/shiki`, `mori://shinzui/shomei`, `mori://shinzui/keiro-benchmarks`, `mori://shinzui/pgmq-hs`, `mori://shinzui/shibuya-pgmq-adapter`, `mori://shinzui/shibuya-message-db-adapter`, `mori://tan/message-db-hs`, `mori://tan/mls-service-v2` and `mori://tan/registration-service-v2`. Also audit source pins in `mori://shinzui/keiei`, `mori://shinzui/kizashi` and `mori://shinzui/meibo`, and the freeze in `mori://shinzui/koyomi`. Resolve checkout paths through Mori rather than assuming repo layouts.


## Plan of Work

First enumerate consumers from registry dependents and a scoped source scan of registered first-party paths. Read AGENTS instructions and preserve initial status. Record each real dependency, source pin, version constraint, startup and existing helper. Do not treat documentation fixtures or unrelated temporaryRoot variables as consumer evidence.

Next replace configless startup with config-taking brackets, or add stable-root configuration to start/startCached while preserving settings. Add directory/unix dependencies only to components using those imports. Existing stable helpers, including PGMQ's ephemeralConfig and pg-migrate's defaultEphemeralConfig, take precedence over new implementations. Require 0.3.1 and retain safe normal teardown.

Then update exact Nix recipes and held-pin freezes. Shared channel source replacement retires automatically once the generated layer supplies at least 0.3.1. Runtime compatibility releases go through their existing skills; after publication, append scoped channel generations and regenerate the cohort with recorded new inputs. Preserve historical generations.

Finally run targeted compilation/suites, a cross-session killed-owner probe and the channel gates. Commit only owned files, leaving unrelated changes intact. Re-scan current source/selection evidence and record any unavailable checks explicitly before claiming completion.


## Concrete Steps

From this checkout:

```bash
mori registry dependents shinzui/ephemeral-pg --packages --json
mori registry list --json
mori registry show shinzui/ephemeral-pg --full
curl -fsSL https://hackage.haskell.org/package/ephemeral-pg-0.3.1.0/ephemeral-pg.cabal
git ls-remote --tags https://github.com/shinzui/ephemeral-pg.git v0.3.1.0 'v0.3.1.0^{}'
```

Use `mori path mori://<namespace>/<project>` to locate each consumer. Within that project, run the modified component's build/test command with bounded jobs:

```bash
cabal build all --dry-run --enable-tests
cabal build TARGET -j2
cabal test TEST_TARGET -j2 --test-show-details=direct --test-options='+RTS -N2 -RTS'
git diff --check
```

Use existing Nix shells for native inputs when required, with `--max-jobs 2 --cores 2`. Root staging receipts are `/tmp/mp3-ephemeral-consumer-edits.json` and `/tmp/mp3-ephemeral-remaining-edits.json`; their scripts reject input changes before applying. Runtime audit is `/tmp/mp3-ephpg-runtime-audit.json`. Main consumer gates preserve logs in `/tmp/mp3-ephemeral-consumer-gates-limited`. These are session evidence; durable summaries belong here.


## Validation and Acceptance

Each current dependency plan and Nix selection must use at least 0.3.1.0. Actual modified components must compile, and their applicable database suites must pass. Bounds/formatter checks alone are not compilation evidence. Every startup must reach a stable effective-UID root or a verified existing helper, preserving custom settings and enabled sweeping.

For behavior, start a test-owned database through an actual modified helper in a private test setup, kill only its consumer, change TMPDIR and start again. The next run must stop/reclaim the abandoned owned server/data while keeping a concurrently live consumer connectable. Do not kill or remove production processes/directories. Cache, socket and permanent-data exclusions remain unchanged. Record absent environments or other blockers; never substitute a source scan for a passing behavior probe.


## Idempotence and Recovery

Staged edit scripts compare exact inputs and affect only reviewed paths. Repeating a completed migration must not append duplicate helpers or imports; re-audit before extending scripts. Interrupted builds retain logs/caches and may resume with bounded jobs. Release retries verify existing tags and Hackage bytes instead of overwriting published artifacts. Keep historical inventories/generations intact, preserve unowned edits, and restore only known task-owned temporary files after a failed freeze solve.


## Interfaces and Dependencies

Use `EphemeralPg.Config`, `EphemeralPg.withConfig` and `EphemeralPg.withCachedConfig`; `temporaryRoot` is assigned through `Data.Monoid.Last (Just root)`. Obtain the effective UID through `System.Posix.User.getEffectiveUserID` and create roots with `System.Directory.createDirectoryIfMissing`. Wrappers retain `(Database -> IO a) -> IO (Either StartError a)` behavior; configuration modifiers retain `Config -> IO Config`. Caller-specific database names/settings remain intact.

Plan 8 continues to own the solver/freeze; plan 9 owns Nix projection; plan 10 owns shared policy. This extension owns cross-project cleanup configuration and compatibility publications. It has no hard prerequisite, but its new release/input selections must be reflected by those owners before their final acceptance or consumer deployment.
