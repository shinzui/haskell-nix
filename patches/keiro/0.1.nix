# keiro - shinzui/keiro release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiro";
    rev = "638aab4e969221a686dc655e684e8c92b8d0be11";
    hash = "sha256-EKy35+ufjLCbU7bMwDX7vFKV1sz28RiYx18REzsdsdk=";
  };
in
{
  keiro = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro" src { }));
  keiro-core = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-core" (src + "/keiro-core") { }));
  keiro-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-migrations" (src + "/keiro-migrations") { }));
}
