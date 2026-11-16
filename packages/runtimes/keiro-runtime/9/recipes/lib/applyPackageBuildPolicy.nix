# Apply a declared policy while constructing a recipe. A strict profile must be
# selected before any source/metadata rewrite; this cannot undo an earlier one.
profileName: haskellLib: package:
let
  profiles = (builtins.fromJSON (builtins.readFile ../config/package-build-policies.json)).profiles;
  profile = profiles.${profileName} or (throw "package build policy: unknown profile ${profileName}");
  # Existing selections keep these immutable semantics. Narrowing needs a new
  # profile and selection, rather than a mutation of a historical default.
  legacy = {
    legacy-first-party-v1 = [ "skip" "relax" ];
    legacy-skip-relax-v1 = [ "skip" "relax" ];
    legacy-skip-enforce-v1 = [ "skip" "enforce" ];
    legacy-run-relax-v1 = [ "run" "relax" ];
    strict-v1 = [ "run" "enforce" ];
    verified-bytestring-lexing-ghc9124-v1 = [ "run" "enforce" ];
  };
  expected = legacy.${profileName} or [ profile.tests.mode profile.bounds.mode ];
  complete = profile.construction == "complete";
  bounded =
    if profile.bounds.mode == "relax" then haskellLib.doJailbreak package
    else if complete then haskellLib.dontJailbreak package else package;
in
assert builtins.elem profile.tests.mode [ "run" "skip" ];
assert builtins.elem profile.bounds.mode [ "enforce" "relax" ];
assert builtins.elem profile.construction [ "complete" "legacy-layer" ];
assert complete == (builtins.elem profileName [ "strict-v1" "verified-bytestring-lexing-ghc9124-v1" ]
  || !(builtins.hasAttr profileName legacy));
assert expected == [ profile.tests.mode profile.bounds.mode ];
# A migrated layer that historically did not alter tests/bounds preserves that
# inherited setting. Its declared mode is not a claim about the final recipe.
if profile.tests.mode == "skip" then haskellLib.dontCheck bounded
else if complete then haskellLib.doCheck bounded else bounded
