# keiki - shinzui/keiki release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiki";
    rev = "869253ab49e2380bcc4556d6d6332913ff0ef52c";
    hash = "sha256-vBFnwKuvH3ae4KrQyAooufJJWHSsb4I0LcWDY8mWld0=";
  };
in
{
  keiki = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki" src { }));
  keiki-codec-json = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki-codec-json" (src + "/keiki-codec-json") { }));
}
