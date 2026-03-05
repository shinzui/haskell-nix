# pgmq-effectful 0.1.2.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "pgmq-effectful";
  ver = "0.1.2.0";
  sha256 = "sha256-AcdDkpyBLUqEJXdyivQZGbOH0iNWkZ0DmyFQfA+/1WI=";
} {}))
