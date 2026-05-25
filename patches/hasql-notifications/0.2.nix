# hasql-notifications - official diogob/hasql-notifications master (0.2.5.0).
#
# The Hackage release nixpkgs ships (0.2.4.0) only supports hasql < 1.10 and
# fails to compile against the hasql 1.10 the keiro stack uses (Hasql.Connection
# / Hasql.Session no longer export withLibPQConnection / run / sql). Upstream
# master (0.2.5.0) targets `hasql >=1.10 && <1.11`, so build from there.
# doJailbreak relaxes any remaining bounds against the pinned package set;
# dontCheck skips the postgres-backed test suite.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "diogob";
    repo = "hasql-notifications";
    rev = "66112e10f81d9de612344db9d2b88d446d6a410f";
    hash = "sha256-gJVeuloNGWAVe3dTICLHVjFL7QwCwJQTaBVd8e+f9E4=";
  };
in
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "hasql-notifications" src { }))
