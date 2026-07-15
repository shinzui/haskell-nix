---
id: 2
slug: build-the-haskell-package-refresh-cli
title: "Build the Haskell package refresh CLI"
kind: exec-plan
created_at: 2026-07-15T17:12:57Z
intention: intention_01kv1bq794e62tthz1rj47dqrx
master_plan: "docs/masterplans/1-automate-dual-channel-first-party-haskell-package-updates.md"
---

# Build the Haskell package refresh CLI

This ExecPlan is a living document. The sections Progress, Surprises & Discoveries,
Decision Log, and Outcomes & Retrospective must be kept up to date as work proceeds.


## Purpose / Big Picture

This plan adds a small Haskell executable, `haskell-nix-update`, that turns a repetitive
multi-family refresh into one reviewable command. `refresh` advances selected locked GitHub
inputs, discovers their root Cabal packages through Mori-located Git repositories, compares
each package with official Hackage metadata, calculates release hashes, and atomically
rewrites the generated package lock. `check` detects local or online drift without changing
files.

The executable is available as `nix run .#haskell-nix-update -- ...`, follows the user's
standards in `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei`, never commits or pushes, and
has network-free tests. A maintainer can preview an update, apply it, inspect a concise
summary, and rely on the Nix checks from EP-1 for downstream validation.


## Progress

- [x] Scaffold the GHC2024 library, executable, test suite, root Cabal project, and plain-Nixpkgs flake app.
- [x] Implement typed config/lock decoding and validation with golden round-trip tests.
- [x] Implement injectable process, Mori, Git, Nix-lock, and Hackage adapters.
- [x] Implement root-package discovery, version comparison, Hackage hashing, and deterministic planning.
- [x] Implement safe `refresh` and `check` commands, dry-run output, rollback, and offline tests.
- [x] Run standards, CLI help, package, test, and flake validation; document the workflow.


## Surprises & Discoveries

- The pinned Nixpkgs revision provides optparse-applicative 0.18.1.0, while this plan's
  option-group API requires 0.19. The updater therefore uses a private, fixed-output
  optparse-applicative 0.19 override from the existing audited package expression; it
  still builds entirely from the plain Nixpkgs GHC 9.12.2 package set.

- Cabal 3.14 warns that its published compatibility bounds predate GHC 9.12, but the
  Cabal library, executable, test suite, and Haddock all compile successfully with GHC
  9.12.2 in the repository's pinned Nixpkgs.

- Git discovery reads each one-directory-deep `.cabal` file, but the generated lock must
  store that file's directory rather than the filename. EP-1 appends `package.path` to the
  family source before calling Cabal2nix, so retaining the filename would have selected a
  file where a package source directory is required.


## Decision Log

- Decision: Use GHC 9.12+, GHC2024, and the baseline conventions from
  `/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/core/standards.md`.
  Rationale: The user explicitly selected these standards, and they match the wider local
  Haskell fleet.
  Date: 2026-07-15

- Decision: Use a library-plus-thin-executable package layout.
  Rationale: Pure planning and parsing logic belongs in testable library modules; `app/Main.hs`
  should only call the CLI runner, following the local Mori CLI pattern.
  Date: 2026-07-15

- Decision: Use Mori JSON plus Git object commands instead of traversing Nix input store paths.
  Rationale: Mori provides authoritative registered project roots, while `git show` and
  `git ls-tree` can read the exact locked revision without searching `/nix/store`.
  Date: 2026-07-15

- Decision: Discover exactly one-directory-deep `.cabal` files and parse their declared
  package name/version with the Cabal library.
  Rationale: This is robust to stale Mori package metadata, matches all requested monorepos,
  and excludes nested fixtures and examples by construction.
  Date: 2026-07-15

- Decision: Make online and process effects injectable and keep tests offline.
  Rationale: Refresh orchestration needs deterministic failure/rollback tests and must not
  depend on GitHub or Hackage availability in `nix flake check`.
  Date: 2026-07-15

- Decision: Override only optparse-applicative inside the updater's private plain-Nixpkgs
  Haskell package set.
  Rationale: Nixpkgs' 0.18.1.0 lacks `parserOptionGroup`, while the already-audited 0.19
  expression supplies the required API without coupling the repair tool to either
  generated first-party channel.
  Date: 2026-07-15


