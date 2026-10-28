# Mirror the three verified exceptions owned by mori://shinzui/mori-rei-app
# in cabal/common.config. Preserve the released source and all other bounds.
{ pkg, haskellLib, ... }:
haskellLib.overrideCabal
  (drv: {
    postPatch = (drv.postPatch or "") + ''
      substituteInPlace dhall-json.cabal \
        --replace-fail 'aeson                     >= 1.4.6.0   && < 2.2' 'aeson                     >= 1.4.6.0   && < 2.3' \
        --replace-fail 'bytestring                                < 0.12' 'bytestring                                < 0.13' \
        --replace-fail 'text                      >= 0.11.1.0  && < 2.1' 'text                      >= 0.11.1.0  && < 2.2'
    '';
  })
  pkg
