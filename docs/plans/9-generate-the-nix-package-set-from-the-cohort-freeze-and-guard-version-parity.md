---
id: 9
slug: generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity
title: "Generate the Nix package set from the cohort freeze and guard version parity"
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
      harness: "codex"
      at: 2026-10-07T00:41:12Z
      mode: "implement"
      note: "Independent format guard and parser/generator preparation; activation remains gated on EP8 acceptance"
  reviews:
    - model: "gpt-6.1-sol"
      harness: "codex-cli"
      at: 2026-10-04T13:51:42Z
      verdict: "changes-requested"
      note: "Original review found static-link/duplicate-version false parity, metadata-revision drift and missing cache proof; applied findings in update."
---

# Generate the Nix package set from the cohort freeze and guard version parity

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.
If durable project context changes, update or create ADRs in docs/adr/ in the same change.


## Purpose / Big Picture

Today the Haskell package versions this repository's Nix channel hands to consumers are chosen
by hand, one pinned patch file at a time, while the same applications' Cabal builds choose their
versions with Cabal's solver. The two disagree silently. On 2026-09-26 Rei's shipped Nix binary
linked hasql 1.10.2.4, tls 2.3.1, aeson 2.2.4.1 and shibuya-pgmq-adapter 0.16.0.0, while the Cabal
build Rei's test suite runs linked hasql 1.10.3.7, tls 2.4.6, aeson 2.2.5.1 and
shibuya-pgmq-adapter 0.16.1.0. The tests never exercised the code that ships.

After this plan, the channel's versions are no longer written by hand. A sibling plan (plan 8,
`docs/plans/8-resolve-one-upgrade-only-cohort-freeze-for-the-rei-family-of-applications.md`)
commits `cabal/cohort.freeze`: one Cabal constraints file listing a single version for every
Haskell package the five Rei-family applications use. This plan adds a generator that reads that
file and writes `generated/cohort-versions.nix`, a Nix file naming the exact Hackage release for
every package whose version differs from what nixpkgs already ships. The channel loads it, so
evaluating, for example, `haskell.packages.ghc9124.hasql.version` through the channel returns the
frozen version. A pure `nix flake check` entry fails the moment any frozen package's Nix version
differs from the freeze, and a shared comparison script under `scripts/` answers the same question
for a consumer's Cabal `plan.json` or for a built Nix store closure.

How to see it working, once the plan is done, from the repository root:

```bash
nix eval --json .#lib.cohort.versionTable --apply 'v: { inherit (v) hasql tls aeson warp shibuya-pgmq-adapter; }'
nix build --no-link --print-build-logs ".#checks.aarch64-darwin.cohort-versions"
nix run .#cohort-compare -- --freeze cabal/cohort.freeze --plan-json ../rei-project/rei/dist-newstyle/cache/plan.json
```

The first command prints the frozen versions (for example hasql 1.10.3.7 where it used to print
1.10.2.4), the second succeeds, and the third prints a per-package verdict and exits non-zero while
any Rei package still differs from the freeze.

