# crypton-x509 1.9.0 — Hackage pin.
# nixpkgs' 1.7.x still derives memory-based instances; 1.9.0 matches
# crypton 1.1.x + ram.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (hself.callHackageDirect {
  pkg = "crypton-x509";
  ver = "1.9.0";
  sha256 = "179mrn79kyk6srf6k38q5vls894d0bmcvg56n3j45vrqd0r9kwyr";
} {})
