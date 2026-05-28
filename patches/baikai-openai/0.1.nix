{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "baikai";
    rev = "72cb4034b61fe96fdadcebad1529351ec4b6f76f";
    hash = "sha256-RHk9BXKLpYY9fm/n2KTHdNnD0mmZ1tqkntmzInwYcoE=";
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
    (haskellLib.doJailbreak (hself.callCabal2nix "baikai-openai" (src + "/baikai-openai") { }))
)
