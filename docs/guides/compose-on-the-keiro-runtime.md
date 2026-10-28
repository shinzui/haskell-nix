---
type: Guide
title: Compose applications on the Keiro runtime
description: Select a retained runtime generation, materialize its Cabal imports and compose application recipes in one checked Haskell scope.
docId: DOC-6
tags: [runtime, composition, adoption]
generated:
  by: process:codex
  at: 2026-10-17T01:23:52Z
---

[Guides](README.md)

# Compose applications on the Keiro runtime

Generation 1 retains 311 package identities and 35 roots across
`mori://shinzui/keiki`, `mori://shinzui/keiro`, `mori://shinzui/kiroku`,
`mori://shinzui/shibuya`, `mori://shinzui/pgmq-hs`, `mori://shinzui/settei`,
`mori://shinzui/pg-migrate` and `mori://shinzui/hw-kafka-client`.
The closure includes Keiki's JSON codec, PGMQ/Kiroku/Kafka adapters and the maintained
Kafka streaming fork. Applications build only the components they use.

Generation 2 retains the same membership, versions and native Nix dependency identities,
and enables Dhall HTTPS imports in Cabal. Both generations are verified for the same matrix.
Applications requiring Cabal HTTPS imports select generation 2 explicitly and use `2` in
both the selector and materialized import paths below. Existing unqualified runtime build
outputs continue to select generation 1; generation 2 has `keiro-runtime-2` build outputs.
The fingerprint-bound support receipts live under `cabal/runtime-cache/keiro-runtime/`.

