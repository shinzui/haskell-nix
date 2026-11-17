---
id: 23
slug: compose-retained-keiro-generation-9-http-applications
title: "Compose retained Keiro generation 9 HTTP applications"
kind: exec-plan
created_at: 2026-11-17T22:09:40Z
provenance:
  created_by:
    model: "gpt-6.2-sol"
    harness: "codex-cli"
    at: 2026-11-17T22:09:40Z
  revisions:
    - model: "gpt-6.2-sol"
      harness: "codex-cli"
      at: 2026-11-17T23:26:48Z
      mode: "update"
      note: "Audit the real server dependency graph, expand the complement to 12 published recipes, and require exact server derivation parity."
---
# Compose retained Keiro generation 9 HTTP applications

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision
Log, and Outcomes & Retrospective current as work proceeds. Record implementation
friction using `agents/skills/exec-plan/FRICTION.md` and distill durable decisions into
`docs/adr/` at completion.


## Purpose / Big Picture

An HTTP service adopting Keiro runtime generation 9 can use the published health probe
and dynamic SQL libraries through one checked Nix package scope. The service gets
`servant-health` 0.1.0.0 and `hasql-dynamic-statements` 0.5.1.2, can supply its own
immutable Servant instrumentation source, and shares the same runtime builds as other
generation 9 consumers. Compare the production server build to the originating
service's working assembly to catch other missing application recipes. A small
Hackage-channel service proves the HTTP and SQL behavior with an in-process request.

The request is [IR-4](../improvement-requests/document-the-application-complement-for-retained-keiro-http-services.md).
Its linked report is
`mori://tan/tan-app-infrastructure/okf/friction-log/concepts/FRIC-12`, raised while
building `mori://tan/agent-reputation-service/packages/agent-reputation-service-server`.


## Progress

- [ ] Publish an opt-in generation 9 application cohort. The Hackage scope resolves
  the published application recipes, passes the independent runtime identity check,
  and reproduces the originating service's working server derivation.
- [ ] Deliver a runnable HTTP consumer check and adoption instructions. The consumer
  builds with the demonstrated instrumentation pin, answers the health request, renders
  the expected SQL and rejects a runtime-owned recipe replacement.


## Surprises & Discoveries

The initial three-recipe probe passed the generation 9 identity check, but the
production server derivation differed from the service's working assembly. On
`aarch64-darwin` at service revision `6f5578b1dc402e4f26d67dae0c36a71bdf92baa4`,
adding nine published records restored the exact server derivation and all 285
Haskell derivations observed by walking its Cabal dependency fields. Omitting
each of the nine in turn changed the server derivation. For example, the narrow
scope otherwise resolves Hspec to 2.11.17 from Nixpkgs instead of the working
assembly's 2.11.18, and uses a different recipe for `boring` at the same version.
The validation includes the real server graph because the small HTTP fixture alone
does not exercise all of these dependencies.


## Decision Log

- 2026-11-17. Deliver a generation-specific cohort value passed through the existing
  `applicationCohort` argument. The runtime and the general application cohort were
  resolved at different Cabal index cutoffs. Starting with the complete generation 9
  cohort and admitting a short list of published recipes preserves the runtime's
  identity and limits the set of application packages this example selects.
- 2026-11-17. Supply the instrumentation pin through the existing consumer
  `applicationRegistry` argument. The originating service uses a different commit
  from the shared patch, and the runtime lock owns neither source. The guide and the
  fixture will use the service's demonstrated pin as an example.
- 2026-11-17. Require the public complement to reproduce the pinned service's
  existing server derivation. This checks the entire production build graph,
  including version matches with different recipes, and gives a concrete basis
  for choosing which additional published records to include.


## Outcomes & Retrospective


## Context and Orientation

A retained generation captures the versions, sources, Cabal metadata, and build recipes
required by the runtime and its dependencies. A Nix derivation is a build description
identified by its `drvPath`. Comparing those paths checks whether two consumers would
build the same inputs, including transitive dependencies. The Hackage channel uses the
published Haskell package index for first-party releases where available and still
honors explicitly selected source exceptions.

