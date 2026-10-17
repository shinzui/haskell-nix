---
type: Reference
title: Maintainer tools
description: Find repository formatting, test, derivation-diff, and validation commands.
docId: DOC-6
tags: [maintainers, testing, nix]
timestamp: 2026-10-17T13:15:43Z
generated:
  by: human:nadeem
  at: 2026-09-21T14:33:46Z
---

# Maintainer tools

The flake uses flake-parts for system-specific output wiring. Shared package-selection and
overlay logic stays in `lib/`; existing build checks live in `checks/default.nix` and tool
checks live in `nix/tooling.nix`. Both flake-parts and treefmt-nix follow the existing inputs
of `mori://shinzui/haskell-nix-dev`. Nix-unit and nix-diff come from the same pinned Nixpkgs
as the development shell. Tool adoption does not update family sources or the compiler pin.

## Compatibility declaration reports

`lib.compatibilityReport` exports a read-only declaration context for an explicit
package set, compiler, channel, system and optional retained runtime configuration.
The caller supplies each package's version, source identity, Cabal metadata identity
and derivation **before its compatibility repair**, plus its selected construction
profiles and generated-source layer. Do not substitute a final repaired recipe or
stock Nixpkgs facts for those selected inputs. Automatic capture from real recipe
construction is still pending; the checked-in example is a controlled fixture.

Run the fixture and its native interchange check from this repository:

```bash
nix eval --impure --json .#lib.compatibilityReport \
  --apply 'report: report (import ./checks/fixtures/compatibility-policy/context.nix)' \
  > /tmp/compatibility-context.json
nix run .#haskell-nix-update -- compatibility report --context /tmp/compatibility-context.json --json
nix run .#haskell-nix-update -- compatibility check --context /tmp/compatibility-context.json
nix build --no-link .#checks.aarch64-darwin.compatibility-report
```

The report shares the executable registry's row selector and compiler/version
predicates. It distinguishes inactive rows, inactive scopes and selected unverified
entries. Entries outside the supplied package subset are listed separately.
Selected declarations remain unverified: a source assertion in a build hook has
not passed merely because its compiler/version predicate matches. Retirement
thresholds produce candidates with unmet checks, never automatic removals.

`check` validates the declaration interchange contract and fails if any explicitly
required evidence is missing or unverified. A context with no required evidence
can pass that check while retaining unverified native coverage; this is not a
dependency-test, bounds-enforcement or retirement receipt. The CLI rejects forged
pass statuses and inconsistent required-evidence diagnostics. It does not rerun
Nix selection from JSON, validate arbitrary patch-function effects or authenticate
caller-supplied input facts. Invalid command arguments exit 2; malformed contexts
and unmet evidence exit 1. Reports and checks do not change locks or recipes.

## Formatting

Run these commands from the repository root:

```bash
just fmt
just fmt-check
```

`nix fmt` runs treefmt using `treefmt.nix`. The formatter is nixpkgs-fmt, matching the existing
fleet style. `nix fmt -- --ci` checks without writing. `checks.<system>.formatting` runs the
same policy during `nix flake check`. Managed skill directories are excluded.

## Fast Nix tests

```bash
just nix-test
```

This builds only `checks.<current-system>.nix-unit`. The named tests in `checks/unit.nix`
validate registry inventories, rejection of malformed data, and source-fetch laziness without
building Haskell packages or fetching family sources. Dependencies of the test runner may be
downloaded the first time. Add snapshot-selection contract tests here as schema version 2
is implemented; keep real compilation and derivation-identity checks separate.

For interactive test filtering, the shell provides the same runner:

```bash
nix develop -c nix-unit --flake .#lib.tests
nix develop -c nix-unit --flake .#lib.tests --attr testGithubInventoryWithoutFetching
```

Nix-unit embeds the Nix evaluator from its pinned package, which can differ from the installed
Nix executable. Run the ordinary flake checks as well to exercise the host's evaluator.

## Derivation differences

When two expected-equal derivation paths differ, preserve both paths printed by the failed
comparison and inspect them with nix-diff:

```bash
just drv-diff '<before.drv>' '<after.drv>'
```

Replace the placeholders with the actual `.drv` paths. The command runs nix-diff in the
development shell. Differences in source, compiler, dependency derivations, patches, or build
flags are real rebuild inputs; set labels and unrelated selections should not appear there.

## Full validation

```bash
just flake-check
git diff --check
```

The flake checks include formatting and pure Nix tests alongside the existing registry,
version, overlay, build-setting, and updater checks. Cabal2nix evaluation can require building
generators. Checks run on the current system; other supported systems require their own
native or configured remote builders. No Git hooks are installed automatically, and
nix-eval-jobs remains deferred until evaluation performance warrants it.
