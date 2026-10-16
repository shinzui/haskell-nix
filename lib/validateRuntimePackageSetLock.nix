{ lib }:
{ config, lock, firstPartyLock, root ? ../., readProjection ? (path: builtins.readFile (root + "/${path}")) }:
let
  require = condition: message: if condition then true else throw "runtime lock: ${message}";
  exact = names: value: builtins.isAttrs value && builtins.attrNames value == builtins.sort builtins.lessThan names;
  unique = values: builtins.length (lib.unique values) == builtins.length values;
  hash = value: builtins.isString value && builtins.match "[0-9a-fA-F]{64}" value != null;
  name = value: builtins.isString value && builtins.match "[a-z0-9-]+" value != null;
  project = value: builtins.isString value && builtins.match "mori://[^/]+/[^/]+" value != null;
  path = value: builtins.isString value && value != "" && !(lib.hasPrefix "/" value)
    && builtins.all (part: !(builtins.elem part [ "" "." ".." ])) (lib.splitString "/" value);
  requiredProjects = map (name: "mori://shinzui/${name}") [ "keiki" "keiro" "kiroku" "shibuya" "pgmq-hs" "settei" "pg-migrate" "hw-kafka-client" ];
  requiredGroups = [ "keiki" "keiro" "kiroku" "shibuya" "pgmq-hs" "settei" "pg-migrate" ];
  requiredRoots = [ "keiki" "keiki-codec-json" "keiro" "kiroku-store" "shibuya-core" "pgmq-core" "settei" "pg-migrate" "hw-kafka-client" "shibuya-pgmq-adapter" "shibuya-kiroku-adapter" "shibuya-kafka-adapter" "kafka-effectful" "hw-kafka-streamly" ];
  hasAll = required: actual: builtins.all (value: builtins.elem value actual) required;
  validateDefinition = runtime: definition:
    require
      (name runtime && exact [ "projects" "groups" "roots" ] definition
        && unique definition.projects && unique definition.groups && definition.groups != [ ]
        && builtins.all project definition.projects && builtins.attrNames definition.roots != [ ]
        && hasAll definition.projects (map (entry: entry.project) (builtins.attrValues definition.roots))
        && builtins.all
        (package:
          let entry = definition.roots.${package}; in name package
            && exact [ "project" "capability" "role" ] entry && project entry.project
            && builtins.elem entry.capability [ "core" "pgmq" "kafka" ]
            && builtins.elem entry.role [ "library" "test" "build-tool" ])
        (builtins.attrNames definition.roots)
        && (runtime != "keiro-runtime" || (hasAll requiredProjects definition.projects
        && hasAll requiredGroups definition.groups && hasAll requiredRoots (builtins.attrNames definition.roots))))
      "invalid definition or missing required roots/projects: ${runtime}";
  knownGroup = group: generation: builtins.any
    (snapshot: snapshot.group == group && snapshot.generation == generation)
    firstPartyLock.groupSnapshots;
  closure = packages: visited: pending:
    if pending == [ ] then builtins.sort builtins.lessThan visited else
    let current = builtins.head pending; rest = builtins.tail pending;
    in if builtins.elem current visited then closure packages visited rest
    else if !(builtins.hasAttr current packages) then throw "runtime lock: missing dependency ownership: ${current}"
    else closure packages (visited ++ [ current ]) (packages.${current}.dependencies ++ rest);
  configuration = value: exact [ "system" "compiler" "channel" "disableProfiling" "disableHaddock" ] value
    && builtins.elem value.system [ "aarch64-darwin" "x86_64-linux" ] && value.compiler == "ghc9124"
    && builtins.elem value.channel [ "github" "hackage" ] && value.disableProfiling == true && value.disableHaddock == true;
  validateRecord = definition: record:
    let
      packageNames = builtins.attrNames record.ownership;
      selectionNames = builtins.attrNames record.selections;
      projectionNames = builtins.attrNames record.projections;
    in
    require
      (exact [ "generation" "selections" "configurations" "roots" "ownership" "roles" "components" "projections" "fingerprint" "recipeDirectory" "freezeFile" "sourceFile" "versionFile" "policyFile" ] record
        && builtins.isInt record.generation && record.generation > 0 && hash record.fingerprint
        && selectionNames == builtins.sort builtins.lessThan definition.groups
        && builtins.all (group: knownGroup group record.selections.${group}) selectionNames
        && record.configurations != [ ] && unique record.configurations && builtins.all configuration record.configurations
        && record.roots == builtins.attrNames definition.roots
        && closure record.ownership [ ] record.roots == packageNames
        && builtins.attrNames record.roles == packageNames
        && builtins.all
        (package:
          let entry = record.ownership.${package}; roles = record.roles.${package};
          in entry.identities != [ ]
            && builtins.all (identity: (identity.pkg-name or null) == package && (identity.pkg-version or null) == entry.version) entry.identities
            && builtins.all
            (identity:
              builtins.all (field: (identity.${field} or null) == ((builtins.head entry.identities).${field} or null))
                [ "pkg-src" "pkg-src-sha256" "pkg-cabal-sha256" "flags" ])
            entry.identities
            && builtins.match "[0-9]+(\\.[0-9]+)*" entry.version != null
            && roles != [ ] && unique roles && hasAll roles [ "library" "test" "build-tool" "compiler" ])
        packageNames
        && hasAll (builtins.attrNames record.components) packageNames
        && projectionNames != [ ] && builtins.all path projectionNames
        && builtins.all
        (file: hash record.projections.${file}
          && builtins.hashString "sha256" (readProjection file) == record.projections.${file})
        projectionNames
        && hasAll [ record.freezeFile record.sourceFile record.versionFile record.policyFile ] projectionNames
        && path record.recipeDirectory && builtins.any (lib.hasPrefix "${record.recipeDirectory}/") projectionNames)
      "invalid generation, ownership, support configuration or projection hash";
  checks = [
    (require (exact [ "schemaVersion" "runtimes" ] config && config.schemaVersion == 1 && builtins.attrNames config.runtimes != [ ]) "invalid runtime config schema")
    (require (exact [ "schemaVersion" "runtimes" ] lock && lock.schemaVersion == 1 && builtins.attrNames lock.runtimes == builtins.attrNames config.runtimes) "runtime lock names/schema disagree")
  ] ++ lib.concatMap
    (runtime:
      let definition = config.runtimes.${runtime}; records = lock.runtimes.${runtime}; generations = map (record: record.generation) records;
      in [
        (validateDefinition runtime definition)
        (require (builtins.all (group: builtins.any (snapshot: snapshot.group == group) firstPartyLock.groupSnapshots) definition.groups) "unknown runtime group")
        (require (unique generations && generations == builtins.sort builtins.lessThan generations) "runtime generations must be unique and ordered")
      ] ++ map (validateRecord definition) records)
    (builtins.attrNames config.runtimes);
in
builtins.deepSeq checks lock
