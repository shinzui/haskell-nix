# Validation-only inventory, prior to the explicit production catalog migration.
{ lib, mkFirstPartyRegistries }:
let
  proposed = builtins.fromJSON (builtins.readFile ./proposed.json);
  additions = builtins.fromJSON (builtins.readFile ../../../config/catalog-additions/ep22.json);
  sources = lib.mapAttrs'
    (name: selected: {
      name = "${name}-src";
      value = builtins.fetchTree {
        type = "github";
        owner = "shinzui";
        repo = name;
        inherit (selected) rev;
        narHash = selected.hash;
      };
    })
    proposed;
  config = { schemaVersion = 1; inherit (additions) families; };
  lock = {
    schemaVersion = 1;
    families = lib.mapAttrsToList
      (name: selected: {
        inherit name;
        githubInput = "${name}-src";
        githubRev = selected.rev;
        packages = map
          (package: {
            inherit (package) name path version;
            cabal2nixOptions = "";
            hackage = if package.hackageHash == null then null else {
              inherit (package) version;
              hash = package.hackageHash;
            };
          })
          selected.packages;
      })
      proposed;
  };
in
mkFirstPartyRegistries { inherit config lock sources; }
