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
guarantee is that the deployed machine actually runs that set. Today dotfiles lets every
application bring its own revision of this repository (the "channel"), so on 2026-09-26 the
deployed system mixed four channel revisions, and the same library was built two or three
different ways inside one system: `rei` and `mori-rei-app` each carried their own `rei-core`,
`kioku-core` and `baikai` store paths. Nothing noticed, because nothing looks.

After this plan:

- dotfiles pins exactly one channel revision, and all five application inputs are forced
  to use it;
- the update recipes in `justfile` move one application at a time, and moving the channel
  is a separate, deliberate recipe with its own build gate;
- `./bin/build.sh` refuses to hand the user a system to activate unless a guard passes. The
  guard checks that every application's own repository was tested against the same channel
  revision dotfiles deploys, that every Haskell package in every deployed application has the
  version the freeze names, and that shared libraries (`rei-core`, `kioku-core`, `baikai`,
  `keiro`, `hasql`, `aeson`) are one identical store path across the applications that link
  them.

To see it working, run `just verify-haskell-parity` in dotfiles after a build: it prints one
`ok` line per check and exits 0. Break it on purpose (Milestone 3 shows how, by overriding
`mori-rei-app` to an old revision) and it prints `PARITY FAIL: rei-core has 2 store paths …`
and exits 1, and `./bin/build.sh` leaves `./result` pointing at the previous good system.


## Progress

- [ ] M1: Confirm plans 11, 12 and 13 are complete and every application's GitHub head pins one channel revision (record it as `R` in Decision Log).
- [ ] M1: Confirm the channel at `R` exposes plan 9's comparison app and contains `cabal/cohort.freeze`.
- [ ] M1: Confirm the dotfiles tree is safe to edit (no foreign `flake.lock` changes) and record the baseline shared-library table.
- [ ] M2: Add `bin/verify-haskell-parity.sh` and the `verify-channel-pins` / `verify-haskell-parity` recipes; show `--pins-only` fails before M3.
- [ ] M2: Commit the guard in dotfiles.
- [ ] M3: Add the root `haskell-nix` input pinned to `R`, pin `haskell-nix-dev` by revision, make the five inputs follow both (and `mori-rei-app` follow `rei` if it has a Rei flake input).
- [ ] M3: Relock without moving any application; prove all five resolve to the root node; `--pins-only` passes.
- [ ] M3: Negative test: override `mori-rei-app` to `2acd4ed4…`, build to a scratch link, and see the guard fail on `rei-core`.
- [ ] M3: Commit `flake.nix` and `flake.lock`.
- [ ] M4: Replace `_update-with-base` with `_gated-update`, per-application recipes, `update-rei-family` and `update-channel`; make `./bin/build.sh` build a candidate, run the guard and only then promote `./result`; make `darwin-rebuild-sungkyung.sh` refuse an unguarded `./result`; ignore `result-candidate`.
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
  Evidence: `git diff --stat flake.lock` → `295 insertions(+), 138 deletions(-)`.
- Observation: Thirteen dotfiles inputs consume this repository, on four channel revisions
  (working tree): rei and mori-rei-app `4cabd105`; mori and notion-hub `018d1e32`;
  reiko, mina, kizamu, kazuha, nihongo `b88d3173`; seihou, shiki, okf, notion-cli
  `7b696dc8`. There is no root `haskell-nix` input.
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
  mina) are the cohort lag plans 12 and 13 fix.
- Observation: Every `nix eval` in dotfiles prints
  `warning: input 'mina/haskell-nix' has an override for a non-existent input 'haskell-nix-dev'`,
  because mina's channel `b88d3173` predates the `haskell-nix-dev` input. Following one root
  channel removes it.
- Observation: `bin/build.sh` is a single line with no shebang
  (`nix build .#darwinConfigurations.SungkyungM1X.system`), and
  `bin/darwin-rebuild-sungkyung.sh` is `./result/sw/bin/darwin-rebuild switch --flake .#SungkyungM1X $@`.
  darwin-rebuild re-evaluates and builds the flake itself and only borrows the
  `darwin-rebuild` binary from `./result`, so a guard in `build.sh` alone does not stop an
  unguarded activation. M4 adds a check to the activation script for that reason.
- Observation: `sed` on this machine's PATH is GNU sed 4.10 (from the Nix profile), not BSD
  sed, so the macOS idiom `sed -i '' …` fails (GNU reads `''` as the script). Recipes use
  `sed -E -i.bak …`, which both accept.


## Decision Log

- Decision: Only the five Rei-family inputs (rei, mori, mori-rei-app, reiko, mina) follow the
  root `haskell-nix` input. The other eight inputs that consume this repository (kizamu,
  seihou, kazuha, nihongo, shiki, okf, notion-cli, notion-hub) keep the channel revision their
  own locks choose.
  Rationale: Only the five import `cabal/cohort.freeze`; forcing the others onto the channel
  would change what they build without their Cabal side moving, which is the exact divergence
  this initiative removes. Bringing them in is a follow-up (see Outcomes).
  Date: 2026-09-26
- Decision: Pin the root `haskell-nix` input by revision in its URL, and also pin the root
  `haskell-nix-dev` input by revision, to the `haskell-nix-dev` revision the channel's own
  `flake.lock` records.
  Rationale: With a revision in the URL, a bare `nix flake update` cannot move the channel;
  only `just update-channel` (which edits the URL) can. The channel's generated versions are
  only proven against the nixpkgs its own lock selects, so the base dotfiles deploys must be
  that same base; pinning it makes the equality explicit and lets the guard check it.
  Date: 2026-09-26
