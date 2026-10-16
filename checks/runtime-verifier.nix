# Reuse scenarios from mori://shinzui/keiro-runtime-kenshou (source URI pending).
{ lib, pkgs, mkRuntimePackageSet, channelRevision, channel ? "github" }:
let
  source = builtins.fetchTree {
    type = "github";
    owner = "shinzui";
    repo = "keiro-runtime-kenshou";
    rev = "a1648293443ad88ff1695ed800ff44c99993574e";
    narHash = "sha256-69/e3WcOkVVyXEB6EFxDZ6YtODN6HJ1xwFuv0VXKI9M=";
  };
  # Admit the exact new cohort in the verification project, retaining bound checks.
  admittedSource = pkgs.applyPatches {
    name = "kenshou-retained-runtime-source";
    src = source.outPath;
    patches = [ ./fixtures/runtime-verifier-cohort-bounds.patch ];
  };
  selected = mkRuntimePackageSet {
    runtime = "keiro-runtime";
    generation = 1;
    inherit channel;
    applicationSelections = {
      kioku = 8;
      okf = 1;
      openapi-hs = 1;
      relay-pagination = 3;
      servant-openapi-hs = 1;
      shikumi-baikai = 9;
    };
  };
  packageSource = name:
    if name == "kenshou-kafka" then
      pkgs.applyPatches
        {
          name = "kenshou-kafka-retained-ack-api";
          src = admittedSource + "/${name}";
          patches = [ ./fixtures/runtime-verifier-kafka-ack.patch ];
        } else if builtins.elem name [ "kenshou-kiroku" "kenshou-shibuya" "kenshou-pgmq" "kenshou-keiro" ] then
      pkgs.applyPatches
        {
          name = "${name}-effectful-2.7";
          src = admittedSource + "/${name}";
          patches = lib.optional (name != "kenshou-keiro") (./fixtures + "/runtime-verifier-${name}-effectful.patch")
            ++ lib.optional (builtins.elem name [ "kenshou-kiroku" "kenshou-keiro" ]) (./fixtures + "/runtime-verifier-${name}-typed-api.patch");
        } else admittedSource + "/${name}";
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
        (hself.callCabal2nix name (packageSource name) { }))) // {
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
  profile = builtins.fromJSON (builtins.readFile (../cabal/runtimes/keiro-runtime/1 + "/${channel}-sources.json"));
  component = name:
    let
      package = profile.${name};
      origin = (builtins.head package.identities)."pkg-src";
      pinned = origin."source-repo" or null;
      root = selected.metadata.definition.roots.${name} or null;
    in
    {
      id = name;
      moriUri = if root != null then root.project else selected.metadata.definition.sourceProjects.${name};
      source = if pinned == null then { type = "hackage"; } else {
        type = "git";
        location = pinned.location;
        rev = pinned.tag;
      };
      packages = [ ({ inherit name; version = package.version; } // lib.optionalAttrs (pinned != null) { subdir = pinned.subdir or null; }) ];
    };
  descriptor = {
    name = "keiro-runtime-1";
    indexState = selected.metadata.indexState;
    components = map component (selected.metadata.roots ++ [ "dhall" ]);
  };
  # mori://shinzui/keiro-runtime-kenshou, project-relative nix/kenshou/identity.nix
  # (artifact-level source URI pending).
  identity = import (source.outPath + "/nix/kenshou/identity.nix") {
    inherit pkgs descriptor;
    hp = scope;
    cohort = descriptor.name;
    variant = "retained-runtime";
    localNames = names;
    inputs = {
      nixpkgs.rev = selected.metadata.nixpkgsRevision;
      haskell-nix.rev = channelRevision;
    };
    lock = {
      descriptorSha256 = builtins.hashString "sha256" (builtins.toJSON descriptor);
      packages = lib.mapAttrs
        (_: package: {
          tarballSha256 = (builtins.head package.identities)."pkg-src-sha256" or null;
        })
        profile;
    };
  };
in
assert selected.validateApplicationScope pkgs scope;
pkgs.symlinkJoin {
  name = "keiro-runtime-verifier";
  paths = [ scope.kenshou-cli ];
  meta.mainProgram = "kenshou";
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/kenshou" \
      --set KENSHOU_COHORT_IDENTITY ${identity.file}
  '';
  passthru = {
    cohortIdentity = identity.value;
    inherit descriptor;
    executable = scope.kenshou-cli;
  };
}
