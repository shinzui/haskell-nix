{ pkgs, scope }:
pkgs.runCommand "serialise-${scope.ghc.version}-compatibility"
{
  nativeBuildInputs = [ (scope.ghcWithPackages (packages: [ packages.serialise packages.containers packages.time ])) ];
}
  ''
    ghc -odir . -hidir . -o compatibility ${./fixtures/serialise/Compatibility.hs}
    ./compatibility
    touch "$out"
  ''
