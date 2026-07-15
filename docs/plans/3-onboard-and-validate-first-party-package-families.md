---
id: 3
slug: onboard-and-validate-first-party-package-families
title: "Onboard and validate first-party package families"
kind: exec-plan
created_at: 2026-07-15T17:12:57Z
intention: intention_01kv1bq794e62tthz1rj47dqrx
master_plan: "docs/masterplans/1-automate-dual-channel-first-party-haskell-package-updates.md"
---

# Onboard and validate first-party package families

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan uses the completed channel foundation and updater CLI to onboard pg-migrate,
Keiro, Kiroku, the main Shibuya monorepo, pgmq-hs, Shikumi, and Baikai. GitHub consumers get
all 51 root packages from the latest locked source revisions; Hackage consumers get the
latest 41 published packages from official release tarballs. Ten currently unpublished
developer packages remain intentionally GitHub-only.

After activation, both channels resolve under `ghc9122` and `ghc914`, every package builds
on the current host with `ghc9122`, and a consumer-shaped Nix expression can select either
provenance. The old handwritten family pins and stale snapshot files are removed only after
the generated registries pass these checks.


## Progress

- [x] (2026-07-15) Add seven non-flake source inputs and seven family config records, then establish a clean managed-file baseline.
- [x] (2026-07-15) Run CLI dry-run and refresh; review the generated 51-package/41-Hackage lock and confirm a second dry-run reports no changes.
- [x] (2026-07-15) Compose generated registries, remove superseded manual entries/files, and preserve unrelated pins.
- [x] (2026-07-15) Resolve exact versions for both channels under `ghc9122` and `ghc914`, with all four mismatch lists empty.
- [ ] Build all 51 GitHub and 41 Hackage packages on the host with `ghc9122`.
- [ ] Run online drift checks, document consumer/update workflows, and finalize outcomes.


## Surprises & Discoveries

- EP-1's eager validation and EP-2's original strict decoder both required the configured
  and locked family sets to be exactly equal. That made the first production refresh from
  an empty lock impossible and made the pre-generation flake check fail with
  `config, lock, source inputs, and Cabal2nix options do not agree`. Refresh now accepts a
  sorted lock containing a subset of configured families and the planner adds observed new
  families; `check`, final planning validation, and Nix evaluation remain exact. Two new
  tests cover the lenient decoder and end-to-end bootstrap, bringing the offline suite to
  34 tests before the later adapter cases were added.

- Mori records local paths but no GitHub repository metadata for Baikai, Keiro, and Shikumi.
  The updater now accepts an empty Mori repository list because the catalog owns the GitHub
  slug, while continuing to reject a non-empty list that conflicts with the catalog. Two
  adapter tests cover both branches.

- The live official Hackage package JSON maps versions directly to status strings such as
  `"normal"`; the original fixtures used objects containing a `status` field. The decoder
  now accepts both shapes, prefixes live failures with the package metadata URL, and has
  direct plus workflow regression coverage. The resulting 37-test suite passes, and the
  first complete production dry-run discovered all expected 51 packages without writing
  either managed lock file.

- The first mutating production refresh received `InvalidChunkHeaders` from Hackage while
  querying `pg-migrate-test-support`. The updater restored both managed files exactly as
  designed. A retry with warmed caches completed, wrote 7 families, 51 packages, 41 Hackage
  pins, and 10 null pins, and a subsequent dry-run reported `No changes.`

- Exact GitHub resolution exposed `shikumi-okf`'s dependency on `okf-core`, which is not in
  the pinned Nixpkgs. Mori located `shinzui/okf`; its current `okf-core` 0.1.2.0 release is
  on Hackage with verified hash
  `sha256-p2LC8DDdqeLnlQn/n8jBL6tt6Iid+bPK15zBRwIOnJg=`. A shared compatibility pin now
  supplies it to both channels.

