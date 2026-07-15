# baikai-trace-otel 0.3.0.1 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "baikai-trace-otel";
  ver = "0.3.0.1";
  sha256 = "sha256-VecnPvDchP1RwfiuTDrklBFnQ3KNJXQ5OeOG2eGSZnw=";
} {}))
