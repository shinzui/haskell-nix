{ hself, haskellLib, pkgs, ... }:

let
  src = builtins.fetchGit {
    url = "https://github.com/shinzui/baikai";
    rev = "1a9fbaba74ce9e41ead6963c57e5a271c15c383a";
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