This plan also satisfies the haskell-nix improvement request
`mori://shinzui/haskell-nix/okf/improvement-requests/concepts/IR-2` ("Provide a coherent modern CLI
and WAI dependency cohort"), because aeson 2.2.5.1, generic-lens 2.3, wai 3.2.5 and warp 3.4.16 and
their transitive cohort all arrive through the freeze.


## Review requirements (2026-10-04)

Plan 16 (`docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md`) owns retained runtime records and guarded application composition after this plan and plan 10. Provide reusable generator and manifest helpers accepting an explicit resolved cohort/source/configuration context. Plan 16 uses them to generate immutable runtime projections and extends manifests with runtime name/generation/configuration; no duplicate freeze parser, source/hash lookup or comparator is permitted. A selected runtime projection protects its owned dependency recipes when applying additional application entries. Detect shared-name source/metadata/flag/policy conflicts before claiming reuse. Keep ordinary default/historical factory behavior and checks valid. Runtime builds/cache warming in plan 16 reuse this plan's publication mechanism, including any additional runtime roots.

Follow [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md): ordinary application edits retain the cohort and toolchain pins. Matching versions alone is insufficient evidence of reused builds. Historical input revisions, package counts and deletion lists below are starting observations; refresh them from recorded contributor revisions.

Plan 9 owns the shared `cohort-compare` app. Use `--freeze FILE_OR_URL --plan-json FILE` for a freshly generated Cabal plan and `--freeze FILE_OR_URL --nix-manifest FILE` for the executable's build evidence. Use `--compare-manifests FILE FILE` to compare build identities and `--resolve-channel-lock FILE --input-path PATH` to obtain a channel's full locked revision. The resolver starts at the lock's declared root and handles recursive array `follows`, string nodes, missing nodes and cycles. Check the Cabal import revision against the application's own resolved lock, rather than assuming a node named `haskell-nix` exists. Return 0 on success, 1 on drift or missing/unverifiable evidence, and 2 on usage error.

Export `packages.<system>.cohort-manifest` through plan 9's construction helper. Its JSON schema records the system, compiler/toolchain/channel, actual executable root drv/output and Haskell packages with names, versions, component roles, source/metadata identities, flags/policy and drv/output paths. Generate records from the actual composed scope used to build the executable, then verify dependency edges against that root's derivation graph through Nix metadata APIs. Runtime closures may omit static Haskell libraries; basename parsing and unrelated channel evaluation cannot prove parity. All instances of a Haskell package must pass, including when one correct and one incorrect version coexist. Missing expected dependencies fail. Native build tools and compiler packages are distinguished by role.

Refresh `plan.json` with tests and benchmarks enabled for supported configurations; check all non-local packages. Record own packages and non-Hackage source pins in the channel's declared policy and `cabal/cohort-sources.json` (exact source revision/subdirectory plus reasons and owners for intentional Cabal/Nix source or flag differences). Do not use arbitrary `--ignore` lists. Keep exact-binary release rehearsals: version parity alone does not establish flag/source or behavioral equivalence. Consumer checks are thin calls to shared tooling, with no fallback comparator.

Extend plan 8's model/parser/CLI; own generation-specific modules and `just cohort-generated-check`, called by plan 8's aggregate `cohort-check`. Do not redefine `CohortTest` or shared type ownership. A same-version Hackage package may have different Cabal metadata after index-state changes: select the metadata revision at the recorded index-state, key revision lookup by package/version/index-state, and reuse the tarball hash independently. `sameAsBase` requires matching source and metadata policy as well as version; otherwise emit a metadata override. Record source-pinned packages and declared local ownership, without silently excluding their provenance.

Build and publish shared dependency outputs to the existing trusted cache before plans 11–13 adopt them. Verify publication credentials and read access on configured CI workers; retain no credentials in artifacts. Build one declared supported set/compiler per system and record actual substitution on a fresh worker. Scope parity claims to those selected sets, channels and compilers. Keep existing immutable historical selection and cache-identity checks passing; do not assume all older selectable first-party sets match the new default freeze. Preserve the updater's bootstrap independence from generated consumer dependencies.

Acceptance fixtures include statically linked missing dependencies, wrong plus correct package instances, native homonyms, source/metadata changes without version changes, recursive/cyclic/missing follows paths, and stale import revisions. Cache readiness and shared identity evidence are gates distinct from version parity. Existing runtime-closure commands elsewhere below are diagnostic only.

## Progress

- [ ] (2026-10-06, started) Independent preparation: add the format guard and fixture-based rich parser/generator modules while EP-8's aggregate acceptance runs. No generated layer activation or completion is claimed.

- [ ] Manifest/lock-resolution fixtures pass and shared dependency outputs are available from the CI cache

- [ ] Milestone 1 (prototype): reproduce which `cabal-version` values the channel's
  `callCabal2nix` path parses at the pinned nixpkgs, and decide whether a GHC 9.12 `cabal2nix`
  overlay is needed.
- [x] (2026-10-07 UTC) Milestone 1: add the `cabal-version-support` check with `cabal-version: 3.14` and `3.16`
  fixtures (and, only if the prototype says so, the fallback override).
- [x] (2026-10-07 UTC) Milestone 2: add `lib/parseCohortFreeze.nix` and twelve meaningful nix-unit checks. Shared packaged parser corpus covers comments, flags, trailing commas, duplicate versions/flag records, ranges, garbage, internal empty records and flag-only input; the real freeze is compared with the independently recorded source manifest.
- [ ] Milestone 2: add `config/cohort-policy.json`.
- [ ] Milestone 2: add the `cohort generate` subcommand to `haskell-nix-update`, with Haskell tests.
- [ ] Milestone 2: run the generator against `cabal/cohort.freeze` and commit
  `generated/cohort-versions.nix` and `generated/ghc-boot-packages.nix`.
- [ ] Milestone 3: add `checks/cohort-parity.nix` (`cohort-generated-fresh`, `cohort-versions`,
  `ghc-boot-packages`) and record the failing `cohort-versions` output before wiring.
- [ ] Milestone 4: add `lib/mkCohortVersionLayer.nix` and wire it into
  `lib/mkHaskellExtension.nix`, `lib/mkHaskellOverlay.nix`, `lib/mkFirstPartyPackageSet.nix` and
  `flake.nix`.
- [ ] Milestone 4: convert every hand-written version pin in `overlays/registry.nix` to a
  policy-only entry or delete it; delete the retired `patches/*` files and the unreferenced
  `patches/hasql/1.9.nix`.
- [ ] Milestone 4: add the `registry-policy-only` lint check; `nix flake check` passes.
- [ ] Milestone 5: add `scripts/cohort-compare.sh`, the `cohort-compare` flake app and its
  fixture check; run it against Rei's `plan.json` and Rei's deployed closure.
- [ ] Milestone 6: build `cohort-closure` on aarch64-darwin (and the x86_64-linux curated matrix);
  record the before/after versions table and build times.
- [ ] Milestone 6: write `docs/adr/3-generate-the-channels-package-versions-from-the-cohort-freeze.md`,
  update `docs/user/adding-patches.md` and `docs/user/package-sets.md`, mark IR-2 completed, and
  update the MasterPlan's Progress and Surprises.


## Surprises & Discoveries

- Observation (2026-10-06): forcing both 3.14 and 3.16 fixtures through both channel `callCabal2nix` paths parses successfully, but building the 3.16 fixture with GHC 9.12.4's boot Cabal 3.14.2.0 fails before configure. The guard must build the 3.14 fixture and separately force all four parser derivations. The two tools' supported format ceilings are distinct; no cabal2nix rebuild is justified by a setup-driver failure.
  Evidence: the corrected `nix build .#checks.aarch64-darwin.cabal-version-support --no-link --max-jobs 2 --cores 2` exits 0, realizing the 3.14 tiny library and the guard after forcing all four parser paths. `nix fmt` succeeds. The guard does not claim that GHC's boot setup driver supports 3.16.

- Observation: The channel's `callCabal2nix`, `callHackage` and `callHackageDirect` already parse
  `cabal-version: 3.14` and `3.16` at the pinned nixpkgs `d5dfd8e6`, and reject only `3.18`. The
  MasterPlan's Surprises entry ("rejects 3.14 and 3.16") describes the standalone
  `pkgs.cabal2nix` / `pkgs.cabal2nix-unwrapped` binary (cabal2nix 2.21.3, GHC 9.10.3, Cabal 3.12),
  which nothing in this repository runs. Import-from-derivation (IFD: Nix builds a derivation
  during evaluation and reads its output as Nix code) goes through the package set's
  `haskellSrc2nix`, which uses `pkgs.buildPackages.haskellPackages.cabal2nix-unstable`: cabal2nix
  `2.21.3-unstable-2026-03-30`, built with GHC 9.10.3 but against the non-boot `Cabal-3.16.1.0`.
  That binary is on cache.nixos.org.
  Evidence (scratch packages that differ only in the `cabal-version` field, evaluated through
  `overlays.github` on aarch64-darwin, 2026-09-26):

  ```text
  cabal-version 3.14 -> /nix/store/av2lh7nb…-tiny-0.1.0.0.drv
  cabal-version 3.16 -> /nix/store/zn6w90zk…-tiny-0.1.0.0.drv
  cabal-version 3.18 -> *** cannot parse ".../tiny.cabal": Unsupported cabal format version in cabal-version field: 3.18.
  IFD cabal2nix drv inputs: Cabal-3.16.1.0.drv, ghc-9.10.3.drv, distribution-nixpkgs-1.7.1.1-unstable-2026-03-30.drv
  ```

- Observation: Building `haskell.packages.ghc9124.cabal2nix-unstable` (the MasterPlan's proposed
  overlay) is not free. `nix build --dry-run` lists 75 derivations to compile from source on
  aarch64-darwin (Cabal-syntax 3.16.1.0, aeson, lens, tls 2.1.8, http-client-tls, …), because
  `haskell.packages.ghc9124.*` is not on cache.nixos.org. Every consumer would pay that before its
  first IFD.
- Observation: A Haskell extension can replace `haskellSrc2nix` for its scope. With
  `overrides = self: super: { haskellSrc2nix = _: throw "EXT"; }`, `callCabal2nix` on a scratch
  package fails evaluation while the unmodified set succeeds. That is the fallback route if the IFD
  path ever regresses, and it reaches consumers that only compose `lib.haskellExtension` (which is
  how rei, mori and mori-rei-app consume the channel), unlike a nixpkgs-level overlay.
- Observation: nixpkgs' pinned `all-cabal-hashes` (commit `3a3b69b`, a 78 MB tarball) predates the
  cohort. `callHackage "hasql" "1.10.3.7"` fails with
  `tar: */hasql/1.10.3.7/hasql.cabal: Not found in archive`; so do shibuya-pgmq-adapter 0.16.1.0,
  warp 3.4.16 and tls 2.4.6.
- Observation: `callHackageDirect` accepts a Hackage cabal-file revision:
  `rev = { revision = "1"; sha256 = "<hex sha256 from Hackage's revisions API>"; }`. For
  http-conduit 2.3.9.1 the derivation with `rev` differs from the one without. Hackage's
  `https://hackage.haskell.org/package/<p>-<v>/revisions/` (with `Accept: application/json`)
  returns each revision's number, time and sha256, which is enough to choose the revision Cabal
  saw at an index-state.
- Observation: Measured against Rei's current `dist-newstyle/cache/plan.json` (412 non-local
  packages), nixpkgs' plain `haskell.packages.ghc9124` has 36 as GHC boot packages (null in the
  Nix set), 45 absent (mostly first-party family packages plus `hs-opentelemetry-api-types`,
  `-propagator-jaeger`, `-propagator-xray`, `typeid-hs-*`), 230 at the same version, and 101 at a
  different version. So the generated layer for Rei alone is about a hundred entries; the
  five-application freeze will be somewhat larger. Every boot package in the plan is
  `pre-existing` (Cabal used GHC's copy); none was reinstalled.
- Observation: Among first-party packages, Rei's plan differs from the default package set only
  for `baikai-effectful` (plan 0.4.0.1, lock 0.4.0.2 on both channels; 0.4.0.2 is on Hackage). For
  every published first-party package in the default set, the GitHub-channel version equals the
  Hackage-channel version today.
- Observation: The channel today (at `4cabd10`, `overlays.github`, ghc9124) evaluates hasql
  1.10.2.4, hasql-pool 1.4.1, tls 2.3.1, crypton 1.1.2, aeson 2.2.4.1, warp 3.4.9, wai 3.2.4,
  generic-lens 2.2.2.0, sbv 11.7, shibuya-pgmq-adapter 0.16.0.0, baikai-effectful 0.4.0.2,
  optparse-applicative 0.19.0.0, streamly 0.11.0, brick 2.9 and vty 6.4. These are the "before"
  values for Milestone 6.


## Decision Log

- Decision (2026-10-06): implement only the additive preparatory milestones explicitly permitted in Context while EP-8 aggregate acceptance runs. Root owns format fixtures/check integration and CLI registration; the Haskell worker extends the existing freeze/model ownership with isolated generation modules/tests. The generator reads the source manifest as well as the 445-entry freeze, retaining all five source pins and the 450-selection identity coverage. Keep generated-layer activation gated on EP-8 and preserve final acceptance requirements.

- Decision (runtime plan, 2026-10-04): adopt the plan-16 integration contract above. It owns retained runtime selection/composition, while this plan retains its existing solver/generation/policy/consumer/deployment responsibility. Consumer plans 11–13 require runtime delivery before adoption; preparatory shared tools do not depend on consumers.

- Decision (2026-10-04 review update): adopt the Review requirements above and ADR 5's update-isolation/build-evidence contract. Historical closure-only acceptance, fixed package counts and duplicated comparison implementations are superseded where noted. Preserve the agreed advisory fleet guard and effectful migration policy. Implementation evidence remains pending.

- Decision: Do not add the `cabal2nix-unwrapped = justStaticExecutables haskell.packages.ghc9124.cabal2nix`
  overlay by default. Milestone 1 re-proves that the IFD path parses `cabal-version: 3.14` and
  `3.16`, and adds a `cabal-version-support` check so a future nixpkgs bump that regresses is
  caught. The GHC 9.12 build is kept as a documented fallback, applied through a `haskellSrc2nix`
  override in the channel's Haskell extension, not a nixpkgs overlay.
  Rationale: The MasterPlan asked for the overlay so that a `cabal-version: 3.14` package needs no
  patch. The evidence shows that is already true for every code path the channel uses. The
  overlay would also not have reached that path, because `haskellSrc2nix` uses
  `buildPackages.haskellPackages.cabal2nix-unstable`, not `cabal2nix-unwrapped`. Building it with
  GHC 9.12 costs 75 uncached derivations for every consumer. The guard check delivers the
  MasterPlan's outcome (3.14 needs no patch, and a regression is loud) without that cost. The
  implementer updates the MasterPlan's Surprises entry and its EP-9 Progress wording in
  Milestone 6.
  Date: 2026-09-26
- Decision: Generated entries use `callHackageDirect` with a prefetched unpacked hash
  (`nix store prefetch-file --unpack`, the same helper `prefetchHackage` the updater already uses)
  plus, when the freeze's index-state saw one, the Hackage cabal-file revision. Do not pin a newer
  `all-cabal-hashes` and use `callHackage`.
  Rationale: The two were evaluated.
  - **Where it can be applied.** Consumers compose `lib.haskellExtension` into their own nixpkgs;
    `all-cabal-hashes` is a nixpkgs-level attribute, so the `callHackage` route would need either
    a nixpkgs overlay consumers do not apply or a re-implemented `hackage2nix` inside the
    extension. `callHackageDirect` works inside the extension unchanged.
  - **Input size.** `all-cabal-hashes` is a 78 MB input that would move on every freeze update and
    be downloaded by every consumer. `callHackageDirect` fetches only the tarballs the build needs
    anyway.
  - **Reviewability and reproducibility.** Each entry names its version and hash in a diff a
    reviewer can read; nothing depends on the contents of a large snapshot.
  - **Generator speed.** The generator reuses the previous hash whenever a package's version and
    revision are unchanged, so it only prefetches changed packages (about a hundred on the first
    run, a handful afterwards).
  - **Cache behavior.** Equivalent: a package's derivation depends on its source hash either way,
    and moving one entry changes only that package and its dependents.
  - **What `callHackage` does better** is using Hackage's latest cabal-file revision
    automatically. The generator closes that gap by emitting `rev` from the revisions API, chosen
    as the last revision at or before the freeze's index-state, which is what Cabal saw.
  Date: 2026-09-26
- Decision: The generator is a new `cohort generate` subcommand of the existing Haskell updater
  (`cli/haskell-nix-update`), not a shell script.
  Rationale: The updater already has a typed Hackage HTTP client (`HaskellNix.Update.Hackage`),
  the unpacked-hash prefetch (`HaskellNix.Update.Nix.prefetchHackage`), a process runner with test
  doubles, a tasty test suite that runs in `nix flake check`, and it reads
  `packages/first-party-lock.json`. The generator needs all five.
  Date: 2026-09-26
- Decision: Emit a generated entry only when the frozen version differs from nixpkgs' plain
  `haskell.packages.ghc9124` version, or when the package is absent from nixpkgs. Packages at the
  same version get no entry, but the parity check still asserts them.
  Rationale: The MasterPlan asks for the smallest layer, and fewer entries mean fewer IFDs at
  every consumer's evaluation. The parity check catches the case where a later nixpkgs bump moves
  a base version away from the freeze, and rerunning the generator then adds the entry.
  Date: 2026-09-26
- Decision: GHC boot packages (the libraries GHC ships, such as `base`, `containers`, `text`,
  `Cabal`, which the Nix set exposes as `null`) are never generated. The generator records GHC
  9.12.4's shipped versions in `generated/ghc-boot-packages.nix`, read from the pinned compiler's
  `ghc-pkg list --global`. The pure check asserts every frozen boot entry equals that table. A
  build check re-runs `ghc-pkg` to prove the table is still true of the compiler. If the freeze
  ever asks for a non-shipped version of a boot package, the generator fails with a message naming
  the package; it does not reinstall a boot package.
  Rationale: Replacing a boot package in nixpkgs is possible but rebuilds everything and breaks
  GHC-linked libraries. Cabal chose GHC's copy for every boot package in the observed plans.
  Date: 2026-09-26
- Decision: Every generated entry gets `dontCheck`. `doJailbreak` stays an explicit per-package
  policy in `overlays/registry.nix`, never a blanket generator behavior.
  Rationale: Cabal solves test-suite dependencies only for local packages, so a third-party
  package's test dependencies are not in the freeze and its tests would configure against
  arbitrary base versions. Every hand-written pin being retired already had `dontCheck`. Jailbreak
  hides a real bound violation, so it should appear only where an application's `allow-newer`
  (or a Nix-only difference) makes it necessary, and it should be visible in review.
  Date: 2026-09-26
- Decision: Precedence, from first applied to last: build-setting flags (profiling, Haddock),
  then the channel's `extraOverrides` (the Hackage channel's nulling of GitHub-only packages), then
  the generated version layer, then registry entries (common policy, compatibility profiles, and
  last the first-party registry). A generated name that is also a selected first-party package is
  a construction error.
  Rationale: Policy entries such as `doJailbreakOnly` must wrap the generated derivation, so the
  version layer must sit underneath them. First-party snapshots must win for their own names, as
  the MasterPlan's Integration Points require, and the error makes an accidental overlap loud
  rather than order-dependent.
  Date: 2026-09-26
