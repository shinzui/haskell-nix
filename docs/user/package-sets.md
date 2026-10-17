---
type: Explanation
title: Package sets
description: Understand first-party package-set selection, retention, and cache behavior.
docId: DOC-7
tags: [package-sets, snapshots, cache]
generated:
  by: human:nadeem
  at: 2026-10-17T00:04:00Z
---

[User guide](README.md)

# Package sets

A package set lets a consumer update one first-party release line without moving every
other first-party package. Package selection and source provenance are separate choices:
choose a package set first, then choose its GitHub or Hackage channel.

## The model

A **family** is every package discovered in one source repository. All packages in the
Keiro repository, for example, share one source revision and move together.

An **update group** is one or more families that must move atomically. Most families are
implicit one-family groups. The explicit `shikumi-baikai` group contains Baikai and Shikumi,
so neither can be selected or refreshed alone.

A **family generation** is an immutable snapshot of one family's locked source, package
inventory, Hackage pins, Cabal2nix options, and exclusions. A **group generation** refers to
one family generation for every member of an update group and names the compatibility
profile that applies to that cohort.

A **named package set** is a complete mapping from every update group to one retained group
generation. `default` preserves the legacy outputs. Historical sets may retain old or mixed
selections for reproducibility without making them supported release lines.

A package set has a **support level**. `curated` sets are built by this repository across
both channels, every supported GHC, and every supported system. `historical` sets remain
selectable and reproducible but are not promised to keep building on future toolchains.
Consumer-owned mappings have no repository support designation.

A **compatibility profile** is an immutable, named registry fragment associated with a
group generation. If a workaround changes, maintainers add a new profile name rather than
changing the meaning of an old snapshot.

A **channel** chooses source provenance after selection. `github` uses the content-addressed
locked repository revision and includes unpublished packages. `hackage` uses recorded
release archives and omits packages whose Hackage pin is null. Changing channels does not
change the selected family or group generations.

## Shared third-party cohort

Every package set constructed by the channel also receives the shared third-party versions
from `generated/cohort-versions.nix`, generated from `cabal/cohort.freeze`. Its records retain
source hashes and the Hackage metadata revision visible at the frozen index-state.
Compiler boot libraries remain supplied by GHC. Owned non-Hackage source pins and selected
first-party packages are classified separately.

The modern CLI projection includes Aeson 2.2.5.1, generic-lens 2.3 and
optparse-applicative 0.19. The WAI/Warp cohort moves together: Warp 3.4.16 requires
WAI 3.2.5, HTTP/2 5.4, HTTP Semantics 0.4 and recv 0.1.2; their dependencies include
time-manager 0.3 and network 3.2.9. Updating only Warp can leave an unbuildable graph.
Update the retained cohort as a unit and compose the shared extension instead of copying
these Hackage replacements into each consumer.

The Haskell extension applies global profiling and Haddock settings, channel-specific extra
overrides, generated third-party versions, then common and compatibility policy and the
selected first-party registry. A generated recipe cannot also own a selected first-party name.
Policy wraps the generated selection; it does not independently pin a Hackage release.

`just cohort-generate` refreshes the projection after an accepted cohort update.
`just cohort-generated-check` verifies it without writing files. The pure
`cohort-generated-fresh` check verifies retained records; `cohort-versions` evaluates the
actual composed default scope for both source channels under the cohort compiler, GHC 9.12.4.
Historical selections retain their first-party versions and are not claimed to match the
default cohort. GHC 9.14 receives the generated versions while retaining its own boot libraries;
its curated build matrix is separate evidence from the GHC 9.12 parity check.

Version equality alone does not prove source, flags, metadata or derivation equality.
Intentional source/configuration differences require owned policy and build evidence before
cache reuse can be claimed. Routine application edits retain the shared cohort and toolchain;
refresh them through the cohort workflow when a dependency update is intended.

## Select a named set

`lib.mkFirstPartyPackageSet` returns a registry, Haskell extension, Nixpkgs overlay, the
normalized selection, and selected-family metadata:

```nix
let
  selected = inputs.haskell-nix.lib.mkFirstPartyPackageSet {
    packageSet = "default";
    channel = "github"; # or "hackage"
  };

  haskellPackages = pkgs.haskell.packages.ghc9124.override {
    overrides = pkgs.lib.composeExtensions
      (selected.haskellExtension pkgs.haskell.lib.compose pkgs)
      myOverrides;
  };
in
  haskellPackages
```

