# dhall — disable the `use-http-client-tls` manual flag.
#
# Upstream dhall pins http-client-tls <0.4 when the flag is on. Cabal disables
# it via `dhall -use-http-client-tls`; on nix we flip the same flag so dhall
# compiles against http-client-tls 0.4.x.
{ pkg, haskellLib, ... }:

haskellLib.appendConfigureFlag "-f-use-http-client-tls" pkg
