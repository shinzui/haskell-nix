# servant-health 0.1.0.0: shared application selection.
# Version pin: plan 9's generated layer owns this version once it exists; keep only the build policy then.
{ hself, haskellLib, ... }:
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect { pkg = "servant-health"; ver = "0.1.0.0"; sha256 = "sha256-new4jAeDaP1kzFkN0SB4FwVObZwV1zp3SlddGa2VRLw="; } { }))
