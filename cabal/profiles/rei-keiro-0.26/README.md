# Rei application profile for Keiro 0.26

This named profile supports mori://shinzui/rei/plans/307-adopt-the-released-keiro-runtime-and-retire-superseded-rei-workarounds.
It selects Keiro 0.26.0.0, Kioku 0.14.0.0 and the Hackage channel on retained runtime
generation 11. At the first index that includes the complete Kioku release,
crypton-connection 0.4.6 has a newer Cabal metadata revision. Generation 11
captures that digest while retaining the 37 roots and all other runtime-owned
identities from generation 10. The profile records the exact Shomei release source
and its closure. The consumer supplies the Shomei Nix source recipe.

Reproduce the profile in this directory with the stock compiler from
`.#cohort-inventory`.

```bash
cabal build all --dry-run --project-file=cohort.project --with-compiler="$COHORT_GHC" --with-hc-pkg="$COHORT_GHC_PKG"
cabal freeze --project-file=cohort.project --with-compiler="$COHORT_GHC" --with-hc-pkg="$COHORT_GHC_PKG"
```

Normalize the Cabal freeze using `cohort normalise-freeze` and the recorded
index and channel revision. From the channel root verify the generated profile.

```bash
haskell-nix-update cohort generate \
  --group-selection keiro=11 --group-selection kiroku=7 --group-selection shibuya=5 \
  --group-selection kioku=12 --group-selection shikumi-baikai=12 \
  --freeze cabal/profiles/rei-keiro-0.26/cohort.freeze \
  --policy cabal/profiles/rei-keiro-0.26/cohort-policy.json \
  --output generated/profiles/rei-keiro-0.26/cohort-versions.nix \
  --boot-output generated/profiles/rei-keiro-0.26/ghc-boot-packages.nix \
  --context-output generated/profiles/rei-keiro-0.26/context.json --check
```
