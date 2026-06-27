# kiroku - shinzui/kiroku release source.
{ hself, haskellLib, pkgs, ... }:

let
  callKirokuPackage = name:
    haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix name (src + "/${name}") { }));

  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "kiroku";
    rev = "9a52aa62380c28b0ec36eeb9b517f49e40900fd8";
    hash = "sha256-Lv/M6QgQjzCPNIz784DryoNFwIq1rz/2uoamiWtAW54=";
  };
in
{
  kiroku-cli = callKirokuPackage "kiroku-cli";
  kiroku-jitsurei = callKirokuPackage "kiroku-jitsurei";
  kiroku-metrics =
    haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nixWithOptions "kiroku-metrics" (src + "/kiroku-metrics") "-f-example" { }));
  kiroku-otel = callKirokuPackage "kiroku-otel";
  kiroku-store = callKirokuPackage "kiroku-store";
  kiroku-store-migrations = callKirokuPackage "kiroku-store-migrations";
  kiroku-test-support = callKirokuPackage "kiroku-test-support";
  shibuya-kiroku-adapter = callKirokuPackage "shibuya-kiroku-adapter";
}
