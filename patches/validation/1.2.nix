# validation 1.2.2 — pin from Hackage.
#
# validation-1.2.0 removed `toEither` in favour of the `Data.Validation.either`
# iso. Consumers that use the new iso need 1.2.x; nixpkgs' ghc9122 set still
# ships 1.1.3.
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
  {
    pkg = "validation";
    ver = "1.2.2";
    sha256 = "sha256-KC1S6oQKHxcSoD/SealsGSzu9KX1/M14tfRsVse6zn4=";
  } { }))
