# shikumi-trace 0.2.0.0 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "shikumi-trace";
  ver = "0.2.0.0";
  sha256 = "sha256-ob8bvV8UlUpbLbQ7jQuYS7HKuDARoz35w4+pJck3Vfk=";
} {}))
