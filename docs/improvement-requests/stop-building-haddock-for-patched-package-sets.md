---
type: Improvement Request
title: Stop building Haddock for the package sets haskell-nix patches
description: Add a Haddock counterpart to the opt-in disableProfiling flag, so a
  consumer that ships CLI tools and never reads the generated documentation can
  stop compiling it for every package in the set.
timestamp: 2026-08-11T03:59:38Z
generated:
  by: claude-code/opus-5
  at: "2026-08-11T03:59:38Z"
origin: mori://shinzui/dotfiles.nix
requestId: IR-1
status: proposed
---

# Improvement Request: Stop building Haddock for the package sets haskell-nix patches

## Status

- **Status:** proposed
- **Origin:** `shinzui/dotfiles.nix` (raised while cutting the time
  `darwin-rebuild switch` spends compiling the globally installed Haskell CLIs).
  That repository is not yet Mori-registered; the URI above is its intended
  canonical form.
- **Owner of the build:** `shinzui/haskell-nix`
- **Size:** small — a second flag alongside `disableProfiling`, following the
  shape that already exists
- **Planning:** unplanned

## Problem

Every library in a package set this flake patches is compiled, and then
documented. `doHaddock` defaults to true in nixpkgs' Haskell builder, so each
library package carries a `doc` output and pays a full Haddock pass over its
own modules and its dependencies' interfaces. No consumer of this flake reads
any of it. All six registry consumers — `mina`, `nihongo`, `notion-hub`,
`kazuha`, `kizamu`, `seihou` — ship command-line tools; the documentation a
human actually opens is on Hackage, and the profiling and doc artifacts a
developer occasionally wants come from `cabal` in the dev shell, against its
own package db rather than this set.

The cost is not offset by the binary cache. Hydra builds only the default
compiler's `haskellPackages`; nixpkgs' default is currently GHC 9.10.3 while
this fleet pins 9.12.4, so `haskell.packages.ghc9124.*` is absent from
cache.nixos.org — `nix path-info --store https://cache.nixos.org` reports
`aeson-2.2.4.1` for that set as *not valid*. Every consumer therefore compiles
the entire closure locally, Haddock included, and pays it again on each
toolchain or registry bump.

## Evidence

**The waste is visible at the far end of the chain.** In
`shinzui/dotfiles.nix`, which installs these tools into the darwin profile,
11 of the 13 Haskell flake outputs still carried a `doc` output: `mori`, `rei`,
`okf`, `kazuha`, `kizamu`, `nihongo`, `shiki`, `notion-cli`, `notion-hub`,
`mori-rei-app`, and `notion-hub-subscriptions`. Only `mina` and `reiko` had
already set `doHaddock = false` by hand in their own overlays, and `seihou`'s
default output is not a Cabal derivation at all.

**Turning it off at that end reaches almost none of it.** `dotfiles.nix` now
wraps each flake output in `dontHaddock`, but a derivation override reaches
only the top-level package. The dependency closure is instantiated inside each
project's flake against that flake's own `pkgs`, which no overlay in the
consuming repository can influence. For `mori` alone that closure is roughly
40 source-built packages whose Haddock is untouched by the wrapper.

**The mechanism this needs already exists.** `lib/disableProfilingOverride.nix`
overrides `mkDerivation` in the package scope to drop `enableLibraryProfiling`,
reached through the opt-in `disableProfiling` flag on `lib.mkChannelExtension`
and `lib.mkHaskellOverlay`. It measurably flips the whole set: with the flag on,
`aeson` moves from `--enable-library-profiling` to `--disable-library-profiling`,
and `kazuha-cli` — a consumer that never disabled profiling for its own packages
— builds with the flag disabled and no mixed-state failure. Adding
`doHaddock = false` to that same attribute set is one line; the flag that gates
it is a few more.

## Proposal

**A `disableHaddock` flag beside `disableProfiling`**, on both
`lib.mkChannelExtension` and `lib.mkHaskellOverlay`, defaulting to false. The
precedent settles the question the profiling change had to answer: build
settings are the consumer's call, not the flake's, so this is opt-in too.
`shellFor`-based dev shells and any future Hoogle index over this set would
lose their inputs, which is reason enough not to impose it.

**Decide whether the two flags stay separate or collapse into one.** They will
almost always be set together, and each one costs a full rebuild of the set on
its own. A single `leanBuild` flag would be one switch and one rebuild; two
flags keep the reasons distinct, which matters because the arguments for them
are not the same strength — nothing consumes the profiling way, whereas Haddock
has real consumers this fleet just doesn't happen to have.

**Extend the `disableProfiling` section of
`docs/user/consumer-integration.md`** rather than adding a second one, so the
page reads as one list of build settings.

## Why this shape

The profiling change had to be set-wide because profiling is contagious across
a dependency edge: a library built the `p_` way needs its dependencies' `p_hi`
files, so patching only registry packages would have broken exactly the
consumers that had not already disabled profiling for their own packages.
Haddock has no such coupling — a package can skip documentation whether or not
its dependencies did — so it *could* be done per package. It should not be, for
the plainer reason that the same one-line hook covers the whole set correctly
and a per-package list would need maintaining against every new registry entry.

The reason this is a request rather than a commit is scope, not difficulty.
Turning Haddock off changes the build of every package in a consuming package
set, and by default this flake confines itself to *which* package versions
resolve. A flag keeps that default intact while making the choice available —
but adding a second build-settings knob is still a decision about what this
flake is for, and worth making deliberately rather than by accretion.

## Notes for whoever builds it

This reaches at most six of the thirteen tools in the profile, and only those
that opt in. `mori`, `rei`, `reiko`, `shiki`, `okf`, `mori-rei-app`, and
`notion-cli` hand-roll their overlays and do not consume this flake at all;
their source-built dependency lists carry the same Haddock and profiling cost
and would each need the same treatment locally, or a migration onto the
registry. The registry consumers are the cheap half of the problem.

Flipping a `mkDerivation` attribute changes every store path in the set, so each
flag costs a consumer one full rebuild when it turns it on. If both flags are
wanted, land the second before any consumer adopts the first, or the fleet pays
the rebuild twice — which is also the argument for collapsing them into one.