Use `selected.overlay` instead when the consumer does not add another `overrides` value to
the same Haskell package set.

Inspect the names, support levels, and complete mappings without fetching package sources:

```bash
nix eval --json .#lib.firstPartyPackageSets
nix eval --json .#lib.firstPartyGroupSnapshots
```

## Own a complete selection

The constructor accepts `selections` instead of `packageSet`. Exactly one must be supplied,
and the mapping must contain every resolved group with a positive retained generation:

```nix
let
  liveDefault = inputs.haskell-nix.lib.firstPartyPackageSets.default.selections;
  selected = inputs.haskell-nix.lib.mkFirstPartyPackageSet {
    selections = liveDefault // {
      keiro = 2;
      okf = 1;
    };
    channel = "hackage";
  };
in
  selected.haskellExtension
```

Merging over `firstPartyPackageSets.default.selections` deliberately follows future default
generations for every group not overridden. To pin every group until you edit it, copy the
complete evaluated mapping into the consumer as literal attributes. Generation numbers are
opaque snapshot identities; confirm them against `firstPartyGroupSnapshots` instead of
inferring them from package versions.

Selections are always complete. Baikai and Shikumi move together, all packages from Keiro
move as one family, and the singleton OKF group can advance independently.

## Retention and topology

Published snapshots are append-only. Refreshing a curated set appends changed family and
group generations and moves only that named set; it does not rewrite other named sets.
Old discovery options and exclusions remain part of their family snapshots.

Schema version 2 fixes the family inventory and update-group membership. Adding or removing
a family, or regrouping existing families, needs a future explicit catalog migration. It
must not silently add a group to an existing complete consumer mapping.

## Cache contract

Package-set names and generation labels are selection metadata, not derivation inputs. Two
first-party derivations can reuse the same path only when all effective inputs are equal:

- system, compiler, and Nixpkgs;
- channel and selected source/version;
- the transitive dependency graph;
- compatibility profiles and patches; and
- profiling, Haddock, and other build settings.

The production checks prove that selecting OKF 0.9 instead of 0.8 leaves every Keiro 0.14
derivation unchanged under otherwise equal inputs. A consumer package that directly depends
on OKF may still rebuild, even when its Keiro dependency does not. This repository proves
derivation identity and buildability; it does not promise that any particular external
binary cache has published the resulting path.

First-party packages are currently built with Cabal bounds jailbroken and test suites
disabled by the generated registry. A curated matrix therefore proves the supported Nix
construction, not unmodified upstream bounds or upstream test-suite success.

## Build manifests and cache receipts

`lib.mkCohortManifest { pkgs; scope; root; context; localPackages; }` constructs JSON evidence
for a root built by the supplied composed Haskell scope. It records actual Haskell dependency
instances, native dependencies, compiler, source and metadata inputs, configuration, and
derivation/output paths. Nix exports the root's derivation graph to the builder; construction
fails if a recorded Haskell package or dependency edge is absent from that graph. This covers
static libraries that disappear from a runtime output closure. `context` is explicit so a
retained runtime projection can reuse the same helper without reading mutable defaults.
Captured recipe arguments must reconstruct the exact actual derivation. Express recipe
changes through `overrideCabal`; a lower-level override that changes unrecorded build inputs
fails manifest construction.

Build the channel's example with `nix build .#cohort-manifest`. Compare two manifest files with
`nix run .#cohort-compare -- --compare-manifests BEFORE AFTER`; changed identities include input
fields and direct users. Compare a manifest against its retained cohort with:

```bash
nix run .#cohort-compare -- --freeze cabal/cohort.freeze --nix-manifest MANIFEST.json
```

The comparator verifies source and metadata identities, resolved Cabal flags and dependency
edges. It obtains flags from an exact configure replay, including automatic defaults.
Intentional differences require an owner and reason in the sibling
`cohort-nix-policy.json`; this also declares compiler-bundled tools whose configured version
and provider are verified. A missing dependency, unknown package or unverifiable identity
fails with status 1. Passing a manifest comparison does not establish full compiler/channel
matrix or fresh-CI-worker cache acceptance; those remain separate gates.

After the cohort build passes, publish its dependency outputs with:

```bash
nix run .#cohort-cache -- publish --root .#cohort-closure --cache tan --receipt publication.json
```

Repeat `--root` for additional runtime roots on the same system. The full cohort link farm
retains every cohort library, including static dependencies. Publication verifies the remote
NAR hashes, sizes and references before writing a receipt; a successful build alone is not
publication evidence.

