# http-client-tls 0.4.0 — Hackage pin (paired with tls 2.3.1 + crypton 1.1.x).
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "http-client-tls";
  ver = "0.4.0";
  sha256 = "1qgwh3zip36pbjn7c5pn1l6zv044d6l77mnariz66bdhwy9hrx1s";
} {}))
