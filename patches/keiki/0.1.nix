# keiki - shinzui/keiki release source.
# Keep the whole event-sourcing stack (keiro, kioku, rei) on one keiki revision.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiki";
    rev = "bc987f46393b604c335f034385b4c3c1ad118074";
    hash = "sha256-VPLtEAvJC7QiVDI0NYC66Q3gN8m8pGbRi9LFfxFfVHE=";
  };
in
{
  keiki = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki" src { }));
  keiki-codec-json = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki-codec-json" (src + "/keiki-codec-json") { }));
}
