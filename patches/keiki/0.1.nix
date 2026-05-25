# keiki - shinzui/keiki release source.
# Pinned to 869253a (EP-53 "structural re-indexing"): `Term`/`OutFields` gained an
# `ifs :: [Keiki.Core.Slot]` type parameter for sound structural replay. Consumers with
# explicit `Term`/`OutFields` annotations must add the parameter; record-syntax /
# deriveAggregate / reg authoring is unaffected. keiro is on EP-53; rei adopted it (its
# 10 explicit `Term` sigs gained a free `ifs`). Keep the whole stack on one keiki revision.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "keiki";
    rev = "869253ab49e2380bcc4556d6d6332913ff0ef52c";
    hash = "sha256-vBFnwKuvH3ae4KrQyAooufJJWHSsb4I0LcWDY8mWld0=";
  };
in
{
  keiki = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki" src { }));
  keiki-codec-json = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "keiki-codec-json" (src + "/keiki-codec-json") { }));
}
