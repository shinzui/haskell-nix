# New catalog bindings must be unambiguous. The public selector independently
# preserves the historical first-always/first-matching rule for legacy callers.
{ lib }:
registry:
let
  valid = row: builtins.isAttrs row && (
    if row.always or false then true else
    row ? min && row ? max && builtins.isString row.min && builtins.isString row.max
      && builtins.match "[0-9]+(\\.[0-9]+)*" row.min != null
      && builtins.match "[0-9]+(\\.[0-9]+)*" row.max != null
      && lib.versionOlder row.min row.max
  );
  overlap = a: b: (a.always or false) || (b.always or false)
    || (lib.versionOlder a.min b.max && lib.versionOlder b.min a.max);
  validate = name: rows:
    if !(builtins.isList rows && builtins.all valid rows) then
      throw "compatibility policy: malformed selector range for ${name}"
    else if lib.any
      (i: lib.any (j: i < j && overlap (builtins.elemAt rows i) (builtins.elemAt rows j))
        (lib.range 0 (builtins.length rows - 1)))
      (lib.range 0 (builtins.length rows - 1)) then
      throw "compatibility policy: overlapping selector rows for ${name}"
    else true;
in
builtins.all (name: validate name registry.${name}) (builtins.attrNames registry)