## Outcomes & Retrospective

Completed on 2026-07-15. The repository now provides a GHC 9.12.2/GHC2024
`haskell-nix-update` library, executable, tests, flake app, and development shell. The CLI
implements strict EP-1 codecs; injectable process and HTTP boundaries; Mori, Git, Hackage,
Nix-lock, prefetch, and validation adapters; a deterministic planner with explicit change
categories; grouped `refresh` and `check` interfaces; family scoping; dry-run and online
checking; dirty-file refusal; atomic package-lock replacement; and byte-for-byte rollback.

The network-free suite contains 32 tests covering schema fixtures, adapter parsing, every
planner change category, legitimate GitHub/Hackage version differences, refresh success,
no-change behavior, partial selection, dry-run, dirty refusal, missing Git objects,
Hackage 404, prefetch failure, post-update validation failure, rollback, and offline/online
check behavior. `nix build .#haskell-nix-update`, both subcommand help screens,
`nix develop -c cabal test haskell-nix-update-test`, the real empty-catalog offline check,
and `nix flake check --print-build-logs` all pass. EP-3 can now use the updater to create
and validate the production seven-family lock instead of assembling it manually.


## Context and Orientation

This repository currently contains only Nix and documentation. EP-1,
`docs/plans/1-introduce-manifest-driven-hackage-and-github-channels.md`, is a hard dependency
and must be complete. It defines `config/first-party-families.json` as hand-authored policy
and `packages/first-party-lock.json` as generated state. The updater must treat the EP-1
schemas as fixed interfaces rather than introducing a parallel configuration format.

The executable lives in a new Cabal package at `cli/haskell-nix-update/`. Add a root
`cabal.project` containing only that directory. The package contains a library, a thin
`haskell-nix-update` executable, and a Tasty test suite. Use this module layout:

```text
cli/haskell-nix-update/
  haskell-nix-update.cabal
  app/Main.hs
  src/HaskellNix/Update.hs
  src/HaskellNix/Update/Cli.hs
  src/HaskellNix/Update/Types.hs
  src/HaskellNix/Update/Catalog.hs
  src/HaskellNix/Update/PackageLock.hs
  src/HaskellNix/Update/Mori.hs
  src/HaskellNix/Update/Git.hs
  src/HaskellNix/Update/Hackage.hs
  src/HaskellNix/Update/Nix.hs
  src/HaskellNix/Update/Process.hs
  src/HaskellNix/Update/Plan.hs
  src/HaskellNix/Update/Workflow.hs
  test/Main.hs
  test/fixtures/
```

`HaskellNix.Update.Types` owns the shared domain types. Use records equivalent to these
signatures; field names may be qualified to avoid ambiguity, but their meanings must not
change:

```haskell
newtype FamilyName = FamilyName Text
newtype PackageName = PackageName Text
newtype GitRevision = GitRevision Text
newtype SriHash = SriHash Text

data FamilyConfig = FamilyConfig
  { name :: FamilyName
  , moriProject :: Text
  , github :: Text
  , githubInput :: Text
  , packageOverrides :: Map PackageName PackageOverride
  }

data LockedPackage = LockedPackage
  { name :: PackageName
  , path :: FilePath
  , version :: Version
  , cabal2nixOptions :: Text
  , hackage :: Maybe HackagePin
  }

data HackagePin = HackagePin
  { version :: Version
  , hash :: SriHash
  }

data RefreshPlan = RefreshPlan
  { familyChanges :: [FamilyChange]
  , nextPackageLock :: PackageLock
  }
```

Use Aeson for JSON and the Cabal package library to parse `.cabal` files and compare
versions. Use `process` behind a project-owned runner interface for `mori`, `git`, and `nix`.
Use `http-client` plus `http-client-tls` for Hackage's official JSON endpoint. The Hackage
endpoint `https://hackage.haskell.org/package/<package>.json` returns an object whose keys
are published versions. Select the greatest numeric version with status `normal`; if none
is normal, select the greatest returned version and report that fallback in the refresh
summary. HTTP 404 means unpublished and produces `hackage = null`. Prefetch a selected
release with:

```text
nix store prefetch-file --json --unpack https://hackage.haskell.org/package/<name>-<version>/<name>-<version>.tar.gz
```

