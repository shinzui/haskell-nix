{ lib }:
let
  fixtures = ./fixtures/first-party;
  readJson = name: builtins.fromJSON (builtins.readFile (fixtures + "/${name}"));
  mkRegistries = import ../lib/mkFirstPartyRegistries.nix { inherit lib; };
  config = readJson "valid-config.json";
  lock = readJson "valid-lock.json";
  # Registry construction must validate metadata without evaluating source trees.
  sources.example-src = throw "unit tests must not fetch a source";
  registries = mkRegistries { inherit config lock sources; };
  invalidConfigs = [
    "invalid-config-duplicate-family.json"
    "invalid-config-unknown-override-key.json"
  ];
  invalidLocks = [
    "invalid-lock-absolute-path.json"
    "invalid-lock-parent-path.json"
    "invalid-lock-dot-segment-path.json"
    "invalid-lock-mismatched-family.json"
    "invalid-lock-mismatched-input.json"
    "invalid-lock-malformed-version.json"
    "invalid-lock-malformed-hash.json"
    "invalid-lock-duplicate-package.json"
  ];
  rejects = candidate: {
    expr = (builtins.tryEval (builtins.deepSeq
      {
        github = builtins.attrNames candidate.github;
        hackage = builtins.attrNames candidate.hackage;
      }
      true)).success;
    expected = false;
  };
in
{
  testGithubInventoryWithoutFetching = {
    expr = builtins.attrNames registries.github;
    expected = [ "example-core" "example-dev" "example-special" ];
  };
  testHackageOmitsUnpublishedWithoutFetching = {
    expr = builtins.attrNames registries.hackage;
    expected = [ "example-core" "example-special" ];
  };
  testRepositoryRootPackage = {
    expr = builtins.attrNames (mkRegistries {
      config = readJson "valid-root-config.json";
      lock = readJson "valid-root-lock.json";
      sources.example-root-src = throw "root metadata must not force sources";
    }).github;
    expected = [ "example-root" ];
  };
} // lib.listToAttrs (map
  (name: {
    name = "testReject-${name}";
    value = rejects (mkRegistries {
      inherit lock sources;
      config = readJson name;
    });
  })
  invalidConfigs) // lib.listToAttrs (map
  (name: {
    name = "testReject-${name}";
    value = rejects (mkRegistries {
      inherit config sources;
      lock = readJson name;
    });
  })
  invalidLocks)
