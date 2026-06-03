# kiroku - shinzui/kiroku release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "kiroku";
    rev = "0a39598a4a9614528316f6c9c63842cc1d55d313";
    hash = "sha256-Q709y+KFw2Qemvchc4fu/sucC5h23Xm48CMv9Z1AH4Y=";
  };
in
{
  kiroku-store = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store" (src + "/kiroku-store") { }));
  kiroku-store-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store-migrations" (src + "/kiroku-store-migrations") { }));
  kiroku-test-support = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-test-support" (src + "/kiroku-test-support") { }));
  shibuya-kiroku-adapter = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-kiroku-adapter" (src + "/shibuya-kiroku-adapter") { }));
}
