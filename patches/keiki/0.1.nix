# keiki - shinzui/keiki release source.
# Pinned to 1f7d18f (EP-52), the tag rei and the rest of the keiro stack are
# built against. NOTE: keiki 869253a (EP-53 "structural re-indexing") makes a
# breaking change to `Term` (adds a `[Keiki.Core.Slot]` type parameter); pinning
# it here breaks every consumer not yet updated for EP-53. Keep keiki, keiro,
# kiroku and consumers on one coordinated keiki revision.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiki";
    rev = "1f7d18f2180dfbf2993dc842182995a5d44560e7";
    hash = "sha256-3JuBxejHpmfG3zhjbg33dRek4L8t4ImGUDPpT2OdxzU=";
  };
in
{
  keiki = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki" src { }));
  keiki-codec-json = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki-codec-json" (src + "/keiki-codec-json") { }));
}
