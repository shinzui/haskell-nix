# pgmq-core 0.1.2.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-core";
  ver = "0.1.2.0";
  sha256 = "sha256-tWoU7cQoi8ZoxRef7XkyS2rPR0Y1G4Xw4yKKZpp7jGk=";
} {}))
