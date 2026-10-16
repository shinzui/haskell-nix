# The CLI inherits the same KindID coercion panic as kioku-core.
# mori://MMZK1526/mmzk-typeid/upstream-issues/mmzk-typeid-kindid-ghc-9-12-4-profiling-coercionkind-panic
# Verified GHC 9.14.1 nonprofiled build: DemoSession also needs this supported flag.
# Retire when a fixed compiler builds the unchanged source without the flag.
# The additional 0.9.0.2 proof covers mori://shinzui/kioku, project-relative
# kioku-cli/src/ and kioku-cli/app/ (source-file artifact URIs pending), at c4bf956b5b00c899adde225e026484c3a1a44258.
{ pkg, haskellLib, hself, ... }:
if hself.ghc.version != "9.14.1" then pkg
else if pkg.version == "0.9.0.2" then
  haskellLib.overrideCabal
    (drv: {
      configureFlags = (drv.configureFlags or [ ]) ++ [ "--ghc-option=-fno-opt-coercion" ];
      postPatch = (drv.postPatch or "") + ''
        # All 14 src/app files match published 0.9.0.2 and
        # mori://shinzui/kioku at c4bf956b5b00c899adde225e026484c3a1a44258.
        # Source-file artifact URIs are pending. DemoSession repeats the panic.
        sourceManifestHash=$(find src app -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
        test "$sourceManifestHash" = '843f7b9593b93d2ccd0f4a00f47c8c64d6ce22543651063cfc3eb1acafca984b'
        echo 'Verified Kioku CLI 0.9.0.2 source for GHC 9.14.1 coercion workaround.'
      '';
    })
    pkg
else if pkg.version != "0.8.0.2" then pkg
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