- Removing legacy family entries exposed that Cabal2nix-generated Hackage functions still
  require dependencies used only by disabled tests and benchmarks. For example, published
  `keiro` names unpublished `keiro-test-support` only in its test and benchmark components.
  The Hackage Haskell extension now supplies null placeholders for all ten GitHub-only names
  during package construction; `dontCheck` and default-disabled benchmarks remove those
  components, while `lib.registries.hackage` still contains none of the ten names. The new
  flake check reports empty mismatch lists for GitHub/Hackage under both compilers.


## Decision Log

- Decision: Onboard every one-directory-deep Cabal package in the seven monorepos.
  Rationale: This yields the 51 requested packages, including benchmarks, examples, smoke,
  and test-support packages, while excluding nested fixtures and the pg-migrate basic example.
  Date: 2026-07-15

- Decision: Keep ten unpublished packages only in the GitHub channel.
  Rationale: Hackage has no source artifact for them; fabricating a Hackage fallback would
  make the channel label misleading.
  Date: 2026-07-15

- Decision: Leave separate Shibuya adapter repositories out of scope and preserve the
  existing `shibuya-pgmq-adapter` Hackage pin.
  Rationale: Mori identifies the Kafka, Message DB, and PGMQ adapters as separate projects;
  the user asked for the main Shibuya package family rather than `shibuya*` repositories.
  Date: 2026-07-15

- Decision: Retain `-f-example` only for `kiroku-metrics`.
  Rationale: The current source patch requires this Cabal2nix option; no other requested
  package has an existing package-specific call option.
  Date: 2026-07-15

- Decision: Build the full matrix for both channels with `ghc9122` and evaluate both under
  `ghc914`.
  Rationale: Supporting both provenances requires compilation evidence for both, while a
  second complete compiler build would add disproportionate cost after exact evaluation.
  Date: 2026-07-15

- Decision: Permit refresh, but not check or Nix registry construction, to load a package
  lock whose family set is a subset of the configured catalog.
  Rationale: Adding a family is a normal refresh operation, and exact equality before the
  updater runs creates an unbootstrappable cycle. Final planner validation still guarantees
  that a successful refresh writes the complete exact family set.
  Date: 2026-07-15

- Decision: Keep the source-input baseline and generated package lock in one final working
  commit by amending the temporary clean baseline after refresh.
  Rationale: The updater requires committed managed lock files before mutation, but the
  strict Nix registry intentionally rejects the transient non-empty-config/empty-lock state.
  Amending preserves the updater's clean-file safety check without retaining a broken commit.
  Date: 2026-07-15

- Decision: Keep unpublished family packages out of the public Hackage registry while
  supplying null placeholders inside the Hackage Haskell extension.
  Rationale: Cabal2nix includes disabled test and benchmark dependencies in generated
  function arguments. The placeholders let published libraries evaluate without presenting
  GitHub-only packages as Hackage packages or fetching their source into that channel.
  Date: 2026-07-15


## Outcomes & Retrospective

(To be filled during and after implementation.)


## Context and Orientation

This plan has two hard dependencies. EP-1,
`docs/plans/1-introduce-manifest-driven-hackage-and-github-channels.md`, must provide the
versioned config/package-lock schemas, generic Nix registry constructors, and dual public
outputs. EP-2, `docs/plans/2-build-the-haskell-package-refresh-cli.md`, must provide the
tested `nix run .#haskell-nix-update` workflow. Do not implement this plan by manually
recreating the generated lock.

Before migration, `overlays/registry.nix` mixes common compatibility patches with manual
first-party entries. pg-migrate is absent. Keiro, Kiroku, and Shibuya use old
`fetchFromGitHub` revisions. pgmq-hs uses five 0.3 Hackage pins, and Shikumi and Baikai expose
only partial Hackage subsets. The generated registries must win on duplicate names during
the transition so old entries remain a safe fallback until deletion.

Add these non-flake inputs to `flake.nix`; Nix records their immutable revisions and content
hashes in `flake.lock`:

