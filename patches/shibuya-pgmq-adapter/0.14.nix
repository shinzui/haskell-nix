# shibuya-pgmq-adapter 0.14.0.0 — pin from Hackage.
#
# keiro-pgmq 0.12.0.0 requires shibuya-pgmq-adapter ^>=0.14.0.0. Cabal bounds
# do not select versions under Nix, so the previous 0.12.0.0 pin was compiled
# against it anyway and failed: Shibuya.Adapter.Pgmq.Internal selects the
# visibilityTime field from a Maybe Pgmq.Message, which no longer typechecks
# against pgmq-core 0.5.0.0.
{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
{
  pkg = "shibuya-pgmq-adapter";
  ver = "0.14.0.0";
  sha256 = "sha256-qhUp+UkrlDgFTkE+ilCmUVKYlcg1yMpPDVoTJfRl894=";
}
{ }))