`packages/runtime-lock.json` records generation 9's fingerprint, toolchain, captured
recipe directory and 325 owned names. Of these, 38 are boot packages provided by the
compiler. `lib/mkRuntimePackageSet.nix` loads the full cohort from
`packages/runtimes/keiro-runtime/9/recipes/generated/cohort-versions.nix`. The public
projection `generated/runtimes/keiro-runtime/9.nix` contains the runtime subset.
The constructor checks all runtime-owned cohort entries and rejects registry entries
for any owned name. Its `mkApplicationScope` resolves the application and runtime in
one Haskell package set, so a dependency name resolves to the same package throughout.
It runs `validateApplicationScope` against an independently assembled reference,
comparing GHC and every non-boot owned derivation.

A cohort carries pinned package records. An application complement supplies the
records the application needs in addition to the retained runtime. The published
records in `generated/cohort-versions.nix`, already exported as `lib.cohort.versions`,
include `servant-health` 0.1.0.0, `hasql-dynamic-statements` 0.5.1.2, and its dependency
`hasql-implicits` 0.2.0.3. All three are absent from generation 9 ownership and its
captured version layer. The captured common registry still has compatibility entries
for the first two. A compatibility entry that patches the preceding package cannot
create the package by itself. On the unmodified Darwin Hackage scope, forcing
`servant-health.version` reports `attribute 'servant-health' missing` and
`hasql-dynamic-statements.version` returns `0.3.1.8` from the base package set.

`lib/mkFirstPartyPackageSet.nix` passes the cohort to `lib/mkCohortVersionLayer.nix`.
The latter constructs Hackage recipes using the selected versions and hashes, then
applies the captured build policy. The captured `overlays/cohort-arguments.nix` supplies
the explicit test-only arguments needed to translate dynamic statements 0.5.1.2.
The default build policy skips those upstream tests. Within the same overlay stack,
the captured common registry applies the existing bounds adjustments. A planning
probe added only the three published records to the captured cohort and evaluated their
derivation paths in a checked Hackage scope on Apple Silicon. The three versions
resolved as expected and the scope passed validation. The consumer build and HTTP
smoke test are the implementation milestones.

The originating service composes published records with the generation 9 runtime
projection and passes its own instrumentation recipe into the same constructor.
In the checkout for
`mori://tan/agent-reputation-service/packages/agent-reputation-service-server`,
the project-relative files `nix/runtime-selection.json`, `nix/application-cohort.nix`,
`nix/application-registry.nix` and `nix/haskell-overlay.nix` define that working
assembly (artifact-level source URIs pending). The server derivation recursively
identifies its build inputs, including build-time tools and enabled package tests.
Comparing that path in two scopes built from the same service source catches
silent Nixpkgs fallbacks and source, metadata or policy changes at unchanged
versions.
The shared instrumentation recipe in
`patches/hs-opentelemetry-instrumentation-servant/source.nix` selects commit
`7a6f692e85295f965cd1827f9354c28af9e62742`; the service selects
`5e99a7857032484abc669076704dee4335e7d0ad`. Both are from
`mori://shinzui/hs-opentelemetry-instrumentation-servant/packages/hs-opentelemetry-instrumentation-servant`.
The service's recipe builds the library and disables the upstream demo executable,
which uses an older OpenTelemetry shutdown API. The generation 9 lock owns no
instrumentation recipe, so the existing registry argument can supply the service source
subject to the final scope check.

[ADR 7](../adr/7-compose-applications-on-retained-keiro-runtime-baselines.md) requires
explicit application selections, an independent identity comparison and append-only
generation history. [ADR 4](../adr/4-consumer-overlays-define-only-their-own-packages.md)
puts shared Hackage recipes in this channel and limits consumer overrides to declared
application-owned dependencies. [ADR 5](../adr/5-keep-routine-application-changes-independent-of-cohort-and-toolchain-updates.md)
requires identical transitive build inputs for application-only changes. The existing
pattern for the independent scope check and negative cases is in
`checks/runtime-composition.nix`. [ExecPlan 16](16-create-the-keiro-runtime-package-set-and-compose-applications-on-it.md)
established that contract.


## Plan of Work

### Milestone 1. Expose the generation 9 HTTP application cohort

