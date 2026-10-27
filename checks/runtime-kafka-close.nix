# Execute the maintained upstream scoped-close regression against retained libraries.
# Source project: mori://shinzui/hw-kafka-streamly (source artifact URI pending).
{ lib, pkgs, mkRuntimePackageSet }:
let
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
    } // import ../lib/catalogApplicationComplements.nix;
  };
  scope = selected.mkApplicationScope pkgs (_: _: { });
  specification = selected.metadata.components.hw-kafka-streamly.recipe;
  source = builtins.fetchTree {
    type = "github";
    inherit (specification) owner repo rev;
    narHash = specification.hash;
  };
  compiler = scope.ghcWithPackages (hs: [
    hs.hw-kafka-streamly
    hs.hw-kafka-client
    hs.streamly-core
    hs.tasty
    hs.tasty-hunit
  ]);
  main = pkgs.writeText "RuntimeKafkaClose.hs" ''
    module Main where
    import Kafka.Streamly.WithStreamTest qualified as Close
    import Test.Tasty (defaultMain)
    main :: IO ()
    main = defaultMain Close.tests
  '';
in
pkgs.runCommand "runtime-kafka-deterministic-close"
{
  nativeBuildInputs = [ compiler pkgs.coreutils ];
} ''
  ghc -threaded -XGHC2024 -XDataKinds -XDuplicateRecordFields \
    -XImportQualifiedPost -XLambdaCase -XNoFieldSelectors -XOverloadedRecordDot \
    -XOverloadedStrings -i${source.outPath}/hw-kafka-streamly/test \
    -outputdir . -o runtime-kafka-close ${main}
  set -o pipefail
  timeout 45 ./runtime-kafka-close --timeout 10s 2>&1 | tee "$out"
''