On a worker matching the published system, verify substitution into an empty isolated store:

```bash
nix run .#cohort-cache -- verify --receipt publication.json \
  --store 'local?root=/absolute/empty-worker' --evidence substitution.json
```

Use a path without symlink parents (`/private/tmp/...` rather than `/tmp/...` on macOS).
Verification rejects a store that already holds any expected path, copies exclusively from
the cache without building, and checks the complete recorded graph. Receipts record the
worker system and hostname. An isolated store on a developer machine proves substitution
there; supported CI-worker acceptance still requires running it in the declared CI environment.


## Retained Keiro runtime generations

A runtime generation retains a transitive dependency baseline as well as the first-party
selection. `keiro-runtime` generation 1 owns 311 packages, including Keiki and its JSON codec,
Keiro, Kiroku, Shibuya, PGMQ, Settei, pg-migrate and the maintained Kafka client and streaming
forks. Its 35 roots are available lazily: an application builds only dependencies it uses.
The record captures recipes, source hashes, metadata, flags, policies and toolchain pins.
The existing complete-selection API and catalog topology are unchanged.

Inspect `lib.runtimePackageSets.keiro-runtime` for explicit generation records, configurations,
roots and the recorded complementary `applicationSelections`. Persist the chosen generation,
source channel and complete complementary map in the application's `nix/runtime-selection.json`.
The constructor never fills missing groups from a moving default. Equal duplicate runtime
group selections are allowed; conflicting values fail by group name.

```nix
let
  choice = builtins.fromJSON (builtins.readFile ./nix/runtime-selection.json);
  selected = inputs.haskell-nix.lib.mkRuntimePackageSet choice;
  hs = selected.mkApplicationScope pkgs (hself: _hsuper: {
    my-application = hself.callCabal2nix "my-application" ./my-application { };
  });
in {
  packages.default = hs.my-application;
  packages.cohort-manifest = selected.mkApplicationManifest {
    inherit pkgs;
    scope = hs;
    root = hs.my-application;
  };
}
```

Use the retained nixpkgs/GHC toolchain and declared profiling/Haddock choices. The checked
scope constructor compares every non-boot runtime derivation against an independent retained
scope and checks the compiler. It rejects application overrides of owned packages before the
application builds. `haskellExtension` and `overlay` remain available for existing composition;
call `validateApplicationScope pkgs hs` when constructing a scope manually. Always compare the
actual executable manifest using the shared comparator to catch additional dependency instances.

Materialize the generation's Cabal project and its two relative imports from the same full
channel revision used by the application's lock:

```bash
nix run github:shinzui/haskell-nix/REV#runtime-import -- \
  --revision REV --generation 1 --channel github \
  --destination cabal/runtime/keiro-runtime/1
```

Replace `REV` with the full locked commit and commit the resulting four files. Add
`import: cabal/runtime/keiro-runtime/1/github.project` alongside the complete cohort freeze
import. The tool verifies each unmodified projection against the retained lock and records
the revision/fingerprint in `selection.json`; `--check` verifies the committed imports without
writing. Cabal resolves relative children of a URL import against the application directory,
so directly importing the remote runtime project does not fetch its sibling files. A local,
hash-checked projection preserves those imports. Both channels retain declared source forks. Enable the application's own
supported tests and benchmarks explicitly. Application dependencies outside runtime ownership
still need complete cohort source and configuration policy; a runtime projection alone is not
a complete application solver input.

`runtime snapshot --name keiro-runtime --cohort-freeze cabal/cohort.freeze` stages and checks a
new generation. An unchanged effective input returns the existing record without writing.
`runtime check --name keiro-runtime` verifies retained artifacts; `runtime describe --name
keiro-runtime --json` reports metadata. Existing generations remain immutable when membership
or policy changes. Build/cache evidence lives outside their immutable projection directories.

The root, closure and manifest outputs are `keiro-runtime`, `keiro-runtime-closure` and
`keiro-runtime-manifest`, with corresponding `keiro-runtime-hackage*` outputs. Verified generation-1
configurations are GHC 9.12.4 on aarch64-darwin and x86_64-linux, both source channels, profiling and
Haddock disabled. The exported `support.status` is `verified` only when a support receipt matches the
immutable fingerprint; new records without acceptance evidence remain `unverified`. Generation numbers and documentation
labels do not enter library derivation inputs.
