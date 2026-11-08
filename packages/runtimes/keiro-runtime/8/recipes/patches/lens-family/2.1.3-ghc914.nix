# Locally verified released-source compatibility, not upstream endorsement.
# mori://roconnor/lens-family, core/lens-family-core.cabal and lens-family.cabal;
# artifact-level URIs pending. Hackage and Darcs HEAD still exclude containers 0.8.
# Both released libraries compile; ten container optics smoke assertions pass.
# Retire when an admitting upstream release/revision is selected.
{ name, sha256 }:
{ pkg, lib, haskellLib, hself, ... }:
if !((import ../../lib/compatibilityEntryApplies.nix { inherit lib; }) "legacy-${name}-v1" {
  version = pkg.version;
  compiler = hself.ghc.version;
})
then pkg
else
  haskellLib.overrideCabal
    (drv: {
      postPatch = (drv.postPatch or "") + ''
        echo '${sha256}  ${name}.cabal' | sha256sum --check
        substituteInPlace ${name}.cabal --replace-fail '< 0.8' '< 0.9'
      '';
    })
    pkg
