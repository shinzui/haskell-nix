# shikumi-trace-otel 0.1.1.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "shikumi-trace-otel";
  ver = "0.1.1.0";
  sha256 = "sha256-zXv2Hx2qPAIj9IBiPeuUbxir9ZEDC+S9tDQBBqW3GKo=";
} {}))