- Decision: An application's own `flake.lock` (and the freeze import in its `cabal.project`)
  must pin the same channel revision as dotfiles, and the guard fails otherwise.
  Rationale: `follows` makes dotfiles win at deploy time regardless, so a mismatch never breaks
  the build; it silently means the application's tests ran on a different package set than
  the one deployed, which is the failure this initiative exists to remove.
  Date: 2026-09-26
- Decision: Version comparison against the freeze uses plan 9's shared script, run as a flake
  app from the pinned channel revision; the cross-application identity check (same store path
  for a shared library) lives in the dotfiles guard.
  Rationale: The MasterPlan requires the version comparison logic to exist once, in this
  repository. The identity check is deploy-specific (it needs all five closures at once), is
  a dozen lines, and has no Cabal counterpart.
  Date: 2026-09-26
- Decision: Compare output store paths, not `.drv` paths, and print the `.drv` (via
  `nix-store -qd`) only as a diagnostic.
  Rationale: For ordinary (input-addressed) Nix derivations the output path is computed from
  the derivation, so equal output paths mean equal derivations; output paths are available
  straight from `nix-store -qR` of the deployed system, whereas `.drv` files may be absent for
  substituted paths.
  Date: 2026-09-26
- Decision: `./bin/build.sh` builds to `./result-candidate`, runs the guard, and only then
  points `./result` at the new system; `bin/darwin-rebuild-sungkyung.sh` refuses to activate
  when `./result` is not the system the flake currently evaluates to. `HASKELL_PARITY=skip`
  bypasses both with a loud warning.
  Rationale: The user activates whatever the flake evaluates to, not `./result`; tying the two
  together is the only way the guard actually guards. The bypass exists for emergency
  rollbacks to a lock recorded before the guard existed.
  Date: 2026-09-26
- Decision: This plan runs no database migration.
  Rationale: The Kiroku `0012` cutovers belong to plan 11 (applied to the global `rei` database
  on 2026-09-26) and plan 12 (the `mori` database). By the time this plan runs, every
  application already runs a Kiroku 0.9 build, and this plan only changes how dotfiles pins
  them.
  Date: 2026-09-26


## Outcomes & Retrospective

(To be filled during and after implementation.)

Known follow-up at drafting time: the eight non-family Haskell inputs listed in the Decision
Log still bring their own channel revisions. Onboarding them means each imports the freeze and
is added to the `family` list in `bin/verify-haskell-parity.sh` and to the follows block.


## Context and Orientation

Words used in this plan:

- **Channel**: this repository, `mori://shinzui/haskell-nix`, consumed as a Nix flake input
  named `haskell-nix`. It provides the Haskell package overrides that make Nix build the
  frozen versions. A channel revision is one git commit of it.
- **Base**: the flake `github:shinzui/haskell-nix-dev`, input name `haskell-nix-dev`. It pins
  nixpkgs (today `d5dfd8e6`) and the GHC toolchain. The channel follows the base's nixpkgs.
- **Freeze**: `cabal/cohort.freeze` in the channel, written by plan 8. One
  `any.<package> ==<version>` line per Haskell package. All five applications' `cabal.project`
  files import it by URL at a fixed channel revision, for example
  `import: https://raw.githubusercontent.com/shinzui/haskell-nix/<rev>/cabal/cohort.freeze`.
- **Flake lock**: `flake.lock` records, for every input and every input of an input, the
  exact revision used. Dotfiles' `flake.lock` contains a node per application and, nested
  under each, the channel revision that application chose.
- **`follows`**: in a flake input declaration, `inputs.haskell-nix.follows = "haskell-nix";`
  means "when you evaluate this application, ignore the channel revision the application's
  own lock names and hand it dotfiles' root `haskell-nix` input instead". The application's
  source code is unchanged; only which revision of the channel it sees changes. Dotfiles
  already does this for the base (`inputs.haskell-nix-dev.follows = "haskell-nix-dev";`).
  Consequence: at deploy time dotfiles always wins. The application's own `flake.lock` still
  matters, because that is what its developers and its test suite build against. If it names
  a different channel revision, the application was tested on one package set and ships on
  another. That is why this plan adds a check that the two agree.
- **Closure**: the set of store paths a store path needs at runtime, printed by
  `nix-store -qR <path>`. Each entry looks like `/nix/store/<32-char hash>-<name>-<version>`.
- **Store path identity**: two applications "share" a library only if both closures contain
  the very same `/nix/store/<hash>-<name>-<version>` path. Same name and version with a
  different hash means the library was built twice with different inputs.
- **Activation**: `sudo ./bin/darwin-rebuild-sungkyung.sh` in dotfiles, which switches the Mac
  to the new system and restarts every launchd agent whose definition changed. Only the user
  runs it. Agents never activate, never push, and never migrate a production database.

Files in dotfiles (`/Users/shinzui/.config/dotfiles.nix`) this plan touches:

