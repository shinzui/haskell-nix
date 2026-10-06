# Resolve the Rei family cohort upgrade-only

Status: Accepted for implementation; published-cohort acceptance is pending.

Date: 2026-10-05

## Context

The Rei family currently records different Cabal and Nix dependency selections. Aligning
them must preserve versions already in use and make subsequent dependency changes explicit.
The selected first-party snapshots and the user's Effectful 2.7 requirement also constrain
the result. A successful application build alone cannot prove that another application's
dependencies have not been downgraded.

## Decision

Inventory contributor revisions and supported configurations explicitly, including local
packages and library, executable, test, benchmark and build-tool dependencies. Generate one
union stub from those declarations. Exclude contributor-owned packages and documented
dependencies vendored into consumers; preserve their provenance in the inventory.

For each released package, take the highest observed Hackage version across fresh contributor
plans, the recorded channel, deployed binaries, selected default first-party snapshots and
user policy floors. GHC boot packages follow the recorded compiler. A Git-only version does
not establish a Hackage floor. Retain exact source identities separately, including intentional
forks, rather than pretending that equal version strings imply equal sources.

Use distinct policy floors of Effectful 2.7.1.0 and effectful-core 2.7.1.1, and Random 1.3.1
(the user's 2026-10-05 decision to move above 1.3), and ephemeral-pg 0.3.1.0
(the user's 2026-10-06 decision to retire 0.2 and fix abandoned-cluster cleanup). Observed versions
can raise these floors further. Do not bridge these policy floors with allow-newer. Resolve a
conflict through an admitting release or a documented scoped exception for another package;
record the declared bound, compatibility evidence and retirement condition. Never silently
lower a floor or remove a capped dependency from the solve.

Write sorted version-only constraints with exactly one recorded index-state. Retain sources,
Cabal metadata, flags and dependency edges in the accompanying source manifest. Report every
missing or downgraded required package, policy target, consumer cap, selected first-party lag
and source pin. A freeze-only solve must reproduce the versions and manifest.

Routine targeted updates start from that freeze, unlock only requested package names and
hold unrelated versions exact. A conflict reports the need for explicit transitive unlocks
before changing the request. Retain the index-state, toolchain and contributor revisions.
Stage outputs, reject concurrent recorded-input changes and validate before promotion. Report
version, source, metadata, flag and policy changes with reverse paths to affected components.
An application update also retains the runtime projection unless explicitly updating runtime
dependencies, as specified by [ADR 7](7-compose-applications-on-retained-keiro-runtime-baselines.md).

The shared updater owns this model, parser and impact report. Nix generation and runtime
composition extend these interfaces. Broad cohort refresh remains an explicit operation.
Inventory capture stages observations and a review receipt by default. Explicit refresh
rejects removed or lowered historical floors, checks complete captured input membership and
bytes, and restores recorded files if promotion fails. A fresh observation is not permission
to discard a historical floor merely because it makes the union harder to solve.

## Alternatives and consequences

Taking the lowest common version would make alignment easier while regressing working
consumers. Independent application solves cannot establish one shared selection. A broad
update on every application change would repeatedly invalidate unrelated dependencies.

The union stub establishes a candidate selection; actual consumers still need to resolve and
compile with their supported flags and components. Version agreement alone does not establish
equal build inputs or cache reuse. [ADR 5](5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md)
defines the additional manifest, exact-binary and fresh-worker evidence.

## Validation

Plan 8 owns the inventories, freeze, report and targeted-update acceptance. Shared tests cover
maximum floors, excluded dependencies, Git-only sources, capped bounds, downgrade failures,
freeze normalization, unrelated-pin isolation, runtime ownership and transitive component
impact. The integrated implementation passes 88 updater tests and 13 Python regression tests.

Completion also requires a published-package solve, a zero-downgrade report, a deliberately
lowered-version negative report, a matching freeze-only plan, targeted-update conflict and
isolation experiments, and byte-identical regeneration. The earlier 450-package checkpoint
passed the published solve, zero-downgrade report, negative downgrade, freeze-only replay,
targeted identity isolation, real conflict experiment and byte-identical regeneration.
The new Random policy and refreshed stock observations now pass coherent regeneration:
450 selections, zero downgrades, Random 1.3.1, matching freeze/source replay and byte-identical
second regeneration. Exact released-source checks justify three scoped non-Effectful bound
exceptions; the full Nix gate remains pending. Plan 9 owns Nix generation and
build/cache evidence; consumer adoption is separate.


Implementation clarification (2026-10-05): explicit `cabal/policy-roots.json` records dependencies needed by supported configurations whose parent flags cannot all be selected in one union solve, with canonical owners and reasons. Both PostgreSQL discovery helpers remain roots; choosing one parent flag does not remove the other configuration's recorded floor. Solve/check/update commands select the stock compiler binaries independently of updater-shell libraries, so third-party source hashes, metadata and flags are captured in the manifest rather than hidden as pre-existing registrations.

Implementation clarification (2026-10-06): explicit roots also retain historical observed libraries when newer transitive dependencies stop selecting them. Basement, memory and old-time remain at or above their recorded floors even after fresh stock inventories classify them as configured Hackage dependencies. A missing selection remains a downgrade; removing an old transitive edge does not authorize discarding its historical floor.

Cleanup configuration (2026-10-06): adopting ephemeral-pg 0.3.1.0 also requires consumers to set a short, stable, effective-user-ID-specific `temporaryRoot`, shared by their suites across shell sessions, and retain enabled startup sweeping. Configless `with`/`withCached` wrappers inherit a changing `$TMPDIR` and cannot implement this contract. Use config-taking wrappers or existing stable configuration helpers while preserving custom PostgreSQL settings. The reference implementation and guide belong to `mori://shinzui/ephemeral-pg`; project-relative path `docs/guides/temporary-roots-and-stale-cleanup.md` (artifact-level URI pending). [Plan 17](../plans/17-upgrade-every-ephemeral-postgresql-consumer-to-stable-cleanup-roots.md) tracks cross-project configuration adoption and release evidence.
