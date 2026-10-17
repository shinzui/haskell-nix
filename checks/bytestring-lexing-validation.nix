# Explicit real-policy narrowing pilot. This is not a removal probe: the selected
# package has no standalone repair row, and production keeps its legacy waiver.
{ channel, system ? "aarch64-darwin", sourceChannel ? "github" }:
let
  pkgs = import channel.inputs.nixpkgs { inherit system; };
  lib = pkgs.lib;
  hl = pkgs.haskell.lib.compose;
  scope = pkgs.haskell.packages.${channel.lib.defaultGhc}.override {
    overrides = channel.lib.haskellExtensions.${sourceChannel} hl pkgs;
  };
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
{
  inherit strict production manifest behavior;
  context = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON {
    schemaVersion = 1;
    kind = "real-policy-narrowing-pilot";
    inherit system sourceChannel entry;
    compiler = scope.ghc.drvPath;
    exceptionId = "legacy-skip-enforce-v1-test-suppression";
    production = facts production;
    candidate = facts strict;
    requiredSuites = [ "test-all" ];
    graph = { derivation = manifest.drvPath; inherit (manifest) declaration; };
    behavior = behavior.drvPath;
    status = "unverified";
  }));
}
