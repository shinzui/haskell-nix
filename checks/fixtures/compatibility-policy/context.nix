{
  packageSet = "report-fixture";
  channel = "github";
  ghc = { version = "9.14.1"; derivation = "fixture-compiler"; };
  system = "aarch64-darwin";
  runtimeConfiguration = { name = "fixture-runtime"; generation = 1; };
  packages = {
    kioku-core = {
      version = "0.8.0.2";
      sourceIdentity = "fixture-kioku-source";
      metadataIdentity = "fixture-kioku-metadata";
      derivation = "fixture-kioku-before-repair";
      profiles = [ "legacy-first-party-v1" ];
      generated = [ "generated-first-party" ];
    };
    cborg-json = {
      version = "0.2.6.0";
      sourceIdentity = "fixture-cborg-source";
      metadataIdentity = "fixture-cborg-revision";
      derivation = "fixture-cborg-before-repair";
    };
  };
}
