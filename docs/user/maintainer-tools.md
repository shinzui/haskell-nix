# Maintainer tools

The flake uses flake-parts for system-specific output wiring. Shared package-selection and
overlay logic stays in `lib/`; existing build checks live in `checks/default.nix` and tool
checks live in `nix/tooling.nix`. Both flake-parts and treefmt-nix follow the existing inputs
of `mori://shinzui/haskell-nix-dev`. Nix-unit and nix-diff come from the same pinned Nixpkgs
as the development shell. Tool adoption does not update family sources or the compiler pin.

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
