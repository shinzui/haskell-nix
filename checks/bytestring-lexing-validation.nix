# Explicit real-policy validation. Old receipts bind their original immutable
# source/context; the current selected policy is checked against the strict recipe.
{ channel ? null
, system ? "aarch64-darwin"
, sourceChannel ? "github"
, pkgs ? import channel.inputs.nixpkgs { inherit system; }
, scope ? pkgs.haskell.packages.${channel.lib.defaultGhc}.override {
    overrides = channel.lib.haskellExtensions.${sourceChannel} pkgs.haskell.lib.compose pkgs;
  }
}:
let
  lib = pkgs.lib;
  hl = pkgs.haskell.lib.compose;
  cohort = import ../generated/cohort-versions.nix;
  entry = cohort.packages.bytestring-lexing;
  raw = (import ../lib/callCohortHackage.nix { inherit lib; }) {
    hself = scope;
    haskellLib = hl;
    inherit pkgs entry;
    name = "bytestring-lexing";
    arguments = { };
  };
  strict = (import ../lib/applyPackageBuildPolicy.nix) "strict-v1" hl raw;
  legacy = (import ../lib/applyPackageBuildPolicy.nix) "legacy-skip-enforce-v1" hl raw;
  production = scope.bytestring-lexing;
  facts = package: (import ../lib/packageRecipeFacts.nix { inherit lib; }) {
    haskellLib = hl;
    inherit package;
    includeTestDependencies = true;
  };
  behavior = pkgs.runCommand "bytestring-lexing-strict-behavior"
    {
      nativeBuildInputs = [ (scope.ghc.withPackages (_: [ strict ])) ];
    } ''
    cat > Main.hs <<'HS'
    import Control.Monad (unless)
    import qualified Data.ByteString.Char8 as B
    import Data.ByteString.Lex.Integral (readDecimal, packDecimal)
    main :: IO ()
    main = do
      unless (readDecimal (B.pack "123tail") == Just (123 :: Integer, B.pack "tail")) (fail "decimal parser behavior")
      unless (readDecimal (B.pack "bad") == (Nothing :: Maybe (Integer, B.ByteString))) (fail "invalid parser input")
      unless (packDecimal (123 :: Integer) == Just (B.pack "123")) (fail "decimal serializer behavior")
      putStrLn "EP21_REAL_POLICY_BEHAVIOR_PASSED"
    HS
    runghc Main.hs
    touch "$out"
  '';
  manifest = (import ../lib/mkCohortManifest.nix { inherit lib; }) {
    inherit pkgs scope;
    root = strict;
    context = { purpose = "bytestring-lexing test-policy narrowing"; inherit sourceChannel; };
  };
in
assert entry.version == "0.5.0.16" && entry.revision == null;
assert scope.ghc.version == "9.12.4";
assert production.cohortBuildPolicySelection == {
  profile = "verified-bytestring-lexing-ghc9124-v1";
  selectionId = "bytestring-lexing-ghc9124-native-v1";
};
assert production.drvPath == strict.drvPath && production.drvPath != legacy.drvPath;
{
  inherit strict production legacy manifest behavior;
  check = pkgs.linkFarm "bytestring-lexing-selected-policy-${sourceChannel}" [
    { name = "selected-package"; path = production; }
    { name = "complete-test-input-graph"; path = manifest; }
    { name = "parser-serializer-behavior"; path = behavior; }
  ];
  context = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON {
    schemaVersion = 1;
    kind = "real-policy-narrowing-pilot";
    inherit system sourceChannel entry;
    compiler = scope.ghc.drvPath;
    exceptionId = "legacy-skip-enforce-v1-test-suppression";
    production = facts production;
    previousProduction = facts legacy;
    selectedPolicy = production.cohortBuildPolicySelection;
    candidate = facts strict;
    requiredSuites = [ "test-all" ];
    graph = { derivation = manifest.drvPath; inherit (manifest) declaration; };
    behavior = behavior.drvPath;
    status = "unverified";
  }));
}
