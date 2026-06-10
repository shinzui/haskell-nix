{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shikumi";
    rev = "b12174dd1c4306f7af4c79fd8c69a6ca87b43917";
    hash = "sha256-MMAURQjACef3O0sRLPJ77AmcQ4P7y+hqrcIrXlecjj8=";
  };
in
haskellLib.dontCheck (
  haskellLib.doJailbreak (hself.callCabal2nix "shikumi" (src + "/shikumi") { })
)
