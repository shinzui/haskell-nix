# shibuya — from shinzui/shibuya monorepo.
{ hself, haskellLib, pkgs, ... }:

let
  callShibuyaPackage = name:
    haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix name (src + "/${name}") { }));

  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "shibuya";
    rev = "3f276ee190e563fddb0bc81e01d62a96a1b31715";
    hash = "sha256-me2v551ggAMtSI6NTy0OoimHWUVV5bzF7OsADV0fmG4=";
  };
in
{
  shibuya-core = callShibuyaPackage "shibuya-core";
  shibuya-example = callShibuyaPackage "shibuya-example";
  shibuya-metrics = callShibuyaPackage "shibuya-metrics";
}
