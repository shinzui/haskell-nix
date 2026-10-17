# Read-only declaration report. Callers supply facts from the selected source
# layer, before compatibility repairs; final package versions are not substitutes.
{ lib, policy ? (import ./mkCompatibilityPolicy.nix { inherit lib; }) (import ../overlays/registry.nix) }:
{ packageSet, channel, ghc, system, packages, runtimeConfiguration ? null, requiredEvidence ? [ ] }:
let
  select = import ./selectCompatibilityEntry.nix { inherit lib; };
  applies = import ./compatibilityEntryApplies.nix { inherit lib; catalog = policy.catalog; };
  nonempty = value: builtins.isString value && builtins.match ".*[^[:space:]].*" value != null;
  unique = values: lib.unique values == values;
  version = value: nonempty value && builtins.match "[0-9]+(\\.[0-9]+)*" value != null;
  factsValid = facts:
    builtins.isAttrs facts && lib.all (key: nonempty (facts.${key} or null))
      [ "version" "sourceIdentity" "metadataIdentity" "derivation" ]
    && version facts.version
    && builtins.isList (facts.profiles or [ ])
    && unique (facts.profiles or [ ])
    && lib.all (name: builtins.hasAttr name policy.policies.profiles) (facts.profiles or [ ])
    && builtins.isList (facts.generated or [ ])
    && unique (facts.generated or [ ])
    && lib.all (kind: builtins.elem kind [ "generated-first-party" "generated-cohort" ]) (facts.generated or [ ])
    && (!(facts ? selectedExceptionIds) || (builtins.isList facts.selectedExceptionIds
    && unique facts.selectedExceptionIds && lib.all (id: builtins.elem id ids) facts.selectedExceptionIds));
  configuration = { inherit packageSet channel ghc system runtimeConfiguration; };
  ids = map (entry: entry.id) policy.catalog.entries;
  valid = nonempty packageSet && builtins.elem channel [ "github" "hackage" ]
    && version ghc.version && nonempty ghc.derivation && nonempty system
    && builtins.isAttrs packages && lib.all factsValid (builtins.attrValues packages)
    && builtins.isList requiredEvidence && unique requiredEvidence && lib.all (id: builtins.elem id ids) requiredEvidence;
  selectedFor = name: facts:
    select (policy.registry.${name} or [ ]) { inherit (facts) version; };
  relevant = entry: name: facts:
    let binding = entry.binding; in
    if binding.kind == "registry-row" then binding.package == name
    else if binding.kind == "profile" then builtins.elem binding.name (facts.profiles or [ ])
    else builtins.elem binding.kind (facts.generated or [ ]);
  rowSelected = entry: name: facts:
    if facts ? selectedExceptionIds then builtins.elem entry.id facts.selectedExceptionIds else
    entry.binding.kind != "registry-row" ||
    (let row = selectedFor name facts; in row != null && builtins.elem entry.id row.exceptionIds);
  describe = entry: name:
    let
      facts = packages.${name};
      selectedInputs = facts.inputsByException.${entry.id} or facts;
      selected = rowSelected entry name facts;
      inScope = applies entry.id { inherit channel system; inherit (selectedInputs) version; compiler = ghc.version; }
        && (entry.applicability.packages == null || builtins.elem name entry.applicability.packages);
      active = selected && inScope;
      construction = facts.construction.${entry.id} or null;
      constructionProblems = if !active || construction == null then [ ] else
      lib.optional (builtins.elem "test-suppression" entry.effects && construction.after.effective.testsEnabled != false)
        "declared test suppression not visible: ${entry.id}/${name}"
      ++ lib.optional (builtins.elem "bound-relaxation" entry.effects && construction.after.effective.boundsRelaxed != true)
        "declared bounds relaxation not visible: ${entry.id}/${name}";
      metadataAlreadySelected = active && entry.retirement.kind == "admitting-metadata"
        && construction != null && construction.before != null
        && construction.before.metadataIdentity == construction.after.metadataIdentity
        && construction.before.derivation == construction.after.derivation
        && construction.after.effective.editedCabalFile != null;
      candidate = entry.retirement.kind == "selected-version" && entry.retirement.threshold != null
        && lib.versionAtLeast selectedInputs.version entry.retirement.threshold || metadataAlreadySelected;
    in
    {
      inherit (entry) id kind owner reason effects retirement;
      package = name;
      status = if !selected then "inactive-row" else if !inScope then "inactive-scope" else "selected-unverified";
      # Source guards execute in recipes. Never infer their success from scope.
      sourceGuard = if entry.applicability.sourceGuard == null then "not-required" else "unverified";
      evidenceStatus = entry.evidence.status;
      retirementCandidate = candidate;
      unmetChecks = if active || candidate then entry.evidence.requirements else [ ];
      inputs = { inherit (selectedInputs) version sourceIdentity metadataIdentity derivation; };
      required = builtins.elem entry.id requiredEvidence && active;
    } // lib.optionalAttrs (facts ? construction && builtins.hasAttr entry.id facts.construction) {
      inherit construction constructionProblems;
    };
  entries = lib.concatMap
    (entry: map (describe entry)
      (builtins.filter (name: relevant entry name packages.${name}) (builtins.attrNames packages)))
    policy.catalog.entries;
  # A report may intentionally be scoped to a dependency subset. Required IDs
  # must nevertheless have a selected instance rather than disappearing silently.
  missingRequired = builtins.filter
    (id: !lib.any (entry: entry.id == id && entry.status == "selected-unverified") entries)
    requiredEvidence;
  problems = map (id: "required entry has no selected instance: ${id}") missingRequired
    ++ map (entry: "required evidence is unverified: ${entry.id}/${entry.package}")
    (builtins.filter (entry: entry.required) entries)
    ++ lib.concatMap (entry: entry.constructionProblems or [ ]) entries;
  identity = {
    inherit configuration; packages = lib.mapAttrs
    (_: facts: {
      inherit (facts) version sourceIdentity metadataIdentity derivation;
      profiles = facts.profiles or [ ];
      generated = facts.generated or [ ];
    } // lib.optionalAttrs (facts ? construction) {
      capture = { inherit (facts) selectedExceptionIds inputsByException construction; };
    })
    packages;
  };
in
if !valid then throw "compatibility report: invalid configuration, pre-repair input facts or required evidence IDs"
else
  builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.toJSON {
    schemaVersion = 1;
    reportKind = "declaration-only";
    inherit configuration entries requiredEvidence problems;
    unselectedEntries = map (entry: { inherit (entry) id; reason = "no package instance in the supplied scope"; })
      (builtins.filter (entry: !lib.any (name: relevant entry name packages.${name}) (builtins.attrNames packages)) policy.catalog.entries);
    inputIdentity = builtins.hashString "sha256" (builtins.unsafeDiscardStringContext (builtins.toJSON identity));
    # This identity describes semantic policy only, excluding prose and timestamps.
    policyIdentity = builtins.hashString "sha256" (builtins.toJSON {
      profiles = policy.policies;
      entries = map (entry: { inherit (entry) id effects applicability binding; }) policy.catalog.entries;
    });
  }))
