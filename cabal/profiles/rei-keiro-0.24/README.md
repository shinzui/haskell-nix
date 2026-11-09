# Rei application profile for Keiro 0.24

This scoped solve supports mori://shinzui/rei/plans/290-migrate-rei-to-keiro-0-24-and-mount-operations-for-keiro-ui.
It leaves the broad cohort and every retained runtime generation unchanged.
`selection.json` records the consumer constructor inputs. Generation 8 owns the
framework; Kioku 11 and shikumi-baikai 11 select the released application complement
on the Hackage channel. Shikumi 0.5.1 requires baikai-effectful 0.4.0.5; its family
snapshot records that official normal release separately from the newer Git source.

The solve retains all unrelated baseline versions and source forks. The targeted
unlocks are represented by `retained.config`; `cohort.project` fixes the newer index
state after that import. Its solver-only package names the complete retained library
and executable dependency set, without importing stale application contributor bounds.
It adds no allow-newer exceptions. The complete source records for all 325 runtime-owned
packages equal generation 8 exactly, including component identities, metadata and flags.

Reproduce the solve with the stock GHC 9.12.4 compiler from `.#cohort-inventory`, not
a package-enriched shell. From this directory:

```bash
cabal build all --dry-run --project-file=cohort.project --with-compiler="$COHORT_GHC" --with-hc-pkg="$COHORT_GHC_PKG"
cabal freeze --project-file=cohort.project --with-compiler="$COHORT_GHC" --with-hc-pkg="$COHORT_GHC_PKG"
```

From the repository root, normalize the resulting freeze with the updater's
`cohort normalise-freeze`, retaining the recorded compiler, index state and base
channel revision. Generate or verify the source-aware Nix tables with:

```bash
haskell-nix-update cohort generate \
  --group-selection keiro=9 --group-selection kiroku=6 \
  --group-selection kioku=11 --group-selection shikumi-baikai=11 \
  --freeze cabal/profiles/rei-keiro-0.24/cohort.freeze \
  --output generated/profiles/rei-keiro-0.24/cohort-versions.nix \
  --boot-output generated/profiles/rei-keiro-0.24/ghc-boot-packages.nix \
  --context-output generated/profiles/rei-keiro-0.24/context.json
```

Add `--check` for a no-write comparison. These read-only retained group selections
never mutate named package sets. Consumers import this freeze and `common.config`
from one immutable channel revision, materialize generation 8's `hackage.project`
with `runtime-import --retained-cohort`, and pass the generated profile through
`applicationCohort`. Put the profile's index state after runtime imports: that
runtime retains an older cutoff, while this solve proves its owned identities
remain unchanged at the newer cutoff. Compare both build systems against this
profile's complete source manifest; use the channel-root contributor and Nix
policy files. Native consumer builds establish support; these generated declarations
do not claim Linux execution evidence.
