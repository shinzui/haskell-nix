# Bind an explicitly validated recipe context to its content-addressed functions.
# The owning factory supplies its captured context, rather than reading it back
# from the artifact under validation. Reviewed policy runs once after construction.
{ lib }:
{ manifest, recipes, context, policyExtension }:
haskellLib: pkgs:
let
  cfg = context.configuration;
  names = builtins.attrNames context.packages;
  converter = pkgs.buildPackages.haskellPackages.cabal2nix-unstable.bin;
  fail = message: throw "mkGeneratedRecipeExtension: ${message}";
  require = condition: message: if condition then true else fail message;
  validName = name: builtins.match "[A-Za-z0-9_-]+" name != null;
  packageFile = name: recipes + "/packages/${name}.nix";
  inputFacts = input: {
    inherit (input) unpackedHash revision nativeArguments;
  } // lib.optionalAttrs (input ? sourcePin) { inherit (input) sourcePin; };
  manifestFacts = entry: {
    inherit (entry) unpackedHash revision nativeArguments;
  } // lib.optionalAttrs (entry ? sourcePin) { inherit (entry) sourcePin; };
  inspect = name:
    let
      recipe = import (packageFile name);
      arguments = builtins.mapAttrs
        (argument: _:
          if argument == "mkDerivation" then (attrs: attrs)
          else if argument == "lib" then { } else argument)
        (builtins.functionArgs recipe);
      attrs = recipe arguments;
      fields = builtins.filter
        (field: builtins.match ".*Depends" field != null || field == "buildTools")
        (builtins.attrNames attrs);
    in
    {
      metadata = {
        name = attrs.pname;
        inherit (attrs) version;
        revision = if (attrs.revision or null) == null then null else toString attrs.revision;
      };
      roles = builtins.listToAttrs (map
        (field:
          let values = attrs.${field};
          in assert builtins.isList values && builtins.all builtins.isString values;
          { name = field; value = values; })
        fields);
    };
  verifyPackage = name:
    let
      entry = manifest.packages.${name};
      input = context.packages.${name};
      facts = inspect name;
    in
    require (manifestFacts entry == inputFacts context.packages.${name}) "source/native input mismatch for ${name}"
    && require (builtins.hashFile "sha256" (packageFile name) == entry.recipeSha256) "recipe content changed for ${name}"
    && require (facts.metadata.name == name && facts.metadata.version == context.generationContext.sources.${name}.version) "selected package identity mismatch for ${name}"
    && require
      (if input ? sourcePin then facts.metadata.revision == null else
      facts.metadata.revision == toString input.revision.number
      || (input.revision.number == 0 && facts.metadata.revision == null)) "selected metadata revision mismatch for ${name}"
    && require (facts.metadata == entry.convertedMetadata) "converted identity changed for ${name}"
    && require (facts.roles == entry.dependenciesByComponent) "component dependencies changed for ${name}";
  validation =
    require (context.schemaVersion == 2 && manifest.schemaVersion == 2) "format 2 is required"
    && require (manifest.generationContext == context.generationContext) "generation context mismatch"
    && require (manifest.configuration == cfg) "configuration/policy identity mismatch"
    && require (names != [ ] && builtins.all validName names) "invalid package names"
    && require (builtins.attrNames manifest.packages == names) "generated coverage mismatch"
    && require (builtins.readDir (recipes + "/packages") == builtins.listToAttrs (map (name: { name = "${name}.nix"; value = "regular"; }) names)) "unexpected recipe files"
    && require (pkgs.stdenv.hostPlatform.system == cfg.system) "unsupported system"
    && require (converter.drvPath == cfg.converter.derivation && toString converter == cfg.converter.output) "converter is not from the selected builder"
    && require (!(cfg ? extractor) || (pkgs.gnutar.drvPath == cfg.extractor.derivation && toString pkgs.gnutar == cfg.extractor.output)) "extractor is not from the selected builder"
    && builtins.all verifyPackage names;
  nativeArguments = input: builtins.mapAttrs
    (_: path: lib.foldl' (scope: component: scope.${component}) pkgs (lib.splitString "." path))
    input.nativeArguments;
  sourceFor = name: input:
    if !(input ? sourcePin) then
      pkgs.fetchzip
        {
          url = "mirror://hackage/${name}-${context.generationContext.sources.${name}.version}/${name}-${context.generationContext.sources.${name}.version}.tar.gz";
          sha256 = input.unpackedHash;
        } else
      let
        pin = input.sourcePin;
        parts = builtins.match "https://github.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)" pin.repository;
        repo = builtins.elemAt parts 1;
        plainRepo =
          if builtins.match ".*\\.git" repo != null
          then builtins.substring 0 (builtins.stringLength repo - 4) repo else repo;
      in
      assert parts != null;
      pkgs.fetchFromGitHub {
        owner = builtins.elemAt parts 0;
        repo = plainRepo;
        rev = pin.revision;
        hash = input.unpackedHash;
      };
  raw = final: _previous: builtins.listToAttrs (map
    (name:
      let
        input = context.packages.${name};
        source = sourceFor name input;
        src =
          if input ? sourcePin && input.sourcePin.subdirectory != "."
          then source + "/${input.sourcePin.subdirectory}" else source;
        change = args:
          if input ? sourcePin then {
            passthru = (args.passthru or { }) // {
              cohortSourceOrigin = { inherit source; subdirectory = input.sourcePin.subdirectory; };
            };
          } else
            lib.optionalAttrs (input.revision.number != 0) {
              revision = toString input.revision.number;
              editedCabalFile = input.revision.sha256;
            };
      in
      {
        inherit name;
        value = assert final.ghc.version == cfg.compilerVersion
          && final.ghc.drvPath == pkgs.haskell.packages.${cfg.compilerKey}.ghc.drvPath;
          haskellLib.overrideCabal change (final.callPackage (packageFile name)
            ({ inherit src; } // nativeArguments input));
      })
    names);
in
builtins.seq validation (lib.composeExtensions raw policyExtension)
