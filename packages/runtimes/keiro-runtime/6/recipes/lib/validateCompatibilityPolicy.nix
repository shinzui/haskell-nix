# Validate descriptive coverage without evaluating any package or patch function.
{ lib }:
{ catalog, policies, recipeBindings }:
let
  exact = keys: value: builtins.isAttrs value && builtins.attrNames value == lib.sort builtins.lessThan keys;
  text = value: builtins.isString value && builtins.match ".*[^[:space:]].*" value != null;
  unique = values: builtins.length values == builtins.length (lib.unique values);
  strings = values: builtins.isList values && builtins.all text values && unique values;
  version = value: text value && builtins.match "[0-9]+(\\.[0-9]+)*" value != null;
  range = value: value == null || (exact [ "min" "max" "exact" ] value && (
    if value.exact != null then strings value.exact && value.exact != [ ] && builtins.all version value.exact && value.min == null && value.max == null
    else version value.min && version value.max
      && lib.versionOlder value.min value.max
  ));
  entries = catalog.entries;
  ids = map (entry: entry.id) entries;
  byId = lib.listToAttrs (map (entry: lib.nameValuePair entry.id entry) entries);
  profileNames = builtins.attrNames policies.profiles;
  immutableModes = {
    legacy-first-party-v1 = [ "skip" "relax" ];
    legacy-skip-relax-v1 = [ "skip" "relax" ];
    legacy-skip-enforce-v1 = [ "skip" "enforce" ];
    legacy-run-relax-v1 = [ "run" "relax" ];
    strict-v1 = [ "run" "enforce" ];
    verified-bytestring-lexing-ghc9124-v1 = [ "run" "enforce" ];
  };
  knownEffects = [ "source-replacement" "cabal-metadata" "source-patch" "source-assertion" "compiler-flags" "bound-relaxation" "test-suppression" "unbreaking" "native-input" "platform-policy" ];
  validBinding = binding:
    if (binding.kind or null) == "registry-row" then
      exact [ "kind" "package" "row" ] binding && text binding.package && builtins.isInt binding.row && binding.row >= 0
    else exact [ "kind" "name" ] binding
      && builtins.elem binding.kind [ "profile" "generated-first-party" "generated-cohort" ] && text binding.name;
  validEntry = entry:
    exact [ "id" "kind" "owner" "reason" "upstreamReferences" "effects" "applicability" "binding" "evidence" "retirement" ] entry
    && text entry.id && builtins.elem entry.kind [ "source-selection" "compatibility-repair" "build-policy" ]
    && builtins.isString entry.owner && builtins.match "mori://[^/]+/[^/]+(/.*)?" entry.owner != null
    && text entry.reason && strings entry.upstreamReferences
    && strings entry.effects && entry.effects != [ ] && builtins.all (effect: builtins.elem effect knownEffects) entry.effects
    && validBinding entry.binding
    && (
      let scope = entry.applicability; in
      exact [ "packages" "channels" "compiler" "systems" "versions" "sourceGuard" "layer" ] scope
      && (scope.packages == null || (strings scope.packages && scope.packages != [ ]))
      && strings scope.channels && scope.channels != [ ] && builtins.all (channel: builtins.elem channel [ "github" "hackage" ]) scope.channels
      && range scope.compiler && range scope.versions
      && (scope.systems == null || (strings scope.systems && scope.systems != [ ]
      && builtins.all (system: builtins.elem system [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ]) scope.systems))
      && builtins.elem scope.layer [ "selected-source" "after-first-party" ]
      && (scope.sourceGuard == null || (exact [ "status" "implementation" ] scope.sourceGuard
      && scope.sourceGuard.status == "enforced-in-recipe" && strings scope.sourceGuard.implementation && scope.sourceGuard.implementation != [ ]))
    )
    && exact [ "status" "requirements" "references" ] entry.evidence
    && entry.evidence.status == "unverified" && strings entry.evidence.requirements && entry.evidence.requirements != [ ]
    && entry.evidence.references == [ ]
    && exact [ "kind" "condition" "threshold" ] entry.retirement
    && builtins.elem entry.retirement.kind [ "review" "admitting-metadata" "compiler-probe" "selected-version" ]
    && text entry.retirement.condition && (entry.retirement.threshold == null || text entry.retirement.threshold);
  validPolicy = name: profile:
    exact [ "tests" "bounds" "construction" ] profile
    && exact [ "mode" "services" "exceptionIds" ] profile.tests
    && exact [ "mode" "exceptionIds" ] profile.bounds
    && builtins.elem profile.tests.mode [ "run" "skip" ] && strings profile.tests.services
    && builtins.elem profile.bounds.mode [ "enforce" "relax" ]
    && builtins.elem profile.construction [ "complete" "legacy-layer" ]
    && (if builtins.elem name [ "strict-v1" "verified-bytestring-lexing-ghc9124-v1" ] then profile.construction == "complete"
    else if builtins.hasAttr name immutableModes then profile.construction == "legacy-layer"
    else profile.construction == "complete")
    && (immutableModes.${name} or [ profile.tests.mode profile.bounds.mode ]) == [ profile.tests.mode profile.bounds.mode ]
    && (
      let
        validWaivers = effect: needed: references:
          strings references && (if needed then references != [ ] else references == [ ])
          && builtins.all
            (id: builtins.hasAttr id byId && byId.${id}.binding == { kind = "profile"; inherit name; }
            && builtins.elem effect byId.${id}.effects)
            references;
      in
      validWaivers "test-suppression" (profile.tests.mode == "skip") profile.tests.exceptionIds
      && validWaivers "bound-relaxation" (profile.bounds.mode == "relax") profile.bounds.exceptionIds
    );
  declaredBindings = map (entry: entry.binding) entries;
  bindingExists = binding: builtins.elem binding recipeBindings;
  validation =
    if !(exact [ "schemaVersion" "entries" ] catalog && catalog.schemaVersion == 1 && builtins.isList entries) then
      throw "compatibility policy: catalog must use schemaVersion 1 and entries"
    else if !builtins.all validEntry entries then throw "compatibility policy: malformed entry, scope, owner, effects, evidence or retirement"
    else if !unique ids then throw "compatibility policy: duplicate exception ID"
    else if !(exact [ "schemaVersion" "profiles" ] policies && policies.schemaVersion == 1 && builtins.isAttrs policies.profiles) then
      throw "compatibility policy: malformed build-policy profiles"
    else if !builtins.all (name: validPolicy name policies.profiles.${name}) profileNames then
      throw "compatibility policy: invalid policy mode or missing/dangling waiver reference"
    else if !builtins.all bindingExists declaredBindings then throw "compatibility policy: orphan exception recipe binding"
    else if !builtins.all (binding: builtins.elem binding declaredBindings) recipeBindings then
      throw "compatibility policy: recipe binding lacks exception coverage"
    else true;
in
builtins.seq validation { inherit catalog policies byId; }
