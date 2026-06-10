{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "baikai";
    rev = "2d5bf2c0bfa43b57f0100d6467dfcb7e4c30a915";
    hash = "sha256-RQ8wf/MfJ95rl5QpEUu48HmjCFc5u9tpGFiHIVm/FAU=";
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
