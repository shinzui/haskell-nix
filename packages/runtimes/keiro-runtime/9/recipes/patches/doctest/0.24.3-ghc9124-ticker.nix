# mori://sol/doctest, test/RunSpec.hs (source-file artifact URI pending).
# Retain the bootstrap tool and every test; normalize only GHC's known EINTR
# diagnostic in captured test output. Released library/executable code is intact.
{ pkg, lib, pkgs, hself, haskellLib, patchFile ? ./0.24.3-ghc9124-ticker.patch, ... }:
if !((import ../../lib/compatibilityEntryApplies.nix { inherit lib; }) "legacy-doctest-v1" {
  version = pkg.version;
  compiler = hself.ghc.version;
  system = pkgs.stdenv.hostPlatform.system;
})
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        echo '23f0224c088382bef245b77a261fbb153127ce58ccecdae3625db4f23c2a5e9d  test/RunSpec.hs' | sha256sum -c -
        patch -p1 < ${patchFile}
      '';
    })
    pkg