- Decision: The version layer applies to every supported compiler set (`ghc9124` and `ghc9141`),
  as today's hand-written pins do. In a compiler where a generated name is a boot package
  (`hsuper.<name>` is `null`), the entry leaves it `null`. Parity is asserted only for `ghc9124`,
  the compiler the freeze was solved with.
  Rationale: Scoping the layer to 9.12 only would silently drop GHC 9.14 back to hasql 1.9-era
  versions, regressing what the pins provide today and what IR-2 asks for ("every supported
  GHC"). If the GHC 9.14 cells of the curated matrix fail to build because of a generated version,
  the fallback is to guard the layer on `hsuper.ghc.version`, inside the attribute value, and
  record that here.
  Date: 2026-09-26
- Decision: For first-party packages the parity check asserts the freeze on both channels, for
  every package with a Hackage pin. GitHub-only first-party packages (Hackage pin `null`) cannot
  appear in a Cabal freeze and are ignored.
  Rationale: Consumers use `lib.haskellExtension`, which is the GitHub channel. Today both
  channels agree for every published package, so the assertion costs nothing, and it catches a
  future refresh that moves GitHub HEAD past the frozen release.
  Date: 2026-09-26
- Decision: A hand-written pin whose package is not in the freeze is not deleted. It is reported
  to plan 8, which adds it to the cohort as an explicit member (the channel still promises it to
  non-family consumers such as `mori://shinzui/hurl-workbench`), and it is retired when the
  regenerated freeze contains it.
  Rationale: Deleting it would silently downgrade a consumer outside the five applications.
  Adding it to the freeze keeps one source of truth.
  Date: 2026-09-26
- Decision: Cabal flag lines in the freeze (`any.blake3 -avx2 …`) are parsed and ignored by the
  generator. Flags stay registry policy (`patches/blake3/portable.nix`,
  `patches/dhall/keep-http-client-tls.nix`).
  Rationale: `cabal freeze` lists every flag of every package, defaults included. Mapping them
  onto Nix needs each package's default flags, and the only flags that matter today are already
  expressed as reviewed policy.
  Date: 2026-09-26
- Decision: Parity is two checks.
  - `cohort-generated-fresh` is pure evaluation with no IFD, and takes seconds. It checks that the
    generated file was produced from the committed freeze (a SHA-256 of the freeze is recorded in
    it), that its versions equal the freeze, that boot and base-equal entries match, and that
    every freeze entry is classified.
  - `cohort-versions` evaluates `.version` of every frozen package in the composed channel, which
    forces IFD, and fails listing each mismatch.
  Rationale: The first gives a fast signal and runs anywhere, including other systems without a
  builder. The second is the real guarantee the MasterPlan asks for.
  Date: 2026-09-26
- Decision: Add a `registry-policy-only` lint check that fails when `overlays/` or `patches/` fetch
  a Hackage release (`callHackageDirect`, `callHackage`, or a `hackage.haskell.org/package` URL).
  Source pins of non-Hackage packages (`codd`, `hasql-migration`, and plan 10's `typeid-hs`)
  remain allowed.
  Rationale: This is how the MasterPlan's "registry keeps only build policy" rule stays true after
  plan 10 and future maintainers add entries.
  Date: 2026-09-26
- Decision: The shared comparison tool is `scripts/cohort-compare.sh` (bash and jq), exposed as
  the flake app `cohort-compare` through `writeShellApplication`. It has two modes, `--plan-json`
  and `--closure` (plus a testable `--closure-list`).
  Rationale: Plans 11 to 14 run it from other repositories with
  `nix run github:shinzui/haskell-nix/<rev>#cohort-compare`. A small script with no compiled
  dependency runs instantly there. The derivation-path comparison plan 14 needs can be added to
  the same script as a third mode.
  Date: 2026-09-26
- Decision: Do not pre-generate cabal2nix expressions into the repository (the way nixpkgs'
  `hackage-packages.nix` does) to avoid IFD.
  Rationale: cabal2nix output is platform-specific (`--system`), the first-party registry already
  relies on IFD, and ADR 1 accepts IFD. Revisit if consumer evaluation time becomes a complaint.
  Date: 2026-09-26


## Outcomes & Retrospective

Independent preparation is underway. The Cabal-format guard passes on native Darwin and is committed/pushed at `3b2a593`. The exported Nix freeze parser shares packaged input files with the Haskell parser tests and adds live freeze/source membership equality. Generation modules are being tested; live source prefetch, command dispatch, generated artifacts, layer activation, manifests, comparison/lock tooling and cache publication are not yet delivered.

The important early correction is to distinguish cabal2nix parsing from the boot Cabal setup driver. Building the 3.16 fixture caused an avoidable aggregate failure even though both channel parsers accepted it. The corrected check builds 3.14 and forces all four parsing paths. Aggregate validation now uses an immutable committed snapshot while additive work proceeds independently, preserving the required gates without serializing all preparation.


## Context and Orientation

This repository (`mori://shinzui/haskell-nix`, checked out at
`/Users/shinzui/Keikaku/bokuno/haskell-nix`) is a Nix flake that gives several Haskell
applications one shared set of Haskell packages. Some terms used throughout:

- **nixpkgs Haskell package set.** `pkgs.haskell.packages.ghc9124` is a large attribute set with
  one derivation per Hackage package, built with GHC 9.12.4. It is a fixed point: each package's
  dependencies are looked up in the final set.
- **Haskell extension.** A function `hself: hsuper: { … }` that replaces packages in that fixed
  point. `hsuper.<name>` is the package before this extension; `hself.<name>` is the final one.
  Consumers apply one with `pkgs.haskell.packages.ghc9124.override { overrides = … }`.
- **Boot package.** A library GHC itself ships (for example `base`, `containers`, `text`,
  `Cabal`). In the nixpkgs set these attributes are `null`, meaning "use GHC's copy".
- **IFD (import-from-derivation).** Nix builds a small derivation during evaluation and reads its
  output as Nix code. `callCabal2nix`, `callHackage` and `callHackageDirect` all do this: they run
  the `cabal2nix` tool on a package's `.cabal` file to produce the package's Nix expression.
- **Unpacked hash.** `callHackageDirect { pkg; ver; sha256; }` fetches
  `https://hackage.haskell.org/package/<pkg>-<ver>/<pkg>-<ver>.tar.gz` with `fetchzip`, so
  `sha256` is the hash of the unpacked tree. It comes from
  `nix store prefetch-file --unpack --json <url>` or `nix-prefetch-url --unpack <url>`, not from the
  tarball's own hash. For shibuya-pgmq-adapter 0.16.1.0 the correct value is
  `sha256-8yXtZ/qufiD4QdO1BtrxTIJWYfT8WbxkIMDA9a2svfI=`.
- **Hackage revision.** Hackage lets maintainers edit a released package's `.cabal` file, usually
  to relax bounds. Cabal uses the latest revision at its `index-state`. A revision is numbered
  (0 is the original upload).
- **Cohort freeze.** `cabal/cohort.freeze`, produced by plan 8. It is a Cabal project fragment in
  the format `cabal freeze` writes: a `constraints:` field with one `any.<package> ==<version>`
  line per package (comma-separated), lines of the form `any.<package> +flag -flag` for flags, and
  an `index-state:` line (`index-state: hackage.haskell.org 2026-09-26T18:09:31Z`). Only plan 8
  edits it. If plan 8 records the index-state somewhere other than the freeze, read it from there
  and update this paragraph.

Files that matter, with what each does today:

- `flake.nix` builds everything. Lines ~40-69 read `overlays/registry.nix` as `commonRegistry`,
  read `config/first-party-families.json` and `packages/first-party-lock.json`, build the
  `mkFirstPartyPackageSet` factory, and create the `github` and `hackage` channel package sets from
  `defaultPackageSet`. `lib.haskellExtension` (= `lib.haskellExtensions.github`) is what consumers
  compose. `mkUpdaterHaskellPackages` (lines ~124-143) builds the updater CLI on plain nixpkgs with
  its own inline optparse-applicative 0.19 pin. That pin is the tool's own build, not part of the
  channel, and this plan leaves it alone. `perSystem` builds `pkgsPlain`, `pkgsGithub` and
  `pkgsHackage` and imports `checks/default.nix`.
- `lib/mkFirstPartyPackageSet.nix` selects first-party family snapshots, builds
  `registry = commonRegistry // profileRegistry // firstPartyRegistry` (line ~207), and returns
  `{ selections, selectedFamilies, registry, haskellExtension, overlay }`.
- `lib/mkHaskellExtension.nix` turns a registry into one composed extension:
  `[disableProfiling] ++ [disableHaddock] ++ [extraOverrides] ++ perPackageOverrides`.
  `lib/mkHaskellOverlay.nix` does the same for a nixpkgs overlay over every compiler in
  `compilers`.
- `lib/fixPackageByVersion.nix` implements a registry entry. An entry is a list of either
  `{ always = true; patch; }` or `{ min; max; patch; }` (applied when `min <= version < max`), and
  a patch receives `{ pkg, lib, haskellLib, pkgs, hself, hsuper }`. It carefully keeps the version
  test inside the attribute value, because making attribute existence depend on `hsuper.<pkg>`
  causes infinite recursion. The new version layer must follow the same rule.
- `overlays/registry.nix` is the patch registry. It has helper policies (`dontCheckDoJailbreak`,
  `markUnbrokenDontCheckDoJailbreak`, `dontCheckOnly`, `markUnbrokenDontCheck`, `doJailbreakOnly`)
  and entries of three kinds:
  1. **Pure policy:** tool jailbreaks, `sbv`, `fuzzyfind`, `ephemeral-pg`, `cradle`,
     `wai-app-static`, `http-conduit`, `repline`, `tls-session-manager`, `ram`, `mlkem`,
     `unicode-data`, `haxl`, `thread-utils-*`.
  2. **Source pins of non-Hackage code:** `codd` (GitHub `c32d365`) and `hasql-migration`
     (shinzui fork `4aaff6c`).
  3. **Hand-written Hackage version pins,** each in a `patches/<pkg>/<ver>.nix` file:
     - `optparse-applicative` 0.19.0.0, `streamly-core` 0.3.0 and `streamly` 0.11.0 (these three
       via `callCabal2nix` + `fetchTarball`);
     - `validation` 1.2.2;
     - the hasql family: `hasql` 1.10.2.4, `postgresql-binary` 0.15.0.1, `hasql-pool` 1.4.1,
       `hasql-transaction` 1.2.2, `hasql-implicits` 0.2.0.2, `hasql-dynamic-statements` 0.5.1,
       `hasql-notifications` 0.2.5.0;
     - the `hs-opentelemetry` 1.40 family (14 packages, all in `patches/hs-opentelemetry/1.40.nix`);
     - `claude` 1.5.0 and `openai` 2.5.4;
     - `shibuya-pgmq-adapter` 0.16.0.0;
     - the crypton family: `crypton` 1.1.2, `crypto-token` 0.2.0, `hpke` 0.1.0, `crypton-x509`,
       `-store`, `-system` and `-validation` 1.9.0 (all `dontCheck` only);
     - `tls` 2.3.1, `crypton-connection` 0.4.6 and `http-client-tls` 0.4.0.

  `blake3` and `dhall` are flag and bound policy. Every entry is `always`; there are no
  version-scoped (`min`/`max`) entries today.
- `patches/hasql/1.9.nix` exists but nothing references it.
- `checks/default.nix` defines the flake checks. `first-party-versions` (lines ~132-176) already
  asserts, for first-party packages only, that each channel's `.version` equals the lock. Also
  there: `registry-valid`, `overlay-eval`, `build-setting-flags`, the cache-identity checks and
  the curated `package-set-<name>` matrices (`checks/package-set-matrix.nix`), which build every
  first-party package plus a fixture consumer for both channels and both GHCs. Every check is a
  derivation, with diagnostic JSON in `passthru.results` (a rule from ADR 1). Pure named tests
  live in `checks/unit.nix`; the `nix-unit` check in `nix/tooling.nix` runs them with only `lib`
  available (`just nix-test`).
- `cli/haskell-nix-update/` is the maintainer CLI (`nix run .#haskell-nix-update --`). Modules
  under `src/HaskellNix/Update/`: `Cli.hs` (optparse-applicative subcommands `refresh`, `check`,
  `migrate-lock`, `package-set`), `Hackage.hs` (`queryHackage`, `packageArchiveUrl`, an
  `HttpClient` record), `Nix.hs` (`prefetchHackage :: ProcessRunner -> PackageName -> Version -> IO (Either UpdateError SriHash)`),
  `Process.hs` (a `ProcessRunner` abstraction that tests replace), `Types.hs` (`PackageName`,
  `SriHash`, `UpdateError`, …) and `PackageLock.hs`. Tests are in `test/` (tasty). The flake's
  `haskell-nix-update` check builds the CLI and runs them.
- `scripts/` holds only `family-status.awk` today.
- `justfile` has recipes `validate`, `flake-check`, `nix-test`, `fmt`, `check-docs`, `drv-diff`.

The nixpkgs pin is `haskell-nix-dev` `206ecd25` → nixpkgs `d5dfd8e6`. Supported compilers are
`ghc9124` (default) and `ghc9141`. Supported systems are `x86_64-linux` and `aarch64-darwin`.
`haskell.packages.ghc9124.*` is not on cache.nixos.org, so every consumer builds the Haskell
closure from source.

Relevant ADRs:

- [`docs/adr/1-compose-first-party-snapshots-in-one-haskell-scope.md`](../adr/1-compose-first-party-snapshots-in-one-haskell-scope.md)
  (the original local composition ADR; ADR 5 now adds update isolation). The rules this plan must keep:
  - one nixpkgs fixed point with one version per package name;
  - immutable first-party snapshots;
  - no dependency solver in this repository;
  - cache reuse only when transitive inputs are equal;
  - every flake check is a derivation, with diagnostics in `passthru.results`.

  It also records that `callHackageDirect` hashes are unpacked-tree hashes and that IFD-based
  checks need a builder for the evaluated system. `docs/adr` is a plain filesystem ADR directory,
  not an OKF bundle (`mori.dhall` declares OKF bundles only for `docs/improvement-requests`,
  `docs/user` and `docs/guides`), so the new ADR follows ADR 1's shape: an H1 title, `Status:`,
  `Date:`, and sections Context, Decision, Alternatives and consequences, Validation. No
  frontmatter.
- `mori://shinzui/rei/okf/adrs/concepts/ADR-18` ("An index-state bump is half a cohort
  adoption"): Cabal and Nix select versions by different mechanisms. This plan turns the Nix half
  into generated data plus a check.
- The MasterPlan
  [`docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md`](../masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md)
  defines the freeze file, the precedence rule (first-party snapshots win and must equal the
  freeze; the generated layer supplies every other version; the registry and patches keep only
  build policy) and the shared script this plan owns.

Neighbouring plans:

- Plan 8 must have committed `cabal/cohort.freeze` before Milestone 2 can run against real data.
  Milestones 1 and 2's parser and generator code can be written against the fixtures in this plan
  first.
- Plan 10 (`docs/plans/10-own-the-shared-third-party-overrides-in-the-channel-instead-of-consumer-overlays.md`)
  also edits `overlays/registry.nix`. Whichever lands second rebases. If plan 10 landed first with
  version pins (for example generic-lens 2.3, wai-app-static 3.2.1, link-canonical 0.1.0.0), this
  plan converts them like every other pin.


## Plan of Work

The work is six milestones. Milestones 1 to 3 are additive and change no package derivation.
Milestone 4 is the one that changes versions. Milestone 5 is independent tooling. Milestone 6
proves the result with real builds and records durable decisions.


### Milestone 1 (prototype): settle the cabal-version question and guard it

Scope: find out whether the channel needs a GHC 9.12-built `cabal2nix`, and leave behind a check
that fails if `cabal-version: 3.14` or `3.16` ever stops evaluating. At the end, the
`cabal-version-support` flake check exists and passes, and the Decision Log's first entry is
either confirmed or replaced by the fallback.

Create two fixture packages, `checks/fixtures/cabal-version/3.14/` and `.../3.16/`. Each holds a
`tiny.cabal` with the corresponding `cabal-version:` field, `name: tiny`,
`version: 0.1.0.0`, `build-type: Simple` and a library exposing module `Tiny` with
`build-depends: base`, plus `Tiny.hs` containing `module Tiny where`. Add a check
`cabal-version-support` in `checks/default.nix`. It evaluates, for both
`pkgsGithub.haskell.packages.${defaultGhc}` and `pkgsHackage…`,
`(scope.callCabal2nix "tiny" <fixture> { }).drvPath` for both fixtures, and builds one of them
(forcing the derivation proves the IFD succeeded; building `tiny` is seconds). Put the evaluated
paths in `passthru.results`. Also run the prototype commands in Concrete Steps and paste their
output into Surprises & Discoveries. They confirm or refute that 3.14 and 3.16 parse and that 3.18
does not, on this machine.

Promotion or discard criteria for the prototype:

- If 3.14 and 3.16 evaluate, keep the check, add no overlay, and record the result.
- If they fail (for example after a future nixpkgs bump), apply the fallback in this order:
  1. In `lib/mkHaskellExtension.nix`, add an extension that overrides `haskellSrc2nix` with a
     copy of nixpkgs' implementation (a `pkgs.buildPackages.runCommand "cabal2nix-${name}"` whose
     `nativeBuildInputs` is
     `[ (pkgs.buildPackages.haskell.lib.compose.justStaticExecutables pkgs.buildPackages.haskell.packages.ghc9124.cabal2nix-unstable) ]`
     and whose script is
     `cabal2nix --compiler=${hself.ghc.haskellCompilerName} --system=${pkgs.stdenv.hostPlatform.config} --sha256=<sha256 or empty> "${src}" ${extraCabal2nixOptions} > "$out/default.nix"`,
     with `export HOME="$TMP"; mkdir -p "$out"` first, exactly as the nixpkgs derivation shown in
     Surprises does). Warn in the Decision Log that it compiles about 75 derivations per system.
  2. If `ghc9124.cabal2nix-unstable` does not build, apply `doJailbreak` to
     `distribution-nixpkgs-unstable`, `language-nix-unstable` and `hackage-db-unstable` inside
     that tool's own package set, or pin distribution-nixpkgs to its newest Hackage release.
  3. If neither builds, keep the stock tool and document in the ADR that the channel's
     cabal-version ceiling is whatever the pinned nixpkgs' IFD cabal2nix parses.

The standalone `pkgs.cabal2nix` binary (Cabal 3.12) is used nowhere in this repository and is out
of scope.


### Milestone 2: parse the freeze and generate the version layer

Scope: everything needed to turn `cabal/cohort.freeze` into committed Nix data, without changing
any package yet. At the end, `generated/cohort-versions.nix` and
`generated/ghc-boot-packages.nix` exist and are fresh, and nix-unit and Haskell tests cover the
parser and the classification.

**Freeze parser.** Add `lib/parseCohortFreeze.nix`: `{ lib }: text: { constraints; flags; indexState; }`.
- Split the text on newlines, drop `--` comments, then split on commas, trim, and strip a leading
  `constraints:`.
- Match each item against `any\.([A-Za-z0-9][A-Za-z0-9-]*)[[:space:]]*==[[:space:]]*([0-9]+(\.[0-9]+)*)`
  (a version constraint) or `any\.([A-Za-z0-9][A-Za-z0-9-]*)([[:space:]]+[+-][A-Za-z0-9_-]+)+`
  (a flag line).
- Read `index-state:` with an optional `hackage.haskell.org` repository name.
- Throw on a duplicate package, a non-`==` constraint, or an unrecognised non-empty item, naming
  the offending line.

Export it from `flake.nix` as `lib.parseCohortFreeze`, and export
`lib.cohort = { freeze = parseCohortFreeze (builtins.readFile ./cabal/cohort.freeze); versions = import ./generated/cohort-versions.nix; boot = import ./generated/ghc-boot-packages.nix; versionTable = <freeze constraints>; }`
(`versionTable` is the name → version map, which is what Purpose's first command reads).

**Policy file.** Add `config/cohort-policy.json` with `schemaVersion: 1` and two keys:
- `excluded`: a map from package name to a one-sentence reason. These are frozen packages the
  channel does not provide, because each belongs to an application: for example `rei-core`,
  `mori-types`, `mori-app`, `mori-schema-pin`, or any other application-local library that plan 8's
  freeze includes. The reason names the providing flake with a `mori://` URI.
- `sourcePinned`: a list of names the registry provides from a non-Hackage source (today `codd` and
  `hasql-migration`; plan 10 adds `typeid-hs`, `typeid-hs-sql` and `typeid-hs-pg-migrate`).

Both kinds are skipped by the generator. `sourcePinned` names are still parity-checked;
`excluded` names are not.

**Generator.** Add `cli/haskell-nix-update/src/HaskellNix/Update/Cohort.hs` (listed in
`exposed-modules`) and a `cohort` subcommand group in `Cli.hs` with
`generate [--freeze PATH] [--policy PATH] [--output PATH] [--boot-output PATH] [--check]`.
Defaults are `cabal/cohort.freeze`, `config/cohort-policy.json`,
`generated/cohort-versions.nix` and `generated/ghc-boot-packages.nix`. The generator:

1. Parses the freeze with the same grammar as the Nix parser (keep one set of fixtures under
   `checks/fixtures/cohort/` and test both parsers against it).
2. Reads the default package set's first-party packages from `packages/first-party-lock.json`
   through the existing `PackageLock` module.
3. Gets GHC's shipped libraries. It realises the pinned compiler with
   `nix build --no-link --print-out-paths --impure --expr '(import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }).haskell.compiler.ghc9124'`
   and runs `<out>/bin/ghc-pkg list --global --simple-output`. GHC is substituted from
   cache.nixos.org.
4. Gets nixpkgs' base versions for every frozen name in one call:
   `nix eval --json --impure --expr` over the flake's nixpkgs input, plain
   `haskell.packages.ghc9124`, mapping each name to its version, `"null"` (boot) or `"absent"`.
   This needs no IFD and takes about two seconds for 400 names.
5. Classifies each freeze entry, in this order:
   - `boot` (in the `ghc-pkg` list). If the frozen version differs from GHC's, fail.
   - `firstParty` (in the lock). The generator writes nothing for it; the parity check asserts it.
   - `excluded` or `sourcePinned` (from the policy file).
   - `sameAsBase` only when version, source identity and selected Cabal metadata match the base.
     If only metadata differs, emit the metadata override instead of skipping the package.
   - `generated`.
6. For each entry, independently reuses the source tarball hash when its package/version is
   unchanged. Resolve Cabal metadata at the selected index-state even when the version is
   unchanged; cache that lookup by package/version/index-state. For a new source call
   `prefetchHackage`, then fetch
   `https://hackage.haskell.org/package/<p>-<v>/revisions/` with `Accept: application/json` and
   picks the highest revision whose `time` is at or before the index-state. A revision above 0 is
   recorded with its number (as a string) and its hex sha256.
7. Writes both files deterministically: sorted by name, two-space indented, and already in
   `nixpkgs-fmt` style so `nix fmt` leaves them unchanged. Each file starts with a header comment
   saying it is generated and naming the command.

With `--check`, the generator writes nothing and exits 1 if either file would change. Add
`just cohort-generate` and `just cohort-generated-check` recipes; plan 8's aggregate
`cohort-check` invokes the latter.

The generated file's shape:

```nix
# GENERATED by `nix run .#haskell-nix-update -- cohort generate` from cabal/cohort.freeze.
# Do not edit. Versions come from the freeze; build policy lives in overlays/registry.nix.
{
  schemaVersion = 1;
  freezeSha256 = "3f1c…";          # builtins.hashFile "sha256" ../cabal/cohort.freeze
  indexState = "2026-09-26T18:09:31Z";
  ghc = "9.12.4";
  nixpkgsBase = "d5dfd8e6…";       # nixpkgs revision whose ghc9124 set was the diff base
  packages = {
    hasql = { version = "1.10.3.7"; sha256 = "sha256-…"; revision = null; };
    http-conduit = {
      version = "2.3.9.1";
      sha256 = "sha256-vO7c0uCT/4lly27O4rx9OcUymKWNaP8QcmDS7rQdpfQ=";
      revision = { number = "1"; sha256 = "6c521a2da3172343a5f6917bec1790f7cd3f0eb253a15e85a144b7f73b08dc69"; };
    };
  };
  # Classification of every other freeze entry, so the pure check needs no nixpkgs diff.
  sameAsBase = [ "array-builder" "…" ];
}
```

(`http-conduit` appears here only to show the revision shape. It gets an entry only if its frozen
version differs from nixpkgs.) `generated/ghc-boot-packages.nix` is
`{ ghc = "9.12.4"; packages = { base = "4.21.2.0"; Cabal = "3.14.2.0"; … }; }`.

Tests:
- In `checks/unit.nix`, add nix-unit tests for `parseCohortFreeze`:
  - a valid fixture with flags, comments, `index-state` and a trailing comma;
  - rejection of a duplicate package, a `>=` constraint and a garbage line.
- In `cli/haskell-nix-update/test/CohortTest.hs` (add it to `other-modules`), add tasty tests:
  - the parser;
  - classification with a fake `ProcessRunner` returning canned `ghc-pkg`, `nix eval` and
    prefetch output (the pattern `WorkflowTest.hs` already uses);
  - revision selection at an index-state;
  - hash reuse for unchanged versions;
  - failure on a non-shipped boot version;
  - byte-for-byte rendering.


### Milestone 3: add the parity checks and watch them fail

Scope: make the gap visible as a failing, precise check before anything is fixed. At the end,
`checks/cohort-parity.nix` defines three checks wired into `checks/default.nix`:
`cohort-generated-fresh` and `ghc-boot-packages` pass, and `cohort-versions` fails listing today's
mismatches, whose output is pasted into Surprises. Milestone 4 turns it green.

- **`cohort-generated-fresh`** (pure; no IFD). It asserts:
  - `builtins.hashFile "sha256" ../cabal/cohort.freeze == versions.freezeSha256`;
  - every `versions.packages.<p>.version` equals the freeze;
  - every freeze entry is in exactly one class (boot, first-party, excluded, sourcePinned,
    `sameAsBase`, `packages`);
  - every boot entry equals `boot.packages.<p>`, and `pkgsPlain.haskell.packages.ghc9124.<p>` is
    `null` or absent;
  - every `sameAsBase` name has `pkgsPlain.haskell.packages.ghc9124.<p>.version` equal to the
    freeze. Plain nixpkgs versions need no IFD.

  On failure it throws a message listing each offending package, the expected value and the found
  value. Otherwise it is a `runCommand` whose `passthru.results` carries the counts per class.
- **`cohort-versions`** (IFD). For every freeze entry that is not boot and not excluded, and for
  `pkgsGithub` and `pkgsHackage` under `ghc9124`, it compares `scope.<p>.version` with the freeze.
  A first-party package whose Hackage pin is `null` is skipped on both channels.
  `passthru.results` holds `{ github-ghc9124 = [mismatches]; hackage-ghc9124 = [...]; }`, and the
  check throws when either is non-empty, listing `name: nix=<found> freeze=<expected>` one per line.
- **`ghc-boot-packages`** (build). A `runCommand` with the pinned `ghc` in `nativeBuildInputs`
  runs `ghc-pkg list --global --simple-output`, turns it into `name version` lines, and `diff`s
  them against a text rendering of `generated/ghc-boot-packages.nix`. A difference means nixpkgs
  moved GHC and the generator must be rerun.

These checks read `cabal/cohort.freeze`, so they exist only once plan 8 has landed. Until then,
guard the attribute with `builtins.pathExists ../cabal/cohort.freeze` so `nix flake check` keeps
working on this branch.


### Milestone 4: wire the generated layer and retire the hand-written pins

Scope: the change that moves versions. At the end, the composed channel's versions equal the
freeze, `cohort-versions` passes, and no file under `overlays/` or `patches/` fetches a Hackage
release.

Add `lib/mkCohortVersionLayer.nix`:

```nix
# mkCohortVersionLayer :: { lib } -> CohortVersions -> HaskellLib -> Pkgs -> HaskellExtension
# Replaces every package named in generated/cohort-versions.nix with its frozen Hackage release.
# Attribute NAMES come only from the generated file, never from hsuper, so the attrset structure
# cannot force the fixed point (see fixPackageByVersion.nix).
{ lib }:
cohort: haskellLib: _pkgs:
hself: hsuper:
lib.mapAttrs
  (name: entry:
    # A GHC boot package in this compiler (null in nixpkgs) is GHC's own copy; never replace it.
    if builtins.hasAttr name hsuper && hsuper.${name} == null then null
    else haskellLib.dontCheck (hself.callHackageDirect
      ({ pkg = name; ver = entry.version; sha256 = entry.sha256; }
        // lib.optionalAttrs (entry.revision != null) {
        rev = { revision = entry.revision.number; sha256 = entry.revision.sha256; };
      })
      { }))
  cohort.packages
```

Composition changes:

- `lib/mkHaskellExtension.nix` gains an argument `versionLayer ? (_: _: _: _: { })` and composes
  `[profiling] ++ [haddock] ++ [extraOverrides] ++ [ (versionLayer haskellLib pkgs) ] ++ perPackageOverrides`.
- `lib/mkHaskellOverlay.nix` passes `versionLayer` through.
- `lib/mkFirstPartyPackageSet.nix`'s factory gains `cohortVersions ? { packages = { }; }`. It
  builds `versionLayer = mkCohortVersionLayer cohortVersions`, passes it to both constructors, and
  adds a validation branch: if
  `lib.intersectLists (builtins.attrNames cohortVersions.packages) selectedPackageNames != [ ]`,
  throw
  `"mkFirstPartyPackageSet: the generated cohort layer names first-party packages: …"`.
- `flake.nix` imports `./generated/cohort-versions.nix` (guarded by `pathExists` as above) and
  passes it to the factory.

The unit-test factory in `checks/unit.nix` keeps the empty default. Add nix-unit tests for:
- the layer leaves a `null` (boot) attribute `null`;
- the layer adds an absent package;
- the layer passes `rev` only when a revision exists (stub `hself.callHackageDirect` to return its
  arguments, and `haskellLib.dontCheck` to the identity, the way the existing okf test stubs
  `callCabal2nix`);
- the factory rejects an overlap with a first-party name.

Retire the pins, in `overlays/registry.nix` and `patches/`. For each pin, first confirm its
package is in the freeze. If it is not, leave the entry, list it under Surprises, and hand it to
plan 8, as the Decision Log says. Then:

- **Jailbreak + dontCheck pins** (their patches used `dontCheck (doJailbreak (callHackageDirect …))`
  or `callCabal2nix` + `fetchTarball`): replace the entry with `always doJailbreakOnly`, because
  the generated layer already applies `dontCheck`. This covers `optparse-applicative`,
  `streamly-core`, `streamly`, `validation`, `hasql`, `postgresql-binary`, `hasql-pool`,
  `hasql-transaction`, `hasql-implicits`, `hasql-dynamic-statements`, `hasql-notifications`, the
  14 `hs-opentelemetry-*` entries, `claude`, `openai`, `tls`, `crypton-connection` and
  `http-client-tls`. Delete the corresponding `patches/<pkg>/<ver>.nix` files and the
  `patches/hs-opentelemetry/1.40.nix` family file.
- **dontCheck-only pins** (`crypton`, `crypto-token`, `hpke`, `crypton-x509`,
  `crypton-x509-store`, `crypton-x509-system`, `crypton-x509-validation`): delete the entries and
  their patch files. The generated layer supplies both version and `dontCheck`.
- **`shibuya-pgmq-adapter`**: delete the entry and `patches/shibuya-pgmq-adapter/0.16.nix`. The
  freeze supplies 0.16.1.0, which declares `shibuya-core ^>=0.10` natively, so it should need no
  jailbreak. Milestone 6 proves that by building it. Only if it fails, add
  `always doJailbreakOnly` and record why.
- **Delete `patches/hasql/1.9.nix`** (unreferenced).
- **Rewrite registry comments that justify a policy with a version** ("nixpkgs ships
  wai-app-static 3.1.9.1", "crypton 1.1 / tls 2.3 / x509 1.9 cascade", "0.0.9 caps crypto-token
  < 0.2") so they state the policy's reason without claiming which version is selected. Add a
  header comment to `overlays/registry.nix`: versions come from `generated/cohort-versions.nix`;
  entries here are build policy only (jailbreak, dontCheck, flags, markUnbroken, and source pins
  of non-Hackage packages).
- **Version-scoped entries.** None exist today, but note in that header that `{ min; max; }`
  entries now match against the frozen version, so a policy that should expire when the freeze
  moves past a release can be written that way.
- **Keep untouched:** the policy entries (tool jailbreaks, `sbv`, `fuzzyfind`, `cradle`,
  `ephemeral-pg`, `wai-app-static`, `http-conduit`, `repline`, `tls-session-manager`, `ram`,
  `mlkem`, `unicode-data`, `haxl`, `thread-utils-*`), `blake3`, `dhall`, `codd` and
  `hasql-migration`.

Add the `registry-policy-only` check to `checks/default.nix`: a `runCommand` over
`${../overlays}` and `${../patches}` that runs
`grep -rnE 'callHackageDirect|callHackage |hackage\.haskell\.org/package' …` and fails, printing
the matches, if any line is found.

Update `docs/user/adding-patches.md`, which uses `patches/hasql/1.10.nix` and
`patches/optparse-applicative/0.19.nix` as examples. The rewrite says: never pin a Hackage version
in the registry; a version change goes through plan 8's freeze and `just cohort-generate`; a patch
file holds policy. Add a short section to `docs/user/package-sets.md` explaining the generated
layer and its precedence. Both are in the `docs/user` OKF bundle: advance each document's
`generated.at`, add an `okf log add docs/user --kind Update -m "…"` entry, and run
`just check-docs`.

**Rebuild and cache cost (read before running Milestone 4 builds).** Moving hasql, tls, crypton,
aeson, http2, warp and QuickCheck changes the derivation of nearly every package above them. On
first build, every machine rebuilds almost the whole Haskell closure of every consumer: rei-cli's
closure is about 400 Haskell packages. `haskell.packages.ghc9124.*` is not on cache.nixos.org, so
nothing is substituted. Do not move any consumer's `flake.lock` to this revision as part of this
plan; plans 11 to 14 do that one application at a time. Build on the deploy platform
(aarch64-darwin) first, so the store already holds the closure when those plans run.


### Milestone 5: shared comparison, manifest construction and lock resolution

Scope: implement the interface in Review requirements for plans 11–14. Add
`scripts/cohort-compare.sh`, expose `packages.cohort-compare` and `apps.cohort-compare`,
and implement the manifest construction helper alongside the package-set composition.
The script may use jq and Nix metadata commands; it must never traverse store files.

Acceptance modes:

```text
cohort-compare --freeze FILE_OR_HTTPS_URL (--plan-json FILE | --nix-manifest FILE) [--all]
cohort-compare --compare-manifests FILE FILE
cohort-compare --resolve-channel-lock FILE --input-path PATH
```

Compare every non-local Cabal package and every expected Haskell dependency in the actual
Nix root's graph. Classify declared local and source-pinned packages explicitly. Verify
source-pinned identities against `cabal/cohort-sources.json`; intentional source/flag
exceptions need a reason and owner. A package found at a wrong version fails even if another
instance has the expected version. Native homonyms are separate roles. A missing expected
Haskell package or unverifiable root fails, including when static linking hides it from the
runtime output closure. An empty graph must not pass a nonempty expected dependency set.
Identity comparison reports changed drv/output paths together with changed inputs and users.
Do not turn channel revision metadata alone into library derivation inputs.

The lock mode starts at the declared root and resolves string nodes and array follows paths
recursively. Add nested application/library follows, nonstandard root names, missing inputs
and cycles to fixtures. Consumer apps alias the pinned channel's comparator for initial
lock resolution, so the resolver does not depend on guessing a lock node name.

Add fixture checks under `checks/fixtures/cohort/` for the positive and negative cases in
Review requirements, exact exit statuses and diagnostic records. Existing `--closure` and
`--closure-list` interfaces may remain for diagnostics, explicitly labeled insufficient for
acceptance. Add `just cohort-compare *args`; no child creates another comparison script.


### Milestone 6: prove it with builds, and record what is durable

Scope: build what the five applications use, show the before and after versions, and distill the
decisions. At the end, the full flake check and the cohort build pass on aarch64-darwin, the
evidence is in this plan, ADR 3 exists, and IR-2 is completed.

**The cohort build.** Add `packages.cohort-closure` in `flake.nix`'s `perSystem`: a
`pkgsGithub.linkFarm "cohort-closure"` over `pkgsGithub.haskell.packages.ghc9124.<p>` for every
freeze entry that is not boot and not excluded. That set is exactly "every Haskell package the five
applications use", because the freeze is their union. Building it proves the whole cohort compiles
together.

If the full build does not fit the session, add `packages.cohort-roots`, a `linkFarm` of these
packages, which between them pull every large cohort:
- `keiro`, `kiroku-store`, `kioku-core`, `shibuya-pgmq-adapter`, `pg-migrate-cli`
  (hasql, crypton and tls);
- `baikai-kit`, `claude`, `openai` (http-client-tls);
- `relay-pagination-servant`, `servant-openapi-hs`, `warp`, `wai-app-static`
  (the WAI/Warp cohort of IR-2);
- `brick` (vty), `sbv`, `dhall`, `hs-opentelemetry-exporter-otlp`, `streamly`, `generic-lens`.

Build `cohort-roots` first, then `cohort-closure`. The plan is not complete until
`cohort-closure` has built on aarch64-darwin. For x86_64-linux, build the curated
`package-set-default` check through the configured remote builder. If no builder is available,
record that as an open item in Outcomes rather than claiming support.

Also run the full `nix flake check`, which includes the curated matrices for both compilers and
the cache-identity checks. If a `ghc9141` cell fails because of a generated version, apply the
Decision Log's fallback (guard the layer on `hsuper.ghc.version` inside the attribute value),
record it, and rerun.

**The versions table.** Evaluate the before table at `4cabd10` (the values are already in
Surprises) and the after table at the new commit with the same expression (Concrete Steps). Paste
both into Outcomes. Also run `cohort-compare --closure` on a freshly built
`pkgsGithub.haskell.packages.ghc9124.shibuya-pgmq-adapter` closure, to show a Nix closure that is
entirely `ok`.

**ADR.** Write `docs/adr/3-generate-the-channels-package-versions-from-the-cohort-freeze.md` in
ADR 1's format (Status: Accepted, Date).
- Context: two solvers disagreed; the numbers from Purpose.
- Decision:
  - the freeze is the single source of versions;
  - the generator emits `callHackageDirect` entries for base-differing packages;
  - boot packages are asserted, not generated;
  - the precedence order;
  - the registry holds only policy, enforced by `registry-policy-only`;
  - parity is a pure check and an IFD check;
  - the cabal-version finding and its guard.
- Alternatives and consequences: `all-cabal-hashes` with `callHackage`, pre-generated
  expressions, haskell.nix, a nixpkgs bump, the GHC 9.12 cabal2nix overlay, generating Cabal from
  Nix. Also the rebuild cost of any cohort move.
- Validation: the checks and builds from this milestone.

**IR-2.** In `docs/improvement-requests/provide-a-coherent-modern-cli-and-wai-dependency-cohort.md`:
- set `status: completed`;
- add `completedAt: "<UTC now>"` and `timestamp: <UTC now>`;
- add a `resolution: >-` paragraph. It says that aeson, generic-lens, wai, warp and their
  transitive cohort now come from `cabal/cohort.freeze` through `generated/cohort-versions.nix`,
  for both supported GHCs, proved by `cohort-versions` and `cohort-closure`. It also names
  acceptance item 4 (Hurl Workbench deleting its local pins) as that consumer's follow-up in
  `mori://shinzui/hurl-workbench`.
- update the body's `Status` bullet.

Then run
`okf log add docs/improvement-requests IR-2 --kind "Status change" -m "IR-2 proposed -> completed: satisfied by ExecPlan 9's generated cohort layer"`
and
`okf validate docs/improvement-requests --strict --profile mori/improvement-requests-profile.dhall --profile-enforce --log-enforce`.
If the freeze's versions differ from IR-2's table (for example http2 5.4.6 rather than 5.4.4), say
so in the resolution: the request's floor is met or exceeded.

**MasterPlan.** Tick EP-9's three Progress lines, correct its first Surprises entry (the IFD path
already parses 3.14 and 3.16), and set the registry row's Status.

Commits: one per milestone, Conventional Commits, ending with these trailers:

```text
feat(cohort): generate the Nix version layer from the cohort freeze

MasterPlan: docs/masterplans/3-align-one-cabal-and-nix-package-set-across-the-rei-family-of-applications.md
ExecPlan: docs/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity.md
Intention: intention_01m3fw8cpte9xtje3e5j7f2ng2
```

Suggested subjects:
- `test(checks): guard cabal-version 3.14 and 3.16 evaluation`
- `feat(update): add cohort generate`
- `test(checks): add cohort parity checks`
- `refactor(registry): replace hand-written version pins with the generated cohort layer`
- `feat(scripts): add cohort-compare`
- `docs(adr): generate the channel's versions from the cohort freeze`

Commit on the current branch, and do not push without the user's go-ahead.


## Concrete Steps

Use the Review requirements for final manifest-based acceptance. Historical runtime-closure commands below describe baseline diagnostics; they cannot establish Haskell dependency parity. Consumers export an app alias `apps.<system>.cohort-compare` from their pinned channel to bootstrap lock resolution without guessing node names.

All commands run from `/Users/shinzui/Keikaku/bokuno/haskell-nix` unless stated. Put scratch
files under a scratch directory, never in the repository.

Milestone 1 prototype. Create the 3.14, 3.16 and 3.18 fixture copies (the 3.18 copy only in
scratch), then:

```bash
for v in 3.14 3.16; do
  nix eval --impure --raw --expr "
    let f = builtins.getFlake (toString ./.);
        pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; overlays = [ f.overlays.github ]; };
    in (pkgs.haskell.packages.ghc9124.callCabal2nix \"tiny\" ./checks/fixtures/cabal-version/$v { }).drvPath"
  echo
done
nix build --no-link --print-build-logs ".#checks.$(nix eval --impure --raw --expr builtins.currentSystem).cabal-version-support"
```

Expected: two `/nix/store/…-tiny-0.1.0.0.drv` paths and a successful build. For the 3.18 scratch
copy, expect `Unsupported cabal format version in cabal-version field: 3.18.`

Milestone 2, after plan 8 has committed the freeze:

```bash
nix run .#haskell-nix-update -- cohort generate
nix fmt
git diff --stat generated/
nix run .#haskell-nix-update -- cohort generate --check   # expect exit 0, no output changes
just nix-test
```

Expected: `generated/cohort-versions.nix` with roughly 100 to 150 `packages` entries, the
generator's summary line (something like
`cohort: 412 frozen = 36 boot + 78 first-party + 4 excluded + 2 source-pinned + 190 same-as-base + 102 generated`;
the numbers depend on the freeze), `nix fmt` changing nothing, and nix-unit printing all tests
passed.

