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
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-08T04:24:34Z
      mode: "implement"
      note: "Resume legacy compatibility migrations and concurrent cleanup acceptance"
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
- [x] (2026-10-06) Validate and commit En (`c3ee100`) and Shomei (`0eedad1`): En integration scenarios and lookup-spike compilation pass; Shomei migration tests, test-support and server compilation pass with published pg-migrate 1.2 and ephemeral-pg 0.3.1. Repository formatting hooks pass; unrelated En manifest edits remain untouched.
- [x] (2026-10-06) Main Mori/Rei consumer gates pass 4,554 tests; actual modified Mori helper reclaims a killed owner's server/data across different TMPDIR sessions. Concurrent-live-consumer protection still needs explicit probe evidence.
- [x] (2026-10-06) Regenerate MLS freeze through a held-pin solve: ephemeral-pg 0.2.2 becomes 0.3.1; 426 other versions remain unchanged; filelock 0.1.1.9 is the only added package.
- [x] (2026-10-07) Verify stable-root behavior through Mori's actual helper in three different TMPDIR sessions: killed-owner process/data reclamation, concurrent live-consumer SQL connectivity and normal teardown all pass. Durable harness: `scripts/verify-ephemeral-cleanup.py`; probe: `cabal/fixtures/ephemeral-cleanup-probe.hs`; receipt: `/tmp/mp3-ep17-live-retention.json`.
- [x] (2026-10-07) Backport only Keiei/Meibo's legacy test helpers; fresh whole-project solves retain every unrelated version and all Keiro/Kiroku/PG-migrate production unit identities. Both application migration fixtures and both five-assertion upstream PG helper suites pass. Commits: `f919e31` in `mori://shinzui/keiei`, `f0f4dec` in `mori://shinzui/meibo`.
- [x] (2026-10-07) Finish all remaining default database suites: Kizashi 233, codd-extras 10, PGMQ 100, Shibuya PGMQ adapter 177 and Kawa 37. Kawa's broker-only case retains its existing opt-in gate. The benchmark remains compile-only because it has no applicable suite.
- [x] (2026-10-07) Commit and push Keiei (`f919e31`), Meibo (`f0f4dec`) and Kizashi (`6ef0576`) cleanup adoption; unrelated Kizashi plan remains untouched.
- [x] (2026-10-07) Finish codd-extras: full Darwin Nix package build/check passes; ephemeral-pg target builds on Darwin and Linux. Commit `af5239e` records the source/recipe and writable build-owned initdb cache. GitHub rejects publication with HTTP 403 because the repository is archived; Kizashi uses the tested local checkout. The local commit is retained, and publication requires separately restoring write access.
- [x] (2026-10-06) Regenerate MLS and Koyomi freezes through held-pin solves. MLS retains 426 unrelated versions; Koyomi retains 310, all 56 ordered migration tuples and all 11 PostgreSQL assertions. Koyomi is pushed at `73bad36e968946efaaacd854d32b877d7aa35bcc`.
- [x] (2026-10-07) Complete shared/standalone recipes and targeted Darwin/Linux cleanup checks. The accepted full native channel gate and four compiler/channel cells remain valid; the Linux ephemeral-pg target passes, as do codd-extras's full native package and both platform dependency targets. EP-9 retains the generated-layer/parity/cache gates.
- [x] (2026-10-06) Publish and verify Kioku 0.8.0.2, Relay 0.1.1.2 and Shikumi cache-postgres 0.1.3.2 through their release skills: ten source packages, nine documentation archives, 22 suites and 1,305 tests passed. Exact source/Cabal/tag evidence is preserved in `/tmp/mp3-ep17-runtime-releases.json`.
- [x] (2026-10-06) Refresh the runtime channel generations and shared cohort at observed signed index `2026-10-06T21:15:24Z`; all ten release entries are admitted, with zero downgrades and verified replay/deterministic regeneration.
- [x] (2026-10-06) Remaining four consumers pass 1,363 tests plus eight exact-function configuration guards: MessageDB 22, registration 911, Shibuya MessageDB adapter 37 and MLS 393. Commits are clean; MessageDB uses an external working toolchain because its own private dependency host is unavailable. The two archived consumers retain their historical cutoffs through an exact published ephemeral-pg source pin.
- [x] (2026-10-06) Root batch compilation completes for all seven targets after retries: Shibuya PGMQ explicitly enables tests; Kawa uses its declared native Kafka shell. En/Shomei/Shiki database suites pass; PGMQ/adapter/benchmark/Kawa compilation alone does not claim those suites ran.
- [x] (2026-10-07) Commit verified consumer changes with canonical trailers, push writable authorized repositories and finalize the audit. Registered current shinzui/tan source bounds and explicit local dependency paths contain no old `<0.3` ephemeral-pg bounds. Receipts: `/tmp/mp3-ep17-final-old-bounds.json` and `/tmp/mp3-ep17-local-dependency-audit.json`. Archived codd-extras publication is unavailable as recorded above; Mori push/deployment remains a separate coordinated step.


