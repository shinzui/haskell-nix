# Reuse scenarios from mori://shinzui/keiro-runtime-kenshou (source URI pending).
{ lib, pkgs, mkRuntimePackageSet }:
let
  source = builtins.fetchTree {
    type = "github";
    owner = "shinzui";
    repo = "keiro-runtime-kenshou";
    rev = "a1648293443ad88ff1695ed800ff44c99993574e";
    narHash = "sha256-69/e3WcOkVVyXEB6EFxDZ6YtODN6HJ1xwFuv0VXKI9M=";
  };
  selected = mkRuntimePackageSet {
    runtime = "keiro-runtime";
    generation = 1;
    applicationSelections = {
      kioku = 8;
      okf = 5;
      openapi-hs = 1;
      relay-pagination = 3;
      servant-openapi-hs = 1;
      shikumi-baikai = 9;
    };
  };
  names = map (suffix: "kenshou-${suffix}") [
    "check"
    "cli"
    "core"
    "diagnose"
    "evidence"
    "kafka"
    "keiro"
    "kiroku"
    "measure"
    "pgmq"
    "remote"
    "runtime"
    "shibuya"
    "telemetry"
  ];
  scope = pkgs.haskell.packages.ghc9124.override {
    overrides = lib.composeExtensions
      (selected.haskellExtension pkgs.haskell.lib.compose pkgs)
      (hself: _: (lib.genAttrs names (name: pkgs.haskell.lib.compose.dontCheck
        (hself.callCabal2nix name (source.outPath + "/${name}") { }))) // {
        # Verification-only dependency, outside the runtime ownership closure.
        hs-opentelemetry-exporter-prometheus = hself.callHackageDirect
          {
            pkg = "hs-opentelemetry-exporter-prometheus";
            ver = "1.0.0.0";
            sha256 = "sha256-6yCjTQ/1hriFD2n3zprJDHKBsjLAD5jzlSfOuN/3ej0=";
          }
          { };
      });
  };
in
assert selected.validateApplicationScope pkgs scope;
scope.kenshou-cli
