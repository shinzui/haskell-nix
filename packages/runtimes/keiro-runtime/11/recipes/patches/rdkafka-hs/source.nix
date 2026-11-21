# Shoko's <1.1 binding is owned by mori://shinzui/rdkafka-hs/packages/rdkafka-hs.
# The v1.0.0.1 tag is immutable; the shared cohort and hw-kafka pins are independent.
{ hself, haskellLib, pkgs, ... }:
let
  source = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "rdkafka-hs";
    rev = "45d9e21ad3c72b56c482173e17ca3fa2bd8b1bc7";
    hash = "sha256-lno5sy1FDVLTzHeunuUmnbqNAMGGrFymWyJg/5KgwuM=";
  };
in
haskellLib.dontCheck (haskellLib.overrideCabal
  (drv: {
    passthru = (drv.passthru or { }) // {
      cohortSourceOrigin = { inherit source; subdirectory = "."; };
    };
  })
  (hself.callCabal2nix "rdkafka-hs" source { rdkafka = pkgs.rdkafka; }))
