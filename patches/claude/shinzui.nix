{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "claude"
  (pkgs.fetchFromGitHub
    {
      owner = "shinzui";
      repo = "claude-project";
      rev = "60332ebb5686fa0a9ba2aa4ce9e582611cac4463";
      hash = "sha256-WDQRhEqhU6y73cPC+WWNBlpRFOORNrlCI2yQK6X6nZk=";
    } + "/claude")
{ }))
