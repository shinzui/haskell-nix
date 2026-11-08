{ lib }:
familySource: packageSource:
let
  packageEntries = builtins.readDir packageSource;
  familyEntries = builtins.readDir familySource;
  inheritedLinkNames = builtins.filter
    (name:
      (packageEntries.${name} or null) == "symlink"
      && builtins.hasAttr name familyEntries)
    (builtins.attrNames packageEntries);
  stageLink = name:
    let sourceEntry = familySource + "/${name}";
    in
    ''
      if [ ! -e ${lib.escapeShellArg name} ]; then
        unlink ${lib.escapeShellArg name}
        cp -R ${sourceEntry} ${lib.escapeShellArg name}
      fi
    '';
in
lib.concatMapStrings stageLink inheritedLinkNames
