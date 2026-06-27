# keiro - shinzui/keiro release source.
{ hself, haskellLib, pkgs, ... }:

let
  callKeiroPackage = name:
    haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix name (src + "/${name}") { }));

  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiro";
    rev = "67eb0b5cf2a2e1e4e7f5287f5fa275d394f30440";
    hash = "sha256-toN2KJEIhHWKEQgmfqVeALWKsNXVbgZadUfttGznPK4=";
  };
in
{
  keiro = callKeiroPackage "keiro";
  keiro-core = callKeiroPackage "keiro-core";
  keiro-dsl = callKeiroPackage "keiro-dsl";
  keiro-migrations = callKeiroPackage "keiro-migrations";
  keiro-pgmq = callKeiroPackage "keiro-pgmq";
  keiro-test-support = callKeiroPackage "keiro-test-support";
  jitsurei = callKeiroPackage "jitsurei";
}