Mori's `mori registry show <qualified-name> --json --full` response contains the project
`path`, repositories, and package metadata. Use the project path and verify that the
configured `github` matches a Mori repository. Read `flake.lock` after a targeted
`nix flake update <githubInput>` and obtain the locked 40-character revision from the named
input node. Ensure the exact Git object exists in the Mori checkout; run
`git -C <path> fetch origin <revision>` only when `git cat-file -e <revision>^{commit}`
fails. Discover package files using `git ls-tree -r --name-only <revision>` and retain paths
of the exact form `<directory>/<file>.cabal`. Read them with
`git show <revision>:<path>`; do not check out branches and do not read `/nix/store`.

The CLI follows the Haskell standards exactly: `cabal-version: 3.4`, `base >=4.20 && <5`,
`default-language: GHC2024`, and a common stanza enabling `DeriveAnyClass`,
`DuplicateRecordFields`, `OverloadedLabels`, and `OverloadedStrings`. All qualified imports
use postpositive syntax. Apply the warning set demonstrated by the local Mori CLI, including
`-Wall`, `-Wcompat`, `-Widentities`, `-Wincomplete-uni-patterns`,
`-Wincomplete-record-updates`, `-Wredundant-constraints`, `-Wmissing-export-lists`, and
`-Wmissing-deriving-strategies`. Use optparse-applicative 0.19 or later and the option-group
pattern documented at
`/Users/shinzui/Keikaku/bokuno/haskell-jitsurei/cli/option-groups.md`.


## Plan of Work

### Milestone 1: Establish the standards-compliant package and pure model

Create the Cabal project, package, module skeleton, and tests. The executable's `Main` module
imports only `runCli` from the library. Implement JSON codecs and validators for the exact
EP-1 schemas, canonical sorting, version parsing, clean relative-path validation, unique-name
checks, and stable pretty JSON ending in one newline. Golden tests must round-trip the valid
EP-1 fixtures and reject every invalid fixture.

Extend `flake.nix` with a package and app built from plain Nixpkgs `ghc9122`, not from either
generated first-party channel. This avoids making the tool that repairs the registry depend
on that registry. `nix build .#haskell-nix-update` and
`nix run .#haskell-nix-update -- --help` must work before external adapters exist.

### Milestone 2: Implement discovery adapters and deterministic planning

Define a narrow `ProcessRunner` abstraction that returns exit code, stdout, and stderr and
supports an optional working directory and environment additions. Implement Mori JSON
decoding, flake-lock decoding and targeted input updates, Git object discovery, official
Hackage queries, and Nix prefetch JSON decoding in separate modules. Error values must name
the family, package, command or URL, and a concise cause without dumping full environment or
credentials.

Implement a pure planner that combines config, previous lock, locked revisions, discovered
Cabal packages, Hackage results, and hashes into a sorted next lock plus a human-readable
change summary. The summary distinguishes GitHub revision movement, added or removed
packages, GitHub version changes, Hackage publication or unpublication, Hackage version
changes, and hash changes. Add unit tests for all categories and for the case where GitHub
and Hackage versions differ legitimately.

### Milestone 3: Implement safe refresh and check workflows

Expose `refresh` and `check` subcommands. Both accept repeatable `--family FAMILY`; no flag
means all configured families. `refresh --dry-run` queries remote Git refs and Hackage but
does not alter `flake.lock` or the package lock. Normal `refresh` refuses to start if either
managed lock file has pre-existing uncommitted changes, saves their original bytes, runs
targeted Nix input updates, builds the next package lock, writes it atomically through a
same-directory temporary file and rename, and runs the EP-1 schema/registry check. If any
step after Nix updates fails, restore both managed files byte-for-byte and return nonzero.

Offline `check` validates config, package lock, and `flake.lock` agreement and confirms that
each locked package still parses from the locally available Git object. `check --online`
also compares configured remote heads and Hackage latest versions but makes no writes. Print
summaries to stdout and actionable errors to stderr. A no-change refresh exits zero and does
not rewrite either lock file.

Use fake process and HTTP adapters plus temporary repositories and files to test success,
no-change, partial-family, dry-run, pre-existing-dirty-file refusal, missing Git object,
Hackage 404, prefetch failure, post-update validation failure, and byte-for-byte rollback.
No default test may use the network.


