# The released implementation uses transformers' ExceptT/MaybeT API unchanged
# by transformers-compat 0.8; relax only that compatibility-shim upper bound.
{ pkg, haskellLib, ... }:
haskellLib.overrideCabal
  (drv: {
    postPatch = (drv.postPatch or "") + ''
      sed -i -E 's/(transformers-compat[[:space:]]+>=[[:space:]]*0\.4[[:space:]]*&&[[:space:]]*<[[:space:]]*)0\.8/\10.9/' errors.cabal
      grep -Eq 'transformers-compat.*< *0\.9' errors.cabal
    '';
  })
  pkg
