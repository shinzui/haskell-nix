# mori://dhall-lang/dhall-haskell: the exact cohort source already admits TLS 0.4.
# Keep HTTPS imports working even on a cache miss. The intentional difference
# from Cabal's TLS-disabled solve is owned in cabal/cohort-nix-policy.json.
{ pkg, haskellLib, ... }:
haskellLib.overrideCabal
  (drv: {
    configureFlags = (drv.configureFlags or [ ]) ++ [ "-fuse-http-client-tls" ];
    postPatch = (drv.postPatch or "") + ''
      grep -q 'http-client-tls.*< *0\.5' dhall.cabal || {
        echo "dhall: selected source no longer admits the TLS cohort" >&2
        exit 1
      }
    '';
  })
  pkg
