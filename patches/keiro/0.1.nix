# keiro - shinzui/keiro release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiro";
    rev = "94c85e2a3ccbdb1adb07fcb5a7ee57b964802a2f";
    hash = "sha256-Hwspz8606mfbWdEYEOW1rS2sZv5gIUGFG1wedVpOeT0=";
  };
in
{
  keiro = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro" (src + "/keiro") { }));
  keiro-core = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-core" (src + "/keiro-core") { }));
  keiro-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-migrations" (src + "/keiro-migrations") { }));
  keiro-test-support = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-test-support" (src + "/keiro-test-support") { }));
  jitsurei = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "jitsurei" (src + "/jitsurei") { }));
}
