{ hself, haskellLib, pkgs, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "openai"
  (pkgs.fetchFromGitHub
    {
      owner = "shinzui";
      repo = "openai-project";
      rev = "ffb38dbd714e23bc5a9a11555dd9a34da4ffe5df";
      hash = "sha256-Q8VcGBNnHiZ8GfM3v9749CndRcx/Wo97YLfPSmJLv2I=";
    } + "/openai")
{ }))
