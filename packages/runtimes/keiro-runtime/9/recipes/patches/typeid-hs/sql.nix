# Source pin: not on Hackage; the generated version layer does not own it.
{ hself, haskellLib, pkgs, ... }@args:
let source = import ./source.nix args;
in haskellLib.dontCheck (haskellLib.doJailbreak (haskellLib.overrideCabal
  (drv: {
    passthru = (drv.passthru or { }) // {
      cohortSourceOrigin = { inherit source; subdirectory = "typeid-hs-sql"; };
    };
  })
  (hself.callCabal2nix "typeid-hs-sql" "${source}/typeid-hs-sql" { })))
