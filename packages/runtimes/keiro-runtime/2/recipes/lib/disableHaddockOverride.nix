# disableHaddockOverride :: hself -> hsuper -> AttrSet
#
# Package-set-wide opt-out of Haddock documentation. ON BY DEFAULT: every caller
# of `mkChannelExtension` or `mkHaskellOverlay` gets it unless they pass
# `disableHaddock = false`. It flipped alongside `disableProfiling` and for the
# same reason: the setting it changes is one nothing in this fleet consumes, and
# leaving it opt-in meant every consumer paid for it by default.
#
# `doHaddock` defaults to true in nixpkgs' Haskell builder, so every library in
# a set carries a `doc` output and pays a full Haddock pass over its own
# modules and its dependencies' interfaces. A fleet that ships CLI tools reads
# none of it: the documentation a human opens is on Hackage, and the docs a
# developer occasionally wants come from `cabal` in the dev shell, against its
# own package db rather than this set.
#
# As with profiling, it is not paid for out of the binary cache. Hydra builds
# only the default compiler's `haskellPackages`; this fleet pins GHC 9.12.4,
# which is not it, so `haskell.packages.ghc9124.*` is absent from
# cache.nixos.org and every consumer compiles the whole closure locally.
# Dropping the Haddock pass costs no cache hits, because there were none to
# lose.
#
# WHY THE WHOLE SET, AND NOT `dontHaddock` PER PACKAGE:
# unlike profiling, Haddock is NOT contagious across a dependency edge — a
# package can skip its documentation whether or not its dependencies did, so a
# per-package list would at least be *correct*. It would still be wrong to
# maintain: the same one-line hook covers the whole set, while a hand-kept list
# drifts against every new registry entry and every dependency a consumer adds.
#
# ONE ATTRIBUTE IS ENOUGH. In generic-builder.nix the entire `haddockPhase`
# body is gated on `doHaddock && isLibrary`, so `doHoogle`,
# `doHaddockQuickjump` and `hyperlinkSource` never get a chance to apply.
# `doHaddockInterfaces` defaults to `doHaddock && ...` and
# `enableSeparateDocOutput` defaults to `doHaddock`, so the interface
# configureFlags and the separate `doc` output fall away with it.
#
# This sets a DEFAULT, not a ceiling: `overrideCabal` re-applies its own attrs
# on top of the scope's `mkDerivation`, so a consumer that wants documentation
# for one particular package can still get it with
# `haskell.lib.compose.doHaddock`.
#
# What genuinely loses its inputs is anything reading a package's `.doc` or its
# now-null `haddockDir` passthru — `shellFor`-based dev shells that want
# dependency documentation, and any Hoogle index over this set. That was the
# reason this stayed opt-in; it is now the reason a consumer with such a shell
# passes `disableHaddock = false` rather than the reason everyone else pays.
_hself: hsuper: {
  mkDerivation = args: hsuper.mkDerivation (args // {
    doHaddock = false;
  });
}
