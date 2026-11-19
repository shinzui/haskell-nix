# Construct both policies before applying entries. Results are staged, unverified
# probe requests; constructing this record never claims that a suite has run.
{ lib }:
{ pkgs, mkRecipe, entryId, requiredServices ? [ ], providedServices ? { } }:
let
  haskellLib = pkgs.haskell.lib.compose;
  facts = package: (import ./packageRecipeFacts.nix { inherit lib; }) {
    inherit haskellLib package;
    includeTestDependencies = true;
  };
  baseline = mkRecipe { policyProfile = "strict-v1"; disabledEntryIds = [ ]; inherit providedServices; };
  candidate = mkRecipe { policyProfile = "strict-v1"; disabledEntryIds = [ entryId ]; inherit providedServices; };
  missingServices = builtins.filter
    (name: !(builtins.hasAttr name providedServices
      && builtins.isAttrs providedServices.${name} && providedServices.${name} ? drvPath))
    requiredServices;
  available = missingServices == [ ];
  baselineFacts = facts baseline;
  candidateFacts = facts candidate;
  strict = snapshot: snapshot.effective.testsEnabled == true && snapshot.effective.boundsRelaxed == false
    && !snapshot.effective.testExecution.customCheckPhase
    && snapshot.effective.testExecution.targets == [ "" ]
    && snapshot.effective.testExecution.flags == [ ]
    && !(builtins.any
    (flag: builtins.any (prefix: lib.hasPrefix prefix flag)
      [ "--allow-newer" "--allow-older" "--disable-tests" "--enable-tests=false" ])
    snapshot.effective.configureFlags);
  sameInputs = baselineFacts.sourceIdentity == candidateFacts.sourceIdentity
    && baselineFacts.metadataIdentity == candidateFacts.metadataIdentity
    && baselineFacts.version == candidateFacts.version
    && baseline.compiler.drvPath == candidate.compiler.drvPath
    && baselineFacts.effective.dependencies == candidateFacts.effective.dependencies;
  context = {
    schemaVersion = 1;
    inherit entryId requiredServices missingServices;
    providedServiceProbes = lib.genAttrs requiredServices (name: providedServices.${name}.drvPath);
    status = if available then "unverified" else "blocked";
    policyProfile = "strict-v1";
    tests = "run";
    bounds = "enforce";
    # Native execution and full transitive graph coverage are separate evidence.
    graphStatus = "unverified";
    compiler = baseline.compiler.drvPath;
    system = pkgs.stdenv.hostPlatform.system;
    baseline = baselineFacts;
    candidate = candidateFacts;
  };
in
assert lib.assertMsg (builtins.isString entryId && builtins.match ".*[^[:space:]].*" entryId != null) "package validation: missing entry ID";
assert lib.assertMsg
  (builtins.isList requiredServices && builtins.all (name: builtins.isString name && name != "") requiredServices
    && lib.unique requiredServices == requiredServices) "package validation: invalid or duplicate service requirement";
if !available then {
  baseline = null;
  candidate = null;
  context = { inherit entryId missingServices; schemaVersion = 1; status = "blocked"; policyProfile = "strict-v1"; };
} else
  assert lib.assertMsg (strict baselineFacts && strict candidateFacts)
    "package validation: constructor did not retain standard enabled Cabal suites and disabled jailbreak";
  assert lib.assertMsg sameInputs "package validation: removal changed selected source, metadata, compiler or dependency instances";
  {
    inherit baseline candidate;
    context = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON (context // {
      inputIdentity = builtins.hashString "sha256" (builtins.unsafeDiscardStringContext (builtins.toJSON context));
    })));
  }
