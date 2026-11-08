# A metadata-only derivation lets Nix canonicalize lazy source paths and their
# selected subdirectories. It is never built or included in a runtime closure.
{ lib }:
source:
let
  text = if builtins.isPath source then "${source}" else toString source;
  context = builtins.getContext text;
  projection = builtins.derivation {
    name = "compatibility-source-identity";
    system = "builtin";
    builder = "builtin:compatibility-source-identity";
    src = source;
  };
in
if context == { } then text else
"nix-source:" + builtins.unsafeDiscardStringContext projection.drvPath
