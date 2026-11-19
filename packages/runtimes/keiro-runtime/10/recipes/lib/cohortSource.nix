# Shared actual-source facts for manifests and retained runtime components.
{ lib }:
{
  record = source:
    if source == null then null else {
      path = "${source}";
      hash = if builtins.isAttrs source then source.outputHash or source.narHash or null else null;
      hashMode = if builtins.isAttrs source then source.outputHashMode or null else null;
      urls = if builtins.isAttrs source then source.urls or (lib.optional (source ? url) source.url) else [ ];
      revision = if builtins.isAttrs source then source.rev or null else null;
    };
  originPath = origin: "${origin.source}" + lib.optionalString
    (!(builtins.elem origin.subdirectory [ "" "." ])) "/${origin.subdirectory}";
}