Generation 6 selects the October 27 release cohort:
[Keiro](mori://shinzui/keiro) 0.22.0.0,
[Kiroku Store](mori://shinzui/kiroku/packages/kiroku-store) 0.12.0.0,
[PGMQ](mori://shinzui/pgmq-hs) 0.7.0.0,
[Shibuya](mori://shinzui/shibuya) 0.12.0.0 and
[Settei](mori://shinzui/settei) 0.3.0.0. Its adapters are
[`shibuya-pgmq-adapter`](mori://shinzui/shibuya-pgmq-adapter/packages/shibuya-pgmq-adapter) 0.18.0.0,
[`shibuya-kafka-adapter`](mori://shinzui/shibuya-kafka-adapter/packages/shibuya-kafka-adapter) 0.12.0.0 and
[`shibuya-kiroku-adapter`](mori://shinzui/kiroku/packages/shibuya-kiroku-adapter) 0.7.0.0.
It adds the [`keiro-ops-http`](mori://shinzui/keiro/packages/keiro-ops-http) and
[`pgmq-inspect`](mori://shinzui/pgmq-hs/packages/pgmq-inspect) inspection packages.
Select `generation = 6`, materialize imports into
`cabal/runtime/keiro-runtime/6`, and retain Kioku application selection 9.
The explicit Nix outputs are `keiro-runtime-6*`; existing generations and
unqualified outputs retain their selections. Broad support remains `unverified`
until evidence is recorded for its own fingerprint.

Applications adopting this cohort must use Settei's 0.3 API and the new runtime
schemas. Follow the migration guidance for
[`kiroku-store`](mori://shinzui/kiroku/packages/kiroku-store) and
[`keiro`](mori://shinzui/keiro/packages/keiro), including Kiroku migration 0016
and PGMQ migration 0007. The shared Cabal configuration retains narrowly scoped
[Kioku 0.11](mori://shinzui/kioku/packages/kioku-core) bounds exceptions for the runtime APIs it consumes; other application
bounds and source migrations remain owned by their consumers.

Generation 7 retains the same framework package and migration versions as generation 6,
while selecting the later Cabal index required by [Kioku](mori://shinzui/kioku) 0.12.0.1.
Use application selections `kioku=10`, `shikumi-baikai=10`, and `okf=6`. These select
[Baikai](mori://shinzui/baikai) 0.10.0.0 and [OKF](mori://shinzui/okf) 0.11.0.0;
the Shikumi release versions stay unchanged with refreshed source provenance.
The only additional runtime source-identity change is
[Streamly](mori://composewell/streamly/packages/streamly) 0.11.1 metadata revision 2 to 3,
which widens its streamly-core upper bound; the resolved core version stays 0.3.1.
Generation 7 uses the established recipe constructor. The optional generated-recipe
selection is retained as `config/runtime-generated-recipes-opt-in.json`; historical
generations preserve their captured selections. Native consumer validation is scoped to
macOS under [Rei's upgrade plan](mori://shinzui/rei/plans/286-upgrade-rei-to-keiro-0-22-and-the-latest-nix-runtime-package-integration).
Broad runtime support remains unverified; this update does not claim Linux build evidence.

## 1. Pin the channel and record selections

Follow [the flake adoption guide](adopt-in-an-existing-flake.md) to share the toolchain.
Select the exact channel commit containing the runtime. Inspect
`lib.runtimePackageSets.keiro-runtime` for generation 1's toolchain, configurations and
recorded complementary mapping. Commit `nix/runtime-selection.json`:

```json
{
  "runtime": "keiro-runtime",
  "generation": 1,
  "channel": "github",
  "disableProfiling": true,
  "disableHaddock": true,
  "applicationSelections": {
    "kioku": 8,
    "okf": 5,
    "openapi-hs": 1,
    "relay-pagination": 3,
    "servant-openapi-hs": 1,
    "shikumi-baikai": 9
  }
}
```

These complementary selections are explicit identities. A different retained application
group may be selected if it preserves runtime-owned inputs. Missing groups and conflicting
runtime selections fail by name. Generation 1 supports GHC 9.12.4 on aarch64-darwin and
x86_64-linux, both source channels, profiling and Haddock disabled.

## 2. Import the same Cabal runtime

Resolve the consumer's full channel revision using the shared `cohort-compare
--resolve-channel-lock` command. Replace `REV` below with that exact commit:

```bash
nix run github:shinzui/haskell-nix/REV#runtime-import -- \
  --revision REV --generation 1 --channel github \
  --destination cabal/runtime/keiro-runtime/1
```

Commit the six resulting files. Add both imports to `cabal.project`:

```cabal
import: https://raw.githubusercontent.com/shinzui/haskell-nix/REV/cabal/cohort.freeze
import: cabal/runtime/keiro-runtime/1/github.project
```

The materializer verifies the three original projection files against the retained lock and
writes a selection receipt. The selected source projection and `comparison-sources.json`
provide the complete expected source policy to the existing comparator; unrelated cohort
entries are preserved and runtime version conflicts fail. Use the same command with `--check` for no-write verification.
Local projection files preserve Cabal's relative imports; importing the remote runtime project
alone does not fetch its sibling files. Select `hackage` consistently in both build systems to
use that channel. Both configurations preserve the declared Kafka and Dhall source exceptions.
Enable supported application tests and benchmarks after the imports. Retain required
application-only source/flag policy and compare every non-local dependency with the complete
cohort through the shared tool.

Check the fresh Cabal plan through the shared parser, using that selected source policy:

```bash
nix run github:shinzui/haskell-nix/REV#cohort-compare -- \
  --freeze https://raw.githubusercontent.com/shinzui/haskell-nix/REV/cabal/cohort.freeze \
  --sources cabal/runtime/keiro-runtime/1/comparison-sources.json \
  --plan-json dist-newstyle/cache/plan.json
```

For a sibling application library supplied by Git rather than Hackage, pass
`--application-sources cabal/application-sources.json` to the materializer and its
`--check` invocation. Each package entry declares `owner` (the contributor's exact
canonical Mori project URI), a nonempty `reason`, and `package` (the shared inventory's
version/source/identities/dependencies record). Retain the independently captured source
revision and hash evidence in that file. Only declared contributor packages outside the
shared cohort are admitted; immutable HTTPS Git revisions are required. The comparator
then checks those source packages normally, including every component and flag identity.
These declarations cannot replace frozen or runtime-owned packages.

## 3. Construct one checked scope

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

Keep owned source inputs limited to required package files, licenses, schemas and assets.
The checked constructor rejects changed runtime dependency derivations and compiler inputs
before building an application. Existing extension exports can compose in this scope; manual
scope construction must call `validateApplicationScope`. Compare actual executable manifests
with the shared comparator so additional conflicting instances cannot hide behind a correct one.

## 4. Validate updates and resolve conflicts

Run application builds/tests, no-write runtime import checking, frozen Cabal/Nix comparison
and the consumer overlay audit before committing all selectors together. Documentation or
application leaf changes retain runtime library identities; a real shared interface change
invalidates its dependent applications.

Application-only updates retain the channel, runtime and toolchain pins. For an intentional
runtime upgrade, maintainers resolve through the shared cohort workflow, then run `runtime
snapshot --name keiro-runtime --cohort-freeze cabal/cohort.freeze`. Changed effective inputs
append a generation; unchanged inputs return the existing record. Build, integration and
fresh-worker cache evidence establishes support before consumers select the new generation.
Materialize its imports in a new generation directory and move Cabal/Nix selectors atomically.
A runtime-owned conflict requests that explicit update rather than a consumer override.
