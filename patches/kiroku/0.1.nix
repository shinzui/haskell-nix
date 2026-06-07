# kiroku - shinzui/kiroku release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "kiroku";
    rev = "90bd3bcd54e17c39b6162074342f8e3113538b74";
    hash = "sha256-27a4bfBfg+EdrsKRIFds56EGeIqs4j/81GhNGC5AkAA=";
  };
in
{
  kiroku-store = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store" (src + "/kiroku-store") { }));
  kiroku-store-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store-migrations" (src + "/kiroku-store-migrations") { }));
  kiroku-test-support = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-test-support" (src + "/kiroku-test-support") { }));
  shibuya-kiroku-adapter = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-kiroku-adapter" (src + "/shibuya-kiroku-adapter") { }));
}
