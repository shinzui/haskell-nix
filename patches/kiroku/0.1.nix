# kiroku - shinzui/kiroku release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "kiroku";
    rev = "97408c2047b634693879d1e9ebfffaeb261d476d";
    hash = "sha256-Jr11VXRP7Q9jx3SJ8LD2u788DfGJPDx8izVfR1Fb3sI=";
  };
in
{
  kiroku-store = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store" (src + "/kiroku-store") { }));
  kiroku-store-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store-migrations" (src + "/kiroku-store-migrations") { }));
  kiroku-test-support = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-test-support" (src + "/kiroku-test-support") { }));
  shibuya-kiroku-adapter = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-kiroku-adapter" (src + "/shibuya-kiroku-adapter") { }));
}
