# Mirror cabal/common.config's narrow, verified compatibility exception for
# mori://basvandijk/monad-control/packages/monad-control. Keep every other bound.
{ pkg, haskellLib, ... }:
haskellLib.overrideCabal
  (drv: {
    postPatch = (drv.postPatch or "") + ''
      substituteInPlace monad-control.cabal \
        --replace-fail 'transformers-compat  >=0.3   && <0.8' 'transformers-compat  >=0.3   && <0.9'
    '';
  })
  pkg
