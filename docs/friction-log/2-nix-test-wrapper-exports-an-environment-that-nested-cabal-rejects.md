---
type: Friction Entry
title: "Nix test wrapper exports an environment that nested Cabal rejects"
description: "Heni runner tests invoke Cabal, but the Nixpkgs Haskell test wrapper exports GHC_PACKAGE_PATH and causes every nested baseline to fail before compilation."
generated:
  by: "codex-cli/gpt-6.1-sol"
  at: "2026-10-27T14:21:03Z"
frictionId: FRIC-2
status: "accepted"
impact: detour
kind: interface
origin: "mori://shinzui/haskell-nix"
affects: "mori://nixos/nixpkgs"
affectedVersion: "d5dfd8e6716dde34398bc14bc87c10dece9c8c68"
plan: "docs/plans/22-add-hinagata-shoko-heni-and-typesafe-hs-support.md"
workaround: "Use a validation-only Cabal wrapper that unsets GHC_PACKAGE_PATH before invoking the real Cabal; retain the same compiler, sources, fixture commands, and assertions."
resolution: "Retain the validation-only nested Cabal wrapper and fixture PATH setup; production recipes and upstream assertions remain unchanged."
amended:
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-27T15:11:22Z"
    change: "Accept the explicit validation environment adapter required by the Nix test wrapper."
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-27T15:58:11Z"
    change: "Canonicalize the upstream project reference to its intended Mori URI, pending registration, as required by the user."
---
# Nix test wrapper exports an environment that nested Cabal rejects

The intended upstream Mori project URI is recorded above; local registration is pending.

## Attempted

Enable upstream offline heni-runner tests in the frozen package scope

## Encountered

The direct baseline compiled, while the same command launched inside the test wrapper failed with Cabal-8123; inspecting retained runner logs exposed the inherited variable.

```text
Use of GHC environment variable GHC_PACKAGE_PATH is incompatible with Cabal. Use --package-db to specify a package database.
```

## Workaround

Use a validation-only Cabal wrapper that unsets GHC_PACKAGE_PATH before invoking the real Cabal; retain the same compiler, sources, fixture commands, and assertions.