- `flake.nix`: the `inputs` block. Today it has `haskell-nix-dev.url = "github:shinzui/haskell-nix-dev";`
  (no revision) and, for each application, a block like

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
  generates Nix from the freeze and owns the one comparison script under `scripts/`. This
  plan relies on the following contract, and M1 verifies it: the channel flake exposes an app
  named `cohort-compare` such that
  `nix run github:shinzui/haskell-nix/<rev>#cohort-compare -- --freeze "https://raw.githubusercontent.com/shinzui/haskell-nix/$R/cabal/cohort.freeze" --closure <store-path>` reads the
  freeze at that same revision, lists the runtime closure of `<store-path>`, considers only
  Haskell package paths (it must not confuse the C `zlib-1.3.2` with the Haskell `zlib`
  package, both of which appear in closures), ignores packages absent from the freeze (the
  applications' own packages), prints one line per mismatch as
  `<package> nix=<version> freeze=<version>`, and exits 1 on any mismatch and 0 otherwise. If
  plan 9 shipped a different app name or arguments, change only the `parity_cmd` line in the
  guard script and record it in the Decision Log.
- Plan 10 moves shared overrides into the channel.
- Plans 11, 12, 13 make each application import the freeze at channel revision `R`, pin `R`
  in its own `flake.lock`, drop shared overrides, and deploy. Plan 11 also makes mori-rei-app
  take `rei-core` from Rei's flake instead of rebuilding it; M1 finds out the input name it
  chose. Plans 11 and 12 ran the Kiroku `0012` migration on the global `rei` (2026-09-26) and
  `mori` databases. After `0012`, a Kiroku 0.8 binary fails every append, so there is no going
  back to a pre-cutover build (see Idempotence and Recovery).

Relevant ADRs:

- `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` (this repository): one
  Nixpkgs fixed point with one version per package name, and cache reuse only when inputs are
  equal. Two store paths for `rei-core` in one deployed system is a direct violation of the
  "one version per package name" intent at the scale of the deployment, which this plan's
  identity check enforces. This repository's ADRs are plain Markdown files with a `Status:`
  and `Date:` line, not an OKF bundle; follow that convention.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort
  adoption"): Cabal and Nix pick the cohort by different mechanisms and the divergence fails
  silently, so both must be changed and proven. The channel-pin check is the deploy-side proof.
- `mori://shinzui/mori/okf/adrs/concepts/ADR-24` ("Source first-party Haskell packages from
  the shared overlay"): a local override silently shadows the shared one. The identity check
  catches any shadowing that survived plan 10.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-31` ("Gate runtime releases on restored history and
  observed delivery"): a runtime release is proven by observing it deliver, which is what the
  post-activation checks in M5 do.

No dotfiles ADR exists.


## Plan of Work

The work is five milestones. M1 changes nothing. M2 adds the guard alone, so its failure
messages can be seen against today's state before anything is fixed. M3 makes dotfiles pin
one channel and proves the guard both passes and fails correctly. M4 wires the guard into the
build and update paths. M5 runs the whole fleet through it and hands the result to the user
to activate.


### Milestone 1: Preconditions and baseline (read-only)

Scope: prove the three hard dependencies are really done, find the channel revision `R`, and
record the starting state. Nothing is edited.

First, read the Progress sections of plans 11, 12 and 13 and the MasterPlan registry; all
three must be Complete, including their deploy steps. Then, for each application, ask GitHub
(through Nix, not a local checkout, because dotfiles deploys what is pushed) which channel
revision its pushed head locks and which revision its `cabal.project` imports the freeze
from. All five must print the same 40-character revision; that is `R`. Record `R` in the
Decision Log. If they differ, stop: the lagging application's plan is not finished.

Next, check the channel at `R`: its `flake.lock` names a base revision (record it as `B`),
it contains `cabal/cohort.freeze`, and it exposes `cohort-compare`. Run the app once against
the deployed `rei` wrapper to see its output format.

Then check the dotfiles tree. If `git status --short flake.lock` shows a modification, compare
the working-tree lock with the running system: if `./result` equals `/run/current-system` and
the working-tree lock evaluates to it, the change is an uncommitted deploy from an earlier
plan and belongs to that plan's owner; ask the user whether to commit it first (with
`git commit -- flake.lock` and a `chore(<app>): pin deployed revision` message) or to wait.
Do not start M3 with foreign lock changes in the tree, because `flake.lock` is one file and
this plan's commits would carry them.

Finally, record a baseline shared-library table with the loop in Concrete Steps, and paste it
into Surprises & Discoveries next to the 2026-09-26 table.

Acceptance: `R` and `B` are recorded; five matching revisions are shown; `cohort-compare` runs;
the dotfiles `flake.lock` is clean or its owner has committed it.


### Milestone 2: The guard script and its recipes

Scope: add `bin/verify-haskell-parity.sh` and two `justfile` recipes in dotfiles. At the end,
`just verify-channel-pins` and `just verify-haskell-parity` exist and give a readable verdict
on the current system. No input changes yet.

The script has two phases, selectable with `--pins-only` and `--closure-only` (default: both).

The pins phase reads only lock data. It takes `R` from dotfiles' `flake.lock` root input
`haskell-nix` and `B` from root input `haskell-nix-dev`, and fails immediately with
`no root haskell-nix input in flake.lock` if the first is missing. It asks the channel at `R`
which base its own lock records and fails unless that is `B`. For each of the five
applications it takes the application's revision from dotfiles' `flake.lock`, then asks that
revision's own `flake.lock` for its `haskell-nix` revision (must be `R`) and reads its
`cabal.project` (must contain `haskell-nix/<R>/cabal/cohort.freeze`). If M1 found that
mori-rei-app has a flake input for Rei, it also checks that mori-rei-app's own lock pins the
same Rei revision that dotfiles deploys, because otherwise mori-rei-app was tested against a
different `rei-core`.

The closure phase takes a built system path (default `./result`). It evaluates the five
wrapper store paths from the flake in one `nix eval`, checks that each is inside the system's
closure (so the guard is looking at what will be activated), runs `cohort-compare closure` on
each, and then, for each shared library, collects the distinct store paths across the five
closures. More than one distinct path for a library is a failure, printed with each path,
its `.drv`, and which applications use it. A library that an application does not link is
simply absent from that application's closure and is not a failure (reiko links only `aeson`
of the six).

Two environment variables make the script testable without editing it: `PARITY_FLAKE`
(default `.`) and `PARITY_NIX_FLAGS` (default empty, appended to the `nix eval` call, for
example `--override-input mori-rei-app github:shinzui/mori-rei-app/<rev>`). The script prints
`ok:` lines for passing checks and `PARITY FAIL:` lines to standard error for failing ones,
runs every check before exiting, and exits 1 if any failed.

The full script is in Interfaces and Dependencies. The recipes are:

```just
# Check, without building, that dotfiles and every Rei-family application pin one channel revision
[group: 'tools']
verify-channel-pins:
    ./bin/verify-haskell-parity.sh --pins-only

# Check a built system (default ./result): channel pins, versions against the cohort freeze,
# and one store path per shared library across the Rei-family applications
[group: 'tools']
verify-haskell-parity system="./result":
    ./bin/verify-haskell-parity.sh {{system}}
```

Acceptance: `just verify-channel-pins` exits 1 with
`PARITY FAIL: no root haskell-nix input in flake.lock` (that is the state before M3), and
`./bin/verify-haskell-parity.sh --closure-only ./result` produces a verdict consistent with
the M1 baseline table. Commit `bin/verify-haskell-parity.sh` and `justfile`.


### Milestone 3: One channel input that every family application follows

Scope: edit `flake.nix` in dotfiles, relock, and prove the result. At the end the five
applications' nested channel nodes are gone from `flake.lock`, replaced by the one root
`haskell-nix` node at `R`, and the guard passes on a freshly built system and fails on a
deliberately broken one.

In `flake.nix`, change the base line to a pinned revision and add the channel right after it,
with a comment explaining the rule:

```nix
haskell-nix-dev.url = "github:shinzui/haskell-nix-dev/<B>";

# The one revision of mori://shinzui/haskell-nix (the shared package set generated
# from cabal/cohort.freeze) that every Rei-family application builds on. The five
# inputs below follow it, so dotfiles deploys this revision whatever each
# application's own flake.lock says; bin/verify-haskell-parity.sh fails the build
# when an application's own lock or its cabal.project freeze import disagrees.
# Move it only with `just update-channel <rev>`; `<B>` above must equal the
# haskell-nix-dev revision this channel revision's own flake.lock records.
haskell-nix = {
  url = "github:shinzui/haskell-nix/<R>";
  inputs.haskell-nix-dev.follows = "haskell-nix-dev";
};
```

The channel's own `nixpkgs`, `flake-parts` and `treefmt-nix` already follow its
`haskell-nix-dev`, so following the base is enough; its source inputs (`baikai-src`,
`keiro-src` and the rest) are copied into dotfiles' lock from the channel's own lock
unchanged. Then add `inputs.haskell-nix.follows = "haskell-nix";` to each of the five blocks
`rei`, `mori`, `mori-rei-app`, `reiko` and `mina`, keeping their existing two `follows` lines.
If M1 found a Rei flake input in mori-rei-app (for example named `rei`), also add
`inputs.<that name>.follows = "rei";` to the `mori-rei-app` block, so its `rei-core` is Rei's
by construction; record the name in the Decision Log. Do not touch the other eight Haskell
inputs (see Decision Log).

Relock with `nix flake lock` (not `nix flake update`, which would move everything). Check
with the lock-inspection snippet in Concrete Steps that the five application revisions are
unchanged, that each application's `haskell-nix` now resolves to the root `haskell-nix` node,
and that that node is at `R`. Then build a system to a scratch link and run the guard.

Negative test: build a second system with `--override-input mori-rei-app
github:shinzui/mori-rei-app/2acd4ed4…` (the pre-plan-11 revision that rebuilds `rei-core`
from source with its own overlay) to a scratch link, and run the guard with the same override
in `PARITY_NIX_FLAGS`. It must fail on `rei-core` and, because that old overlay replaces
`wai-app-static` and jailbreaks `servant-server`, on versions too. This proves the guard
detects exactly the drift it exists for. The scratch system is never activated.

Acceptance: `just verify-channel-pins` passes; the full guard passes on the scratch build;
the negative test fails as described. Commit `flake.nix` and `flake.lock`.


### Milestone 4: Gate the build and the update recipes

Scope: make the guard impossible to forget. At the end, `./bin/build.sh` only promotes a
passing system to `./result`, the activation script refuses a `./result` that is not the
current flake's system, and the update recipes move exactly what they name and roll back on
failure.

Rewrite `bin/build.sh` (adding a `#!/usr/bin/env bash` shebang) to build `.#darwinConfigurations.SungkyungM1X.system` with
`--out-link result-candidate`, run the guard on `./result-candidate`, and on success run
`nix build <that store path> --out-link result` (which only registers a garbage-collector root
for the already-built path; a plain `ln -s` would not protect it from garbage collection) and
remove `result-candidate`. On failure it leaves `./result` alone, prints where the candidate
is, and exits 1. `HASKELL_PARITY=skip` skips the guard with a warning. Add `result-candidate`
to `.gitignore`.

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
  nine per-application recipes, not only the five family ones: moving the base is now only
  done by `update-channel`.
- `update-rei-family`: `(_gated-update "rei" "mori" "mori-rei-app" "reiko" "mina")`.
- `update-tools` and `update-haskell-fleet` keep their input lists and use `_gated-update`
  (no base).
- `update-channel REV base="no"`: the deliberate channel move. It checks `REV` is 40 hex
  characters, reads the channel's own base revision at `REV`, and refuses with a message if
  that differs from the current base unless `base="yes"` was passed (moving the base rebuilds
  all thirteen Haskell inputs, so it must be intended). It backs up `flake.nix` and
  `flake.lock`, rewrites the `haskell-nix` URL (and, with `base="yes"`, the `haskell-nix-dev`
  URL) in `flake.nix` with `sed`, verifies the rewrite took, and runs
  `nix flake update haskell-nix haskell-nix-dev rei mori mori-rei-app reiko mina` followed by
  `./bin/build.sh`. The five applications move in the same step because the pins check
  requires their own locks to pin the new channel, so their latest pushed heads must already
  be on it. On failure both files are restored.

Why `update-channel` must edit `flake.nix`: when the URL contains a revision,
`nix flake update haskell-nix` has nothing to update; the revision in the URL is the pin.

Why per-application updates can now fail where they used to need the base: if an
application's new head was built on a newer channel or base, the pins check fails and names
both revisions. The fix is to move the channel deliberately (`just update-channel <rev>`),
not to let an application drag it. The old `follows a non-existent input` error from the
justfile comment is the same situation surfacing earlier, and has the same fix.

`./bin/build.sh` forwards any arguments to `nix build` and, through `PARITY_NIX_FLAGS`, to the
guard's evaluation, so `./bin/build.sh --override-input mori-rei-app <old>` exercises the real
gate with the M3 negative-test override.

Acceptance: `./bin/build.sh` on the M3 state passes and updates `./result`; running it with
the negative-test override fails and leaves `./result` unchanged;
`just --list` shows the new recipes and no `_update-with-base`;
`just update-channel abc` exits 2 with the revision message. Commit `bin/build.sh`,
`bin/darwin-rebuild-sungkyung.sh`, `justfile` and `.gitignore`.


### Milestone 5: Full-fleet proof and activation

Scope: run the real workflow end to end. At the end the Mac runs all five applications built
on channel `R`, the guard has passed on exactly the activated system, and every application is
observed working.

Run `just update-rei-family`. It moves only the five application inputs to their latest pushed
heads, builds, and runs the guard. If an application's head has moved to a newer channel
since M1, the pins check fails, the lock is restored, and the correct move is
`just update-channel <new R>` once all five are on it. When it passes, tell the user it is
ready and ask them to run `sudo ./bin/darwin-rebuild-sungkyung.sh`. Record the local time
just before they activate; call it `T` (format `2026-09-26T16:05`).

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

All dotfiles commands run in `/Users/shinzui/.config/dotfiles.nix`. All scratch output goes
under the session scratchpad; the examples below write it as `$SCRATCH`. Use quoted heredoc
delimiters (`<<'EOF'`) whenever a heredoc contains backticks or `$`.

M1, find `R` and check the five pushed heads. `nix flake metadata --json <ref>` returns a
flake's own lock as `.locks`, so no checkout is needed:

```bash
for app in rei mori mori-rei-app reiko mina; do
  head=$(git ls-remote "https://github.com/shinzui/$app" HEAD | cut -f1)
  pin=$(nix flake metadata --json "github:shinzui/$app/$head" \
        | jq -r '.locks as $l | $l.nodes[$l.nodes[$l.root].inputs["haskell-nix"]].locked.rev')
  imp=$(nix eval --impure --raw --expr \
        "builtins.readFile ((builtins.fetchTree { type = \"github\"; owner = \"shinzui\"; repo = \"$app\"; rev = \"$head\"; }).outPath + \"/cabal.project\")" \
        | grep -o 'haskell-nix/[0-9a-f]\{40\}/cabal/cohort.freeze')
  printf '%-13s head=%.8s lock=%s import=%s\n' "$app" "$head" "$pin" "$imp"
done
```

Expected: five lines whose `lock=` values are the same 40 characters and whose `import=`
values all contain that revision. That revision is `R`.

M1, check the channel at `R`:

```bash
R='paste the 40-character revision found above'
MRA='paste the mori-rei-app revision from flake.lock'
nix flake metadata --json "github:shinzui/haskell-nix/$R" \
  | jq -r '.locks as $l | $l.nodes[$l.nodes[$l.root].inputs["haskell-nix-dev"]].locked.rev'   # this is B
nix eval --impure --raw --expr \
  'builtins.substring 0 200 (builtins.readFile ((builtins.fetchTree { type = "github"; owner = "shinzui"; repo = "haskell-nix"; rev = "'"$R"'"; }).outPath + "/cabal/cohort.freeze"))'
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
git commit -m "feat(haskell): add the Rei-family channel and closure parity guard" \
  -m "$(cat <<'EOF'
Add bin/verify-haskell-parity.sh and the verify-channel-pins and
verify-haskell-parity recipes. The guard checks that dotfiles and each
Rei-family application pin one haskell-nix revision, that deployed
closures match the cohort freeze, and that shared libraries are one
store path across applications.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
)" -- bin/verify-haskell-parity.sh justfile
```

Expected before M3:

```text
PARITY FAIL: no root haskell-nix input in flake.lock
exit=1
```

M3, after editing `flake.nix`:

```bash
cp flake.lock "$SCRATCH/flake.lock.before-m3"
nix flake lock
python3 - "$SCRATCH/flake.lock.before-m3" flake.lock <<'EOF'
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
print("root haskell-nix", root.get("haskell-nix"), an[root["haskell-nix"]]["locked"]["rev"])
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

Expected: `root haskell-nix haskell-nix <R>`; five lines `rev unchanged … haskell-nix -> haskell-nix`
(the root node name, not `haskell-nix_10` and the like); the guard ends with `exit=0`.

M3, negative test (the full revision is `2acd4ed4…`; get it with
`git -C /Users/shinzui/Keikaku/bokuno/mori-project/mori-rei-app rev-parse 2acd4ed`):

```bash
old="github:shinzui/mori-rei-app/$(git -C /Users/shinzui/Keikaku/bokuno/mori-project/mori-rei-app rev-parse 2acd4ed)"
nix build .#darwinConfigurations.SungkyungM1X.system --override-input mori-rei-app "$old" \
  --out-link "$SCRATCH/m3-negative"
PARITY_NIX_FLAGS="--override-input mori-rei-app $old" \
  ./bin/verify-haskell-parity.sh --closure-only "$SCRATCH/m3-negative"; echo "exit=$?"
```

Expected (hashes will differ):

```text
PARITY FAIL: mori-rei-app closure differs from the cohort freeze (see above)
PARITY FAIL: rei-core has 2 store paths across the Rei family:
  /nix/store/…-rei-core-6.0.0.0  drv=/nix/store/…-rei-core-6.0.0.0.drv  used by: rei
  /nix/store/…-rei-core-6.0.0.0  drv=/nix/store/…-rei-core-6.0.0.0.drv  used by: mori-rei-app
exit=1
```

Only the closure phase is run here, because the override is not in `flake.lock` and the
pins phase reads the lock. Commit:

```bash
git commit -m "feat(haskell): deploy one haskell-nix revision to the Rei family" \
  -m "$(cat <<'EOF'
Add a root haskell-nix input pinned by revision, pin haskell-nix-dev to the
base that channel revision was locked on, and make rei, mori, mori-rei-app,
reiko and mina follow it, so the deployed system carries one channel.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
)" -- flake.nix flake.lock
```

M4, after the edits:

```bash
just --list | grep -E 'update-|verify-'
just update-channel abc; echo "exit=$?"          # expect exit=2
./bin/build.sh; echo "exit=$?"; readlink result   # expect exit=0 and the M3 system path
good=$(readlink result)
./bin/build.sh --override-input mori-rei-app "$old"; echo "exit=$?"   # expect PARITY FAIL lines, exit=1
[ "$(readlink result)" = "$good" ] && echo "result unchanged"
rm -f result-candidate
git commit -m "feat(haskell): gate builds and updates on Rei-family parity" \
  -m "$(cat <<'EOF'
Replace _update-with-base, which moved haskell-nix-dev on every application
update, with _gated-update (one input, build, guard, restore on failure),
update-rei-family and a deliberate update-channel. build.sh now promotes
./result only after the parity guard passes, and the activation script
refuses a ./result that is not the current flake's system.

MasterPlan: mori://shinzui/haskell-nix/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications
ExecPlan: mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
EOF
)" -- bin/build.sh bin/darwin-rebuild-sungkyung.sh justfile .gitignore
```

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

Before activation, all of these hold on the M5 build:

- `just verify-haskell-parity` exits 0 and prints, in order, `ok: channel <R> on base <B>`,
  five `ok: <app>@<rev> pins channel <R> and imports its freeze` lines, five
  `ok: <app> closure matches the cohort freeze` lines, and six
  `ok: <lib> is one store path` (or `ok: <lib> is linked by no family application`) lines.
- `readlink result` equals `nix eval --raw .#darwinConfigurations.SungkyungM1X.system.outPath`.

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
positions in the Kiroku status output) is the evidence that Kiroku appends work.

