# shikumi 0.3.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "shikumi";
  ver = "0.3.0.0";
  sha256 = "sha256-mqcwh3LVPFCMz4aT0b33wjgyIecrOCVLu1Ea7lu5fPg=";
} {}))
