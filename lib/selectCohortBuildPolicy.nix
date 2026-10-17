# Select a narrower policy for an explicitly verified source/context. These are
# eligibility guards, not alternate source pins; the cohort still owns sources.
{ lib
, selections ? builtins.fromJSON (builtins.readFile ../config/cohort-build-policy-selections.json)
, profiles ? (builtins.fromJSON (builtins.readFile ../config/package-build-policies.json)).profiles
}:
let
  exact = fields: value: builtins.isAttrs value
    && builtins.attrNames value == lib.sort builtins.lessThan fields;
  text = value: builtins.isString value && builtins.match ".*[^[:space:]].*" value != null;
  strings = values: builtins.isList values && values != [ ]
    && lib.unique values == values && builtins.all text values;
  version = value: text value && builtins.match "[0-9]+(\\.[0-9]+)*" value != null;
  sourceHash = value: builtins.isString value
    && builtins.match "sha256-[A-Za-z0-9+/]{43}=" value != null;
  metadataHash = value: sourceHash value || (builtins.isString value
    && builtins.match "[0-9a-f]{64}" value != null);
  revision = value: value == null || (exact [ "number" "sha256" ] value
    && text value.number && builtins.match "[0-9]+" value.number != null
    && metadataHash value.sha256);
  strict = profile: profile.construction == "complete"
    && profile.tests == { mode = "run"; services = [ ]; exceptionIds = [ ]; }
    && profile.bounds == { mode = "enforce"; exceptionIds = [ ]; };
  validRule = rule:
    exact [ "id" "package" "profile" "owner" "reason" "evidence" "eligibility" ] rule
    && text rule.id && text rule.package && text rule.profile
    && builtins.hasAttr rule.profile profiles && strict profiles.${rule.profile}
    && builtins.isString rule.owner && builtins.match "mori://[^/]+/[^/]+" rule.owner != null
    && text rule.reason && strings rule.evidence
    && (
      let eligible = rule.eligibility; in
      exact [ "compilers" "systems" "channels" "version" "sha256" "revision" ] eligible
      && strings eligible.compilers && builtins.all version eligible.compilers
      && strings eligible.systems && builtins.all
        (system: builtins.elem system [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ])
        eligible.systems
      && strings eligible.channels && builtins.all
        (channel: builtins.elem channel [ "github" "hackage" ])
        eligible.channels
      && version eligible.version && sourceHash eligible.sha256 && revision eligible.revision
    );
  rules = selections.selections;
  overlap = left: right: left.id != right.id && left.package == right.package
    && lib.intersectLists left.eligibility.compilers right.eligibility.compilers != [ ]
    && lib.intersectLists left.eligibility.systems right.eligibility.systems != [ ]
    && lib.intersectLists left.eligibility.channels right.eligibility.channels != [ ];
  validation =
    if !(exact [ "schemaVersion" "selections" ] selections && selections.schemaVersion == 1
      && builtins.isList rules && builtins.all validRule rules) then
      throw "cohort build policy: malformed selection or non-strict/service-dependent profile"
    else if lib.unique (map (rule: rule.id) rules) != map (rule: rule.id) rules then
      throw "cohort build policy: duplicate selection ID"
    else if builtins.any (left: builtins.any (overlap left) rules) rules then
      throw "cohort build policy: overlapping context selections"
    else true;
  # Exclude ownership prose and evidence observations from recipe policy identity.
  semanticSelections = map (rule: { inherit (rule) id package profile eligibility; }) rules;
  select = { name, entry, compiler, system, channel }:
    let
      named = builtins.filter (rule: rule.package == name) rules;
      matches = builtins.filter
        (rule: builtins.elem compiler rule.eligibility.compilers
          && builtins.elem system rule.eligibility.systems
          && builtins.elem channel rule.eligibility.channels)
        named;
      chosen = builtins.head matches;
      eligible = chosen.eligibility;
    in
    if matches == [ ] then { profile = "legacy-skip-enforce-v1"; selectionId = null; }
    else if entry.version != eligible.version || entry.sha256 != eligible.sha256
      || entry.revision != eligible.revision then
      throw "cohort build policy: ${name}/${chosen.id} source or metadata changed; revalidate or explicitly review its policy selection"
    else { profile = chosen.profile; selectionId = chosen.id; };
in
builtins.seq validation { inherit select semanticSelections; }
