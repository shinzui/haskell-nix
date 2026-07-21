# mkFirstPartyRegistries ::
#   { sources : AttrSet Path, config : FamilyConfig, lock : PackageLock }
#   -> { github : Registry, hackage : Registry }
{ lib }:

{ sources, config, lock }:

let
  exactAttrs = required: optional: value:
    builtins.isAttrs value
    && builtins.all (name: builtins.hasAttr name value) required
    && builtins.all
      (name: builtins.elem name (required ++ optional))
      (builtins.attrNames value);

  nonEmptyString = value: builtins.isString value && value != "";

  allUnique = values:
    builtins.length values == builtins.length (lib.unique values);

  isSorted = values: values == lib.sort builtins.lessThan values;

  validVersion = value:
    nonEmptyString value
    && builtins.match "[0-9]+(\\.[0-9]+)*" value != null;

  validHash = value:
    nonEmptyString value
    && builtins.match "sha256-[A-Za-z0-9+/]{43}=" value != null;

  validGitRevision = value:
    nonEmptyString value
    && builtins.match "[0-9a-fA-F]{40}" value != null;

  # A package that occupies its whole repository records the root path ".";
  # every other package records a clean relative path below the repository root.
  rootPath = ".";

  validRelativePath = value:
    value == rootPath
    || (
      nonEmptyString value
      && !(lib.hasPrefix "/" value)
      && builtins.all
        (segment: segment != "" && segment != "." && segment != "..")
        (lib.splitString "/" value)
    );

  validOverride = value:
    exactAttrs [ ] [ "cabal2nixOptions" ] value
    && builtins.isString (value.cabal2nixOptions or "");

  validConfigFamily = family:
    exactAttrs
      [ "name" "moriProject" "github" "githubInput" ]
      [ "packageOverrides" ]
      family
    && nonEmptyString family.name
    && nonEmptyString family.moriProject
    && nonEmptyString family.github
    && builtins.match "[^/]+/[^/]+" family.github != null
    && nonEmptyString family.githubInput
    && family.githubInput == "${family.name}-src"
    && (
      let overrides = family.packageOverrides or { };
      in builtins.isAttrs overrides
      && builtins.all validOverride (builtins.attrValues overrides)
    );

  configTopValid =
    exactAttrs [ "schemaVersion" "families" ] [ ] config
    && config.schemaVersion == 1
    && builtins.isList config.families;

  configFamiliesValid =
    configTopValid && builtins.all validConfigFamily config.families;

  configFamilyNames =
    if configFamiliesValid then map (family: family.name) config.families else [ ];

  configInputNames =
    if configFamiliesValid then map (family: family.githubInput) config.families else [ ];

  configUniquenessValid =
    configFamiliesValid
    && allUnique configFamilyNames
    && allUnique configInputNames
    && isSorted configFamilyNames;

  validHackage = value:
    exactAttrs [ "version" "hash" ] [ ] value
    && validVersion value.version
    && validHash value.hash;

  validLockedPackage = package:
    exactAttrs
      [ "name" "path" "version" "cabal2nixOptions" "hackage" ]
      [ ]
      package
    && nonEmptyString package.name
    && validRelativePath package.path
    && validVersion package.version
    && builtins.isString package.cabal2nixOptions
    && (package.hackage == null || validHackage package.hackage);

  validLockFamily = family:
    exactAttrs [ "name" "githubInput" "githubRev" "packages" ] [ ] family
    && nonEmptyString family.name
    && nonEmptyString family.githubInput
    && validGitRevision family.githubRev
    && builtins.isList family.packages
    && builtins.all validLockedPackage family.packages
    && isSorted (map (package: package.name) family.packages);

  lockTopValid =
    exactAttrs [ "schemaVersion" "families" ] [ ] lock
    && lock.schemaVersion == 1
    && builtins.isList lock.families;

  lockFamiliesValid = lockTopValid && builtins.all validLockFamily lock.families;

  lockFamilyNames =
    if lockFamiliesValid then map (family: family.name) lock.families else [ ];

  allLockedPackageNames =
    if lockFamiliesValid
    then lib.concatMap (family: map (package: package.name) family.packages) lock.families
    else [ ];

  lockUniquenessValid =
    lockFamiliesValid
    && allUnique lockFamilyNames
    && isSorted lockFamilyNames
    && allUnique allLockedPackageNames;

  configByName = lib.listToAttrs (map
    (family: { name = family.name; value = family; })
    config.families);

  crossFileValid =
    configUniquenessValid
    && lockUniquenessValid
    && builtins.isAttrs sources
    && configFamilyNames == lockFamilyNames
    && builtins.all
      (lockedFamily:
        let
          configuredFamily = configByName.${lockedFamily.name};
          packageNames = map (package: package.name) lockedFamily.packages;
          overrides = configuredFamily.packageOverrides or { };
          expectedOptions = packageName:
            if builtins.hasAttr packageName overrides
            then overrides.${packageName}.cabal2nixOptions or ""
            else "";
        in
        lockedFamily.githubInput == configuredFamily.githubInput
        && builtins.hasAttr lockedFamily.githubInput sources
        && builtins.all
          (overrideName: builtins.elem overrideName packageNames)
          (builtins.attrNames overrides)
        && builtins.all
          (package: package.cabal2nixOptions == expectedOptions package.name)
          lockedFamily.packages)
      lock.families;

  validation =
    if !configTopValid then
      throw "mkFirstPartyRegistries: family config must use schemaVersion 1 and only the documented top-level fields"
    else if !configFamiliesValid then
      throw "mkFirstPartyRegistries: a family config record is malformed or contains an unknown field"
    else if !configUniquenessValid then
      throw "mkFirstPartyRegistries: config family names and input names must be unique and families sorted"
    else if !lockTopValid then
      throw "mkFirstPartyRegistries: package lock must use schemaVersion 1 and only the documented top-level fields"
    else if !lockFamiliesValid then
      throw "mkFirstPartyRegistries: a package lock record is malformed, unsorted, or contains an unknown field"
    else if !lockUniquenessValid then
      throw "mkFirstPartyRegistries: lock family and package names must be globally unique and families sorted"
    else if !crossFileValid then
      throw "mkFirstPartyRegistries: config, lock, source inputs, and Cabal2nix options do not agree"
    else
      true;

  wrapPackage = haskellLib: package:
    haskellLib.dontCheck (haskellLib.doJailbreak package);

  # Selecting a monorepo subdirectory as a Nix source can leave links such as
  # LICENSE -> ../LICENSE or vendor -> ../vendor dangling in the copied source
  # tree. Stage matching repository-root entries before Cabal configures the
  # package.
  stageFamilyLinks = haskellLib: familySource: packageSource: package:
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
    if inheritedLinkNames == [ ] then package
    else
      haskellLib.overrideCabal
        (drv: {
          prePatch = (drv.prePatch or "")
            + lib.concatMapStrings stageLink inheritedLinkNames;
        })
        package;

  mkGithubEntry = family: package: {
    name = package.name;
    value = [{
      always = true;
      patch = { hself, haskellLib, ... }:
        let
          familySource = sources.${family.githubInput};
          isRootPackage = package.path == rootPath;
          source =
            if isRootPackage
            then familySource
            else familySource + "/${package.path}";
          rawPackage =
            if package.cabal2nixOptions == ""
            then hself.callCabal2nix package.name source { }
            else
              hself.callCabal2nixWithOptions
                package.name
                source
                package.cabal2nixOptions
                { };
          # A root package already owns every repository-root entry, so there is
          # nothing to inherit from an enclosing tree.
          calledPackage =
            if isRootPackage
            then rawPackage
            else stageFamilyLinks haskellLib familySource source rawPackage;
        in
        wrapPackage haskellLib calledPackage;
    }];
  };

  mkHackageEntry = package: {
    name = package.name;
    value = [{
      always = true;
      patch = { hself, haskellLib, ... }:
        wrapPackage haskellLib (hself.callHackageDirect
          {
            pkg = package.name;
            ver = package.hackage.version;
            sha256 = package.hackage.hash;
          }
          { });
    }];
  };

  githubEntries = lib.concatMap
    (family: map (mkGithubEntry family) family.packages)
    lock.families;

  hackageEntries = lib.concatMap
    (family: map mkHackageEntry
      (builtins.filter (package: package.hackage != null) family.packages))
    lock.families;
in
builtins.seq validation {
  github = lib.listToAttrs githubEntries;
  hackage = lib.listToAttrs hackageEntries;
}
