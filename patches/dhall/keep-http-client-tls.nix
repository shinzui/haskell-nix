# dhall — keep the `use-http-client-tls` manual flag ON, and relax the bound
# that made disabling it tempting.
#
# The flag is what compiles `Dhall.Import.HTTP` against a TLS-capable manager.
# With it OFF, dhall still builds and still accepts `https://` imports, but
# every remote fetch throws `TlsNotSupported` at runtime — silently, and only
# on a cache miss, because a hash-pinned import already in `~/.cache/dhall`
# never reaches the network. Any consumer resolving a pinned remote import
# (mori and mina both resolve published okf-profiles profiles this way) is
# broken by that, and looks fine until someone publishes a new version.
#
# Upstream pins `http-client-tls >= 0.2.0 && < 0.4` inside
# `if flag(use-http-client-tls)`, and this package set ships 0.4.x.
# `doJailbreak` does NOT fix it: jailbreak-cabal leaves bounds inside
# conditional blocks alone, so configure still dies with
# "missing or private dependencies: http-client-tls >=0.2.0 && <0.4".
# Rewrite the bound to < 0.5, which is exactly what dhall-haskell PR #2719 did
# upstream, and which mori's cabal.project already builds against by pinning
# that commit (dhall-lang/dhall-haskell 03b40e85). Only the bound was wrong —
# the 0.4 API is compatible, and http-client-tls is already a build input of
# the nixpkgs derivation either way.
{ pkg, haskellLib, ... }:

haskellLib.overrideCabal
  (drv: {
    postPatch = (drv.postPatch or "") + ''
      sed -i -E 's/(http-client-tls[[:space:]]+>=[[:space:]]*0\.2\.0[[:space:]]*&&[[:space:]]*<[[:space:]]*)0\.4/\10.5/' dhall.cabal
      grep -q 'http-client-tls.*< *0\.5' dhall.cabal || {
        echo "dhall/keep-http-client-tls.nix: http-client-tls bound not found in dhall.cabal;" >&2
        echo "upstream changed the constraint — update this patch." >&2
        exit 1
      }
    '';
  })
  pkg
