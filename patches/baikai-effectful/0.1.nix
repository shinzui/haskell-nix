{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "baikai";
    rev = "5f527d8534074875ac02e47ba61d6755b82aca75";
    hash = "sha256-5DHBZzhmPLEcH0XjbrIdHLT+BAgytpBspk//SyrnkZ8=";
  };

  # baikai-effectful/LICENSE is a symlink to ../LICENSE (the repo root LICENSE),
  # which is not present when only the subpackage dir is staged. Materialise the
  # symlink target so `license-file: LICENSE` resolves, mirroring the other baikai
  # patches.
  stageRootFiles = drv: {
    prePatch = (drv.prePatch or "") + ''
      cp ${src}/LICENSE ../LICENSE
    '';
  };
in
haskellLib.dontCheck (
  haskellLib.overrideCabal stageRootFiles
    (haskellLib.doJailbreak (hself.callCabal2nix "baikai-effectful" (src + "/baikai-effectful") { }))
)
