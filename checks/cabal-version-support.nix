{ lib, pkgs, scopes }:
let
  versions = [ "3.14" "3.16" ];
  fixtures = lib.mapAttrs
    (_: scope: lib.genAttrs versions
      (version: scope.callCabal2nix "tiny" (./fixtures/cabal-version + "/${version}") { }))
    scopes;
  results = lib.mapAttrs
    (_: packages: lib.mapAttrs (_: package: package.drvPath) packages)
    fixtures;
in
builtins.deepSeq results (pkgs.runCommand "cabal-version-support"
{
  passthru = { inherit results; };
}
  ''
    # Parsing support belongs to cabal2nix; the build driver uses GHC's boot
    # Cabal 3.14, so build the admitted 3.14 fixture after forcing both parses.
    test -d ${fixtures.github."3.14"}
    touch "$out"
  '')