Milestone 3:

```bash
sys=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build --no-link ".#checks.$sys.cohort-generated-fresh"
nix build --no-link ".#checks.$sys.ghc-boot-packages"
nix build --no-link ".#checks.$sys.cohort-versions" 2>&1 | tail -40   # expected to FAIL here
```

Expected failure excerpt, before wiring (the exact list depends on the freeze):

```text
error: cohort-versions: 101 frozen packages differ in github-ghc9124:
  aeson: nix=2.2.4.1 freeze=2.2.5.1
  hasql: nix=1.10.2.4 freeze=1.10.3.7
  shibuya-pgmq-adapter: nix=0.16.0.0 freeze=0.16.1.0
  tls: nix=2.3.1 freeze=2.4.6
  …
```

Milestone 4:

```bash
nix build --no-link ".#checks.$sys.cohort-versions"
nix build --no-link ".#checks.$sys.registry-policy-only"
nix build --no-link ".#checks.$sys.first-party-versions" ".#checks.$sys.overlay-eval" ".#checks.$sys.registry-valid"
just nix-test
git grep -nE 'callHackageDirect|hackage\.haskell\.org/package' -- overlays patches   # expect no output
```

Milestone 5:

```bash
nix run .#cohort-compare -- --freeze cabal/cohort.freeze \
  --plan-json /Users/shinzui/Keikaku/bokuno/rei-project/rei/dist-newstyle/cache/plan.json
nix run .#cohort-compare -- --freeze cabal/cohort.freeze \
  --closure /nix/store/p1c3d7z5x1nrvzhnicdpp08h0hn2pii0-rei-cli-6.0.0.0
```