Create `lib/keiroRuntime9HttpApplicationCohort.nix` and expose its value as
`lib.keiroRuntime9HttpApplicationCohort` in `flake.nix`. Read generation 9's full
captured cohort through the recipe directory in `packages/runtime-lock.json` and
select these 12 published recipes by name from `generated/cohort-versions.nix`.
The initial three are `servant-health`, `hasql-dynamic-statements` and
`hasql-implicits`. The server graph requires `boring`, `servant-client-core`,
`tasty-hunit`, `hspec`, `hspec-core`, `hspec-discover`, `hspec-expectations`,
`haskell-lexer` and `quickcheck-io` to reproduce the working build. Require a
published package record and corresponding source manifest entry for each.
Reject an admitted name present in the generation's ownership. Merge the
selected entries into `packages`, `sourceManifest`, `flags` and `policy`, preserving
the retained values and scalar context for every other name. Keep the `boot`,
`firstParty` and `sameAsBase` classifications consistent by replacing membership
only for the selected names, using their published classifications. The constructor
continues to use the captured version layer, registry and test-only arguments.

Evaluate the exported cohort and force the three initial derivation paths through
`mkApplicationScope` with generation 9's full application group mapping. That
forces the independent runtime identity check before returning the version report.
Then compare the real server derivation with the working assembly using the
command below. Hold the service source, package overrides and instrumentation
registry fixed in both scopes so any difference points to dependency assembly.
Keep the existing constructor, default package outputs, and generation records on
their current paths. Consumers opt in through `applicationCohort`.

### Milestone 2. Prove and document the consumer path

Add a small Cabal executable in `checks/fixtures/runtime-http-application/` with
`runtime-http-application.cabal` and `Main.hs`. Its direct dependencies are `base`,
`servant`, `servant-server`, `wai-extra`, `http-types`, `servant-health`,
`hasql-dynamic-statements` and `hs-opentelemetry-instrumentation-servant`. Use
`Servant.Health.HealthApi` and `healthServer` with healthy checks, using
`NamedRoutes` mounted under `"health"`. Send `GET /health/live` with
`Network.Wai.Test` against the in-process application and require status 200.
Use `Hasql.DynamicStatements.Snippet.toSql` on a snippet composed with a typed
`param` and require `SELECT $1`. Import the instrumentation library to make the
fixture a consumer of the pinned source. Print `HTTP 200; SQL SELECT $1` and exit
zero only after both assertions pass. The check needs neither a listening port nor
a database.

Add `checks/runtime-http-application.nix` and wire the per-system check
`runtime-9-hackage-http-application` in `flake.nix`. Use the shared generation 9
selection metadata, the new public cohort value, and the platform's pinned Nixpkgs.
Define the fixture via `mkApplicationScope pkgs` and `hself.callCabal2nix`, and
use a `pkgs.runCommand` check with `set -o pipefail` to run the binary and pipe
its stdout through `tee "$out"`.
Assert the named recipe versions and independently force `validateApplicationScope`
on the final scope. Supply an `applicationRegistry` entry for the instrumentation
example using the exact source and application-local demo fix below. Assert the
instrumentation derivation's source is the fixed-revision fetch result. As a
negative case, try construction with `applicationRegistry.aeson = [ ]` and
require failure. An empty registry entry still counts as an attempt to claim a
runtime-owned name.

Update `docs/guides/compose-on-the-keiro-runtime.md` and its bundle log at
`docs/guides/log.md`. In the generation 9 section, show a complete Hackage
selection using the exported generation 9 `applicationSelections` and the
constructor snippet below. Show the fix in the checked fixture and explain how a
consumer supplies its own full Git revision and fixed source hash, and mirrors the
source in its Cabal project if it builds with Cabal. A service that uses the same
package scope for development can pass the same cohort and registry into
`lib.mkProjectDevShell`, which accepts both today. Describe the evidence as a
generation 9 Hackage-channel consumer check on the tested system.


## Concrete Steps

Run the commands from the haskell-nix repository root. Use its locked Nixpkgs,
GHC 9.12.4, and the generation's default disabled profiling and Haddock settings.
Use native `aarch64-darwin` for the required build. Ensure newly added Nix and
fixture files are visible to Git-based flake evaluation, or use a local
`path:$PWD` flake reference during development.

