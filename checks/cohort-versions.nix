{ lib, pkgs, scopes }:
let
  cohort = import ../generated/cohort-versions.nix;
  expected = lib.filterAttrs
    (name: package: package.source != "Boot"
      && !(builtins.hasAttr name cohort.policy && !cohort.policy.${name}.sourcePinned))
    cohort.sourceManifest;
  compare = scope: builtins.filter (entry: entry.actual != entry.expected)
    (lib.mapAttrsToList
      (name: package:
        let
          attempted = builtins.tryEval
            (if builtins.hasAttr name scope && scope.${name} != null then scope.${name}.version else "<missing>");
        in
        { inherit name; expected = package.version; actual = if attempted.success then attempted.value else "<error>"; })
      expected);
  results = lib.mapAttrs (_: compare) scopes;
  clean = builtins.all (entries: entries == [ ]) (builtins.attrValues results);
  diagnostics = pkgs.writeText "cohort-version-mismatches.json" (builtins.toJSON results);
in
pkgs.runCommand "cohort-versions"
{
  passthru.results = results;
}
  ''
    if ${if clean then "true" else "false"}; then
      touch "$out"
    else
      echo 'cohort-versions: composed package versions differ from the frozen sources' >&2
      cat ${diagnostics} >&2
      exit 1
    fi
  ''
