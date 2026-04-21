# ram 0.22.0 — Hackage pin (not yet in nixpkgs).
# crypton 1.1.x swapped `memory` for `ram`; downstreams need this to compile.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "ram";
  ver = "0.22.0";
  sha256 = "1mwg8gha1y2hvk7yf2kd9411ibqba0r9ach1ypg6yk5mxqrfgcv7";
} {})