The second path is Rei's deployed `rei-cli` as of 2026-09-26. If it has been garbage-collected,
use `nix path-info` on dotfiles' `.#darwinConfigurations.SungkyungM1X.pkgs.rei` instead. Expected:
both exit 1 today, listing the packages where Rei has not yet adopted the freeze (for example
`mismatch hasql 1.10.3.7 1.10.2.4` for the closure). This is correct: plan 11 fixes Rei.

Milestone 6. Run long builds in the background and log to a scratch file:

```bash
nix build --no-link --print-build-logs .#cohort-roots   2>&1 | tee "$SCRATCH/cohort-roots.log"
nix build --no-link --print-build-logs .#cohort-closure 2>&1 | tee "$SCRATCH/cohort-closure.log"
nix flake check --print-build-logs 2>&1 | tee "$SCRATCH/flake-check.log"
nix eval --impure --json --expr '
  let f = builtins.getFlake (toString ./.);
      pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; overlays = [ f.overlays.github ]; };
      h = pkgs.haskell.packages.ghc9124;
  in builtins.listToAttrs (map (n: { name = n; value = h.${n}.version; })
       [ "hasql" "hasql-pool" "tls" "crypton" "aeson" "warp" "wai" "generic-lens" "sbv"
         "shibuya-pgmq-adapter" "baikai-effectful" "optparse-applicative" "streamly" "brick" "vty" ])'
```

