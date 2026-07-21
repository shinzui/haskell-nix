{ lib, pkgs, firstPartyRegistries }:

let
  fixtures = ./fixtures/first-party;
  readJson = path: builtins.fromJSON (builtins.readFile path);
  mkFirstPartyRegistries = import ../lib/mkFirstPartyRegistries.nix { inherit lib; };
  sources = { example-src = fixtures + "/source"; };

  config = readJson (fixtures + "/valid-config.json");
  lock = readJson (fixtures + "/valid-lock.json");
  registries = mkFirstPartyRegistries { inherit sources config lock; };

  # A family whose only package occupies the repository root, recorded as ".".
  rootRegistries = mkFirstPartyRegistries {
    sources = { example-root-src = fixtures + "/root-source"; };
    config = readJson (fixtures + "/valid-root-config.json");
    lock = readJson (fixtures + "/valid-root-lock.json");
  };

  githubNames = builtins.attrNames registries.github;
  hackageNames = builtins.attrNames registries.hackage;

  kiokuPackageNames = [
    "kioku-api"
    "kioku-cli"
    "kioku-core"
    "kioku-migrate"
    "kioku-migrations"
  ];

  kiokuGithubNames = builtins.filter
    (name: builtins.hasAttr name firstPartyRegistries.github)
    kiokuPackageNames;
  kiokuHackageNames = builtins.filter
    (name: builtins.hasAttr name firstPartyRegistries.hackage)
    kiokuPackageNames;

  applyGithubEntry = registry: packageName: compiler:
    let
      patch = (builtins.head registry.${packageName}).patch;
      hself = pkgs.haskell.packages.${compiler};
    in
    patch {
      pkg = null;
      inherit lib pkgs hself;
      haskellLib = pkgs.haskell.lib.compose;
      hsuper = hself;
    };

  applyGithubFixture = applyGithubEntry registries.github "example-core";
  applyRootFixture = applyGithubEntry rootRegistries.github "example-root";

  fixtureVersions = {
    ghc9122 = (applyGithubFixture "ghc9122").version;
    ghc914 = (applyGithubFixture "ghc914").version;
  };

  rootFixtureVersions = {
    ghc9122 = (applyRootFixture "ghc9122").version;
    ghc914 = (applyRootFixture "ghc914").version;
  };

  invalidCases = [
    {
      name = "duplicate family";
      config = fixtures + "/invalid-config-duplicate-family.json";
      lock = fixtures + "/valid-lock.json";
    }
    {
      name = "unknown override key";
      config = fixtures + "/invalid-config-unknown-override-key.json";
      lock = fixtures + "/valid-lock.json";
    }
    {
      name = "absolute package path";
      config = fixtures + "/valid-config.json";
      lock = fixtures + "/invalid-lock-absolute-path.json";
    }
    {
      name = "parent-traversing package path";
      config = fixtures + "/valid-config.json";
      lock = fixtures + "/invalid-lock-parent-path.json";
    }
    {
      name = "dot segment inside a package path";
      config = fixtures + "/valid-config.json";
      lock = fixtures + "/invalid-lock-dot-segment-path.json";
    }
    {
      name = "mismatched family";
      config = fixtures + "/valid-config.json";
      lock = fixtures + "/invalid-lock-mismatched-family.json";
    }
    {
      name = "mismatched input";
      config = fixtures + "/valid-config.json";
      lock = fixtures + "/invalid-lock-mismatched-input.json";
    }
    {
      name = "malformed version";
      config = fixtures + "/valid-config.json";
      lock = fixtures + "/invalid-lock-malformed-version.json";
    }
    {
      name = "malformed hash";
      config = fixtures + "/valid-config.json";
      lock = fixtures + "/invalid-lock-malformed-hash.json";
    }
    {
      name = "duplicate package";
      config = fixtures + "/valid-config.json";
      lock = fixtures + "/invalid-lock-duplicate-package.json";
    }
  ];

  invalidResults = map
    (fixture:
      let
        attempted = builtins.tryEval (mkFirstPartyRegistries {
          inherit sources;
          config = readJson fixture.config;
          lock = readJson fixture.lock;
        });
      in {
        inherit (fixture) name;
        rejected = !attempted.success;
      })
    invalidCases;

  allInvalidRejected = builtins.all (result: result.rejected) invalidResults;

  result = {
    inherit
      githubNames
      hackageNames
      kiokuGithubNames
      kiokuHackageNames
      fixtureVersions
      rootFixtureVersions
      invalidResults;
  };
in
{
  inherit result;

  check =
    assert githubNames == [ "example-core" "example-dev" "example-special" ];
    assert hackageNames == [ "example-core" "example-special" ];
    assert kiokuGithubNames == kiokuPackageNames;
    assert kiokuHackageNames == kiokuPackageNames;
    assert allInvalidRejected;
    assert fixtureVersions.ghc9122 == "1.2.0.0";
    assert fixtureVersions.ghc914 == "1.2.0.0";
    assert builtins.attrNames rootRegistries.github == [ "example-root" ];
    assert builtins.attrNames rootRegistries.hackage == [ "example-root" ];
    assert rootFixtureVersions.ghc9122 == "3.1.0.0";
    assert rootFixtureVersions.ghc914 == "3.1.0.0";
    pkgs.runCommand "first-party-registry" { } ''
      echo 'GitHub packages: ${builtins.toJSON githubNames}'
      echo 'Hackage packages: ${builtins.toJSON hackageNames}'
      echo 'Kioku GitHub packages: ${builtins.toJSON kiokuGithubNames}'
      echo 'Kioku Hackage packages: ${builtins.toJSON kiokuHackageNames}'
      echo 'Fixture versions: ${builtins.toJSON fixtureVersions}'
      echo 'Root fixture versions: ${builtins.toJSON rootFixtureVersions}'
      echo 'Invalid fixtures: ${builtins.toJSON invalidResults}'
      touch "$out"
    '';
}