## Surprises & Discoveries

- 2026-10-07: the Codd helper passes all ten Cabal assertions but its full Nix check exposes a separate cache boundary: default HOME is `/homeless-shelter` and read-only. Supply a build-owned `XDG_CACHE_HOME` in `preCheck`, keeping the stable effective-UID instance root separate and preserving developer caches. The sandbox check also supplies PostgreSQL through the generic builder's `testToolDepends` and bounds test runtime to two capabilities.

- 2026-10-07: Kizashi loads the unregistered `mori://shinzui/codd-extras` through `cabal.project.local`. Both of that helper's startup paths and its ephemeral-pg bound need migration. Its standalone Nix recipe also needs the admitting Hasql dependency scope; consume the pinned shared channel rather than duplicating its third-party fixes. The unused Kiroku test-support source goal is absent from every Kizashi component dependency and can be removed without changing its runtime.
- 2026-10-07: old Keiro/PG-migrate test helpers can be backported locally without advancing their persistent migration packages. Baseline/candidate solves change only ephemeral-pg, filelock and the two local helper patch versions; production unit identities remain equal. The local packages are explicitly unpublished, with recorded upstream source revisions and a retirement contract.

- 2026-10-06: startup sweeping defaults to enabled, but its search is confined to `temporaryRoot`. With an unset root, per-session TMPDIR makes the feature miss prior abandoned instances. 0.3.1.0 exports the needed cached config-taking bracket.
- 2026-10-06: source scanning finds additional projects absent from declared reverse dependencies. Recorded Cabal selections were already 0.3.1 for Rei/Mori/mori-rei-app, but their startup helpers still used default roots. Version-only checks would miss the cleanup failure.
- 2026-10-06: Keiro, Kiroku and pg-migrate already have stable UID roots and 0.3.1 bounds; Kioku's migrated fixtures delegate to Keiro, so its remaining bare fixture should use the same root rather than introducing a new public Keiro API.
- 2026-10-06: Shomei's old pg-migrate-test-support 1.1 cap rejects ephemeral-pg 0.3. Published 1.2 is the admitting coherent family; its core/CLI/embed APIs are unchanged, while test support changes the public Config dependency and adds a stable default config. Update coupled Shomei bounds and Nix pins rather than lifting the old cap.
- 2026-10-06: a benchmark `all --enable-tests` solve activates tests in a source-pinned dependency whose test-support package is not included. Its executable-only solve with dependency tests disabled passes; preserve this distinction in validation claims.
- 2026-10-06: host load exceeded 430 during concurrent builds. Workers now run their owned jobs sequentially with Cabal `-j2`, Nix `--max-jobs 2 --cores 2`, and test RTS `-N2`; no daemon settings or unrelated user jobs are changed.
- 2026-10-06: pg-migrate 1.2 is already published and accepted by the shared cohort; this extension adopts that existing release. Koyomi still freezes pg-migrate 1.1 through Keiro migrations 0.15 and Kiroku migrations 0.4. Kiroku migrations 0.5 admits 1.2 without SQL changes, but Keiro migrations through 0.18 still require the older family. Keiro migrations 0.19 also adds Kiroku migration 0012 and requires newer writers. Failed held-pin solves restored all Koyomi inputs; its cleanup upgrade needs an explicit compatibility route rather than silently replacing the persistent migration plan.
- 2026-10-06: Relay 0.1.1.2 is published and verified after 133 tests and native release gates. Shikumi cache-postgres passes 705 tests including required PostgreSQL/Redis backends; remaining release gates and Kioku publication are pending. Shared channel guard fixtures pass 65 cases; targeted Darwin GHC 9.12/9.14 checks pass, while full native and Linux gates remain running.


## Decision Log

- Decision (2026-10-07): use narrowly vendored, application-owned cleanup backports for Keiei/Meibo's test-only helpers, retaining their exact runtime pins and migration composition. Record local patch versions, upstream source revisions, retained tests and retirement conditions in each consumer's `test/compat`. Do not lift bounds on the old helpers or represent the copies as upstream releases. ADR 2 records the durable compatibility contract.

