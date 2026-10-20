---
okf_version: "0.2"
---

# Improvement Request

- [Provide a coherent modern CLI and WAI dependency cohort](provide-a-coherent-modern-cli-and-wai-dependency-cohort.md) - Add the mutually compatible Hackage releases needed by Hurl Workbench to the shared GHC 9.12/9.14 package-set extension, so consumers do not duplicate a fixed-hash override graph for current generic-lens and WAI/Warp APIs.
- [Provide a targeted Rei cohort for Kioku 0.11 and the Store error fix](provide-a-targeted-rei-cohort-for-kioku-0-10-and-the-store-error-fix.md) - Supply a generated Cabal and Nix cohort for published Kioku 0.11.0.0 and Store 0.11.0.1 without consumer-local source overrides or unrelated toolchain upgrades.
- [Stop building Haddock for the package sets haskell-nix patches](stop-building-haddock-for-patched-package-sets.md) - Add a Haddock counterpart to the opt-in disableProfiling flag, so a consumer that ships CLI tools and never reads the generated documentation can stop compiling it for every package in the set.