```nix
pg-migrate-src = { url = "github:shinzui/pg-migrate"; flake = false; };
keiro-src = { url = "github:shinzui/keiro"; flake = false; };
kiroku-src = { url = "github:shinzui/kiroku"; flake = false; };
shibuya-src = { url = "github:shinzui/shibuya"; flake = false; };
pgmq-hs-src = { url = "github:shinzui/pgmq-hs"; flake = false; };
shikumi-src = { url = "github:shinzui/shikumi"; flake = false; };
baikai-src = { url = "github:shinzui/baikai"; flake = false; };
```

Populate `config/first-party-families.json` with seven records. Their family name, Mori
qualified project, GitHub repository, and input name are respectively:

```text
pg-migrate  shinzui/pg-migrate  shinzui/pg-migrate  pg-migrate-src
keiro       shinzui/keiro       shinzui/keiro       keiro-src
kiroku      shinzui/kiroku      shinzui/kiroku      kiroku-src
shibuya     shinzui/shibuya     shinzui/shibuya     shibuya-src
pgmq-hs     shinzui/pgmq-hs     shinzui/pgmq-hs     pgmq-hs-src
shikumi     shinzui/shikumi     shinzui/shikumi     shikumi-src
baikai      shinzui/baikai      shinzui/baikai      baikai-src
```

All `packageOverrides` objects are empty except Kiroku's:

```json
{
  "kiroku-metrics": {
    "cabal2nixOptions": "-f-example"
  }
}
```

Research on 2026-07-15 verified that each local checkout matched remote `master`. The
observed revisions were pg-migrate
`f39d64e354818999667d345a1452f33eb4857fc1`, Keiro
`29bd7952fa5201adf789bbb21427b2cffe228d4b`, Kiroku
`58aff77b3a6d6093e3613753a0543aab62db9fac`, Shibuya
`172df245f40a454af46dd7f4cde855eaa4414c5a`, pgmq-hs
`f4a101843ea6f5c055277fd84859ece02865eff4`, Shikumi
`0df4d85928c79cbfe78d7880a263fc0b9696ddc2`, and Baikai
`4bce32b934c8be302f06e835a72df9a5c9627535`. The updater must use the current remote heads
at implementation time; if any moved, record the new revision and package/version changes
in Surprises & Discoveries and revise the acceptance inventory before activation.

The official Hackage JSON endpoints were checked for every package on 2026-07-15. The
expected baseline is below. A dash means Hackage returned 404 and the package belongs only
to the GitHub channel. The first version is the GitHub Cabal version and the second is the
latest Hackage version:

```text
# pg-migrate
pg-migrate                          1.1.0.0  1.1.0.0
pg-migrate-cli                      1.1.0.0  1.1.0.0
pg-migrate-embed                    1.1.0.0  1.1.0.0
pg-migrate-import-codd              1.1.0.0  1.1.0.0
pg-migrate-import-hasql-migration   1.1.0.0  1.1.0.0
pg-migrate-test-support             1.1.0.0  1.1.0.0

# Keiro
keiro                               0.3.0.0  0.3.0.0
keiro-core                          0.3.0.0  0.3.0.0
keiro-dsl                           0.3.0.0  0.3.0.0
keiro-migrations                    0.3.0.0  0.3.0.0
keiro-pgmq                          0.3.0.0  0.3.0.0
keiro-test-support                  0.1.0.0  -
jitsurei                            0.1.0.0  -

# Kiroku
kiroku-cli                          0.2.0.0  0.2.0.0
kiroku-jitsurei                     0.1.0.0  -
kiroku-metrics                      0.1.0.1  0.1.0.1
kiroku-otel                         0.2.0.1  0.2.0.1
kiroku-store                        0.3.0.1  0.3.0.1
kiroku-store-migrations             0.3.0.0  0.3.0.0
kiroku-test-support                 0.1.0.0  -
shibuya-kiroku-adapter              0.4.0.0  0.4.0.0

# Shibuya
shibuya-core                        0.8.0.1  0.8.0.1
shibuya-core-bench                  0.1.0.0  -
shibuya-example                     0.1.0.0  -
shibuya-metrics                     0.8.0.1  0.8.0.1

# pgmq-hs
pgmq-bench                          0.1.0.0  -
pgmq-config                         0.4.0.1  0.4.0.1
pgmq-core                           0.4.0.1  0.4.0.1
pgmq-effectful                      0.4.0.1  0.4.0.1
pgmq-hasql                          0.4.0.1  0.4.0.1
pgmq-migration                      0.4.0.1  0.4.0.1

# Shikumi
shikumi                             0.3.0.0  0.3.0.0
shikumi-cache                       0.1.2.0  0.1.2.0
shikumi-cache-postgres              0.1.2.0  0.1.2.0
shikumi-cache-redis                 0.1.2.0  0.1.2.0
shikumi-cli                         0.1.0.0  -
shikumi-compile                     0.2.0.0  0.2.0.0
shikumi-eval                        0.2.0.0  0.2.0.0
shikumi-jitsurei                    0.1.0.0  -
shikumi-okf                         0.1.0.1  0.1.0.1
shikumi-optimize                   0.2.1.0  0.2.1.0
shikumi-tools                       0.3.0.0  0.3.0.0
shikumi-trace                       0.2.0.0  0.2.0.0
shikumi-trace-otel                  0.1.1.0  0.1.1.0

# Baikai
baikai                              0.3.1.0  0.3.1.0
baikai-claude                       0.3.0.1  0.3.0.1
baikai-effectful                    0.3.0.1  0.3.0.1
baikai-kit                          0.1.0.2  0.1.0.2
baikai-openai                       0.3.0.1  0.3.0.1
baikai-smoke                        0.1.0.0  -
baikai-trace-otel                   0.3.0.1  0.3.0.1
```

