# hasql-pool 1.4.1 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "hasql-pool";
  ver = "1.4.1";
  sha256 = "sha256-ypgn5F9WhFozOGRvT55xGTRFwviDdTJfn/dJSWUzviI=";
} {}))
