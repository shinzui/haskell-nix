{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "baikai";
    rev = "1a9fbaba74ce9e41ead6963c57e5a271c15c383a";
    hash = "sha256-76SlqTd83pIoEMmlJnYkbZ60AmxAcHeWNHWIJP0N4/0=";
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
