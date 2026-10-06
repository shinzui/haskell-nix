# Consumer-side compiler workaround, verified against the unchanged released source.
# mori://MMZK1526/mmzk-typeid/upstream-issues/mmzk-typeid-kindid-ghc-9-12-4-profiling-coercionkind-panic
# GHC 9.14.1 also panics without profiling in Kioku.Distill.L1.
# Retire after a fixed compiler builds this source without the flag; future package
# versions/compiler releases do not inherit it. Coercion optimisation alone is disabled.
{ pkg, haskellLib, hself, ... }:
if pkg.version != "0.8.0.2" || hself.ghc.version != "9.14.1" then pkg
else
  haskellLib.overrideCabal
    (drv: {
      configureFlags = (drv.configureFlags or [ ]) ++ [ "--ghc-option=-fno-opt-coercion" ];
      postPatch = (drv.postPatch or "") + ''
        # All 36 source files, paths and bytes match both published 0.8.0.2 and
        # mori://shinzui/kioku at d93992ddeb7c888e4b6e45654e325e66ecb85ac3.
        # src/ artifact-level URIs are pending. Fail before configure on source drift.
        sourceManifestHash=$(find src -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
        test "$sourceManifestHash" = '524df9cc52fa48fc1c6326fc398070667ee9ad5d6490f8e42b7d88069b9af055'
        echo 'Verified Kioku 0.8.0.2 source for GHC 9.14.1 coercion workaround.'
      '';
    })
    pkg
