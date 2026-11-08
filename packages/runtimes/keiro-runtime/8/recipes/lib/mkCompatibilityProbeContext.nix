# Explicit native verification plan. Graphs use the existing cohort producer;
# behavioral/service probes are sandboxed check derivations, never shell strings.
{ lib }:
{ validation, graphs, requiredSuites, behaviorProbes, channel, policyIdentity }:
let
  phases = [ "baseline" "candidate" ];
  check = phase:
    let
      graph = graphs.${phase};
      package = validation.${phase};
    in
    assert lib.assertMsg
      (graph.declaration.root.drvPath == package.drvPath
        && graph.declaration.compiler.drvPath == validation.context.compiler
        && graph.declaration.system == validation.context.system)
      "compatibility probe: graph does not describe the selected strict package";
    {
      graph = { derivation = graph.drvPath; inherit (graph) declaration; };
      behaviorProbes = lib.mapAttrs (_: probe: probe.drvPath) behaviorProbes.${phase};
    };
  context = {
    schemaVersion = 1;
    kind = "native-compatibility-probe";
    inherit channel policyIdentity requiredSuites;
    validation = validation.context;
    phases = lib.genAttrs phases check;
  };
in
assert lib.assertMsg (validation.context.status == "unverified") "compatibility probe: validation is blocked";
assert lib.assertMsg (builtins.isString policyIdentity && builtins.match "[0-9a-f]{64}" policyIdentity != null)
  "compatibility probe: semantic policy identity required";
assert lib.assertMsg (builtins.elem channel [ "github" "hackage" ]) "compatibility probe: invalid channel";
assert lib.assertMsg
  (requiredSuites != [ ] && lib.unique requiredSuites == requiredSuites
    && builtins.all (suite: builtins.isString suite && suite != "") requiredSuites)
  "compatibility probe: explicit complete suite inventory required";
assert lib.assertMsg (builtins.all (phase: builtins.attrNames behaviorProbes.${phase} != [ ]) phases)
  "compatibility probe: native behavior checks required for both packages";
builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON context))
