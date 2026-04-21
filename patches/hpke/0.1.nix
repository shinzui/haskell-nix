# hpke 0.1.0 — Hackage pin.
# nixpkgs' 0.0.0 still links against `memory`; 0.1.0 uses `ram` to match
# crypton 1.1.x.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "hpke";
  ver = "0.1.0";
  sha256 = "07fqz8j2rlf6mq36s9v988q4i9wzhwjd1s9s0rqld79f3xs6zdpd";
} {})