The first-party dependency order is pg-migrate before pgmq-hs and Kiroku; Shibuya and
pgmq-hs before Kiroku/Keiro; Kiroku before Keiro; and Baikai before Shikumi. Nix's fixed
point makes textual order unimportant, but use this order to diagnose failures.


## Plan of Work

### Milestone 1: Establish source inputs and generate the production lock

Add the seven `flake = false` inputs and the seven config records. Run `nix flake lock` to
add only missing input nodes, verify each locked revision against the corresponding remote,
and commit `flake.nix`, `flake.lock`, and the family config before invoking the updater. The
active legacy registry remains unchanged, so this is an independently working baseline and
the CLI's dirty-managed-file protection can operate normally.

Run `nix run .#haskell-nix-update -- refresh --dry-run` and compare its proposed family,
package, GitHub version, publication, and Hackage-version results with the baseline inventory
above. Then run the real refresh. Review `packages/first-party-lock.json` rather than trusting
the command summary alone: it must have seven sorted families, 51 globally unique packages,
41 non-null Hackage pins, 10 null pins, clean relative paths, the Kiroku option, locked
revisions matching `flake.lock`, and SRI hashes for every Hackage pin. A second dry-run must
report no changes.

### Milestone 2: Activate generated channels and retire manual family pins

Pass the seven input `outPath` values to the EP-1 GitHub registry constructor in `flake.nix`.
Compose common compatibility entries first and generated channel entries second so the
selected channel wins on duplicate package names. Add version-manifest checks derived from
`packages/first-party-lock.json`: GitHub checks every package's source version, while Hackage
checks only non-null pins against their Hackage version, under both `ghc9122` and `ghc914`.
The check must force `.version`, not merely test attribute presence.

After both channel checks pass, remove the requested families' manual entries from
`overlays/registry.nix`. Preserve unrelated pins, including OpenTelemetry, cryptography,
Hasql compatibility, `blake3`, provider client libraries, and
`shibuya-pgmq-adapter`. Remove now-unreferenced files:
`patches/keiro/0.1.nix`, `patches/kiroku/0.1.nix`,
`patches/shibuya-core/0.1.nix`, all five `patches/pgmq-*` package files,
the four existing Shikumi package files, and the five existing Baikai package files. Use
`rg` to prove no deleted path remains referenced. Commit activation and removal together so
no commit contains dangling imports.

### Milestone 3: Build both provenances and complete operations documentation

