{ pkgs, scope }:
let
  inherit (pkgs) lib;
  hl = pkgs.haskell.lib.compose;
  fixture = ./fixtures/generated-recipes;
  source = name: builtins.path { path = fixture + "/${name}"; name = "recipe-${name}-source"; };
  tune = package: hl.dontHaddock (hl.disableLibraryProfiling (hl.dontCheck package));
  construct = mode: variant: scope.override {
    overrides = final: _prev:
      let
        metadata =
          if variant == "revised" then fixture + "/metadata/revised.cabal"
          else fixture + "/leaf/recipe-leaf.cabal";
        selectedMetadata = pkgs.runCommand "recipe-leaf-selected-metadata" { } ''
          mkdir "$out"
          cp ${metadata} "$out/recipe-leaf.cabal"
        '';
        patchMetadata = package: hl.overrideCabal
          (args: { prePatch = (args.prePatch or "") + ''cp ${metadata} recipe-leaf.cabal''; })
          package;
        convert = name: arguments:
          if mode == "generated" then final.callPackage (fixture + "/packages/${name}.nix") arguments
          else if name == "consumer" then final.callCabal2nix "recipe-consumer" (source "consumer") arguments
          else if name == "pinned" then final.callCabal2nix "recipe-pinned" (source "pinned") arguments
          else
            final.callCabal2nixWithOptions "recipe-leaf" (source "leaf")
              {
                srcModifier = _: selectedMetadata;
                extraCabal2nixOptions = lib.optionalString (variant == "flagged") "--flag=use-text";
              }
              arguments;
        leafName = if variant == "base" then "leaf" else variant;
      in
      {
        recipe-leaf = tune (patchMetadata (convert leafName
          (lib.optionalAttrs (mode == "generated") { src = source "leaf"; })));
        recipe-pinned = tune (convert "pinned" ({ zlib = pkgs.zlib; }
          // lib.optionalAttrs (mode == "generated") { src = source "pinned"; }));
        recipe-consumer = tune (convert "consumer"
          (lib.optionalAttrs (mode == "generated") { src = source "consumer"; }));
      };
  };
  generated = lib.genAttrs [ "base" "revised" "flagged" ] (construct "generated");
  legacy = lib.genAttrs [ "base" "revised" "flagged" ] (construct "legacy");
  hasDependency = name: package: builtins.any
    (dependency: (dependency.pname or null) == name)
    package.getCabalDeps.libraryHaskellDepends;
  behavior = name: sets: pkgs.runCommand name { } ''
    test "$(${sets.base.recipe-consumer}/bin/recipe-consumer)" = 44
    test "$(${sets.revised.recipe-consumer}/bin/recipe-consumer)" = 44
    test "$(${sets.flagged.recipe-consumer}/bin/recipe-consumer)" = 45
    touch "$out"
  '';
  noIfd =
    assert !(hasDependency "recipe-pinned" generated.base.recipe-leaf);
    assert hasDependency "recipe-pinned" generated.revised.recipe-leaf;
    # Compiler-provided libraries may be null in the actual Nix scope; their
    # presence in the converter's arguments is still required.
    assert (builtins.functionArgs (import (fixture + "/packages/revised.nix"))) ? bytestring;
    assert (builtins.functionArgs (import (fixture + "/packages/flagged.nix"))) ? text;
    assert generated.base.recipe-leaf.drvPath != generated.revised.recipe-leaf.drvPath;
    assert generated.base.recipe-leaf.drvPath != generated.flagged.recipe-leaf.drvPath;
    assert builtins.elem pkgs.zlib.drvPath
      (map (dependency: dependency.drvPath)
        generated.base.recipe-pinned.getCabalDeps.librarySystemDepends);
    assert (builtins.functionArgs (import (fixture + "/packages/pinned.nix"))) ? Cabal;
    behavior "generated-recipes-no-ifd" generated;
  parity =
    assert builtins.all
      (variant: builtins.all
        (package: generated.${variant}.${package}.drvPath == legacy.${variant}.${package}.drvPath)
        [ "recipe-leaf" "recipe-pinned" "recipe-consumer" ])
      (builtins.attrNames generated);
    pkgs.runCommand "generated-recipes-parity" { } ''
      test -e ${noIfd}
      test -e ${behavior "legacy-recipe-behavior" legacy}
      touch "$out"
    '';
in
{ inherit noIfd parity generated legacy; }
