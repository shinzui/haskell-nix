# Native feasibility experiment; this does not enable reuse for applications.
{ pkgs, scope }:
let
  inherit (pkgs) lib;
  base = ./fixtures/application-incremental;
  source = variant: pkgs.runCommand "application-incremental-source" { } ''
    cp -R ${base} "$out"
    chmod -R u+w "$out"
    ${lib.optionalString (variant == "leaf") ''
      substituteInPlace "$out/src/Leaf.hs" --replace-fail 'leaf = 2' 'leaf = 3'
    ''}
    ${lib.optionalString (variant == "interface" || variant == "invalid-interface") ''
      substituteInPlace "$out/src/Leaf.hs" \
        --replace-fail 'leaf :: Int' 'leaf :: String' \
        --replace-fail 'leaf = 2' 'leaf = "4"'
    ''}
    ${lib.optionalString (variant == "interface") ''
      substituteInPlace "$out/src/Combined.hs" \
        --replace-fail 'stable + leaf' 'stable + read leaf'
    ''}
    ${lib.optionalString (variant == "data") ''
      echo changed-data > "$out/message.txt"
    ''}
    ${lib.optionalString (variant == "removed") ''
      rm "$out/src/Leaf.hs"
    ''}
  '';
  recipe = variant: previousIntermediates: scope.callPackage
    ({ mkDerivation, base, template-haskell }: mkDerivation {
      pname = "application-incremental";
      version = "0.1.0.0";
      src = source variant;
      isLibrary = true;
      isExecutable = true;
      libraryHaskellDepends = [ base template-haskell ];
      executableHaskellDepends = [ base ];
      license = lib.licenses.mit;
      doCheck = false;
      doHaddock = false;
      enableLibraryProfiling = false;
      doInstallIntermediates = true;
      enableSeparateIntermediatesOutput = true;
      inherit previousIntermediates;
    })
    { };
  seed = recipe "seed" null;
  variants = [ "unchanged" "leaf" "interface" "data" ];
  clean = lib.genAttrs variants (variant: recipe variant null);
  seeded = lib.genAttrs variants (variant: recipe variant seed.intermediates);
  expected = {
    unchanged = "42:seed-data";
    leaf = "43:seed-data";
    interface = "44:seed-data";
    data = "42:changed-data";
  };
  compatibility = {
    schemaVersion = 1;
    packageName = seed.pname;
    packageVersion = seed.version;
    compilerIdentity = seed.compiler.drvPath;
    # The fixture constructor differs only in src and previousIntermediates.
    recipeIdentity = seed.drvPath;
    metadataIdentity = builtins.hashFile "sha256" (base + "/application-incremental.cabal");
    sourceLayoutIdentity = "app/Main.hs;src/Combined.hs;src/Embedded.hs;src/Leaf.hs;src/Stable.hs;message.txt";
    generatedInputPolicy = "tracked TH dependent file";
  };
  guarded = extra: (import ../lib/mkApplicationIncrementalBuild.nix { inherit lib; }) ({
    inherit pkgs;
    package = clean.leaf;
    seedPackage = seed;
    currentCompatibility = compatibility;
    seedCompatibility = compatibility;
  } // extra);
in
assert (guarded { }).package.drvPath == seeded.leaf.drvPath;
assert (guarded { enabled = false; }).package.drvPath == clean.leaf.drvPath;
assert (guarded {
  seedCompatibility = compatibility // { recipeIdentity = "different effective flags or dependencies"; };
}).package.drvPath == clean.leaf.drvPath;
pkgs.runCommand "application-incremental-correctness"
{
  passthru = {
    inherit seed clean seeded;
    # Build these explicitly: both policies must fail, rather than silently
    # accepting a stale interface or the removed module from a seed.
    negative = lib.genAttrs [ "invalid-interface" "removed" ] (variant: {
      clean = recipe variant null;
      seeded = recipe variant seed.intermediates;
    });
    identity = {
      compiler = scope.ghc.drvPath;
      seed = seed.drvPath;
      clean = lib.mapAttrs (_: package: package.drvPath) clean;
      seeded = lib.mapAttrs (_: package: package.drvPath) seeded;
    };
  };
}
  (lib.concatMapStringsSep "\n"
    (variant: ''
      clean="$(${clean.${variant}}/bin/application-incremental)"
      seeded="$(${seeded.${variant}}/bin/application-incremental)"
      test "$clean" = '${expected.${variant}}'
      test "$seeded" = "$clean"
      echo '${variant}: clean and seeded agree'
    '')
    variants + ''
    touch "$out"
  '')
