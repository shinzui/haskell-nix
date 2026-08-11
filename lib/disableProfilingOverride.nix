# disableProfilingOverride :: hself -> hsuper -> AttrSet
#
# Package-set-wide opt-out of GHC profiling libraries. OPT-IN: nothing composes
# it unless a caller passes `disableProfiling = true` to `mkChannelExtension`
# or `mkHaskellOverlay`, or composes this extension directly. The default stays
# false because turning it on changes how a consumer's packages are built, not
# just which versions they resolve, and that is the consumer's call.
#
# nixpkgs builds every Haskell library twice — a vanilla way and a `p_` way —
# because `enableLibraryProfiling` defaults to true. Nothing in this fleet
# consumes the profiling way: consumers ship CLI tools, and the profiling
# builds a human actually asks for happen through `cabal` in the dev shell,
# against its own package db, not against this set. The second GHC pass is
# therefore pure cost.
#
# It is not paid for out of the binary cache either. Hydra builds only the
# default compiler's `haskellPackages`; this fleet pins GHC 9.12.4, which is
# not it, so `haskell.packages.ghc9124.*` is absent from cache.nixos.org and
# every consumer compiles the whole closure locally. Halving that closure's
# GHC work costs no cache hits, because there were none to lose.
#
# WHY THE WHOLE SET, AND NOT `disableLibraryProfiling` PER PACKAGE:
# profiling is contagious across a dependency edge. A library built the `p_`
# way needs its dependencies' `p_hi` files, so a package set that mixes the
# two settings fails to build the moment a profiled consumer package depends
# on an unprofiled one. Disabling it for registry packages alone would break
# exactly the consumers that have not disabled it for their own packages.
# Overriding `mkDerivation` in the scope moves every package in the set at
# once, which is the only self-consistent way to flip it.
#
# `enableExecutableProfiling` already defaults to false, so it is left alone.
_hself: hsuper: {
  mkDerivation = args: hsuper.mkDerivation (args // {
    enableLibraryProfiling = false;
  });
}