The negative test through the gate (`./bin/build.sh --override-input mori-rei-app <old>`, from
M4's Concrete Steps) must still fail and leave `./result` unchanged after M5. That is what
proves the gate is not a no-op.


## Idempotence and Recovery

Every guard and verification command is read-only and can be run any number of times. The
guard builds nothing except, the first time, plan 9's small `cohort-compare` app.

`nix flake lock` after the M3 edit is idempotent; if the lock-inspection snippet reports
`CHANGED` for an application, restore `$SCRATCH/flake.lock.before-m3` and rerun
`nix flake lock` (never `nix flake update` here).

`_gated-update` and `update-channel` restore their own backups on failure, so a failed update
leaves `flake.nix` and `flake.lock` exactly as they were, including any uncommitted state that
was there before. `./bin/build.sh` never replaces `./result` with a failing system.

Rollback of a bad deploy: in dotfiles, `git checkout -- flake.lock` (or check out the previous
commit's `flake.lock` with `git checkout HEAD~1 -- flake.lock` when the bad lock was already
committed), `./bin/build.sh`, and the user re-activates. If the lock being restored predates
the guard's requirements, use `HASKELL_PARITY=skip ./bin/build.sh` and
`sudo HASKELL_PARITY=skip ./bin/darwin-rebuild-sungkyung.sh`, and write down why.

A rollback can never cross a Kiroku `0012` cutover. Once a database has run migration `0012`
(the global `rei` database on 2026-09-26, and the `mori` database in plan 12), a Kiroku 0.8
binary fails every append against it. Rolling dotfiles back to a lock that deploys a Kiroku
0.8 build of rei, mori-rei-app or mori would leave those daemons running but unable to write.
Past a cutover, recovery is fix-forward: repair the application or channel and deploy a newer
0.9 build. This plan itself runs no migration.

Never stop or restart an agent with `pkill` by pattern (a pattern match once killed the
deployed Rei worker); use `launchctl kickstart -k gui/$(id -u)/<label>` or
`launchctl bootout gui/$(id -u)/<label>`.


## Interfaces and Dependencies

Tools used: `nix` (Determinate Nix 3.17 / Nix 2.33 on 2026-09-26) for `flake lock`,
`flake update`, `flake metadata --json`, `eval`, `build` and `run`; `nix-store -qR` and
`nix-store -qd`; `jq`; `just`; `python3` for the one-off lock inspection; `launchctl`, `lsof`.
Nothing here ever lists or reads `/nix/store` directly; store paths are only queried through
`nix-store`, `nix eval` and `nix path-info`.

From the channel: the `cohort-compare` flake app with the contract stated in Context and
Orientation (owned by plan 9), and `cabal/cohort.freeze` (owned by plan 8).

`bin/verify-haskell-parity.sh` in dotfiles, at the end of M2:

```bash
#!/usr/bin/env bash
# Rei-family parity guard (mori://shinzui/haskell-nix/plans/14-deploy-one-channel-revision-from-dotfiles-and-guard-closure-parity).
# Usage: bin/verify-haskell-parity.sh [--pins-only | --closure-only] [SYSTEM]   (SYSTEM defaults to ./result)
set -euo pipefail
cd "$(dirname "$0")/.."

family=(rei mori mori-rei-app reiko mina)
shared_libs=(rei-core kioku-core baikai keiro hasql aeson)
host=SungkyungM1X
flake=${PARITY_FLAKE:-.}
read -r -a nix_flags <<<"${PARITY_NIX_FLAGS:-}"
# Set in M3 if mori-rei-app has a flake input for Rei (for example "rei"); empty otherwise.
mra_rei_input=""

mode=both
case "${1:-}" in --pins-only) mode=pins; shift ;; --closure-only) mode=closure; shift ;; esac
system=${1:-./result}

fail=0
ok() { printf 'ok: %s\n' "$*"; }
bad() { printf 'PARITY FAIL: %s\n' "$*" >&2; fail=1; }

lock_rev() { jq -r --arg i "$1" '.nodes as $n | ($n.root.inputs[$i] // empty) as $k | $n[$k].locked.rev' flake.lock; }
own_rev() {  # flake ref, input name -> the revision that flake's own lock records
  nix flake metadata --json "$1" | jq -r --arg i "$2" '
    .locks as $l | ($l.nodes[$l.root].inputs[$i]) as $k
    | if $k == null then "absent" elif ($k | type) == "array" then "follows:" + ($k | join("/"))
      else $l.nodes[$k].locked.rev end'
}
read_file_at() {  # repo, rev, path -> file contents
  nix eval --impure --raw --expr "builtins.readFile ((builtins.fetchTree { type = \"github\"; owner = \"shinzui\"; repo = \"$1\"; rev = \"$2\"; }).outPath + \"/$3\")"
}

channel=$(lock_rev haskell-nix)
base=$(lock_rev haskell-nix-dev)
if [ -z "$channel" ] || [ "$channel" = null ]; then
  bad "no root haskell-nix input in flake.lock"; exit 1
fi

if [ "$mode" != closure ]; then
  channel_base=$(own_rev "github:shinzui/haskell-nix/$channel" haskell-nix-dev)
  if [ "$channel_base" = "$base" ]; then ok "channel ${channel:0:8} on base ${base:0:8}"
  else bad "channel ${channel:0:8} was locked on haskell-nix-dev ${channel_base:0:8}; dotfiles deploys ${base:0:8}"; fi
  for app in "${family[@]}"; do
    rev=$(lock_rev "$app")
    pin=$(own_rev "github:shinzui/$app/$rev" haskell-nix)
    if [ "$pin" != "$channel" ]; then
      bad "$app@${rev:0:8} pins haskell-nix ${pin:0:8} in its own flake.lock; dotfiles deploys ${channel:0:8}"
    elif ! read_file_at "$app" "$rev" cabal.project | grep -q "haskell-nix/$channel/cabal/cohort.freeze"; then
      bad "$app@${rev:0:8} cabal.project does not import cabal/cohort.freeze at ${channel:0:8}"
    else ok "$app@${rev:0:8} pins channel ${channel:0:8} and imports its freeze"; fi
  done
  if [ -n "$mra_rei_input" ]; then
    want=$(lock_rev rei)
    have=$(own_rev "github:shinzui/mori-rei-app/$(lock_rev mori-rei-app)" "$mra_rei_input")
    if [ "$have" = "$want" ]; then ok "mori-rei-app was built against the deployed rei ${want:0:8}"
    else bad "mori-rei-app's own lock pins rei ${have:0:8}; dotfiles deploys ${want:0:8}"; fi
  fi
fi

if [ "$mode" != pins ]; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  nix-store -qR "$system" >"$tmp/system"
  nix eval --json ${nix_flags[@]+"${nix_flags[@]}"} "$flake#darwinConfigurations.$host.pkgs" --apply \
    'pkgs: builtins.listToAttrs (map (a: { name = a; value = pkgs.${a}.outPath; }) [ "rei" "mori" "mori-rei-app" "reiko" "mina" ])' \
    >"$tmp/paths.json"
  parity_cmd=(nix run "github:shinzui/haskell-nix/$channel#cohort-compare" -- --freeze "https://raw.githubusercontent.com/shinzui/haskell-nix/$R/cabal/cohort.freeze" --closure)
  for app in "${family[@]}"; do
    out=$(jq -r --arg a "$app" '.[$a]' "$tmp/paths.json")
    grep -qxF "$out" "$tmp/system" || bad "$app package $out is not in the closure of $system"
    nix-store -qR "$out" >"$tmp/app-$app"
    if "${parity_cmd[@]}" "$out"; then ok "$app closure matches the cohort freeze"
    else bad "$app closure differs from the cohort freeze (see above)"; fi
  done
  for lib in "${shared_libs[@]}"; do
    paths=$(cat "$tmp"/app-* | grep -E "^/nix/store/[a-z0-9]{32}-$lib-[0-9][0-9.]*\$" | sort -u || true)
    count=$(printf '%s' "$paths" | grep -c . || true)
    if [ "$count" -le 1 ]; then
      [ "$count" -eq 1 ] && ok "$lib is one store path" || ok "$lib is linked by no family application"
    else
      bad "$lib has $count store paths across the Rei family:"
      while read -r p; do
        users=$(grep -lxF "$p" "$tmp"/app-* | sed 's|.*/app-||' | paste -sd, -)
        printf '  %s  drv=%s  used by: %s\n' "$p" "$(nix-store -qd "$p" 2>/dev/null || echo unknown)" "$users" >&2
      done <<<"$paths"
    fi
  done
fi

exit "$fail"
```

`bin/build.sh` at the end of M4:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Extra arguments (for example --override-input NAME REF) go to nix build and to the guard.
nix build .#darwinConfigurations.SungkyungM1X.system --out-link result-candidate "$@"
if [ "${HASKELL_PARITY:-}" = skip ]; then
  echo "WARNING: HASKELL_PARITY=skip, the Rei-family parity guard was NOT run" >&2
elif ! PARITY_NIX_FLAGS="$*" ./bin/verify-haskell-parity.sh ./result-candidate; then
  echo "Parity guard failed; ./result still points at the previous system. Candidate: $(readlink result-candidate)" >&2
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
    if nix flake update {{INPUTS}} && ./bin/build.sh; then
      rm -f "$backup"
    else
      cp "$backup" flake.lock
      echo "update of {{INPUTS}} failed its build or parity gate; flake.lock restored" >&2
      exit 1
    fi

# Update rei flake input to latest (moves nothing else)
[group: 'rei']
update-rei: (_gated-update "rei")

# Update the five Rei-family inputs together (rei, mori, mori-rei-app, reiko, mina)
[group: 'tools']
update-rei-family: (_gated-update "rei" "mori" "mori-rei-app" "reiko" "mina")

# Move the shared Haskell channel (mori://shinzui/haskell-nix) to REV, a full commit,
# together with the five Rei-family inputs, whose pushed heads must already pin REV.
# Pass base="yes" only when REV was locked on a different haskell-nix-dev: moving the
# base rebuilds every Haskell input in this flake.
[group: 'tools']
update-channel REV base="no":
    #!/usr/bin/env bash
    set -euo pipefail
    rev="{{REV}}"
    [[ "$rev" =~ ^[0-9a-f]{40}$ ]] || { echo "REV must be a full 40-character commit of shinzui/haskell-nix" >&2; exit 2; }
    new_base=$(nix flake metadata --json "github:shinzui/haskell-nix/$rev" \
      | jq -r '.locks as $l | $l.nodes[$l.nodes[$l.root].inputs["haskell-nix-dev"]].locked.rev')
    cur_base=$(jq -r '.nodes as $n | $n[$n.root.inputs["haskell-nix-dev"]].locked.rev' flake.lock)
    if [ "$new_base" != "$cur_base" ] && [ "{{base}}" != yes ]; then
      echo "channel $rev is on haskell-nix-dev $new_base, dotfiles is on $cur_base; rerun with base=yes to move it" >&2
      exit 1
    fi
    nix_bak=$(mktemp); lock_bak=$(mktemp)
    cp flake.nix "$nix_bak"; cp flake.lock "$lock_bak"
    restore() { cp "$nix_bak" flake.nix; cp "$lock_bak" flake.lock; echo "update-channel failed; flake.nix and flake.lock restored" >&2; exit 1; }
    # -i.bak (suffix attached) works with both GNU sed, which is first on PATH here, and BSD sed.
    sed -E -i.bak "s|(url = \"github:shinzui/haskell-nix/)[0-9a-f]{40}\"|\1$rev\"|" flake.nix
    sed -E -i.bak "s|(haskell-nix-dev.url = \"github:shinzui/haskell-nix-dev/)[0-9a-f]{40}\"|\1$new_base\"|" flake.nix
    rm -f flake.nix.bak
    grep -q "github:shinzui/haskell-nix/$rev\"" flake.nix || restore
    grep -q "github:shinzui/haskell-nix-dev/$new_base\"" flake.nix || restore
    nix flake update haskell-nix haskell-nix-dev rei mori mori-rei-app reiko mina || restore
    ./bin/build.sh || restore
```

`update-kizamu`, `update-mina`, `update-mori`, `update-mori-rei-app`, `update-seihou`,
`update-reiko`, `update-notion-cli`, `update-notion-hub`, `update-tools` and
`update-haskell-fleet` change the same way as `update-rei`: `_gated-update` with their
existing inputs, no base.

The ADR written in M5, in this repository as
`docs/adr/<next number>-deploy-the-rei-family-on-one-channel-revision.md` following the format
of `docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md` (title, `Status:`,
`Date:`, Context, Decision, Consequences): the deploying flake pins one channel revision that
every freeze-importing application follows; each application's own lock and freeze import
must name that same revision; the base is the one the channel revision was locked on; a
deployed closure must match the freeze and share one store path per shared library; the
guard runs before activation. Cite it from the dotfiles `flake.nix` comment by its
`mori://shinzui/haskell-nix/…` URI once Mori resolves ADRs of this repository (until then,
the canonical project URI plus the repository-relative path).


## Revision Notes

- 2026-09-26: Initial draft (claude-opus-5-5). Replaced the skeleton with the full plan,
  based on a read-only survey of dotfiles at `e652c2d` plus its uncommitted deployed lock.
- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The parity app is renamed from `cohort-parity` to plan 9's `cohort-compare`, and its calls use `--freeze <url> --closure <path>`. Plan 14's shared-`drvPath` comparison becomes a new mode of that same tool.
