# keiro - shinzui/keiro release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiro";
    rev = "102b1e82e179281bdffebc59bde9104d8795bae3";
    hash = "sha256-SsMOrdNncqRjeRCP+UCBd0+HScgVClMXy5EZlm8SjE0=";
  };
in
{
  keiro = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro" src { }));
  keiro-core = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-core" (src + "/keiro-core") { }));
  keiro-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiro-migrations" (src + "/keiro-migrations") { }));
}
