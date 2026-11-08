# Source pin: not on Hackage; the generated version layer does not own it.
{ hself, haskellLib, pkgs, ... }@args:
let source = import ./source.nix args;
in haskellLib.dontCheck (haskellLib.doJailbreak (haskellLib.overrideCabal
  (drv: {
    passthru = (drv.passthru or { }) // {
      cohortSourceOrigin = { inherit source; subdirectory = "typeid-hs-pg-migrate"; };
    };
  })
  (hself.callCabal2nix "typeid-hs-pg-migrate" "${source}/typeid-hs-pg-migrate" { })))
