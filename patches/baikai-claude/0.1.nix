{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "baikai";
    rev = "e47a02ba740945e5aacf545b98c9ce81d2c26c4b";
    hash = "sha256-sGko8ZEBYYLT+MRNmLYAixTou4ezuRQ7sNJKyK2SDWE=";
  };

  stageRootFiles = drv: {
    prePatch = (drv.prePatch or "") + ''
      cp ${src}/CHANGELOG.md ../CHANGELOG.md
      cp ${src}/LICENSE ../LICENSE
    '';
  };
in
haskellLib.dontCheck (
  haskellLib.overrideCabal stageRootFiles
    (haskellLib.doJailbreak (hself.callCabal2nix "baikai-claude" (src + "/baikai-claude") { }))
)
