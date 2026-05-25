# kiroku - shinzui/kiroku release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "kiroku";
    rev = "36ae4318b7701918d511eea404f6e7f3de21be22";
    hash = "sha256-wbAuNujrTl/JVIKCw4tWoyMIH8YdovM3wpIK8H8zq94=";
  };
in
{
  kiroku-store = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store" (src + "/kiroku-store") { }));
  kiroku-store-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store-migrations" (src + "/kiroku-store-migrations") { }));
  kiroku-test-support = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-test-support" (src + "/kiroku-test-support") { }));
  shibuya-kiroku-adapter = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-kiroku-adapter" (src + "/shibuya-kiroku-adapter") { }));
}
