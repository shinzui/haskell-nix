{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "baikai";
    rev = "2d5bf2c0bfa43b57f0100d6467dfcb7e4c30a915";
    hash = "sha256-RQ8wf/MfJ95rl5QpEUu48HmjCFc5u9tpGFiHIVm/FAU=";
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
