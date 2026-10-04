---
id: 14
slug: deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
title: "Deploy one channel revision from dotfiles and guard closure parity"
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
      note: "Original review found static-link/follows guard failures, invalid single-app test and missing measured reuse; applied findings in update."
---

# Deploy one channel revision from dotfiles and guard closure parity

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Five Haskell applications, the "Rei family", are deployed to one Mac from the dotfiles
repository `mori://shinzui/dotfiles.nix` (checked out at `/Users/shinzui/.config/dotfiles.nix`):
`mori://shinzui/rei`, `mori://shinzui/mori`, `mori://shinzui/mori-rei-app`,
`mori://shinzui/reiko` and `mori://shinzui/mina`. Earlier plans of this initiative moved each
of them onto one shared package set: one Cabal freeze file in this repository
(`cabal/cohort.freeze`) and a Nix channel generated from it. What those plans cannot
guarantee is that the deployed machine actually runs the versions each application was
tested with. Today dotfiles lets every application bring its own revision of this repository
(the "channel"), so on 2026-09-26 the deployed system mixed four channel revisions, and the
same library was built two or three different ways inside one system: `rei` and
`mori-rei-app` each carried their own `rei-core`, `kioku-core` and `baikai` store paths.
Nothing noticed, because nothing looks.

After this plan:

- dotfiles has one root channel input that the five applications follow by default, so a
  plain update converges them on one channel revision, while a hotfix to one application can
  still be deployed on a newer channel without moving the other four (by removing that one
  application's `follows` line, as documented in `flake.nix`);
- the update recipes in `justfile` move exactly the inputs they name (one application, the
  five together, or the channel) and never silently move the base `haskell-nix-dev`;
- `./bin/build.sh` runs a guard before it hands the user a system to activate. The guard is
  strict only about what makes a deployed binary wrong: it fails when a deployed
  application contains a Haskell package at a version different from the freeze published
  by the channel revision that application's own `flake.lock` pins (the package set its own
  tests ran on). Everything about fleet-wide uniformity is advisory: applications pinning
  different channel revisions, an application's pin differing from dotfiles' root channel,
  and a shared library (`rei-core`, `kioku-core`, `baikai`, `keiro`, `hasql`, `aeson`) having
  more than one store path across the applications are printed as warnings and never block.
  `HASKELL_PARITY=skip` bypasses the failures for emergencies.

