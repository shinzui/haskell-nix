{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "baikai";
    rev = "0d23a260d5b3cb0c1c6f3d4a29049188c109607f";
    hash = "sha256-buhiPt6zqEayt35/nYx+mEa6TreGnHgi/5qEaa5P6A4=";
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
    (haskellLib.doJailbreak (hself.callCabal2nix "baikai" (src + "/baikai") { }))
)