Expected after-table: every value equals the freeze. For example (the numbers come from Rei's
current Cabal plan; the freeze may be higher, never lower) hasql 1.10.3.7, hasql-pool 1.4.2.3,
tls 2.4.6, crypton 1.1.5, aeson 2.2.5.1, warp 3.4.16, wai 3.2.5, generic-lens 2.3.0.0, sbv 14.8,
shibuya-pgmq-adapter 0.16.1.0, streamly 0.11.1. Record wall-clock times of the two builds in
Outcomes.


## Validation and Acceptance

The review requirements above are additional completion gates, including the assigned update-isolation, manifest and cache evidence. Historical runtime-closure/version tables are diagnostic evidence only; they cannot replace those gates.

The plan is accepted when all of the following are observed:

1. `nix build .#checks.<system>.cabal-version-support` succeeds on aarch64-darwin, and the
   evaluation of the `cabal-version: 3.14` fixture through `overlays.github` returns a `.drv`
   path.
2. `nix run .#haskell-nix-update -- cohort generate --check` exits 0 on a clean tree. Editing any
   version in a scratch copy of the freeze and pointing `--freeze` at it makes `--check` exit 1.
3. With the committed freeze, `cohort-generated-fresh`, `ghc-boot-packages`, `cohort-versions`
   and `registry-policy-only` all build. `cohort-versions` was observed failing in Milestone 3,
   with the list pasted in Surprises, and passing after Milestone 4.
