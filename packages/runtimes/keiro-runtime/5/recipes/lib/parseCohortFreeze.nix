{ lib }:
text:
let
  trim = value:
    let matched = builtins.match "[ \t]*(.*[^ \t])[ \t]*" value;
    in if matched == null then "" else builtins.head matched;
  lines = map (line: trim (builtins.head (lib.splitString "--" line)))
    (lib.splitString "\n" text);
  fields = lib.foldl'
    (state: line:
      if line == "" then state
      else if lib.hasPrefix "index-state:" line then
        state // { indices = state.indices ++ [ (trim (lib.removePrefix "index-state:" line)) ]; }
      else if lib.hasPrefix "constraints:" line then
        if state.started then throw "cohort freeze: duplicate constraints field"
        else state // { started = true; entries = [ (trim (lib.removePrefix "constraints:" line)) ]; }
      else if state.started then state // { entries = state.entries ++ [ line ]; }
      else throw "cohort freeze: unrecognised line: ${line}")
    { indices = [ ]; entries = [ ]; started = false; }
    lines;
  rawIndex =
    if builtins.length fields.indices != 1 then
      throw "cohort freeze: exactly one index-state is required"
    else builtins.head fields.indices;
  indexState = lib.removePrefix "hackage.haskell.org " rawIndex;
  validIndex = builtins.match "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z" indexState != null;
  pieces = map trim (lib.splitString "," (lib.concatStringsSep " " fields.entries));
  pieceCount = builtins.length pieces;
  entries =
    if pieceCount > 0 && builtins.elemAt pieces (pieceCount - 1) == "" then
      builtins.genList (index: builtins.elemAt pieces index) (pieceCount - 1)
    else pieces;
  parsed = lib.foldl'
    (state: entry:
      let
        version = builtins.match "any\\.([A-Za-z0-9][A-Za-z0-9-]*)[ \t]*==[ \t]*([0-9]+(\\.[0-9]+)*)" entry;
        flags = builtins.match "any\\.([A-Za-z0-9][A-Za-z0-9-]*)[ \t]+(.+)" entry;
      in
      if version != null then
        let name = builtins.elemAt version 0;
        in if builtins.hasAttr name state.constraints then
          throw "cohort freeze: duplicate version for ${name}"
        else state // { constraints = state.constraints // { ${name} = builtins.elemAt version 1; }; }
      else if flags != null then
        let
          name = builtins.elemAt flags 0;
          assignments = builtins.filter (flag: flag != "")
            (lib.splitString " " (builtins.replaceStrings [ "\t" ] [ " " ] (builtins.elemAt flags 1)));
          valid = builtins.all (flag: builtins.match "[+-][A-Za-z0-9_][A-Za-z0-9_-]*" flag != null) assignments;
          names = map (flag: builtins.substring 1 (builtins.stringLength flag) flag) assignments;
        in
        if !valid || assignments == [ ] then throw "cohort freeze: invalid constraint: ${entry}"
        else if builtins.hasAttr name state.flags || builtins.length names != builtins.length (lib.unique names) then
          throw "cohort freeze: duplicate flags for ${name}"
        else state // { flags = state.flags // { ${name} = assignments; }; }
      else throw "cohort freeze: invalid constraint: ${entry}")
    { constraints = { }; flags = { }; }
    entries;
in
if !fields.started || entries == [ ] || parsed.constraints == { } then throw "cohort freeze: version constraints are required"
else if !validIndex then throw "cohort freeze: invalid index-state: ${rawIndex}"
else parsed // { inherit indexState; }
