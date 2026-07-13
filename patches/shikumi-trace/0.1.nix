{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shikumi";
    rev = "0df4d85928c79cbfe78d7880a263fc0b9696ddc2";
    hash = "sha256-NhsJUfH8Zw0VHL9xZQUGJOJ1CQhibvi9BCuqULEUrbs=";
  };
in
haskellLib.dontCheck (
  haskellLib.doJailbreak (hself.callCabal2nix "shikumi-trace" (src + "/shikumi-trace") { })
)
