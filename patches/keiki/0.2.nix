# keiki - shinzui/keiki 0.2 release source.
# Keep the whole event-sourcing stack (keiro, kioku, rei) on one keiki revision.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiki";
    rev = "755a01de8febab5db81537b5235a1ab319017c33";
    hash = "sha256-ccrKs5D82pMQn9GARxeKuLS7t7XnUj7BbM6dMpW+Pco=";
  };
in
{
  keiki = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki" src { }));
  keiki-codec-json = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki-codec-json" (src + "/keiki-codec-json") { }));
}
