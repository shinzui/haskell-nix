{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "baikai";
    rev = "5f527d8534074875ac02e47ba61d6755b82aca75";
    hash = "sha256-5DHBZzhmPLEcH0XjbrIdHLT+BAgytpBspk//SyrnkZ8=";
  };

  # baikai-trace-otel/LICENSE is a symlink to the repo-root ../LICENSE, which is
  # outside the package subdir callCabal2nix builds in. Stage it (mirrors the
  # baikai / baikai-claude patches).
  stageRootFiles = drv: {
    prePatch = (drv.prePatch or "") + ''
      cp ${src}/CHANGELOG.md ../CHANGELOG.md
      cp ${src}/LICENSE ../LICENSE
    '';
  };
in
haskellLib.dontCheck (
  haskellLib.overrideCabal stageRootFiles
    (haskellLib.doJailbreak (hself.callCabal2nix "baikai-trace-otel" (src + "/baikai-trace-otel") { }))
)
