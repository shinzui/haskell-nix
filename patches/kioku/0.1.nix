# kioku - shinzui/kioku release source.
{ hself, haskellLib, pkgs, ... }:

let
  callKiokuPackage = name:
    haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix name (src + "/${name}") { }));

  src = pkgs.fetchgit {
    url = "https://github.com/shinzui/kioku";
    rev = "4c886d4aa5723a5a5c53c3fb745633b10131a4b4";
    hash = "sha256-PE5Sc5v9nosXzkmPJiW8Z0z4PXes9c1/trATdi1DEqM=";
  };
in
{
  kioku-api = callKiokuPackage "kioku-api";
  kioku-cli = haskellLib.disableLibraryProfiling (callKiokuPackage "kioku-cli");
  kioku-core = haskellLib.disableLibraryProfiling (callKiokuPackage "kioku-core");
  kioku-migrations = callKiokuPackage "kioku-migrations";
}
