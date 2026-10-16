# Real dependency identities, with independent application scopes and source edits.
{ lib, pkgs, mkRuntimePackageSet }:
let
  arguments = {
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
  selected = mkRuntimePackageSet arguments;
  scope = extra: pkgs.haskell.packages.ghc9124.override {
    overrides = lib.composeExtensions
      (selected.haskellExtension pkgs.haskell.lib.compose pkgs)
      extra;
  };
  source = variant: builtins.path {
    path = ./fixtures + "/runtime-app-${variant}";
    name = if variant == "b" then "runtime-app-b-source" else "runtime-app-a-source";
    filter = path: type: builtins.baseNameOf path != "README.md";
  };
  app = variant: hs: hs.callCabal2nix
    (if variant == "b" then "runtime-app-b" else "runtime-app-a")
    (source variant)
    { };
  a = scope (hself: _: { runtime-app-a = app "a" hself; });
  b = scope (hself: _: { runtime-app-b = app "b" hself; });
  docs = scope (hself: _: { runtime-app-a = app "a-docs" hself; });
  changedLeaf = scope (hself: _: { runtime-app-a = app "a-edit" hself; });
  changedInterface = scope (hself: hsuper: {
    keiki = pkgs.haskell.lib.compose.overrideCabal
      (previous: {
        postPatch = (previous.postPatch or "") + ''
          cat > src/Keiki/RuntimeIdentityProbe.hs <<'HS'
          module Keiki.RuntimeIdentityProbe (runtimeIdentityProbe) where
          runtimeIdentityProbe :: Int
          runtimeIdentityProbe = 1
          HS
          substituteInPlace keiki.cabal --replace-fail '  exposed-modules:' '  exposed-modules:
              Keiki.RuntimeIdentityProbe'
        '';
      })
      hsuper.keiki;
    runtime-app-a = app "a" hself;
    runtime-app-b = app "b" hself;
  });
  unrelatedSelection = mkRuntimePackageSet (arguments // {
    applicationSelections = arguments.applicationSelections // { okf = 1; };
  });
  unrelated = unrelatedSelection.mkApplicationScope pkgs (_: _: { });
  baseline = import ../generated/cohort-versions.nix;
  changed = field: value: baseline // {
    ${field} = baseline.${field} // { aeson = value; };
  };
  identities = hs: map (name: { inherit name; drv = hs.${name}.drvPath; out = hs.${name}.outPath; })
    (builtins.filter (name: selected.metadata.ownership.${name}.source != "Boot") (builtins.attrNames selected.metadata.ownership));
  accepts = value: (builtins.tryEval (builtins.deepSeq value true)).success;
  reject = value: !accepts value;
  assertions = [
    (changedInterface.keiki.drvPath != a.keiki.drvPath)
    (changedInterface.runtime-app-a.drvPath != a.runtime-app-a.drvPath)
    (changedInterface.runtime-app-b.drvPath != b.runtime-app-b.drvPath)
    (changedInterface.aeson.drvPath == a.aeson.drvPath)
    (reject (selected.validateApplicationScope pkgs changedInterface))
    (identities a == identities b)
    (identities a == identities unrelated)
    (identities a == identities changedLeaf)
    (identities a == identities docs)
    (a.runtime-app-a.drvPath == docs.runtime-app-a.drvPath)
    (a.runtime-app-a.drvPath != changedLeaf.runtime-app-a.drvPath)
    (reject (mkRuntimePackageSet (arguments // { applicationCohort = changed "flags" { forged = true; }; })))
    (reject (mkRuntimePackageSet (arguments // { applicationCohort = changed "packages" (baseline.packages.aeson // { version = "0.0"; }); })))
    (reject (mkRuntimePackageSet (arguments // { applicationCohort = changed "sourceManifest" (baseline.sourceManifest.aeson // { source = "SourcePin"; }); })))
    (reject (mkRuntimePackageSet (arguments // { applicationCohort = changed "policy" { owner = "forged"; }; })))
    (selected.validateApplicationScope pkgs a)
    (reject (mkRuntimePackageSet (arguments // { applicationSelections = { }; })))
    (reject (mkRuntimePackageSet (arguments // { applicationSelections = arguments.applicationSelections // { keiki = 1; }; })))
    (reject (mkRuntimePackageSet (arguments // { generation = 999999; })))
    (reject (mkRuntimePackageSet (arguments // { disableHaddock = false; })))
    (reject (mkRuntimePackageSet (arguments // { applicationRegistry.keiki = [ ]; })))
    (reject (selected.validateApplicationScope pkgs (a // {
      keiki = a.keiki.overrideAttrs (_: { runtimeConflict = "test"; });
    })))
  ];
in
assert builtins.all (value: value) assertions;
pkgs.linkFarm "runtime-composition" [
  { name = "app-a"; path = a.runtime-app-a; }
  { name = "app-b"; path = b.runtime-app-b; }
  { name = "app-edited"; path = changedLeaf.runtime-app-a; }
  { name = "runtime-interface-app-a"; path = changedInterface.runtime-app-a; }
  { name = "runtime-interface-app-b"; path = changedInterface.runtime-app-b; }
  {
    name = "identities.json";
    path = pkgs.writeText "runtime-composition-identities.json" (builtins.toJSON {
      runtime = "keiro-runtime";
      generation = 1;
      fingerprint = selected.metadata.fingerprint;
      packages = identities a;
      assertions = builtins.length assertions;
    });
  }
]
