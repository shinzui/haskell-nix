# Retained fixes owned by mori://shinzui/hw-kafka-client and
# mori://shinzui/hw-kafka-streamly. Both source channels keep these exceptions.
name:
{ hself, haskellLib, pkgs, ... }:
let
  sources = builtins.fromJSON (builtins.readFile ../../config/runtime-kafka-sources.json);
  selected = sources.${name};
  source = pkgs.fetchFromGitHub { inherit (selected) owner repo rev hash; };
  packageSource = if selected.subdirectory == "." then source else source + "/${selected.subdirectory}";
  arguments = pkgs.lib.optionalAttrs (name == "hw-kafka-client") { rdkafka = pkgs.rdkafka; };
in
haskellLib.dontCheck (haskellLib.overrideCabal
  (drv: {
    passthru = (drv.passthru or { }) // {
      cohortSourceOrigin = { inherit source; inherit (selected) subdirectory; };
    };
  })
  (hself.callCabal2nix name packageSource arguments))