## Concrete Steps

Run from `/Users/shinzui/Keikaku/bokuno/haskell-nix` after EP-1 is marked Complete in the
master plan. Confirm standards and dependencies through Mori before coding:

```bash
mori registry docs shinzui/haskell-jitsurei
mori registry show pcapriotti/optparse-applicative --full
mori registry show snoyberg/http-client --full
git status --short --branch
```

Build and test incrementally:

```bash
nix build .#haskell-nix-update --print-build-logs
nix run .#haskell-nix-update -- --help
nix develop -c cabal test haskell-nix-update-test
nix flake check --print-build-logs
```

If EP-1 does not already provide a dev shell with GHC 9.12 and Cabal, add one in this plan
using the same plain Nixpkgs package set as the executable. The expected help begins with:

```text
Usage: haskell-nix-update COMMAND

Available commands:
  refresh  Refresh GitHub and Hackage package locks
  check    Check package-lock drift without changing files
```

Use a temporary fixture catalog for workflow tests; do not point tests at the seven real
repositories. Before each commit run `cabal test`, `nix build`, and `git diff --check`.
Use Conventional Commit messages such as the following, with both required trailers:

```text
feat(cli): add package refresh planning

MasterPlan: docs/masterplans/1-automate-dual-channel-first-party-haskell-package-updates.md
ExecPlan: docs/plans/2-build-the-haskell-package-refresh-cli.md
```

At completion exercise only offline production behavior because EP-3 owns the first online
refresh:

```bash
nix run .#haskell-nix-update -- check
nix flake check --print-build-logs
git diff --check
```


## Validation and Acceptance

The Cabal test suite and `nix flake check` must exit zero without network access. Golden
tests prove stable JSON; adapter tests prove exact command arguments and JSON handling;
workflow tests prove dry-run non-mutation and rollback. The built executable reports grouped,
readable help and uses postpositive qualified imports and all required standards.

Given a fixture where the GitHub revision advances, one package is added, one published
version advances, and one package remains unpublished, `refresh --dry-run` must print those
four facts and leave both managed lock files byte-identical. Given the same fixture without
`--dry-run`, it writes the sorted next package lock. If the final validation fake fails, the
command returns nonzero and both files match their original bytes. A second successful
refresh reports no changes and does not alter mtimes through needless rewrites.


## Idempotence and Recovery

`check`, `check --online`, and `refresh --dry-run` are read-only. A successful `refresh` is
idempotent at unchanged upstream state. Before any mutation, refuse dirty managed files and
retain their exact bytes in memory; restore them on every failure after `nix flake update`.
Atomic rename prevents a partial package-lock write. Git fetches may update remote-tracking
metadata in Mori-located repositories, but never branches or working trees.

The CLI never stages, commits, pushes, publishes, deletes packages, or edits upstream
repositories. If network access is interrupted, rerun after connectivity returns. Nix and
Git caches make repeated attempts cheaper. If Hackage responds with malformed metadata,
fail that family rather than treating it as unpublished.


## Interfaces and Dependencies

The stable user interface is:

```text
haskell-nix-update refresh [--family FAMILY]... [--dry-run]
haskell-nix-update check [--family FAMILY]... [--online]
```

`HaskellNix.Update` exports `runCli`. `Catalog` and `PackageLock` export typed decoders,
validators, and canonical encoders. `Plan` exports a pure function equivalent to:

```haskell
planRefresh :: FamilyCatalog -> PackageLock -> [ObservedFamily] -> Either UpdateError RefreshPlan
```

`Workflow` depends only on adapter records or functions, not concrete global effects, so
tests can substitute fakes. The Cabal library depends on `aeson`, `bytestring`, `Cabal`,
`containers`, `directory`, `filepath`, `http-client`, `http-client-tls`,
`optparse-applicative >=0.19`, `process`, `temporary`, and `text`; the tests add `tasty` and
`tasty-hunit`. Before implementation, use Mori to locate registered dependency sources and
read them directly where available; never search `/nix/store`. EP-1's two JSON schemas and
public checks are hard dependencies. EP-3 consumes the executable and may add production
cases, but must not fork its types or rendering rules.
