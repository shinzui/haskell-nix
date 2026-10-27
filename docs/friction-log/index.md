---
okf_version: "0.2"
---

# Files

- [profile.dhall](profile.dhall)

# Friction Entry

- [Translated Linux builder requires a seccomp override](1-translated-linux-builder-requires-a-seccomp-override.md) - The existing x86_64 Apple container guest rejected Nix seccomp installation, requiring an explicit guest-only filter-syscalls override before native package checks could run.
- [Nix test wrapper exports an environment that nested Cabal rejects](2-nix-test-wrapper-exports-an-environment-that-nested-cabal-rejects.md) - Heni runner tests invoke Cabal, but the Nixpkgs Haskell test wrapper exports GHC_PACKAGE_PATH and causes every nested baseline to fail before compilation.
