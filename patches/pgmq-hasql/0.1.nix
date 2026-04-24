# pgmq-hasql 0.2.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-hasql";
  ver = "0.2.0.0";
  sha256 = "sha256-BTB3LanG7EGlh+Ap6AxLLycUoXZMpGchRgDon7YzQ5Q=";
} {}))
