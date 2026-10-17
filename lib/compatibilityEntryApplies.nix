# Shared activation predicates. Source assertions remain executable build checks;
# matching declared scope never constitutes evidence that those checks passed.
{ lib }:
id: facts:
let
  catalog = builtins.fromJSON (builtins.readFile ../config/compatibility-exceptions.json);
  entries = builtins.filter (entry: entry.id == id) catalog.entries;
  entry =
    if builtins.length entries == 1 then builtins.head entries
    else throw "compatibility predicate: expected one catalog entry ${id}";
  scope = entry.applicability;
  range = constraint: value:
    constraint == null || (value != null && (
      if constraint.exact != null then builtins.elem value constraint.exact
      else lib.versionAtLeast value constraint.min && lib.versionOlder value constraint.max
    ));
in
range scope.compiler (facts.compiler or null)
&& range scope.versions (facts.version or null)
&& (scope.systems == null || builtins.elem (facts.system or null) scope.systems)
  && (if facts ? channel then builtins.elem facts.channel scope.channels
else scope.channels == [ "github" "hackage" ])
