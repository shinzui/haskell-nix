# mori://well-typed/cborg/packages/serialise: released 0.2.6.1, metadata revision 5.
# Admit the GHC 9.14 boot base/containers/time lines; retain every other bound.
{ pkg, lib, haskellLib, hself, ... }:
if !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        substituteInPlace serialise.cabal \
          --replace-fail 'base                    >= 4.11    && < 4.22' 'base                    >= 4.11    && < 4.23' \
          --replace-fail 'containers              >= 0.5     && < 0.8' 'containers              >= 0.5     && < 0.9' \
          --replace-fail 'time                  >= 1.5     && < 1.15' 'time                  >= 1.5     && < 1.16'
      '';
    })
    pkg