For the baseline and then the positive probe, use the following expression. Before
implementing, omit the `applicationCohort` line and evaluate one package at a time
by changing the final name set. The base dynamic statements version is
`0.3.1.8`; forcing the health recipe fails with the missing attribute error.
After implementing, the command as written succeeds and returns three objects
with versions `0.1.0.0`, `0.5.1.2`, and `0.2.0.3` under their package names
and a nonempty `drvPath` for each.

```bash
nix eval --impure --json --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    r = builtins.head (builtins.filter (r: r.generation == 9) f.lib.runtimePackageSets.keiro-runtime);
    pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; };
    selected = f.lib.mkRuntimePackageSet {
      runtime = "keiro-runtime";
      generation = 9;
      channel = "hackage";
      inherit (r) applicationSelections;
      applicationCohort = f.lib.keiroRuntime9HttpApplicationCohort;
    };
    scope = selected.mkApplicationScope pkgs (_: _: {});
  in builtins.mapAttrs
    (name: _: { inherit (scope.${name}) version drvPath; })
    { servant-health = true; hasql-dynamic-statements = true; hasql-implicits = true; }
'
```

Compare the production server from the clean service checkout at
`6f5578b1dc402e4f26d67dae0c36a71bdf92baa4`. The command uses the service's own
locked channel for the reference and the working tree's new complement for the
candidate. If Mori's registered checkout has moved, set `IR4_SERVICE_DIR` to a
disposable checkout of the specified revision before running the comparison.
The command must print `{"sameServerDerivation":true}`. If it prints `false`,
evaluate the two root derivation paths and compare their recursive inputs using
`nix derivation show --recursive`. Follow each difference to the first changed
package or build tool before admitting an additional published record.

```bash
export IR4_SERVICE_DIR="${IR4_SERVICE_DIR:-$(dirname "$(mori path mori://tan/agent-reputation-service/packages/agent-reputation-service-server)")}"
test "$(git -C "$IR4_SERVICE_DIR" rev-parse HEAD)" = 6f5578b1dc402e4f26d67dae0c36a71bdf92baa4 &&
test -z "$(git -C "$IR4_SERVICE_DIR" status --porcelain)" &&
nix eval --impure --json --expr '
  let
    f = builtins.getFlake ("path:" + toString ./.);
    service = builtins.toPath (builtins.getEnv "IR4_SERVICE_DIR");
    registry = (builtins.getFlake service).inputs.haskell-nix;
    pkgs = import f.inputs.nixpkgs { system = builtins.currentSystem; };
    inherit (pkgs) lib;
    config = builtins.fromJSON (builtins.readFile (service + "/nix/runtime-selection.json"));
    applicationRegistry = import (service + "/nix/application-registry.nix");
    overlay = import (service + "/nix/haskell-overlay.nix") { inherit pkgs; };
    server = flake: applicationCohort:
      let
        selection = flake.lib.mkRuntimePackageSet
          (config // { inherit applicationCohort applicationRegistry; });
      in (selection.mkApplicationScope pkgs overlay).agent-reputation-service-server.drvPath;
    existing = import (service + "/nix/application-cohort.nix") { inherit registry lib; };
  in {
    sameServerDerivation = server registry existing == server f f.lib.keiroRuntime9HttpApplicationCohort;
  }
'
```

Use the same optional registry shape that the service uses. In the snippet below,
`haskellNix` is the pinned channel flake, `pkgs` is its matching Nixpkgs for the
consumer system, and `./runtime-http-application` is the local Cabal package
directory next to the Nix expression. The guide should point to the checked
fixture for the complete source example. `applicationRegistry` is optional for
a service that uses the shared instrumentation recipe.

