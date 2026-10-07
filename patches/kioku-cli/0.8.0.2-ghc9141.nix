# The CLI inherits the same KindID coercion panic as kioku-core.
# mori://MMZK1526/mmzk-typeid/upstream-issues/mmzk-typeid-kindid-ghc-9-12-4-profiling-coercionkind-panic
# Verified GHC 9.14.1 nonprofiled build: DemoSession also needs this supported flag.
# Retire when a fixed compiler builds the unchanged source without the flag.
{ pkg, haskellLib, hself, ... }:
if pkg.version != "0.8.0.2" || hself.ghc.version != "9.14.1" then pkg
else
  haskellLib.overrideCabal
    (drv: {
      configureFlags = (drv.configureFlags or [ ]) ++ [ "--ghc-option=-fno-opt-coercion" ];
      postPatch = (drv.postPatch or "") + ''
        # All 14 src/app files match published 0.8.0.2 and
        # mori://shinzui/kioku at d93992ddeb7c888e4b6e45654e325e66ecb85ac3,
        # kioku-cli/src/ and kioku-cli/app/ (source artifact URIs pending).
        sourceManifestHash=$(find src app -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
        test "$sourceManifestHash" = '4e6e34bc9816db4c9fe78fe38ecfbc07fbcb3e09a57f378cd9aa6a369403a298'
        echo 'Verified Kioku CLI 0.8.0.2 source for GHC 9.14.1 coercion workaround.'
      '';
    })
    pkg
