# Repository-owned explicit complements for the EP-22 catalog migration.
# The activation guard keeps its committed pre-migration baseline evaluable.
let
  catalog = builtins.fromJSON (builtins.readFile ../config/first-party-families.json);
in
if builtins.any (family: family.name == "heni") catalog.families then {
  heni = 1;
  hinagata = 1;
  shoko = 1;
  typesafe-hs = 1;
} else { }