4. A deliberate break is caught. In a scratch branch, change one entry in
   `generated/cohort-versions.nix` (for example hasql's version) and `cohort-generated-fresh`
   fails naming hasql. Revert. Add `hasql = always (import ../patches/hasql/1.10.nix)` back and
   `registry-policy-only` fails. Revert.
5. `just nix-test` passes, including the new parser and version-layer tests. The
   `haskell-nix-update` check (the CLI's tasty suite, including `CohortTest`) passes.
6. `nix run .#cohort-compare` gives the documented output and exit codes on the fixture check. On
   Rei's current `plan.json` it reports Rei's pre-adoption differences and exits 1.
7. `nix build .#cohort-closure` succeeds on aarch64-darwin. The shibuya-pgmq-adapter entry built
   without a jailbreak, or its jailbreak is recorded in the Decision Log with the build error.
8. `nix flake check` passes on aarch64-darwin, including every curated matrix cell for
   `ghc9124` and `ghc9141`, the cache-identity checks and `first-party-versions`.
9. The before/after versions table is in Outcomes, and every after value equals the freeze.
10. ADR 3 exists, and IR-2 validates as `completed` under strict OKF profile enforcement.


## Idempotence and Recovery

- **The generator is idempotent.** It rewrites both generated files from the freeze and reuses
  existing hashes, so running it twice produces no diff, and `--check` proves that. A failed or
  interrupted run leaves the previous files in place: write to a temporary file in the same
  directory and rename.
- **Checks and evaluations** are read-only and can be rerun freely.
- **Milestone 4 is one revertible commit.** If a build breaks and the cause is not quickly found,
  `git revert` that commit to return to the hand-written pins; the generated file and checks from
  Milestones 2 and 3 stay. Use `just drv-diff <before.drv> <after.drv>` to find which input
  changed.
- **When a single generated package fails to build**, the fix is a policy entry (`doJailbreakOnly`,
  `markUnbroken`, a flag) in `overlays/registry.nix`, never a version pin. If the frozen version
  truly cannot build under Nix, report it to plan 8, which re-resolves the freeze. Do not edit
  `cabal/cohort.freeze` in this plan.
- **Do not touch `flake.lock`, and do not run `haskell-nix-update refresh`** while builds from this
  plan are running. A mutating refresh requires committed managed files and takes more than ten
  minutes.
- **Long builds** can be interrupted and resumed. Nix keeps every completed derivation, so
  rerunning `nix build .#cohort-closure` continues where it stopped. Kill a background build by
  its PID, never with `pkill -f`.
- **No database, deployment or consumer repository is touched.** Consumers keep their current
  channel revision until plans 11 to 14 move them, so nothing that ships changes when this plan's
  commits land.


## Interfaces and Dependencies

Runtime integration: Plan 16 (`docs/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md`) owns retained runtime records and guarded application composition after this plan and plan 10. Provide reusable generator and manifest helpers accepting an explicit resolved cohort/source/configuration context. Plan 16 uses them to generate immutable runtime projections and extends manifests with runtime name/generation/configuration; no duplicate freeze parser, source/hash lookup or comparator is permitted. A selected runtime projection protects its owned dependency recipes when applying additional application entries. Detect shared-name source/metadata/flag/policy conflicts before claiming reuse. Keep ordinary default/historical factory behavior and checks valid. Runtime builds/cache warming in plan 16 reuse this plan's publication mechanism, including any additional runtime roots.

New and changed Nix interfaces, all under this repository:

```nix
# lib/parseCohortFreeze.nix
#   { lib } -> String -> { constraints : AttrSet String; flags : AttrSet [String]; indexState : String | null }
# lib/mkCohortVersionLayer.nix
#   { lib } -> CohortVersions -> HaskellLib -> Pkgs -> (hself -> hsuper -> AttrSet)
# lib/mkHaskellExtension.nix      gains  versionLayer ? (_: _: _: _: { })
# lib/mkHaskellOverlay.nix        gains  versionLayer ? (_: _: _: _: { })
# lib/mkFirstPartyPackageSet.nix  factory gains  cohortVersions ? { packages = { }; }
# flake.nix outputs:
#   lib.parseCohortFreeze
#   lib.cohort = { freeze; versions; boot; versionTable; }
#   packages.<system>.{ cohort-closure, cohort-roots, cohort-compare }
#   apps.<system>.cohort-compare
#   checks.<system>.{ cabal-version-support, cohort-generated-fresh, cohort-versions,
#                     ghc-boot-packages, registry-policy-only, cohort-compare }
```

The generated data type (`CohortVersions`) is the attribute set shown in Milestone 2:
`{ schemaVersion; freezeSha256; indexState; ghc; nixpkgsBase; packages = { <name> = { version; sha256; revision = null | { number; sha256; }; }; }; sameAsBase; }`.

New Haskell module `HaskellNix.Update.Cohort` in `cli/haskell-nix-update`:

```haskell
data Freeze = Freeze
  { constraints :: Map PackageName Version
  , flags :: Map PackageName [Text]
  , indexState :: Maybe UTCTime
  }

data Classification
  = Boot | FirstParty | Excluded Text | SourcePinned | SameAsBase | Generated GeneratedEntry

data GeneratedEntry = GeneratedEntry
  { version :: Version, sha256 :: SriHash, revision :: Maybe (Int, Text) }

parseFreeze :: Text -> Either UpdateError Freeze
selectRevision :: UTCTime -> [HackageRevision] -> Maybe HackageRevision
classify :: CohortInputs -> Freeze -> Either UpdateError (Map PackageName Classification)
renderCohortVersions :: CohortVersions -> Text
renderBootPackages :: Text -> Map PackageName Version -> Text
runCohortGenerate :: ProcessRunner -> HttpClient -> CohortGenerateOptions -> IO (Either UpdateError CohortReport)
```

It reuses `PackageName`, `SriHash` and `UpdateError` from `HaskellNix.Update.Types`, the `Version`
type the other modules already use, `prefetchHackage` from `HaskellNix.Update.Nix`, `HttpClient`
and `getWithManager` from `HaskellNix.Update.Hackage`, and `ProcessRunner` from
`HaskellNix.Update.Process`. It needs a `time` dependency for `UTCTime` (a GHC boot package; add
`time` to the library's `build-depends`) and nothing else new.

New script `scripts/cohort-compare.sh`: bash with `set -euo pipefail`, depending on `jq`, `curl`,
`grep`, `sed`, `coreutils` and `nix` (for `nix-store -qR`). The interface and exit codes are in
Milestone 5, and plans 11, 12, 13 and 14 depend on them.

External inputs:
- Hackage's package tarballs and its revisions JSON endpoint;
- the pinned nixpkgs `d5dfd8e6` (for its `ghc9124` set, `callHackageDirect` and the IFD cabal2nix
  `2.21.3-unstable-2026-03-30`, which parses up to `cabal-version: 3.16`);
- plan 8's `cabal/cohort.freeze`.

Nothing in this plan requires a new flake input.


## Revision Notes

- 2026-09-26 (MasterPlan reconciliation after parallel drafting): The ADR is renumbered to `docs/adr/3-generate-the-channels-package-versions-from-the-cohort-freeze.md`, because the MasterPlan allocates 2 to plan 8, 3 to this plan and 4 to plan 10. The freeze's `index-state:` line is confirmed: plan 8 writes it.

- 2026-10-04: MasterPlan review for reducing change time: clarified shared ownership and acceptance, added the applicable targeted-update/build-identity/cache contracts, and corrected historical assumptions. No implementation completion is claimed.

- 2026-10-04 (runtime workstream): Added EP-16 integration, ownership and applicable acceptance; consumer adoption now requires the retained runtime set and composes application selections/packages onto it. Shared-tool preparation remains acyclic and the fleet advisory policy is preserved.