To see it working, run `just verify-haskell-parity` in dotfiles after a build: it prints one
`ok:` line per passing check, any `PARITY WARN:` lines, and a closing
`parity: 0 failure(s), N warning(s)` line, and exits 0. Break it on purpose (Milestone 3
shows how, by giving the guard a doctored freeze with a wrong `aeson` version) and it prints
`PARITY FAIL: reiko closure differs from its freeze …` and exits 1, and `./bin/build.sh`
leaves `./result` pointing at the previous good system. Build one application on a different
channel revision whose freeze is identical (Milestone 3's second negative test) and the guard
only warns, exits 0, and the other four applications' store paths do not change.


## Review requirements (2026-10-04)

Plan 16 (`docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md`) is a transitive hard dependency through application plans 11–13. Preconditions require those applications to publish an exact runtime generation/configuration and complementary selections, plus matching Cabal/Nix projections. Record these runtime fields in the actual candidate system manifests and deploy/update reports. Compare used runtime dependency identities through plan 9's manifest modes; runtime membership does not imply every application links every component. Generation spread remains a fleet advisory warning, while a mismatch with the application's own selected runtime/cohort or missing evidence fails. The app-only experiment retains runtime generation/configuration/toolchain and complementary unrelated selections. Explicit runtime updates report affected apps; unrelated app or Baikai/Shikumi/OKF updates must not advance runtime records implicitly. No extra dependency back into production deployment is introduced for plan 16's fixture/cache acceptance.

Follow [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md): ordinary application edits retain the cohort and toolchain pins. Matching versions alone is insufficient evidence of reused builds. Historical input revisions, package counts and deletion lists below are starting observations; refresh them from recorded contributor revisions.

Plan 9 owns the shared `cohort-compare` app. Use `--freeze FILE_OR_URL --plan-json FILE` for a freshly generated Cabal plan and `--freeze FILE_OR_URL --nix-manifest FILE` for the executable's build evidence. Use `--compare-manifests FILE FILE` to compare build identities and `--resolve-channel-lock FILE --input-path PATH` to obtain a channel's full locked revision. The resolver starts at the lock's declared root and handles recursive array `follows`, string nodes, missing nodes and cycles. Check the Cabal import revision against the application's own resolved lock, rather than assuming a node named `haskell-nix` exists. Return 0 on success, 1 on drift or missing/unverifiable evidence, and 2 on usage error.

Export `packages.<system>.cohort-manifest` through plan 9's construction helper. Its JSON schema records the system, compiler/toolchain/channel, actual executable root drv/output and Haskell packages with names, versions, component roles, source/metadata identities, flags/policy and drv/output paths. Generate records from the actual composed scope used to build the executable, then verify dependency edges against that root's derivation graph through Nix metadata APIs. Runtime closures may omit static Haskell libraries; basename parsing and unrelated channel evaluation cannot prove parity. All instances of a Haskell package must pass, including when one correct and one incorrect version coexist. Missing expected dependencies fail. Native build tools and compiler packages are distinguished by role.

Refresh `plan.json` with tests and benchmarks enabled for supported configurations; check all non-local packages. Record own packages and non-Hackage source pins in the channel's declared policy and `cabal/cohort-sources.json` (exact source revision/subdirectory plus reasons and owners for intentional Cabal/Nix source or flag differences). Do not use arbitrary `--ignore` lists. Keep exact-binary release rehearsals: version parity alone does not establish flag/source or behavioral equivalence. Consumer checks are thin calls to shared tooling, with no fallback comparator.

The deployment guard keeps the user-approved policy: fleet-wide channel and shared identity differences warn; each application's own freeze mismatch or missing/unverifiable manifest fails. Initial alignment experiments additionally require shared identities to match wherever sources/toolchains/policy match. Obtain manifests from the actual dotfiles-composed application outputs and verify their executable roots are members of the candidate system before promotion; an application flake evaluated under another override is insufficient evidence. Never report a missing static library as “linked by no application” from its runtime absence.

Keep the application update path independent: before/after locks show the cohort and base unchanged; manifests show unchanged dependencies and the other four wrappers unchanged. For targeted cohort rollout use plan 8's impact report to name the affected application source updates; do not require every application HEAD to advance for an unrelated app edit. Preserve the explicit fleet refresh and explicit base update paths. Backups are restored on command failure or interrupt, preserving pre-existing lock edits. Pass Nix arguments as arrays or JSON arrays, not `$*` strings; handle empty overrides under `set -e`.

After plan 9's cache publication and consumer adoption, record before/after measurements on aarch64-darwin and x86_64-linux for repeated builds, documentation edits, leaf application edits, shared-library interface edits, targeted dependency updates and base updates. Separate evaluation, substitution/download, shared dependency compilation, application compilation/linking and tests. A fresh CI worker must substitute published shared outputs; application-only edits require zero avoidable shared dependency compilations. Record actual elapsed times, unexpected rebuilt paths and remaining bottlenecks; no invented latency budget. Do not mark the initiative complete while cache or update-isolation evidence is deferred. Use disposable checkouts/builders, with no production activation for experiments. ADR 6 is reserved for this plan; ADR 5 now records the update-isolation decision.

## Progress

- [ ] Fresh-worker cache substitution and measured update isolation pass on both supported systems

- [ ] M1: Confirm plans 11, 12 and 13 are complete; record each application's pushed head, its own locked channel revision and its freeze import; confirm each pinned revision publishes `cabal/cohort.freeze`; record the shared revision as `R` in the Decision Log (or record the spread if they differ).
- [ ] M1: Confirm the channel at `R` exposes plan 9's `cohort-compare` app, and record the base revision its own lock names (`B`) next to dotfiles' current `haskell-nix-dev`.
- [ ] M1: Confirm the dotfiles tree is safe to edit (no foreign `flake.lock` changes) and record the baseline shared-library table.
- [ ] M2: Add `bin/verify-haskell-parity.sh` (FAIL on version mismatch against each application's own freeze; WARN on revision spread, off-channel applications, base drift and store-path spread) and the `verify-channel-pins` / `verify-haskell-parity` recipes; show the pre-M3 verdict (warnings only, exit 0).
- [ ] M2: Commit the guard in dotfiles.
- [ ] M3: Add the root `haskell-nix` input (unpinned by URL, locked at `R` in `flake.lock`, following the unpinned root `haskell-nix-dev`); make the five inputs follow it (and `mori-rei-app` follow `rei` if it has a Rei flake input); leave `haskell-nix-dev` exactly as it is.
- [ ] M3: Lock the root channel at `R` without moving any application; prove a second `nix flake lock` is a no-op, that all five resolve to the root node, and that the guard passes on a scratch build.
- [ ] M3: Negative test N1: a doctored freeze (one wrong `aeson` version) makes the guard fail.
- [ ] M3: Negative test N2: one application built on a different channel revision with an identical freeze only warns, exits 0, and leaves the other four store paths unchanged.
- [ ] M3: Commit `flake.nix` and `flake.lock`.
- [ ] M4: Replace `_update-with-base` with `_gated-update`, per-application recipes that move one input, `update-rei-family` and `update-channel`; make `./bin/build.sh` build a candidate, run the guard (failures block, warnings print) and only then promote `./result`; make `darwin-rebuild-sungkyung.sh` refuse an unguarded `./result`; ignore `result-candidate`.
- [ ] M4: Commit the recipes and scripts.
- [ ] M5: `just update-rei-family` (build and guard pass); user activates with `sudo ./bin/darwin-rebuild-sungkyung.sh`.
- [ ] M5: Post-activation verification (real binaries, `:9091`, today's logs, `rei intention list` on the global database).
- [ ] M5: Commit the final `flake.lock`; update this plan and the MasterPlan; write the ADR in `docs/adr/`.


## Surprises & Discoveries

Observations made while drafting this plan on 2026-09-26 (re-verify at M1):

- Observation: The deployed lock is uncommitted. `/run/current-system` and `./result` are both
  `/nix/store/052klnd7w86rdwfcxbqnza21sny13bsd-darwin-system-26.11.57a3171`, built from the
  working-tree `flake.lock` (rei `880093cc`, mori-rei-app `2acd4ed4`), while the committed
  `HEAD:flake.lock` still has rei `03cc7b67` and mori-rei-app `a912fb4c`. The dirty lock is
  therefore a deploy someone made and has not committed, not scratch work. M1 handles this.
  Evidence: `git diff --stat flake.lock` → `295 insertions(+), 138 deletions(-)`. (The
  MasterPlan records that it was later committed as dotfiles `14e829b`, local and not pushed.)
- Observation: Thirteen dotfiles inputs consume this repository, on four channel revisions
  (working tree): rei and mori-rei-app `4cabd105`; mori and notion-hub `018d1e32`;
  reiko, mina, kizamu, kazuha, nihongo `b88d3173`; seihou, shiki, okf, notion-cli
  `7b696dc8`. There is no root `haskell-nix` input. None of these four revisions contains
  `cabal/cohort.freeze` (plan 8 creates it), so a pre-initiative application revision fails
  the guard's version check by construction: there is no freeze to compare it with.
- Observation: On aarch64-darwin a Haskell executable's runtime closure contains its Haskell
  libraries (`nix-store -qR` of `rei-cli-6.0.0.0` lists 561 paths, including
  `hasql-1.10.2.4`, `aeson-2.2.4.1`, `rei-core-6.0.0.0`). So the runtime closure, which is what
  ships, is enough for the guard; the build-time closure is not needed.
- Observation: The shared libraries already diverge inside today's system. Per application
  (first 8 characters of the store hash):

```text
rei           rei-core bbd8x2vj  kioku-core 9dpydaf6 (0.8.0.0)  baikai 6h7hmjim (0.7.1.0)  keiro rlc2hb7l (0.19)  hasql 07ddvfah  aeson zwryrac9
mori          -                  kioku-core q7w1ln75 (0.7.0.0)  baikai nj44p70c (0.7.0.0)  keiro damf47cm (0.18)  hasql 07ddvfah  aeson zwryrac9
mori-rei-app  rei-core qd9xjsyi  kioku-core k0kfcvqi (0.8.0.0)  baikai sgad6wyf (0.7.1.0)  keiro rlc2hb7l (0.19)  hasql 07ddvfah  aeson zwryrac9
reiko         -                  -                              -                          -                      -               aeson zwryrac9
mina          -                  -                              baikai g5gl40b3 (0.6.0.1)  -                      -               aeson zwryrac9
```

  Same version, different store path (rei-core, kioku-core and baikai between rei and
  mori-rei-app) is the overlay effect the MasterPlan describes; different versions (mori,
  mina) are the cohort lag plans 12 and 13 fix. Under the revised guard the first kind is a
  warning; the second kind fails only if it disagrees with the freeze the application itself
  pins.
- Observation: Every `nix eval` in dotfiles prints
  `warning: input 'mina/haskell-nix' has an override for a non-existent input 'haskell-nix-dev'`,
  because mina's channel `b88d3173` predates the `haskell-nix-dev` input. Following one root
  channel removes it.
- Observation: `bin/build.sh` is a single line with no shebang
  (`nix build .#darwinConfigurations.SungkyungM1X.system`), and
  `bin/darwin-rebuild-sungkyung.sh` is `./result/sw/bin/darwin-rebuild switch --flake .#SungkyungM1X $@`.
  darwin-rebuild re-evaluates and builds the flake itself and only borrows the
  `darwin-rebuild` binary from `./result`, so a guard in `build.sh` alone does not stop an
  unguarded activation. M4 adds a check to the activation script for that reason. The same
  fact rules out `--override-input` as a way to deploy one application off-channel: the
  override is not in `flake.nix` or `flake.lock`, so activation would evaluate without it.
- Observation: `sed` on this machine's PATH is GNU sed 4.10 (from the Nix profile), not BSD
  sed, so the macOS idiom `sed -i '' …` fails (GNU reads `''` as the script). The one `sed`
  in this plan (negative test N1) writes to a new file and needs no `-i`; the revised
  `update-channel` no longer edits `flake.nix` at all.


## Decision Log

- Decision (runtime plan, 2026-10-04): adopt the plan-16 integration contract above. It owns retained runtime selection/composition, while this plan retains its existing solver/generation/policy/consumer/deployment responsibility. Consumer plans 11–13 require runtime delivery before adoption; preparatory shared tools do not depend on consumers.

- Decision (2026-10-04 review update): adopt the Review requirements above and ADR 5's update-isolation/build-evidence contract. Historical closure-only acceptance, fixed package counts and duplicated comparison implementations are superseded where noted. Preserve the agreed advisory fleet guard and effectful migration policy. Implementation evidence remains pending.

- Decision: Only the five Rei-family inputs (rei, mori, mori-rei-app, reiko, mina) follow the
  root `haskell-nix` input. The other eight inputs that consume this repository (kizamu,
  seihou, kazuha, nihongo, shiki, okf, notion-cli, notion-hub) keep the channel revision their
  own locks choose.
  Rationale: Only the five import `cabal/cohort.freeze`; forcing the others onto the channel
  would change what they build without their Cabal side moving, which is the exact divergence
  this initiative removes. Bringing them in is a follow-up (see Outcomes).
  Date: 2026-09-26
- Decision (superseded later on 2026-09-26 by the user decision below): Pin the root
  `haskell-nix` input by revision in its URL, and also pin the root `haskell-nix-dev` input by
  revision, to the `haskell-nix-dev` revision the channel's own `flake.lock` records.
  Rationale at the time: with a revision in the URL, only `just update-channel` could move the
  channel, and the base deployed would provably equal the channel's own base.
  Date: 2026-09-26
- Decision (superseded later on 2026-09-26 by the user decision below): An application's own
  `flake.lock` and freeze import must pin the same channel revision as dotfiles, and the guard
  fails otherwise.
  Rationale at the time: a mismatch silently means the application's tests ran on a different
  package set than the one deployed.
  Date: 2026-09-26
- Decision: Version comparison against the freeze uses plan 9's shared script, run as a flake
  app from the channel; the cross-application store-path comparison lives in the dotfiles
  guard as a few lines of shell. If plan 9 has by then added a shared-path mode to
  `cohort-compare` (the MasterPlan's reconciliation note suggests one), call that instead;
  either way its result is only a warning.
  Rationale: The MasterPlan requires the version comparison logic to exist once, in this
  repository. The identity check is deploy-specific (it needs all five closures at once) and
  has no Cabal counterpart.
  Date: 2026-09-26
- Decision: Compare output store paths, not `.drv` paths, and print the `.drv` (via
  `nix-store -qd`) only as a diagnostic.
  Rationale: For ordinary (input-addressed) Nix derivations the output path is computed from
  the derivation, so equal output paths mean equal derivations (equal `drvPath`s); output
  paths are available straight from `nix-store -qR` of the deployed system, whereas `.drv`
  files may be absent for substituted paths.
  Date: 2026-09-26
- Decision: `./bin/build.sh` builds to `./result-candidate`, runs the guard, and only then
  points `./result` at the new system; `bin/darwin-rebuild-sungkyung.sh` refuses to activate
  when `./result` is not the system the flake currently evaluates to. `HASKELL_PARITY=skip`
  bypasses both with a loud warning. Only guard failures block; guard warnings are printed and
  the build is promoted.
  Rationale: The user activates whatever the flake evaluates to, not `./result`; tying the two
  together is the only way the guard actually guards. The bypass exists for emergency
  rollbacks to a lock recorded before the guard existed (such locks fail the version check,
  because their channels publish no freeze).
  Date: 2026-09-26
- Decision: This plan runs no database migration, and the guard does not check Kiroku
  migration state. The Kiroku safety condition (no Kiroku 0.8 writer deployed against a
  database whose migration ledger has Kiroku `0012`) is owned by plans 11 and 12, which check
  the ledger before and after each deploy (plan 12's Cases A, B and C).
  Rationale: The `0012` cutovers belong to plan 11 (applied to the global `rei` database on
  2026-09-26) and plan 12 (the `mori` database). By the time this plan runs, every
  application already runs a Kiroku 0.9 build, and this plan only changes how dotfiles pins
  them. The one way this plan could reintroduce a 0.8 writer is a rollback, which Idempotence
  and Recovery forbids across a cutover.
  Date: 2026-09-26
- Decision (user decision, 2026-09-26: "the strict guard is too restrictive"): The guard is
  strict only about what makes a deployed binary wrong and advisory about fleet-wide
  uniformity. It fails (blocking `./bin/build.sh` and activation, bypassable with
  `HASKELL_PARITY=skip`) when an application's deployed closure contains a Haskell package at a
  version different from the freeze published by the channel revision that application's own
  `flake.lock` pins, compared with `cohort-compare --freeze <that revision's freeze> --nix-manifest
  <path>`. It also fails when it cannot perform that comparison (the application's own lock
  has no locked `haskell-nix` input, its pinned revision publishes no freeze, the application
  is not in the system being checked, or `cohort-compare` exits with a usage error), because
  an unverifiable deploy is not a passing one. It only warns when the five applications pin
  different channel revisions, when an application's pin differs from dotfiles' root
  `haskell-nix`, when an application builds off-channel, when the channel's own base differs
  from dotfiles' `haskell-nix-dev`, when an application's `cabal.project` imports the freeze
  from a revision other than its lock's, when mori-rei-app's own lock pins a different Rei
  than dotfiles deploys, and when a shared library has more than one store path across the
  applications.
  Rationale: A revision difference or a second build of the same library costs cache and
  disk but does not change behavior; a version difference from what the application's own
  tests ran on does. Blocking on uniformity made a single-application hotfix on a newer
  channel impossible without moving the other four, which is exactly the coupling the user
  wants to avoid. Comparing each application with its own pinned freeze (rather than dotfiles'
  root) is what makes a converged fleet and a hotfixed application both pass while still
  catching a follows edge that silently builds an application on a channel whose versions
  differ from the ones it was tested with.
  Date: 2026-09-26
- Decision: Keep a root `haskell-nix` input that the five family inputs follow by default,
  declared without a revision in its URL (`github:shinzui/haskell-nix`) and locked in
  `flake.lock`, exactly like today's root `haskell-nix-dev`. `nix flake update haskell-nix`
  (or `just update-channel`) moves it; `nix flake lock --override-input haskell-nix
  github:shinzui/haskell-nix/<rev>` locks it at a chosen revision.
  Rationale: The default must converge: with `follows`, any update deploys the five on one
  channel revision without anyone remembering to. Pinning the revision in the URL was needed
  only while a revision mismatch was a failure; now that the guard checks versions per
  application, an unintended channel move by a broad `nix flake update` is caught where it
  matters (a version that differs from an application's own freeze fails) and merely warned
  about otherwise. Declaring it like `haskell-nix-dev` keeps one mental model and lets
  `update-channel` avoid editing `flake.nix` with `sed`.
  Date: 2026-09-26
- Decision: To deploy one application off-channel (for example a hotfix whose pushed head
  pins a newer channel than the other four), delete that application's
  `inputs.haskell-nix.follows = "haskell-nix";` line in `flake.nix`, leave a one-line
  `# OFF-CHANNEL since <date>: <reason>` comment in its place, and run `just update-<app>`.
  The application then builds on the channel its own `flake.lock` pins (the nested node Nix
  copies from the application's lock), still on dotfiles' base, and the guard warns
  `… is off-channel …` until the follows line is restored after `just update-channel`
  converges the family.
  Rejected alternatives: a per-application root input such as `haskell-nix-rei` followed by
  that one application (a second pin to maintain and to forget, with no benefit over the
  application's own lock, which is by definition what it was tested on); and
  `--override-input` at build time (not recorded in `flake.lock`, so `darwin-rebuild`, which
  re-evaluates the flake, would activate something else, and the activation check would
  rightly refuse it).
  Rationale: One deleted line is the smallest reversible change, it is visible in
  `git diff flake.nix`, and it makes the application build exactly what its own repository
  locks.
  Date: 2026-09-26
- Decision: Do not pin `haskell-nix-dev` by revision. Keep today's behavior: the root
  `haskell-nix-dev` input is unpinned in its URL, locked in `flake.lock`, and every Haskell
  input (the five family inputs and the root `haskell-nix`) follows it. Keep the per-application
  update recipes moving exactly one input instead of `_update-with-base`; the base moves only
  when the user asks (`just update-channel base=yes`, or a plain `nix flake update
  haskell-nix-dev`).
  Rationale: The user did not ask for a base pin, and it would couple every Haskell tool in
  dotfiles (all thirteen consumers follow the same base) to the channel's release cadence. A
  channel locked on a different base than dotfiles' is reported as a warning; if the
  different base changes a frozen version, the version check fails anyway.
  Date: 2026-09-26
- Decision: The guard reads dotfiles' lock through `nix flake metadata --json` with the same
  `PARITY_NIX_FLAGS_JSON` the closure evaluation uses, instead of reading `flake.lock` directly, and
  accepts a test-only `PARITY_FREEZE_OVERRIDE="<app>=<file>"`.
  Rationale: With the lock read through Nix, a build-time `--override-input` (used by the
  negative tests and by `./bin/build.sh <flags>`) is reflected in every check, so a negative
  test no longer has to skip the revision checks. The freeze override gives a deterministic
  version-mismatch test that needs no second channel release.
  Date: 2026-09-26
- Decision: The family's move to `effectful` 2.7, delivered by
  `docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`, needs no change here.
  Rationale: The guard compares each deployed closure with whatever the freeze at the
  application's pinned revision says; once plan 15's releases land in the freeze, `effectful`
  2.7 and the new first-party versions are simply the frozen versions.
  Date: 2026-09-26


## Outcomes & Retrospective

(To be filled during and after implementation.)

Known follow-up at drafting time: the eight non-family Haskell inputs listed in the Decision
Log still bring their own channel revisions. Onboarding them means each imports the freeze and
is added to the `family` list in `bin/verify-haskell-parity.sh`, to the wrapper list in its
`nix eval`, and to the follows block.


## Context and Orientation

Words used in this plan:

- **Channel**: this repository, `mori://shinzui/haskell-nix`, consumed as a Nix flake input
  named `haskell-nix`. It provides the Haskell package overrides that make Nix build the
  frozen versions. A channel revision is one git commit of it.
- **Base**: the flake `github:shinzui/haskell-nix-dev`, input name `haskell-nix-dev`. It pins
  nixpkgs (today `d5dfd8e6`) and the GHC toolchain. The channel follows the base's nixpkgs.
  Dotfiles declares it without a revision and locks it in `flake.lock`; this plan keeps that.
- **Freeze**: `cabal/cohort.freeze` in the channel, written by plan 8. An `index-state:` line
  and one `any.<package> ==<version>` constraint per Haskell package. All five applications'
  `cabal.project` files import it by URL at a fixed channel revision, for example
  `import: https://raw.githubusercontent.com/shinzui/haskell-nix/<rev>/cabal/cohort.freeze`.
  Channel revisions from before plan 8 do not contain the file.
- **An application's pinned channel revision**: the `haskell-nix` revision recorded in the
  application's own `flake.lock` in its own repository. It is the package set the
  application's developers and its test suite build against, and the guard compares the
  deployed closure with the freeze at exactly that revision.
- **Flake lock**: `flake.lock` records, for every input and every input of an input, the
  exact revision used. Dotfiles' `flake.lock` contains a node per application and, unless the
  application follows a root input, nested under it the channel revision that application's
  own lock chose.
- **`follows`**: in a flake input declaration, `inputs.haskell-nix.follows = "haskell-nix";`
  means "when you evaluate this application, ignore the channel revision the application's
  own lock names and hand it dotfiles' root `haskell-nix` input instead". The application's
  source code is unchanged; only which revision of the channel it sees changes. Dotfiles
  already does this for the base (`inputs.haskell-nix-dev.follows = "haskell-nix-dev";`).
  Consequence: for a following application, dotfiles decides the channel at deploy time. If
  that channel's versions differ from the application's pinned freeze, the application ships
  on a package set its tests never saw; that is the failure the guard exists to catch. If
  only the revision differs and the versions agree, nothing about the binary's behavior
  changes, and the guard only warns.
- **On-channel / off-channel**: an application is on-channel when it follows the root
  `haskell-nix`, and off-channel when its follows line has been removed so it builds on the
  channel its own lock pins (the hotfix path in the Decision Log).
- **FAIL / WARN**: the guard prints `PARITY FAIL: …` for conditions that make a deployed
  binary wrong or unverifiable, and exits 1 if there is at least one; it prints
  `PARITY WARN: …` for uniformity conditions, which never change the exit status.
- **Closure**: the set of store paths a store path needs at runtime, printed by
  `nix-store -qR <path>`. Each entry looks like `/nix/store/<32-char hash>-<name>-<version>`.
- **Store path identity**: two applications "share" a library only if both closures contain
  the very same `/nix/store/<hash>-<name>-<version>` path. Same name and version with a
  different hash means the library was built twice with different inputs (different
  `drvPath`s). That costs build time and disk; it is reported, not blocked.
- **Activation**: `sudo ./bin/darwin-rebuild-sungkyung.sh` in dotfiles, which switches the Mac
  to the new system and restarts every launchd agent whose definition changed. Only the user
  runs it. Agents never activate, never push, and never migrate a production database.

Files in dotfiles (`/Users/shinzui/.config/dotfiles.nix`) this plan touches:

- `flake.nix`: the `inputs` block. Today it has `haskell-nix-dev.url = "github:shinzui/haskell-nix-dev";`
  (no revision, and this plan leaves that line alone) and, for each application, a block like

```nix
rei = {
  url = "github:shinzui/rei";
  inputs.nixpkgs.follows = "haskell-nix-dev/nixpkgs";
  inputs.haskell-nix-dev.follows = "haskell-nix-dev";
};
```

- `flake.lock`: written by Nix, never by hand.
- `justfile`: the private helper `_update-with-base +INPUTS` runs
  `nix flake update haskell-nix-dev {{INPUTS}}` and backs `update-kizamu`, `update-mina`,
  `update-mori`, `update-mori-rei-app`, `update-seihou`, `update-rei`, `update-reiko`,
  `update-notion-cli`, `update-notion-hub`, `update-tools` (nine inputs) and
  `update-haskell-fleet` (thirteen inputs). The comment above it explains why: an application
  whose revision expects inputs the locked base does not re-export fails with
  `error: input 'seihou/flake-parts' follows a non-existent input 'seihou/haskell-nix-dev/flake-parts'`.
  The cost is that every single-application update also moves the base, which rebuilds the
  whole Haskell fleet and broke it once (a `tls` test failure on 2026-09-11).
- `bin/build.sh`: `nix build .#darwinConfigurations.SungkyungM1X.system` (no shebang).
- `bin/darwin-rebuild-sungkyung.sh`: `./result/sw/bin/darwin-rebuild switch --flake .#SungkyungM1X $@`.
- `.gitignore`: already ignores `result`.
- `flake-modules/overlays.nix`: defines the deployed packages. `rei`, `mori` and
  `mori-rei-app` are `hsBin` wrappers and `reiko` and `mina` are `hsBinShare` wrappers around
  `inputs.<name>.packages.<system>.default`. A wrapper is a tiny store path that symlinks the
  application's `bin/` (and `share/`), so its closure is the application's closure. They
  evaluate as `.#darwinConfigurations.SungkyungM1X.pkgs.<name>`; on 2026-09-26 those were
  `9v74v26n…-rei` (wraps `rei-cli-6.0.0.0`), `c8by51vm…-mori` (`mori-cli-6.0.0.0`),
  `7s09h7mc…-mori-rei-app` (`mori-rei-app-0.1.0.0`), `96qmg11z…-reiko` (`reiko-cli-0.1.0.0`)
  and `xrf8q7gb…-mina` (`mina-cli-0.1.0.0`).
- `home/rei.nix`, `home/rei-doctor.nix`, `home/mori.nix`, `home/mori-rei-app.nix`,
  `home/reiko.nix`, `home/mina.nix`: the launchd agents. Labels: `com.shinzui.rei-worker`,
  `com.shinzui.rei-worker-kiroku` (Kiroku metrics and subscription status on port 9091),
  `com.shinzui.rei-worker-git-sync`, `com.shinzui.rei-subscription`,
  `com.shinzui.rei-watchdog` (every 5 minutes, kickstarts wedged Rei daemons),
  `com.shinzui.mori-automate`, `com.shinzui.mori-rei-app`, `com.shinzui.reiko-web`,
  `com.shinzui.mina-web`. Logs: `~/.rei/logs/*.log`, `~/.mori/logs/automate.*.log`,
  `~/.mori-rei-app/logs/server.*.log`, `~/.reiko/logs/web.*.log`, `~/.mina/logs/web.*.log`.
  Log lines start with a local timestamp such as `2026-09-26T13:42:24-0700`.
  This plan does not edit these files; it only reads them to know what to check.

Dotfiles has no ADR corpus (`docs/` holds only `plans/` and `bugs/`), no `CLAUDE.md` and no
`AGENTS.md`. It often carries someone else's uncommitted work (on 2026-09-26: mori agent-skill
files under `config/xdg/mori/agents/` and the deployed `flake.lock`), so every commit in this
plan names its paths explicitly: `git commit -- <paths>`.

What earlier plans of this initiative deliver, and this plan assumes (all described in
`docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md`):

- Plan 8 (`docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`)
  commits `cabal/cohort.freeze`.
- Plan 9 (`docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md`)
  owns the structured manifest helper, comparison app and recursive lock resolver described
  in Review requirements. The executable's verified manifest is compared with its own pinned
  freeze. Runtime output closure queries serve only to verify executable/system membership;
  they cannot establish statically linked Haskell package versions.
- Plan 10 moves shared overrides into the channel.
- Plans 11, 12, 13 make each application import the freeze at a channel revision, pin that
  same revision in its own `flake.lock`, drop shared overrides, and deploy. Plan 11 also makes
  mori-rei-app take `rei-core` from Rei's flake instead of rebuilding it; M1 finds out the
  input name it chose. The Kiroku `0012` migrations on the global `rei` and `mori` databases
  were completed on 2026-09-26; plans 11 and 12 own the check that no Kiroku 0.8 writer runs against
  a database whose ledger has `0012`. After `0012`, a Kiroku 0.8 binary fails every append, so
  there is no going back to a pre-cutover build (see Idempotence and Recovery).
- Plan 15 (`docs/plans/15-release-the-first-party-libraries-on-effectful-2-7.md`) moves the
  whole family to `effectful` 2.7 by releasing the first-party libraries on it. It changes the
  freeze's contents, not this plan: the guard compares against whatever the freeze at each
  application's pinned revision says.

Relevant ADRs:

- `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` (this repository): one
  Nixpkgs fixed point with one version per package name, and cache reuse only when inputs are
  equal. The per-application version check enforces "one version per package name" against
  what each application was tested with; two store paths for `rei-core` in one deployed system
  is reported as lost cache reuse. This repository's ADRs are plain Markdown files with a
  `Status:` and `Date:` line, not an OKF bundle; follow that convention.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort
  adoption"): Cabal and Nix pick the cohort by different mechanisms and the divergence fails
  silently, so both must be changed and proven. The version check is the deploy-side proof.
- `mori://shinzui/mori/okf/adrs/concepts/ADR-24` ("Source first-party Haskell packages from
  the shared overlay"): a local override silently shadows the shared one. A shadowing override
  that changes a version fails the version check; one that only changes build policy shows up
  as a store-path warning.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-31` ("Gate runtime releases on restored history and
  observed delivery"): a runtime release is proven by observing it deliver, which is what the
  post-activation checks in M5 do.

No dotfiles ADR exists.


## Plan of Work

The work is five milestones. M1 changes nothing. M2 adds the guard alone, so its verdict can
be seen against today's state before anything is changed. M3 adds the root channel input,
proves the guard passes, fails on a version mismatch and only warns on a revision mismatch.
M4 wires the guard into the build and update paths. M5 runs the whole fleet through it and
hands the result to the user to activate.


### Milestone 1: Preconditions and baseline (read-only)

Scope: prove the three hard dependencies are really done, find the channel revision each
application pins, and record the starting state. Nothing is edited.

First, read the Progress sections of plans 11, 12 and 13 and the MasterPlan registry; all
three must be Complete, including their deploy steps. Then, for each application, ask GitHub
(through Nix, not a local checkout, because dotfiles deploys what is pushed) which channel
revision its pushed head locks, which revision its `cabal.project` imports the freeze from,
and whether that revision publishes `cabal/cohort.freeze`. Every pinned revision must publish
a freeze; if one does not, stop: that application's plan is not finished. The five are
expected to pin the same revision, which this plan calls `R` and records in the Decision Log.
If they differ, that is no longer a blocker: record the spread, take `R` to be the newest
pinned revision, and expect the guard to warn about the others until they catch up.

Next, check the channel at `R`: record the base revision its own `flake.lock` names (call it
`B`) next to dotfiles' current locked `haskell-nix-dev`. If they differ, the guard will warn;
nothing here pins the base. Confirm `R` exposes `cohort-compare` and run it once against the
deployed `rei` wrapper to see its output format.

Then check the dotfiles tree. If `git status --short flake.lock` shows a modification, compare
the working-tree lock with the running system: if `./result` equals `/run/current-system` and
the working-tree lock evaluates to it, the change is an uncommitted deploy from an earlier
plan and belongs to that plan's owner; ask the user whether to commit it first (with
`git commit -- flake.lock` and a `chore(<app>): pin deployed revision` message) or to wait.
Do not start M3 with foreign lock changes in the tree, because `flake.lock` is one file and
this plan's commits would carry them.

Finally, record a baseline shared-library table with the loop in Concrete Steps, and paste it
into Surprises & Discoveries next to the 2026-09-26 table.

Acceptance: each application's head, pinned revision and freeze import are recorded, every
pinned revision publishes a freeze, `R` and `B` are recorded, `cohort-compare` runs, and the
dotfiles `flake.lock` is clean or its owner has committed it.


### Milestone 2: The guard script and its recipes

Scope: add `bin/verify-haskell-parity.sh` and two `justfile` recipes in dotfiles. At the end,
`just verify-channel-pins` and `just verify-haskell-parity` exist and give a readable verdict
on the current system. No input changes yet.

The script reads dotfiles' lock through `nix flake metadata --json` (with any
`--override-input` flags from `PARITY_NIX_FLAGS_JSON` applied), then, for each of the five
applications, records three revisions: the application's own revision in dotfiles' lock;
the channel revision dotfiles actually builds it on (the node its `haskell-nix` input resolves
to, which is the root `haskell-nix` node when it follows and a nested node when it does not);
and its pinned channel revision (the `haskell-nix` revision in the application's own
`flake.lock` at that revision). It fetches the freeze at the pinned revision into a
temporary file. That is all lock data; no build is needed.

The script then has two phases, selectable with `--pins-only` and `--closure-only` (default:
both). The pins phase only reports. It fails (`PARITY FAIL`) only if an application's own lock
has no locked `haskell-nix` input, or its pinned revision publishes no freeze, because either
makes the version check impossible. It warns (`PARITY WARN`) when there is no root
`haskell-nix` input, when the root channel's own base differs from dotfiles' `haskell-nix-dev`,
when an application is off-channel (dotfiles builds it on a channel other than the root),
when an application's pinned revision differs from the channel dotfiles builds it on, when its
`cabal.project` imports the freeze from a revision other than its pin, when the five pin more
than one revision, and (if M1 found that mori-rei-app has a flake input for Rei) when
mori-rei-app's own lock pins a different Rei than dotfiles deploys.

The build-evidence phase (the compatibility option is named `--closure-only`) takes the
candidate system path, obtains manifests from its actual composed application scopes,
checks each executable output is in that system, and verifies manifest/root correspondence.
It calls `--nix-manifest` comparison against each own pinned freeze. A missing expected
Haskell dependency, wrong version or unverifiable root fails. It uses shared identity
comparison for fleet warnings. Runtime absence does not establish that a library is unused.

Test inputs are `PARITY_FLAKE` (default `.`), `PARITY_NIX_FLAGS_JSON` (default `[]`, decoded
as an argv array for metadata/evaluation/build calls), and `PARITY_FREEZE_OVERRIDE`
(default empty; `<app>=<file>` changes only that application's test freeze). The script
prints `ok:` lines for passing checks and `PARITY WARN:` / `PARITY FAIL:` lines to standard
error, runs every check before exiting, ends with `parity: <n> failure(s), <m> warning(s)`,
and exits 1 if and only if there was a failure.

The orchestration contract is in Interfaces and Dependencies. The recipes are:

```just
# Report, without building, which haskell-nix revision each Rei-family application pins
# and builds on (warnings only, unless a pinned revision publishes no cohort freeze)
[group: 'tools']
verify-channel-pins:
    ./bin/verify-haskell-parity.sh --pins-only

# Check a built system (default ./result): each Rei-family closure must match the freeze
# its own pinned channel publishes (FAIL); revision and store-path spread only warn
[group: 'tools']
verify-haskell-parity system="./result":
    ./bin/verify-haskell-parity.sh {{system}}
```

Acceptance: `just verify-channel-pins` exits 0 and prints
`PARITY WARN: no root haskell-nix input in flake.lock; each family application builds on its own channel`
(the state before M3), plus a revision-spread warning if M1 found one, and no failures;
`./bin/verify-haskell-parity.sh --closure-only ./result` exits 0 and its store-path warnings
match the M1 baseline table (a library that shows two hashes there is warned about here). If
it fails instead, the deployed lock carries an application revision that plans 11 to 13 did
not deploy; stop and find out why. Commit `bin/verify-haskell-parity.sh` and `justfile`.


### Milestone 3: One root channel that the family follows by default

Scope: edit `flake.nix` in dotfiles, lock, and prove the result. At the end the five
applications' nested channel nodes are gone from `flake.lock`, replaced by the one root
`haskell-nix` node at `R`, and the guard passes on a freshly built system, fails on a
version mismatch, and only warns on a revision mismatch.

In `flake.nix`, leave `haskell-nix-dev.url = "github:shinzui/haskell-nix-dev";` exactly as it
is, and add the channel right after it, with a comment explaining the rule:

```nix
# The shared Haskell package set, mori://shinzui/haskell-nix, generated from its
# cabal/cohort.freeze. The five Rei-family inputs below follow it by default, so any
# update deploys them on one revision. Move it with `just update-channel [REV]`.
# To deploy ONE application off-channel (for example a hotfix on a newer channel),
# delete that application's `inputs.haskell-nix.follows` line, put
# `# OFF-CHANNEL since <date>: <reason>` in its place and run `just update-<app>`; it then
# builds on the channel its own flake.lock pins. Restore the line once
# `just update-channel` has moved the family. bin/verify-haskell-parity.sh fails the
# build only when a deployed closure disagrees with the freeze its application pins, and
# warns about revision and store-path differences.
haskell-nix = {
  url = "github:shinzui/haskell-nix";
  inputs.haskell-nix-dev.follows = "haskell-nix-dev";
};
```

The channel's own `nixpkgs`, `flake-parts` and `treefmt-nix` already follow its
`haskell-nix-dev`, so following the base is enough; its source inputs (`baikai-src`,
`keiro-src` and the rest) are copied into dotfiles' lock from the channel's own lock
unchanged. Then add `inputs.haskell-nix.follows = "haskell-nix";` to each of the five blocks
`rei`, `mori`, `mori-rei-app`, `reiko` and `mina`, keeping their existing two `follows` lines.
If M1 found a Rei flake input in mori-rei-app (for example named `rei`), also add
`inputs.<that name>.follows = "rei";` to the `mori-rei-app` block, so its `rei-core` is
Rei's by default; record the name in the Decision Log and set `mra_rei_input` in the guard.
Do not touch the other eight Haskell inputs (see Decision Log).

Lock the new input at `R` with
`nix flake lock --override-input haskell-nix github:shinzui/haskell-nix/<R>`, which writes the
chosen revision into `flake.lock` without moving anything else (a bare `nix flake lock` would
lock a new input at the channel's current head, which may be newer than `R`). Then run a plain
`nix flake lock` again: it must leave `flake.lock` byte-identical. If Nix instead moves the
channel to the head on that second run, it does not keep an overridden lock entry for an
unpinned URL; record that in Surprises, and fall back to writing the revision into the URL
(`url = "github:shinzui/haskell-nix/<R>";`) for the root channel only, in which case
`update-channel` must rewrite that URL (the previous revision of this plan, recorded in the
Revision Notes, had such a recipe). Check with the lock-inspection snippet in Concrete Steps
that the five application revisions are unchanged, that each application's `haskell-nix`
now resolves to the root `haskell-nix` node, and that that node is at `R`. Then build a system
to a scratch link and run the guard: it must exit 0.

Negative test N1, a version mismatch must fail: fetch the freeze at `R`, change the `aeson`
constraint to `0.0.0.1`, and run the closure phase on the scratch system with
`PARITY_FREEZE_OVERRIDE="reiko=<that file>"`. `cohort-compare` must report the `aeson`
mismatch, and the guard must print `PARITY FAIL: reiko closure differs from its freeze …` and
exit 1. This proves that the one blocking check actually blocks; it needs no build.

Negative test N2 proves that one application can move off-channel while the other four
retain identical wrappers and dependency identities. Use a disposable detached checkout of
dotfiles, remove only mori-rei-app's follows edge, and lock only its nested channel to a
pushed `R2` with an identical freeze/source policy. Leave root channel and base at `R`/`B`.
Run lock resolution and build the second scratch system from that persistent scratch tree.
The guard warns about that application's effective channel, exits 0, and the other four
wrapper paths and manifests remain identical. Do not override the root channel as a fallback:
that would move the other four applications. If no suitable `R2` exists, record the experiment
as pending; synthetic follows fixtures can proceed but cannot substitute for completion.
Neither scratch system is activated, and no feature branch is needed.

Acceptance: the second `nix flake lock` is a no-op; `just verify-channel-pins` exits 0 with no
warnings when all five pin `R`; the full guard passes on the scratch build; N1 fails as
described; N2 warns and exits 0 with the other four store paths unchanged. Commit `flake.nix`
and `flake.lock`.


### Milestone 4: Gate the build and the update recipes

Scope: make the guard impossible to forget without making it an obstacle. At the end,
`./bin/build.sh` promotes a system to `./result` only when the guard reports no failure
(warnings are printed and do not block), the activation script refuses a `./result` that is
not the current flake's system, and the update recipes move exactly what they name and roll
back on failure.

Rewrite `bin/build.sh` (adding a `#!/usr/bin/env bash` shebang) to build
`.#darwinConfigurations.SungkyungM1X.system` with `--out-link result-candidate`, run the guard
on `./result-candidate`, and on success run `nix build <that store path> --out-link result`
(which only registers a garbage-collector root for the already-built path; a plain `ln -s`
would not protect it from garbage collection) and remove `result-candidate`. On failure it
leaves `./result` alone, prints where the candidate is and how to bypass, and exits 1.
`HASKELL_PARITY=skip` skips the guard with a warning. Add `result-candidate` to `.gitignore`.

Prepend a check to `bin/darwin-rebuild-sungkyung.sh`: evaluate
`.#darwinConfigurations.SungkyungM1X.system.outPath` and compare it with `readlink ./result`;
if they differ, print `./result is not the guarded build of the current flake; run ./bin/build.sh first`
and exit 1. Because the user runs it with `sudo`, the bypass is spelled
`sudo HASKELL_PARITY=skip ./bin/darwin-rebuild-sungkyung.sh`.

In `justfile`, delete `_update-with-base` and its comment, and add:

- `_gated-update +INPUTS`: copy `flake.lock` to a temporary backup, run
  `nix flake update {{INPUTS}}`, then `./bin/build.sh`; on any failure copy the backup back
  and exit 1. Restoring from a backup instead of `git checkout -- flake.lock` preserves any
  uncommitted lock state that existed before the recipe ran.
- Each existing `update-<app>` recipe becomes `(_gated-update "<app>")`, with its comment
  changed to "Update <app> flake input to latest (moves nothing else)". This applies to all
  nine per-application recipes, not only the five family ones: the base now moves only when
  asked for.
- `update-rei-family`: `(_gated-update "rei" "mori" "mori-rei-app" "reiko" "mina")`.
- `update-tools` and `update-haskell-fleet` keep their input lists and use `_gated-update`
  (no base).
- `update-channel REV="" base="no"`: the deliberate channel move. `REV` is empty (move to the
  channel's current head) or a full 40-character commit; anything else exits 2. It backs up
  `flake.lock`, updates the five family inputs to their latest pushed heads, then moves the
  root channel (`nix flake update haskell-nix` without `REV`, or
  `nix flake lock --override-input haskell-nix github:shinzui/haskell-nix/<REV>` with it), also
  moves `haskell-nix-dev` when `base=yes`, and runs `./bin/build.sh`. On failure the lock is
  restored. `flake.nix` is never edited.

Why the five applications move with the channel: the guard compares each application with
its own pinned freeze, so moving the channel under applications whose pushed heads still pin
the old revision fails exactly where the versions differ. Moving them together is what
converges the fleet; if an application has not yet adopted the new channel, the guard names
it and the lock is restored, and the choice is to wait for it or to leave it off-channel
(delete its follows line) for the time being.

Why a per-application update no longer needs the base, and what happens when an application
gets ahead: `just update-rei` moves only `rei`. If Rei's new head pins a newer channel whose
versions differ from the root's, rei (which follows the root) would ship on versions its tests
never saw, and the guard fails and restores the lock. The two ways forward are
`just update-channel` (converge everyone on the newer channel) or the off-channel hotfix path
(delete rei's follows line, rerun `just update-rei`; the guard then only warns). If the newer
channel changed nothing rei links, the update passes with a warning. The old
`follows a non-existent input` error from the justfile comment is the same situation surfacing
earlier, when a new application head needs inputs the locked base does not have, and has the
same two remedies, plus `just update-channel base=yes` when the base really must move.

`./bin/build.sh` forwards any arguments to `nix build` and, through `PARITY_NIX_FLAGS_JSON`, to the
guard's evaluation, so `./bin/build.sh --override-input mori-rei-app <old>` exercises the real
gate: the pre-plan-11 mori-rei-app `2acd4ed4…` pins channel `4cabd105`, which publishes no
freeze, so the guard fails on it.

Acceptance: `./bin/build.sh` on the M3 state passes and updates `./result`; running it with
the old mori-rei-app override fails and leaves `./result` unchanged; running it with the N2
override passes with warnings (and is then undone by rerunning plain `./bin/build.sh`);
`just --list` shows the new recipes and no `_update-with-base`; `just update-channel abc`
exits 2 with the revision message. Commit `bin/build.sh`, `bin/darwin-rebuild-sungkyung.sh`,
`justfile` and `.gitignore`.


### Milestone 5: Full-fleet proof and activation

Scope: run the real workflow end to end. At the end the Mac runs all five applications built
on the root channel, the guard has passed on exactly the activated system, and every
application is observed working.

Run `just update-rei-family`. It moves only the five application inputs to their latest pushed
heads, builds, and runs the guard. If an application's head has moved to a newer channel
since M1 and the versions it links differ, the guard fails, the lock is restored, and the
right move is `just update-channel` once the others are on that channel too (or the
off-channel path for a single urgent application). Revision warnings alone do not stop it;
note them in Surprises. When it passes, tell the user it is ready and ask them to run
`sudo ./bin/darwin-rebuild-sungkyung.sh`. Record the local time just before they activate;
call it `T` (format `2026-09-26T16:05`).

After activation, verify each application is running the new binary and doing its job, with
the commands in Validation and Acceptance. Activation bootstraps every changed launchd agent
at once; on 2026-09-26 that killed `com.shinzui.rei-worker-kiroku`, and
`com.shinzui.rei-watchdog` restarted it about 30 seconds later. So if port 9091 is not
listening, wait one minute and look again before calling it a failure. Check logs only from
lines at or after `T`, because old errors stay in the files.

Then commit the final `flake.lock` in dotfiles, update this plan's Progress, Outcomes and
Surprises, set plan 14 and the MasterPlan's EP-14 Progress lines to done, and write the ADR
described in Interfaces and Dependencies. Nothing is pushed without the user's go-ahead.

Acceptance: every check in Validation and Acceptance passes on the activated system.


## Concrete Steps

Use the Review requirements for final manifest-based acceptance. Historical runtime-closure commands below describe baseline diagnostics; they cannot establish Haskell dependency parity. Consumers export an app alias `apps.<system>.cohort-compare` from their pinned channel to bootstrap lock resolution without guessing node names.

All dotfiles commands run in `/Users/shinzui/.config/dotfiles.nix`. All scratch output goes
under the session scratchpad; the examples below write it as `$SCRATCH`. Use quoted heredoc
delimiters (`<<'EOF'`) whenever a heredoc contains backticks or `$`.

M1, check the five pushed heads. `nix flake metadata --json <ref>` returns a flake's own lock
as `.locks`, so no checkout is needed:

```bash
for app in rei mori mori-rei-app reiko mina; do
  head=$(git ls-remote "https://github.com/shinzui/$app" HEAD | cut -f1)
  pin=$(nix flake metadata --json "github:shinzui/$app/$head" \
        | jq -r '.locks as $l | $l.nodes[$l.nodes[$l.root].inputs["haskell-nix"]].locked.rev')
  imp=$(nix eval --impure --raw --expr \
        "builtins.readFile ((builtins.fetchTree { type = \"github\"; owner = \"shinzui\"; repo = \"$app\"; rev = \"$head\"; }).outPath + \"/cabal.project\")" \
        | grep -o 'haskell-nix/[0-9a-f]\{40\}/cabal/cohort.freeze')
  has=$(nix eval --impure --expr \
        "builtins.pathExists ((builtins.fetchTree { type = \"github\"; owner = \"shinzui\"; repo = \"haskell-nix\"; rev = \"$pin\"; }).outPath + \"/cabal/cohort.freeze\")")
  printf '%-13s head=%.8s lock=%s import=%s freeze=%s\n' "$app" "$head" "$pin" "$imp" "$has"
done
```

Expected: five lines ending in `freeze=true` (any `false` means that application's plan is
not finished; stop). Normally all `lock=` values are the same 40 characters and every
`import=` contains that revision; that revision is `R`. A spread is recorded, not fatal.

M1, check the channel at `R`:

```bash
R='paste the 40-character revision found above'
MRA='paste the mori-rei-app revision from flake.lock'
nix flake metadata --json "github:shinzui/haskell-nix/$R" \
  | jq -r '.locks as $l | $l.nodes[$l.nodes[$l.root].inputs["haskell-nix-dev"]].locked.rev'   # this is B
jq -r '.nodes as $n | $n[$n.root.inputs["haskell-nix-dev"]].locked.rev' flake.lock              # dotfiles' base
nix run "github:shinzui/haskell-nix/$R#cohort-compare" -- --freeze "https://raw.githubusercontent.com/shinzui/haskell-nix/$R/cabal/cohort.freeze" --closure \
  "$(nix eval --raw .#darwinConfigurations.SungkyungM1X.pkgs.rei.outPath)"; echo "exit=$?"
nix flake metadata --json "github:shinzui/mori-rei-app/$MRA" \
  | jq -c '.locks.nodes.root.inputs'   # look for a Rei flake input (not rei-src)
```

M1, dotfiles state and baseline table:

```bash
git status --short
readlink result; readlink /run/current-system
for a in rei mori mori-rei-app reiko mina; do
  p=$(nix eval --raw ".#darwinConfigurations.SungkyungM1X.pkgs.$a.outPath")
  printf '%-13s ' "$a"
  for l in rei-core kioku-core baikai keiro hasql aeson; do
    x=$(nix-store -qR "$p" | grep -E -- "/[a-z0-9]{32}-$l-[0-9][0-9.]*\$" | sed -E 's|/nix/store/(.{8})[a-z0-9]*-|\1-|')
    printf '%s ' "${x:--}"
  done; echo
done
```

M2, after writing the script (Interfaces and Dependencies) and recipes:

```bash
chmod +x bin/verify-haskell-parity.sh
just verify-channel-pins; echo "exit=$?"
./bin/verify-haskell-parity.sh --closure-only ./result; echo "exit=$?"
git commit -m "feat(haskell): add the Rei-family freeze parity guard" \
  -m "$(cat <<'EOF'
Add bin/verify-haskell-parity.sh and the verify-channel-pins and
verify-haskell-parity recipes. The guard fails when a deployed Rei-family
closure differs from the cohort freeze its own pinned haskell-nix revision
publishes, and only warns about revision spread, off-channel applications
and shared libraries built more than once.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
)" -- bin/verify-haskell-parity.sh justfile
```

Expected before M3 (the `ok:` lines are elided; warnings go to standard error):

```text
PARITY WARN: no root haskell-nix input in flake.lock; each family application builds on its own channel
parity: 0 failure(s), 1 warning(s)
exit=0
```

M3, after editing `flake.nix`:

```bash
cp flake.lock "$SCRATCH/flake.lock.before-m3"
nix flake lock --override-input haskell-nix "github:shinzui/haskell-nix/$R"
cp flake.lock "$SCRATCH/flake.lock.m3"
nix flake lock
cmp flake.lock "$SCRATCH/flake.lock.m3" && echo "second lock is a no-op"
python3 - "$SCRATCH/flake.lock.before-m3" flake.lock "$R" <<'EOF'
import json, sys
def load(p):
    n = json.load(open(p))["nodes"]
    def res(ref):
        if isinstance(ref, str): return ref
        cur = "root"
        for part in ref: cur = res(n[cur]["inputs"][part])
        return cur
    return n, res
(bn, _), (an, ares) = load(sys.argv[1]), load(sys.argv[2])
root = an["root"]["inputs"]
rev = an[root["haskell-nix"]]["locked"]["rev"]
print("root haskell-nix", root["haskell-nix"], rev, "== R" if rev == sys.argv[3] else "!= R")
for app in ["rei", "mori", "mori-rei-app", "reiko", "mina"]:
    before = bn[bn["root"]["inputs"][app]]["locked"]["rev"]
    after = an[root[app]]["locked"]["rev"]
    hn = ares(an[root[app]]["inputs"]["haskell-nix"])
    print(f"{app:13} rev {'unchanged' if before == after else 'CHANGED'} {after[:8]} haskell-nix -> {hn}")
EOF
just verify-channel-pins
nix build .#darwinConfigurations.SungkyungM1X.system --out-link "$SCRATCH/m3-system"
./bin/verify-haskell-parity.sh "$SCRATCH/m3-system"; echo "exit=$?"
```

Expected: `second lock is a no-op`; `root haskell-nix haskell-nix <R> == R`; five lines
`rev unchanged … haskell-nix -> haskell-nix` (the root node name, not `haskell-nix_10` and the
like); the guard ends with `parity: 0 failure(s), 0 warning(s)` and `exit=0` when all five pin
`R` (store-path warnings are possible and acceptable; record any in Surprises).

M3, negative test N1 (a version mismatch fails). The freeze is fetched through Nix, so no
extra tool is needed:

```bash
nix eval --impure --raw --expr \
  'builtins.readFile ((builtins.fetchTree { type = "github"; owner = "shinzui"; repo = "haskell-nix"; rev = "'"$R"'"; }).outPath + "/cabal/cohort.freeze")' \
  | sed -E 's/any\.aeson ==[0-9.]+/any.aeson ==0.0.0.1/' >"$SCRATCH/bad.freeze"
grep -c 'any.aeson ==0.0.0.1' "$SCRATCH/bad.freeze"      # expect 1
PARITY_FREEZE_OVERRIDE="reiko=$SCRATCH/bad.freeze" \
  ./bin/verify-haskell-parity.sh --closure-only "$SCRATCH/m3-system"; echo "exit=$?"
```

Expected (the exact `mismatch` wording is plan 9's):

```text
mismatch aeson nix=2.2.5.1 freeze=0.0.0.1
PARITY FAIL: reiko closure differs from its freeze (override …/bad.freeze) (see above)
parity: 1 failure(s), 0 warning(s)
exit=1
```

M3, negative test N2: use the detached scratch-checkout procedure above. Record the own
and effective channel revisions, guard summary and before/after wrapper/manifest tables.
There is no root override and no whitespace-split override string. The other four applications
must be unchanged. A pending R2 experiment remains unchecked in Progress.

M3 commit:

```bash
git commit -m "feat(haskell): add a root haskell-nix channel the Rei family follows" \
  -m "$(cat <<'EOF'
Add a root haskell-nix input, locked like haskell-nix-dev, and make rei,
mori, mori-rei-app, reiko and mina follow it by default so an update
deploys them on one channel revision. One application can still be
deployed off-channel by removing its follows line, as the flake.nix
comment describes.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
)" -- flake.nix flake.lock
```

M4, after the edits (`old` is the pre-plan-11 mori-rei-app, whose own lock pins `4cabd105`;
N2 uses the persistent detached scratch checkout from M3):

```bash
old="github:shinzui/mori-rei-app/$(git -C /Users/shinzui/Keikaku/bokuno/mori-project/mori-rei-app rev-parse 2acd4ed)"
just --list | grep -E 'update-|verify-'
just update-channel abc; echo "exit=$?"          # expect exit=2
./bin/build.sh; echo "exit=$?"; readlink result   # expect exit=0 and the M3 system path
good=$(readlink result)
./bin/build.sh --override-input mori-rei-app "$old"; echo "exit=$?"   # expect PARITY FAIL, exit=1
[ "$(readlink result)" = "$good" ] && echo "result unchanged"
rm -f result-candidate
# Run the off-channel N2 gate in its persistent detached checkout, as described above.
# Invoke build.sh there with argv preserved; verify the other four manifests remain identical.
./bin/build.sh; [ "$(readlink result)" = "$good" ] && echo "result back on the M3 system"
git commit -m "feat(haskell): gate builds and updates on Rei-family freeze parity" \
  -m "$(cat <<'EOF'
Replace _update-with-base, which moved haskell-nix-dev on every application
update, with _gated-update (named inputs only, build, guard, restore on
failure), update-rei-family and update-channel. build.sh promotes ./result
only when the parity guard reports no failure (warnings do not block), and
the activation script refuses a ./result that is not the current flake's
system.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
)" -- bin/build.sh bin/darwin-rebuild-sungkyung.sh justfile .gitignore
```

Expected for the old mori-rei-app (hashes will differ):

```text
PARITY FAIL: mori-rei-app@2acd4ed4 pins haskell-nix 4cabd105, which publishes no cabal/cohort.freeze
PARITY WARN: rei-core has 2 store paths across the Rei family:
  /nix/store/…-rei-core-6.0.0.0  drv=/nix/store/…-rei-core-6.0.0.0.drv  used by: rei
  /nix/store/…-rei-core-6.0.0.0  drv=/nix/store/…-rei-core-6.0.0.0.drv  used by: mori-rei-app
parity: 1 failure(s), 1 warning(s)
Parity guard failed; ./result still points at the previous system. …
exit=1
result unchanged
```

The overridden mori-rei-app still follows dotfiles' root channel (the follows edges are
declared in dotfiles' `flake.nix`, not in the input), so it is not reported as off-channel;
it fails because the channel its own lock pins predates the freeze. Its old overlay also
rebuilds `rei-core`, which shows up as the store-path warning. Other store-path warnings for
`kioku-core` or `baikai` may appear too.

M5:

```bash
just update-rei-family; echo "exit=$?"
# user, in a terminal of their own:  sudo ./bin/darwin-rebuild-sungkyung.sh
```

Then the checks in Validation and Acceptance, then:

```bash
git commit -m "chore(haskell): move the Rei family to one channel revision" \
  -m "$(cat <<'EOF'
Update rei, mori, mori-rei-app, reiko and mina together on haskell-nix <R>.
The parity guard passed on the activated system.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
)" -- flake.lock
```

In this repository (`/Users/shinzui/Keikaku/bokuno/haskell-nix`), commit the plan, MasterPlan
and ADR updates with explicit paths, for example
`git commit -m "docs(plan): record plan 14 fleet deploy" -- docs/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity.md docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md docs/adr/<new ADR file>`.


## Validation and Acceptance

The actual candidate system manifests name the selected runtime generation/configuration. Guard checks prove coherence with each application's own runtime/cohort, and the app-only measurement preserves runtime identity. Fleet runtime-generation differences retain advisory severity.

The review requirements above are additional completion gates, including the assigned update-isolation, manifest and cache evidence. Historical runtime-closure/version tables are diagnostic evidence only; they cannot replace those gates.

Before activation, all of these hold on the M5 build:

- `just verify-haskell-parity` exits 0. Its standard output lists `ok: channel <R> locked on
  base <B>` (or a `PARITY WARN` naming both bases when they differ), five
  `ok: <app>@<rev> pins haskell-nix <R>, publishes a freeze, and is built on it` lines, five
  `ok: <app> closure matches the freeze at <R>` lines, and six
  `ok: <lib> is one store path` (or `ok: <lib> is linked by no family application`) lines;
  it ends with `parity: 0 failure(s), <m> warning(s)`. On a converged fleet `<m>` is expected
  to be 0; any warning is recorded in Surprises with its reason, and does not block.
- `readlink result` equals `nix eval --raw .#darwinConfigurations.SungkyungM1X.system.outPath`.
- The two gate tests still behave: N1 (`PARITY_FREEZE_OVERRIDE` with the doctored freeze)
  exits 1, and `./bin/build.sh --override-input mori-rei-app "$old"` fails and leaves
  `./result` unchanged. That proves the one blocking check is not a no-op. N2, if `R2` exists,
  exits 0 with only warnings, which proves the uniformity checks do not block.

After the user activates (`T` is the time recorded just before):

```bash
readlink /run/current-system            # equals readlink result
for label in rei-worker rei-worker-kiroku rei-worker-git-sync mori-automate mori-rei-app reiko-web mina-web; do
  pid=$(launchctl print "gui/$(id -u)/com.shinzui.$label" | awk '/^\tpid = /{print $3}')
  printf '%-20s pid=%-6s ' "$label" "${pid:--}"
  [ -n "$pid" ] && lsof -p "$pid" | awk '$4=="txt" && $9 ~ /\/nix\/store\/.*-(rei-cli|mori-cli|mori-rei-app|reiko-cli|mina-cli)-/ {print $9; exit}'
  echo
done
```

Each agent must have a pid, and the binary `lsof` shows must be under the store path of the
matching application in `nix-store -qR "$(readlink /run/current-system)"`. Use `lsof`, not
`ps`: the agents start through wrapper scripts, so `ps` shows the wrapper's arguments rather
than the real executable.

```bash
lsof -nP -iTCP:9091 -sTCP:LISTEN          # rei-worker-kiroku listening
KIROKU_REMOTE_URL=http://localhost:9091 rei kiroku subscriptions status | head -20
T=2026-09-26T16:05                         # the recorded activation time
for f in ~/.rei/logs/*.stderr.log ~/.mori/logs/automate.stderr.log \
         ~/.mori-rei-app/logs/server.stderr.log ~/.reiko/logs/web.stderr.log ~/.mina/logs/web.stderr.log; do
  echo "== $f"; awk -v t="$T" 'substr($0,1,16) >= t' "$f" | grep -iE 'error|fail|exception' | tail -5
done
REI_PG_CONNECTION_STRING="host=/Users/shinzui/.local/state/postgresql dbname=rei" rei intention list | head
rei-doctor
```

Expected: port 9091 has a listener owned by the `rei-worker-kiroku` pid (if not, wait a minute
for `rei-watchdog` and check again); subscription status lists subscriptions with no halted
entry; the log filter prints no new errors after `T` other than known, unrelated noise
(record any in Surprises); `rei intention list` prints intentions from the global database
(always set the connection string explicitly, because inside a Rei checkout's shell the
variable points at the repository's development database instead); `rei-doctor` ends with
`pipeline healthy` or only warnings already present before activation. Do not write test
data to prove appends; each daemon's own activity after `T` (for example an `[INGEST]` or
`[WEBHOOK] delivered` line in `~/.mori/logs/automate.stderr.log`, or new subscription
positions in the Kiroku status output) is the evidence that Kiroku appends work. A failing
append (a `category` CHECK violation in a log) would mean a Kiroku 0.8 writer is running
against a `0012` database; that is plans 11 and 12's condition, and it is an incident to
report to the user immediately, not something this guard would have caught.


## Idempotence and Recovery

Every guard and verification command is read-only and can be run any number of times. The
guard builds nothing except, the first time for each distinct pinned revision, plan 9's small
`cohort-compare` app.

`nix flake lock --override-input haskell-nix …/$R` after the M3 edit is idempotent; if the
lock-inspection snippet reports `CHANGED` for an application, restore
`$SCRATCH/flake.lock.before-m3` and rerun the two `nix flake lock` commands (never
`nix flake update` here).

`_gated-update` and `update-channel` restore their own `flake.lock` backup on failure, so a
failed update leaves `flake.lock` exactly as it was, including any uncommitted state that was
there before; neither edits `flake.nix`. `./bin/build.sh` never replaces `./result` with a
system that has a guard failure.

Taking one application off-channel is undone by putting its
`inputs.haskell-nix.follows = "haskell-nix";` line back (replacing the `OFF-CHANNEL` comment)
and running `nix flake lock`, which drops the application's nested channel node; do this only
after `just update-channel` has moved the root to a revision whose freeze the application's
pin agrees with, or the guard will fail on the versions that differ.

Rollback of a bad deploy: in dotfiles, `git checkout -- flake.lock` (or check out the previous
commit's `flake.lock` with `git checkout HEAD~1 -- flake.lock` when the bad lock was already
committed), `./bin/build.sh`, and the user re-activates. If the lock being restored predates
the freeze (its applications pin channels that publish no `cabal/cohort.freeze`), the guard
fails it; use `HASKELL_PARITY=skip ./bin/build.sh` and
`sudo HASKELL_PARITY=skip ./bin/darwin-rebuild-sungkyung.sh`, and write down why.

A rollback can never cross a Kiroku `0012` cutover, and the guard does not check this (plans
11 and 12 own that check). Once a database has run migration `0012` (the global `rei`
database on 2026-09-26, and the `mori` database later on 2026-09-26), a Kiroku 0.8 binary fails every
append against it. Rolling dotfiles back to a lock that deploys a Kiroku 0.8 build of rei,
mori-rei-app or mori would leave those daemons running but unable to write. Past a cutover,
recovery is fix-forward: repair the application or channel and deploy a newer 0.9 build. This
plan itself runs no migration.

Never stop or restart an agent with `pkill` by pattern (a pattern match once killed the
deployed Rei worker); use `launchctl kickstart -k gui/$(id -u)/<label>` or
`launchctl bootout gui/$(id -u)/<label>`.


## Interfaces and Dependencies

Runtime integration: Plan 16 (`docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md`) is a transitive hard dependency through application plans 11–13. Preconditions require those applications to publish an exact runtime generation/configuration and complementary selections, plus matching Cabal/Nix projections. Record these runtime fields in the actual candidate system manifests and deploy/update reports. Compare used runtime dependency identities through plan 9's manifest modes; runtime membership does not imply every application links every component. Generation spread remains a fleet advisory warning, while a mismatch with the application's own selected runtime/cohort or missing evidence fails. The app-only experiment retains runtime generation/configuration/toolchain and complementary unrelated selections. Explicit runtime updates report affected apps; unrelated app or Baikai/Shikumi/OKF updates must not advance runtime records implicitly. No extra dependency back into production deployment is introduced for plan 16's fixture/cache acceptance.

Tools used: `nix` (Determinate Nix 3.17 / Nix 2.33 on 2026-09-26) for `flake lock`,
`flake update`, `flake metadata --json`, `eval`, `build` and `run`; `nix-store -qR` and
`nix-store -qd`; `jq`; `just`; `python3` for the one-off lock inspection; `launchctl`, `lsof`.
Nothing here ever lists or reads `/nix/store` directly; store paths are only queried through
`nix-store`, `nix eval` and `nix path-info`. The script avoids bash associative arrays so it
also runs under macOS's bash 3.2 if that is the `bash` on `PATH`.

From the channel: the `cohort-compare` flake app with the contract stated in Context and
Orientation (owned by plan 9), and `cabal/cohort.freeze` (owned by plan 8).

`bin/verify-haskell-parity.sh` in dotfiles is a thin orchestration script, not another
closure-name parser. Implement the manifest/lock contract in Review requirements:

1. Resolve each application's own channel and effective dotfiles channel with plan 9's
   lock mode, including mori-rei-app → Rei → channel follows paths. Fetch the own pinned
   freeze/source policy; record import/effective-channel differences with the agreed severity.
2. Obtain manifests from the actual candidate system's composed application packages. Verify
   each executable output is in the candidate system and each manifest's root drv corresponds
   to that output. Missing metadata fails; static runtime absence is not proof of non-use.
3. Call `--nix-manifest` comparison for every application against its own pinned freeze.
   Any mismatch or unverifiable evidence fails. Use `--compare-manifests` for fleet identity
   diagnostics, with differences reported as warnings under the user's policy.
4. Preserve override argv as arrays/JSON arrays throughout metadata, evaluation and build
   calls. Never split `$*` or represent a resolved follows path as a literal revision.
5. Run all checks, print the failure/warning summary and return failure iff a blocking
   check failed. Retain `--pins-only`, `--closure-only` (manifest/build evidence phase),
   `PARITY_FLAKE` and test-only freeze overrides. `PARITY_NIX_FLAGS_JSON` is a JSON array,
   empty by default, parsed without a failing empty `read` under `set -e`.

Fixtures use recursive follows, nonstandard root keys, missing/cyclic inputs and missing
static dependencies. The old full shell implementation has been removed because it duplicated
plan 9's parser, failed legitimate follows paths, and inferred parity from runtime basenames.

`bin/build.sh` at the end of M4:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Extra arguments (for example --override-input NAME REF) go to nix build and to the guard.
nix build .#darwinConfigurations.SungkyungM1X.system --out-link result-candidate "$@"
if [ "${HASKELL_PARITY:-}" = skip ]; then
  echo "WARNING: HASKELL_PARITY=skip, the Rei-family parity guard was NOT run" >&2
elif ! PARITY_NIX_FLAGS_JSON="$(jq -cn --args '$ARGS.positional' "$@")" ./bin/verify-haskell-parity.sh ./result-candidate; then
  echo "Parity guard failed; ./result still points at the previous system. Candidate: $(readlink result-candidate)" >&2
  echo "Only PARITY FAIL lines block. To deploy anyway: HASKELL_PARITY=skip ./bin/build.sh" >&2
  exit 1
fi
nix build "$(readlink result-candidate)" --out-link result
rm result-candidate
```

`bin/darwin-rebuild-sungkyung.sh` at the end of M4:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "${HASKELL_PARITY:-}" != skip ]; then
  want=$(nix eval --raw .#darwinConfigurations.SungkyungM1X.system.outPath)
  if [ "$(readlink result)" != "$want" ]; then
    echo "./result is not the guarded build of the current flake; run ./bin/build.sh first" >&2
    exit 1
  fi
fi
./result/sw/bin/darwin-rebuild switch --flake .#SungkyungM1X "$@"
```

`justfile` recipes at the end of M4 (the per-application recipes keep their groups; only the
body and comment change, as shown for `update-rei`):

```just
# Move exactly the named inputs, then build and run the Rei-family parity guard.
# On any failure flake.lock is restored from a backup taken first, so uncommitted
# lock state that existed before the recipe is preserved.
_gated-update +INPUTS:
    #!/usr/bin/env bash
    set -euo pipefail
    backup=$(mktemp -t flake.lock)
    cp flake.lock "$backup"
    restore_on_exit() {
      rc=$?
      trap - EXIT
      if [ "$rc" -ne 0 ]; then cp "$backup" flake.lock; fi
      rm -f "$backup"
      exit "$rc"
    }
    trap restore_on_exit EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    nix flake update {{INPUTS}}
    ./bin/build.sh

# Update rei flake input to latest (moves nothing else)
[group: 'rei']
update-rei: (_gated-update "rei")

# Update the five Rei-family inputs together (rei, mori, mori-rei-app, reiko, mina)
[group: 'tools']
update-rei-family: (_gated-update "rei" "mori" "mori-rei-app" "reiko" "mina")

# Move the shared Haskell channel (mori://shinzui/haskell-nix) to REV (a full commit;
# empty means the channel's head) together with the five Rei-family inputs, which must
# already pin a channel whose freeze agrees with it. base=yes also moves haskell-nix-dev,
# which rebuilds every Haskell input in this flake. flake.nix is never edited.
[group: 'tools']
update-channel REV="" base="no":
    #!/usr/bin/env bash
    set -euo pipefail
    rev="{{REV}}"
    if [ -n "$rev" ] && ! [[ "$rev" =~ ^[0-9a-f]{40}$ ]]; then
      echo "REV must be empty (channel head) or a full 40-character commit of shinzui/haskell-nix" >&2; exit 2
    fi
    backup=$(mktemp -t flake.lock)
    cp flake.lock "$backup"
    restore_on_exit() {
      rc=$?
      trap - EXIT
      if [ "$rc" -ne 0 ]; then cp "$backup" flake.lock; fi
      rm -f "$backup"
      exit "$rc"
    }
    trap restore_on_exit EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    inputs=(rei mori mori-rei-app reiko mina)
    [ "{{base}}" = yes ] && inputs+=(haskell-nix-dev)
    nix flake update "${inputs[@]}"
    if [ -n "$rev" ]; then
      nix flake lock --override-input haskell-nix "github:shinzui/haskell-nix/$rev"
    else
      nix flake update haskell-nix
    fi
    ./bin/build.sh
```

`update-kizamu`, `update-mina`, `update-mori`, `update-mori-rei-app`, `update-seihou`,
`update-reiko`, `update-notion-cli`, `update-notion-hub`, `update-tools` and
`update-haskell-fleet` change the same way as `update-rei`: `_gated-update` with their
existing inputs, no base.

The ADR written in M5, in this repository as
`docs/adr/6-deploy-the-rei-family-on-one-channel-revision.md` following the format
of `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` (title, `Status:`,
`Date:`, Context, Decision, Consequences). Numbers 2 to 4 are allocated to plans 8 to 10 by
the MasterPlan; ADR 5 is the routine-update decision, and ADR 6 is reserved here. Its decision: the deploying flake has one root channel
input that every freeze-importing application follows by default, so updates converge them;
one application may be deployed off-channel by removing its follows edge; the deploy is
blocked when the actual executable manifest disagrees with the application's own pinned
freeze or its evidence is missing/unverifiable, and revision spread, base drift and
duplicated shared-library builds are warnings; the base is not pinned by revision; the guard
runs before activation. Cite it from the dotfiles `flake.nix` comment by its
`mori://shinzui/haskell-nix/…` URI once Mori resolves ADRs of this repository (until then,
the canonical project URI plus the repository-relative path).


## Revision Notes

- 2026-09-26: Initial draft (claude-opus-5-5). Replaced the skeleton with the full plan,
  based on a read-only survey of dotfiles at `e652c2d` plus its uncommitted deployed lock.
- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The parity app is renamed from `cohort-parity` to plan 9's `cohort-compare`, and its calls use `--freeze <url> --closure <path>`. Plan 14's shared-`drvPath` comparison becomes a new mode of that same tool.
- 2026-09-26 (user decision: "the strict guard is too restrictive"): Redesigned the guard to be
  strict only about what makes a deployed binary wrong. It now fails only when an
  application's deployed closure differs in version from the freeze published by the channel
  revision that application's own `flake.lock` pins (or when that comparison cannot be made),
  and only warns about revision spread across the five applications, an application's pin
  differing from dotfiles' root channel, off-channel applications, base drift, freeze-import
  drift, and shared libraries with more than one store path. The root `haskell-nix` input is
  kept and followed by default so updates converge, but is now declared without a revision
  and locked in `flake.lock` like `haskell-nix-dev`; one application is deployed off-channel
  by removing its follows line. `haskell-nix-dev` is no longer pinned by revision (the earlier
  draft's pin is withdrawn), and `update-channel` no longer edits `flake.nix` with `sed`; it
  moves the lock only and moves the base only with `base=yes`. The guard reads the lock
  through `nix flake metadata` so overrides reach every check, and gained a test-only
  `PARITY_FREEZE_OVERRIDE`. Negative tests are now N1 (a doctored freeze must fail) and N2
  (one application on a different channel revision with an identical freeze must only warn,
  with the other four store paths unchanged); the old mori-rei-app `2acd4ed4` override
  remains the gate test through `./bin/build.sh` and now fails because its channel publishes
  no freeze. The Kiroku `0012` safety condition is stated as owned by plans 11 and 12 (the
  guard never checked it), and plan 15's move to `effectful` 2.7 is noted as needing no guard
  change. The earlier Decision Log entries on the URL pins and on failing revision mismatches
  are kept and marked superseded. Every section was updated to match.

- 2026-10-04: MasterPlan review for reducing change time: clarified shared ownership and acceptance, added the applicable targeted-update/build-identity/cache contracts, and corrected historical assumptions. No implementation completion is claimed.

- 2026-10-04 (runtime workstream): Added EP-16 integration, ownership and applicable acceptance; consumer adoption now requires the retained runtime set and composes application selections/packages onto it. Shared-tool preparation remains acyclic and the fleet advisory policy is preserved.
