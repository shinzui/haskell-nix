# Experiments in mori://shinzui/rei and mori://shinzui/mori using their captured
# runtime constructors; application source-file artifact URIs are pending.
{ source
, seedSource
, application
, applicationRevision
, revision ? builtins.substring 0 7 applicationRevision
, seedRevision ? revision
, policy ? "incremental"
, system ? "aarch64-darwin"
}:
let
  checkout = builtins.getEnv "MP4_APPLICATION_CHECKOUT";
  app = builtins.getFlake "git+file://${checkout}?rev=${applicationRevision}";
  pkgs = import app.inputs.nixpkgs { inherit system; };
  inherit (pkgs) lib;
  haskellLib = pkgs.haskell.lib.compose;
  cli = "${application}-cli";
  versionModule = if application == "rei" then "Rei/Cli/Commands/Info.hs" else "Mori/Version.hs";
  # Keep the source transformation explicit. Its normalized form is part of the
  # compatibility identity; only the revision literal varies between builds.
  stamp = value: ''
    substituteInPlace src/${versionModule} \
      --replace-fail '#ifdef GIT_HASH' '#if 1' \
      --replace-fail 'nixGitHash = Just GIT_HASH' 'nixGitHash = Just ${builtins.toJSON (builtins.substring 0 7 value)}'
  '';
  construct = directory: gitRev:
    let
      path = builtins.toPath directory;
      selection = builtins.fromJSON (builtins.readFile (path + "/nix/runtime-selection.json"));
      runtime = app.inputs.haskell-nix.lib.mkRuntimePackageSet selection;
      original = import (path + "/nix/haskell-overlay.nix") ({
        inherit pkgs haskellLib gitRev;
      } // lib.optionalAttrs (application == "mori") {
        inherit (app.inputs) mori-schema-src;
      });
      adapt = value: package: haskellLib.overrideCabal
        (args: {
          configureFlags = builtins.filter
            (flag: flag != "--ghc-option=-DGIT_HASH=\"${builtins.substring 0 7 gitRev}\"")
            (args.configureFlags or [ ]);
          postPatch = (args.postPatch or "") + stamp value;
        })
        package;
      scope = runtime.mkApplicationScope pkgs (final: prev:
        let packages = original final prev;
        in packages // { ${cli} = adapt gitRev packages.${cli}; });
      # Reconstruct exactly the same source-independent recipe projection for
      # both sides; all flags, hooks, tools and dependencies remain in its hash.
      projectedScope = runtime.mkApplicationScope pkgs (final: prev:
        let packages = original final prev;
        in packages // {
          ${cli} = haskellLib.overrideCabal
            (_: {
              src = builtins.toFile "application-compatibility-source" "";
            })
            (adapt "<revision>" packages.${cli});
        });
      packageRoot = path + "/${cli}";
      walk = prefix: directory:
        lib.concatMap
          (name:
            let relative = if prefix == "" then name else "${prefix}/${name}";
            in if (builtins.readDir directory).${name} == "directory"
            then if builtins.elem name [ ".git" "dist-newstyle" "result" ] then [ ] else walk relative (directory + "/${name}")
            else [ relative ])
          (builtins.attrNames (builtins.readDir directory));
      files = walk "" packageRoot;
      metadataFiles = builtins.filter
        (name: lib.hasSuffix ".cabal" name || builtins.elem name [ "Setup.hs" "Setup.lhs" "package.yaml" ])
        files;
      metadata = map (name: { inherit name; hash = builtins.hashFile "sha256" (packageRoot + "/${name}"); }) metadataFiles;
    in
    assert builtins.readFile (path + "/flake.lock") == builtins.readFile (app.outPath + "/flake.lock");
    {
      inherit scope;
      package = scope.${cli};
      compatibility = {
        schemaVersion = 1;
        packageName = scope.${cli}.pname;
        packageVersion = scope.${cli}.version;
        compilerIdentity = scope.${cli}.compiler.drvPath;
        recipeIdentity = projectedScope.${cli}.drvPath;
        metadataIdentity = builtins.hashString "sha256" (builtins.toJSON metadata);
        sourceLayoutIdentity = builtins.hashString "sha256" (builtins.toJSON files);
        generatedInputPolicy = builtins.hashString "sha256" (stamp "<revision>");
      };
    };
  current = construct source revision;
  previous = construct seedSource seedRevision;
  guarded = (import ../../../lib/mkApplicationIncrementalBuild.nix { inherit lib; }) {
    inherit pkgs;
    package = current.package;
    seedPackage = previous.package;
    currentCompatibility = current.compatibility;
    seedCompatibility = previous.compatibility;
    enabled = policy == "incremental";
  };
in
assert builtins.elem application [ "rei" "mori" ];
assert builtins.elem policy [ "clean" "incremental" ];
assert builtins.match "([0-9a-fA-F]{7,40}|dirty)" revision != null;
assert builtins.match "([0-9a-fA-F]{7,40}|dirty)" seedRevision != null;
assert checkout != "";
{
  inherit (guarded) package seed compatibilityReport;
  clean = current.package;
  identity = {
    root = guarded.package.drvPath;
    core = current.scope.${application + "-core"}.drvPath;
    compiler = current.scope.ghc.drvPath;
    inherit (guarded) compatibilityReport;
    currentCompatibility = current.compatibility;
    seedCompatibility = previous.compatibility;
  };
}
