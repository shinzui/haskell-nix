# generic-lens-core 2.3.0.0: shared application selection.
# Version pin: plan 9's generated layer owns this version once it exists; keep only the build policy then.
{ hself, haskellLib, ... }:
haskellLib.dontCheck (hself.callHackageDirect { pkg = "generic-lens-core"; ver = "2.3.0.0"; sha256 = "sha256-Abntgf3UMhQed5gOc6sDoVilMc0FRRCh8VJCeoQfNRY="; } { })
