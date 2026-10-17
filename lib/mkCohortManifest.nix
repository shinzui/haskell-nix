{ lib }:
{ pkgs
, scope
, root
, context
, localPackages ? [ root.pname ]
, name ? "${root.pname}-cohort-manifest"
}:
let
  haskellLib = pkgs.haskell.lib.compose;
  isHaskell = dependency: dependency != null && dependency ? getCabalDeps;
  dependencyRows = package: lib.concatLists (lib.mapAttrsToList
    (field: dependencies: map (dependency: { inherit field dependency; }) dependencies)
    (lib.filterAttrs
      (field: _: lib.hasSuffix "HaskellDepends" field
        || lib.hasSuffix "ToolDepends" field || builtins.elem field [ "buildDepends" "buildTools" "testDepends" "benchmarkDepends" ])
      package.getCabalDeps));
  haskellRows = package: builtins.filter (row: isHaskell row.dependency) (dependencyRows package);
  closure = builtins.genericClosure {
    startSet = [{ key = root.drvPath; package = root; }];
    operator = item: map
      (row: { key = row.dependency.drvPath; package = row.dependency; })
      (haskellRows item.package);
  };
  capture = package:
    let
      expose = args: {
        passthru = (args.passthru or { }) // { cohortManifestArguments = args; };
      };
      captured =
        if package ? overrideScope
        then haskellLib.overrideCabal expose package
        else package.override expose;
    in
    assert lib.assertMsg (package.drvPath == (scope.mkDerivation captured.cohortManifestArguments).drvPath)
      "mkCohortManifest: captured inputs do not reconstruct ${package.pname}; express recipe changes through overrideCabal";
    captured.cohortManifestArguments;
  sourceFacts = import ./cohortSource.nix { inherit lib; };
  sourceRecord = sourceFacts.record;
  sourceIdentity = import ./compatibilitySourceIdentity.nix { inherit lib; };
  # Lazy fetchTree aliases can have different strings for the same source.
  # The existing metadata projection resolves their contexts without building it.
  sameSource = actual: expected:
    toString actual == toString expected || sourceIdentity actual == sourceIdentity expected;
  packageRecord = item:
    let
      package = item.package;
      args = capture package;
      rawSource = args.src or null;
      origin = args.passthru.cohortSourceOrigin or null;
      declared = (context.sourceContext or { }).${package.pname} or null;
      source =
        if origin != null then
          assert lib.assertMsg (sameSource rawSource (sourceFacts.originPath origin))
            "mkCohortManifest: source origin differs from the actual package source";
          (sourceRecord origin.source) // { path = "${rawSource}"; subdirectory = origin.subdirectory; }
        else if declared != null && declared.source != null && declared.source.kind == "github" then
          assert lib.assertMsg (sameSource rawSource declared.source.path)
            "mkCohortManifest: first-party source differs from its retained snapshot for ${package.pname}: actual ${toString rawSource}, expected ${declared.source.path}";
          declared.source // { hashMode = "recursive"; urls = [ ]; }
        else sourceRecord rawSource;
      roles = lib.unique ((lib.optional (item.key == root.drvPath) "root")
        ++ lib.concatMap
        (parent: map (row: row.field)
          (builtins.filter (row: row.dependency.drvPath == item.key) (haskellRows parent.package)))
        closure);
    in
    {
      name = package.pname;
      version = package.version;
      role = if builtins.elem package.pname localPackages then "local" else "haskell";
      componentRoles = roles;
      drvPath = item.key;
      outputPath = package.outPath;
      configurationReplay = import ./mkCohortConfigureEvidence.nix { inherit package; ghc = scope.ghc; };
      inherit source;
      metadata = { revision = args.revision or null; hash = args.editedCabalFile or null; };
      configuration = {
        configureFlags = args.configureFlags or [ ];
        jailbreak = args.jailbreak or false;
        doCheck = args.doCheck or true;
        doBenchmark = args.doBenchmark or false;
        doHaddock = args.doHaddock or true;
        enableLibraryProfiling = args.enableLibraryProfiling or true;
        patches = map (patch: "${patch}") (args.patches or [ ]);
        prePatch = args.prePatch or "";
        postPatch = args.postPatch or "";
        hooks = lib.genAttrs [
          "postUnpack"
          "preConfigure"
          "postConfigure"
          "preBuild"
          "postBuild"
          "preInstall"
          "postInstall"
        ]
          (hook: if (args.${hook} or null) == null then "" else args.${hook});
      };
      dependencies = lib.unique (map (row: row.dependency.drvPath) (haskellRows package));
    };
  nativePackages = builtins.attrValues (lib.listToAttrs (lib.concatMap
    (item: map
      (dependency: {
        name = builtins.unsafeDiscardStringContext dependency.drvPath;
        value = {
          name = dependency.pname or dependency.name;
          version = dependency.version or null;
          role = "native";
          drvPath = dependency.drvPath;
          outputPath = dependency.outPath;
        };
      })
      (builtins.filter
        (dependency: dependency != null && builtins.isAttrs dependency
          && dependency ? drvPath && !(dependency ? getCabalDeps))
        (lib.concatLists (builtins.attrValues item.package.getCabalDeps))))
    closure));
  declaration = {
    schemaVersion = 1;
    system = pkgs.stdenv.hostPlatform.system;
    inherit context nativePackages;
    compiler = { name = "ghc"; version = scope.ghc.version; drvPath = scope.ghc.drvPath; outputPath = scope.ghc.outPath; };
    root = { name = root.pname; drvPath = root.drvPath; outputPath = root.outPath; };
    packages = map packageRecord closure;
  };
in
assert lib.assertMsg (root ? compiler && root.compiler.drvPath == scope.ghc.drvPath)
  "mkCohortManifest: root must use the supplied composed scope's compiler";
pkgs.runCommand name
{
  __structuredAttrs = true;
  nativeBuildInputs = [ pkgs.python3 ];
  rootOutput = root;
  declarationFile = pkgs.writeText "${name}-declaration.json" (builtins.toJSON declaration);
  exportReferencesGraph.derivationGraph = [ (builtins.unsafeDiscardOutputDependency root.drvPath) ];
  passthru = {
    inherit declaration;
    # Retain every library output for cache publication even when the executable
    # is statically linked. This does not modify any dependency derivation.
    cacheRoot = pkgs.linkFarm "${root.pname}-dependency-cache" (map
      (item: {
        name = "${item.package.pname}-${builtins.substring 0 12 (builtins.hashString "sha256" item.key)}";
        path = item.package;
      })
      closure);
  };
}
  ''
    ${scope.ghc}/bin/ghc-pkg list --global --simple-output > compiler-packages
    python3 ${../scripts/cohort-manifest.py} "$declarationFile" .attrs.json compiler-packages "$out"
  ''
