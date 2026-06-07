# keiro - shinzui/keiro release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiro";
    rev = "8dfc1ccc5e0fc0cb885f490c298a8bdfd8fc60ea";
    hash = "sha256-bVFYTtGUDtNBNH3WGrM/uXPGNw38OonAzmUNePbWXrc=";
  };
in
{
  keiro = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro" (src + "/keiro") { }));
  keiro-core = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-core" (src + "/keiro-core") { }));
  keiro-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-migrations" (src + "/keiro-migrations") { }));
  keiro-test-support = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-test-support" (src + "/keiro-test-support") { }));
  jitsurei = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "jitsurei" (src + "/jitsurei") { }));
}