- Decision (user, 2026-10-06): upgrade all projects to ephemeral-pg 0.3 and adopt the cleanup configuration. Require at least 0.3.1.0 because it exports `withCachedConfig`; use `<0.4` for consumer compatibility bounds.
- Decision (2026-10-06): use short `/tmp/ephpg-<project>-<effectiveUid>` roots, shared across a project's suites, preserving caller settings. Retain default-enabled sweeping. Existing stable helpers are reused; copied packaged helpers must select the same root.
- Decision (2026-10-06): keep unrelated dependency pins and user edits intact. Freeze updates use actual Cabal solves; never claim a manually edited version constraint proves compatibility. Minimal coupled pg-migrate updates are part of this migration.
- Decision (2026-10-06): ownership is divided among channel recipes, main family consumers, runtime library releases and the remaining first-party consumers. Only owning agents edit those paths; root owns shared policy, inventories and this living plan.


## Outcomes & Retrospective

Implementation is complete for the cleanup migration's source, dependency and build acceptance. The actual Mori helper reclaims a killed owner's server/data across three TMPDIR sessions while retaining a concurrent live SQL connection and normal teardown. Legacy Keiei/Meibo fixtures pass with narrowly owned test-helper backports; whole-project comparison retains every unrelated selection and all production Keiro/Kiroku/PG-migrate unit identities. Keiei (`f919e31`), Meibo (`f0f4dec`) and Kizashi (`6ef0576`) are pushed.

The final default suites pass: Kizashi 233, codd-extras 10, PGMQ 100, Shibuya PGMQ adapter 177 and Kawa 37; both legacy application migration fixtures and both five-assertion PG helper suites also pass. Kawa's broker-only case remains opt-in and the benchmark has compilation evidence only. codd-extras's full native Nix build/check and Darwin/Linux ephemeral-pg targets pass. Its six scoped files are committed at `af5239e` in `mori://shinzui/codd-extras`; GitHub rejects push with HTTP 403 because the repository is archived. This is an explicit publication limitation: Kizashi uses the validated local package, and restoring remote write access is separate administration. Existing effective lock-input identities remain unchanged; only the immutable shared dependency channel is added.

The shared freeze selects 0.3.1.0 and ten runtime cleanup packages are published and live-verified after 1,305 tests. Their channel refresh is pushed, and the cohort incorporates the used releases at signed index `2026-10-06T21:15:24Z`, with zero downgrades and verified replay/deterministic regeneration. Koyomi retains all 56 ordered migration tuples, 310 unrelated versions and 11 passing PostgreSQL assertions. Final scoped audits include registered source trees and their explicit local dependencies; both old-bound receipts are empty. The durable probe and ADR 2 preserve the operational contract beyond temporary receipts. EP-9's generated layer, remote cache publication and application deployment remain their own acceptance gates.


## Context and Orientation

The shared floor lives in `cabal/policy-floors.json`, the accepted selection in `cabal/cohort.freeze`, and Nix policy in `overlays/registry.nix`. [ADR 2](../adr/2-resolve-the-rei-family-cohort-upgrade-only.md) requires upgrade-only selection and records the stable-root configuration contract. No separate local cleanup ADR existed before this extension.

Upstream is `mori://shinzui/ephemeral-pg`; its guide is available through `mori://shinzui/ephemeral-pg/docs/guides`, project-relative path `temporary-roots-and-stale-cleanup.md` (artifact-level URI pending). `src/EphemeralPg.hs` exports Config, Database, StartError, withConfig, withCachedConfig and sweepStaleInstances. `src/EphemeralPg/Config.hs` defines temporaryRoot and sweepStaleOnStart. A temporary root is the allocation/sweep boundary, not the reusable initdb cache. Effective UID distinguishes developer and Nix sandbox users.

A backport here is a local, unpublished copy of an exact upstream test-helper revision with only cleanup configuration, dependencies and an explicit patch version changed. Each consumer owns `test/compat`, retains upstream tests/provenance and retires the copy when its runtime admits the released replacement; its production migration packages remain pinned.

Runtime owners are `mori://shinzui/keiro`, `mori://shinzui/kiroku`, `mori://shinzui/kioku`, `mori://shinzui/shikumi`, `mori://shinzui/pg-migrate` and `mori://shinzui/relay-pagination`. Consumer owners include `mori://shinzui/rei`, `mori://shinzui/mori`, `mori://shinzui/mori-app`, `mori://shinzui/mori-rei-app`, `mori://shinzui/en`, `mori://shinzui/kawa`, `mori://shinzui/shiki`, `mori://shinzui/shomei`, `mori://shinzui/keiro-benchmarks`, `mori://shinzui/pgmq-hs`, `mori://shinzui/shibuya-pgmq-adapter`, `mori://shinzui/shibuya-message-db-adapter`, `mori://tan/message-db-hs`, `mori://tan/mls-service-v2` and `mori://tan/registration-service-v2`. The additional unregistered helper `mori://shinzui/codd-extras` is located through Kizashi's `cabal.project.local`; its owning Git remote confirms the canonical project identity. Also audit source pins in `mori://shinzui/keiei`, `mori://shinzui/kizashi` and `mori://shinzui/meibo`, and the freeze in `mori://shinzui/koyomi`. Resolve checkout paths through Mori rather than assuming repo layouts.


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