Use one Nix expression per channel to map the generated package names to the overlaid
`ghc9122` derivations and build them with `--keep-going --no-link`. The GitHub expression
must request 51 derivations; the Hackage expression must request 41. Run focused builds in
dependency order when diagnosing errors, record every new compatibility workaround in the
living sections, and rerun each complete matrix after fixes. Do not enable upstream test
suites or live Baikai smoke requests; these registry replacements retain `dontCheck`.

Run `haskell-nix-update check --online` after the build to confirm no source or Hackage drift
occurred during implementation. Update `README.md`, `docs/user/getting-started.md`,
`docs/user/consumer-integration.md`, and `docs/user/updating-first-party-packages.md` with
channel selection, the GitHub-only behavior, the one-command refresh, review expectations,
and downstream `--override-input` validation. The plan completes only when both channel
builds and all flake checks pass and Outcomes & Retrospective records the final counts.


## Concrete Steps

Run from `/Users/shinzui/Keikaku/bokuno/haskell-nix` after EP-1 and EP-2 are marked Complete
in the master plan. Reconfirm registered sources and preserve unrelated changes:

```bash
mori show --full
mori registry show shinzui/pg-migrate --full
mori registry show shinzui/keiro --full
mori registry show shinzui/kiroku --full
mori registry show shinzui/shibuya --full
mori registry show shinzui/pgmq-hs --full
mori registry show shinzui/shikumi --full
mori registry show shinzui/baikai --full
git status --short --branch
```

After adding inputs and config, add missing lock nodes and validate syntax:

```bash
nix flake lock
jq empty config/first-party-families.json packages/first-party-lock.json
nix flake check --print-build-logs
git diff --check
```

Commit this working baseline with both trailers before the updater runs:

```text
feat(packages): register first-party source inputs

MasterPlan: docs/masterplans/1-automate-dual-channel-first-party-haskell-package-updates.md
ExecPlan: docs/plans/3-onboard-and-validate-first-party-package-families.md
```

Preview, apply, and verify generation:

```bash
nix run .#haskell-nix-update -- refresh --dry-run
nix run .#haskell-nix-update -- refresh
jq '[.families[].packages[]] | length' packages/first-party-lock.json
jq '[.families[].packages[] | select(.hackage != null)] | length' packages/first-party-lock.json
jq '[.families[].packages[] | select(.hackage == null)] | length' packages/first-party-lock.json
nix run .#haskell-nix-update -- refresh --dry-run
```

The three counts must be `51`, `41`, and `10`. The final dry-run must report no changes.
Commit the generated lock and updated living documents separately from channel activation so
the updater's product is easy to audit.

After activation, run exact resolution checks and the full flake suite:

```bash
nix eval --json .#lib.registries.github --apply builtins.attrNames
nix eval --json .#lib.registries.hackage --apply builtins.attrNames
nix flake check --print-build-logs
rg -n 'patches/(keiro/0\.1|kiroku/0\.1|shibuya-core/0\.1|pgmq-(core|hasql|effectful|migration|config)|shikumi(-cache|-trace|-trace-otel)?/0\.1|baikai(-claude|-effectful|-openai|-trace-otel)?/0\.1)' overlays docs README.md
```

The final `rg` command should print no references to deleted modules; its exit status of 1
means no matches and is expected. Commit registry activation with a Conventional Commit
subject such as `feat(packages): activate generated Hackage and GitHub channels` and both
trailers.

Build the GitHub matrix:

```bash
nix build --no-link --keep-going --print-build-logs --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ flake.overlays.github ];
    };
    lock = builtins.fromJSON (builtins.readFile ./packages/first-party-lock.json);
    names = builtins.concatMap
      (family: map (package: package.name) family.packages)
      lock.families;
  in
  map (name: pkgs.haskell.packages.ghc9122.${name}) names
'
```

Build the Hackage matrix from only published packages:

```bash
nix build --no-link --keep-going --print-build-logs --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ flake.overlays.hackage ];
    };
    lock = builtins.fromJSON (builtins.readFile ./packages/first-party-lock.json);
    packages = builtins.concatMap (family: family.packages) lock.families;
    names = map (package: package.name)
      (builtins.filter (package: package.hackage != null) packages);
  in
  map (name: pkgs.haskell.packages.ghc9122.${name}) names
'
```

Both commands must exit zero. They use `--no-link`, so they do not create a repository
`result` symlink. Complete with:

```bash
nix run .#haskell-nix-update -- check --online
nix flake check --print-build-logs
git diff --check
git status --short
```

Update every living section before the last documentation/fix commit and include both plan
trailers in every commit made under this child.


## Validation and Acceptance

Acceptance starts with generated-state evidence: the CLI produces seven family records,
51 GitHub packages, 41 Hackage pins, and 10 null Hackage pins; a second refresh dry-run is a
no-op; and offline plus online checks pass. Every `githubRev` must equal its named
`flake.lock` input revision.

The GitHub and Hackage version checks must resolve every applicable package under both
`ghc9122` and `ghc914` to the channel-specific version recorded in the package lock. The two
complete `ghc9122` build commands must exit zero. This proves both provenance paths compile,
not merely that their attributes exist. GitHub-only names such as `baikai-smoke` and
`shikumi-cli` must be present in the GitHub registry and absent from the generated Hackage
registry.

A consumer-shaped expression using `lib.haskellExtensions.hackage` must resolve a published
package such as `pg-migrate`, and the same expression using `.github` must resolve it from
the locked monorepo. The compatibility alias `lib.haskellExtension` must behave like
`.github`. Documentation must state the provenance and availability differences without
implying that the Hackage channel contains unpublished packages.


## Idempotence and Recovery

`nix flake lock` is used only to add missing inputs in the baseline commit. Thereafter the
CLI owns targeted updates and restores both managed lock files on failure. Dry-run, check,
evaluation, and no-link builds are safe to repeat. A failed full matrix leaves successful
Nix artifacts cached and does not modify the working tree.

Do not remove a manual registry entry until the generated replacement resolves in both
compiler sets. If activation fails, keep or restore the manual file by an ordinary patch,
not a destructive Git reset, and record the remaining package in Progress. If an upstream
head or Hackage release changes during implementation, rerun the updater, revise the baseline
inventory and Decision Log, and rebuild both complete matrices before completion.


## Interfaces and Dependencies

This child consumes the EP-1 schemas and `lib/mkFirstPartyRegistries.nix`, the EP-2
`haskell-nix-update` app, Mori qualified projects, GitHub non-flake inputs, official Hackage
JSON/tarballs, and the existing Nixpkgs Haskell APIs. It changes no Haskell package source.

At completion the public interfaces are:

```text
lib.haskellExtensions.hackage  : HaskellLib -> Pkgs -> HaskellExtension
lib.haskellExtensions.github   : HaskellLib -> Pkgs -> HaskellExtension
lib.registries.hackage         : Registry
lib.registries.github          : Registry
overlays.hackage               : NixpkgsOverlay
overlays.github                : NixpkgsOverlay
```

`lib.haskellExtension`, `lib.registry`, `overlays.default`, and `overlays.haskell` remain
GitHub aliases. `config/first-party-families.json` is hand-authored; only the updater writes
`packages/first-party-lock.json`. The common registry retains all packages outside the seven
families and the separate `shibuya-pgmq-adapter` pin. No downstream consumer or upstream
Mori-located source repository is edited.


## Revision Note

2026-07-15: Began implementation, added the seven source inputs and family records, repaired
the updater's empty-lock bootstrap, empty-Mori-repository, and live Hackage-status handling,
and generated the reviewed 51-package production lock after one successfully rolled-back
transient Hackage failure. The baseline/generated-lock commit sequence was consolidated so
every retained commit remains a working state.

2026-07-15: Activated both generated channels, added exact-version checks for both supported
compilers, supplied the Mori-located `okf-core` dependency, removed superseded handwritten
family entries and files, and verified consumer-shaped extensions plus public Hackage
exclusion of all ten unpublished names.
