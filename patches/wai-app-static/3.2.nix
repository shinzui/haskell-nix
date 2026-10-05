# wai-app-static 3.2.1: shared application selection.
# Version pin: plan 9's generated layer owns this version once it exists; keep only the build policy then.
{ hself, haskellLib, ... }:
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect { pkg = "wai-app-static"; ver = "3.2.1"; sha256 = "sha256-HQP76brA2MwBVipRs2ZstY59nUMhzfJkw90Kaep2o9I="; } { }))