```nix
{ haskellNix, pkgs }:
let
  generation9 = builtins.head (builtins.filter
    (record: record.generation == 9)
    haskellNix.lib.runtimePackageSets.keiro-runtime);
  instrumentationSource = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "hs-opentelemetry-instrumentation-servant";
    rev = "5e99a7857032484abc669076704dee4335e7d0ad";
    hash = "sha256-bPiwF5vPswwfYipXLpLr+EWjrLbMWJ4yBDX38ealTrY=";
  };
  selected = haskellNix.lib.mkRuntimePackageSet {
    runtime = "keiro-runtime";
    generation = 9;
    channel = "hackage";
    inherit (generation9) applicationSelections;
    applicationCohort = haskellNix.lib.keiroRuntime9HttpApplicationCohort;
    applicationRegistry.hs-opentelemetry-instrumentation-servant = [{
      always = true;
      patch = { hself, haskellLib, ... }:
        haskellLib.overrideCabal (old: {
          postPatch = (old.postPatch or "") + ''
            substituteInPlace hs-opentelemetry-instrumentation-servant.cabal \
              --replace-fail 'executable server' $'executable server\n    buildable: False'
          '';
        }) (hself.callCabal2nix "hs-opentelemetry-instrumentation-servant" instrumentationSource {});
    }];
  };
  scope = selected.mkApplicationScope pkgs (hself: _: {
    runtime-http-application =
      hself.callCabal2nix "runtime-http-application" ./runtime-http-application {};
  });
in scope.runtime-http-application
```

Build the fixture check and the existing generation 9 Hackage freeze parity check.
The first build emits the fixture's smoke result and both commands exit zero.
Check the working-tree diff against the generation history before recording
acceptance. The last command exits zero with empty output.

```bash
system=$(nix eval --impure --raw --expr builtins.currentSystem)
nix build --no-link --print-build-logs "path:$PWD#checks.$system.runtime-9-hackage-http-application"
nix build --no-link --print-build-logs "path:$PWD#checks.$system.runtime-9-hackage-parity"
git diff --exit-code HEAD -- packages/runtime-lock.json packages/runtimes generated/runtimes cabal/runtime-cache cabal/cohort.freeze generated/cohort-versions.nix flake.lock
```


## Validation and Acceptance

The focused probe must fail for the original missing package and succeed after the
explicit complement is applied. The pinned service must resolve to the same server
derivation using the public complement and its working assembly. The new native
check must build and run the fixture, observe HTTP 200 and the expected placeholder
SQL, prove the caller's instrumentation source was used, pass the same compiler and all 287 non-boot
runtime derivation comparisons, and reject the attempt to replace `aeson`. The
existing Hackage parity check must still pass for the generation's ordinary
scope. Historical recipes, the lock, and the public default selections are
outside the change. Record the system, generation fingerprint and check results
in Progress and Outcomes & Retrospective. Review the guide by following its public
constructor example with the checked fixture. Linux, GitHub-channel validation,
cache publication, and consumer rollout fall outside this acceptance scope.


## Idempotence and Recovery

The export and checks evaluate from committed recipe data and can be rerun after
any interrupted build. Keep the explicit cohort and registry arguments local to the
consumer. To roll back adoption, restore the previous working consumer flake
revision or its existing application assembly and keep the same runtime generation.
If a missing non-runtime dependency prevents the fixture build, identify the
declared dependency edge and add only its already published recipe after proving
that it is outside runtime ownership. Re-run the focused probe and fixture.
If the check reports a runtime-owned conflict, preserve the independent check and
generation records and resolve that conflict before claiming acceptance.


## Interfaces and Dependencies

The public addition is a generation 9 cohort value for the existing
`mkRuntimePackageSet { applicationCohort = ...; }` argument. The other existing
inputs remain explicit. `applicationSelections` chooses named first-party package
groups, while `applicationRegistry` accepts package names mapped to lists of
registry rules of shape `{ always = true; patch = ...; }`. Use the existing
constructor and `validateApplicationScope` in `lib/mkRuntimePackageSet.nix` as
the ownership and derivation authority. The dependency implementations are
`mori://shinzui/servant-health/packages/servant-health`,
`mori://hasql/hasql/packages/hasql-dynamic-statements` and
`mori://hasql/hasql/packages/hasql-implicits`. Use the published hashes and
metadata already selected in `generated/cohort-versions.nix`. This composition
adds no new Cabal solver or lockfile format.


## Revision Notes

2026-11-17. Expanded the planned cohort from three records to 12 after comparing
the real server build graph. Added exact server derivation parity to acceptance
because the narrower complement could pass the runtime identity check while
silently selecting different application dependencies.