The committed live-retention harness runs from this repository against Mori's actual helper:

```bash
python3 scripts/verify-ephemeral-cleanup.py \
  --cwd "$(mori path mori://shinzui/mori)" \
  --helper mori://shinzui/mori/packages/mori-core \
  --receipt /tmp/mp3-ep17-live-retention.json -- \
  cabal exec -- runghc -XGHC2024 -imori-core/test \
  "$PWD/cabal/fixtures/ephemeral-cleanup-probe.hs"
```

It prints `PASS: cross-session orphan reclaimed; concurrent live consumer retained`.
All three consumers and their servers belong to the probe. The receipt records
the command, stable root, distinct TMPDIRs, orphan reclamation, live SQL query and
normal process/data teardown. Keiei and Meibo use their local `test/compat`
packages in `cabal.project`; run their application migration suite and
`pg-migrate-test-support-test` with Cabal `-j2`. Their README and `sources.json`
record the backport ownership, upstream revisions and retirement contract.


## Validation and Acceptance

Each current dependency plan and Nix selection must use at least 0.3.1.0. Actual modified components must compile, and their applicable database suites must pass. Bounds/formatter checks alone are not compilation evidence. Every startup must reach a stable effective-UID root or a verified existing helper, preserving custom settings and enabled sweeping.

For behavior, start a test-owned database through an actual modified helper in a private test setup, kill only its consumer, change TMPDIR and start again. The next run must stop/reclaim the abandoned owned server/data while keeping a concurrently live consumer connectable. Do not kill or remove production processes/directories. Cache, socket and permanent-data exclusions remain unchanged. Record absent environments or other blockers; never substitute a source scan for a passing behavior probe.


## Idempotence and Recovery

Staged edit scripts compare exact inputs and affect only reviewed paths. Repeating a completed migration must not append duplicate helpers or imports; re-audit before extending scripts. Interrupted builds retain logs/caches and may resume with bounded jobs. Release retries verify existing tags and Hackage bytes instead of overwriting published artifacts. Keep historical inventories/generations intact, preserve unowned edits, and restore only known task-owned temporary files after a failed freeze solve.


## Interfaces and Dependencies

Use `EphemeralPg.Config`, `EphemeralPg.withConfig` and `EphemeralPg.withCachedConfig`; `temporaryRoot` is assigned through `Data.Monoid.Last (Just root)`. Obtain the effective UID through `System.Posix.User.getEffectiveUserID` and create roots with `System.Directory.createDirectoryIfMissing`. Wrappers retain `(Database -> IO a) -> IO (Either StartError a)` behavior; configuration modifiers retain `Config -> IO Config`. Caller-specific database names/settings remain intact.

Plan 8 continues to own the solver/freeze; plan 9 owns Nix projection; plan 10 owns shared policy. This extension owns cross-project cleanup configuration and compatibility publications. It has no hard prerequisite, but its new release/input selections must be reflected by those owners before their final acceptance or consumer deployment.


End-of-day clean checkpoint (2026-10-06): `mori://shinzui/koyomi` tested upgrade is committed and pushed at `73bad36e968946efaaacd854d32b877d7aa35bcc`. All 56 ordered migration tuples are identical, all 11 real PostgreSQL assertions pass with stable per-UID cleanup root/default sweep, and 310 unrelated frozen versions remain. Receipt `/tmp/mp3-ep17-koyomi-evidence/acceptance.json`. Its remaining dirty paths are pre-existing user work. Blocked candidate ephemeral-pg pins in `mori://shinzui/keiei`, `mori://shinzui/kizashi` and `mori://shinzui/meibo` were restored to their prior committed state for the requested clean stop. Resume after compatible helper backports; candidate revision is `e38175c155c71a77284d3f4b321726755cdb1de8`, replacing Keiei/Meibo `215e4ae5fc844d322e2c715369bf5ec4ff285294` and Kizashi `304c160f25570ea5e225baf5024778c93f434b56`. No legacy adoption is claimed.
