# Preserve reviewed legacy argument spelling without editing converter output.
{ lib }:
{ name, version, metadataSha256, selectedFlags, rules, haskellLib, package }:
let
  fields = [ "flags" "metadataSha256" "reason" "version" ];
  validRow = row: builtins.isAttrs row && builtins.attrNames row == fields
    && builtins.isString row.version && row.version != ""
    && builtins.isString row.metadataSha256
    && builtins.match "[0-9a-f]{64}" row.metadataSha256 != null
    && builtins.isString row.reason && row.reason != ""
    && builtins.isAttrs row.flags && row.flags != { }
    && builtins.all
    (flag: builtins.match "[a-z0-9][a-z0-9-]*" flag != null && row.flags.${flag} == false)
    (builtins.attrNames row.flags);
  valid = builtins.isAttrs rules && builtins.all validRow (builtins.attrValues rules);
  row = rules.${name} or null;
  applies = row != null && row.version == version && row.metadataSha256 == metadataSha256;
  names = builtins.attrNames row.flags;
  remove = map (flag: "-f-${flag}") names;
in
if !valid then throw "generated recipe flags: invalid reviewed spelling rules"
else if !applies then package
else if !builtins.all (flag: (selectedFlags.${flag} or null) == false) names then
  throw "generated recipe flags: selected flags differ from reviewed defaults for ${name}"
else
  haskellLib.overrideCabal
    (attrs:
    let flags = attrs.configureFlags or [ ]; in
    if !builtins.isList flags || !builtins.all (flag: builtins.elem flag flags) remove then
      throw "generated recipe flags: expected converter spelling missing for ${name}"
    else { configureFlags = builtins.filter (flag: !(builtins.elem flag remove)) flags; })
    package
