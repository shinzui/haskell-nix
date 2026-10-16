# mori://well-typed/cborg/packages/cborg: released source, metadata revision 3.
# Admit only the GHC 9.14 boot base/containers lines; preserve every other bound.
{ pkg, lib, haskellLib, hself, ... }:
if !lib.versionAtLeast hself.ghc.version "9.14"
  || !lib.versionOlder hself.ghc.version "9.15"
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        substituteInPlace cborg.cabal \
          --replace-fail 'base                    >= 4.11    && < 4.22' 'base                    >= 4.11    && < 4.23' \
          --replace-fail 'containers              >= 0.5     && < 0.8' 'containers              >= 0.5     && < 0.9'
      '';
    })
    pkg
