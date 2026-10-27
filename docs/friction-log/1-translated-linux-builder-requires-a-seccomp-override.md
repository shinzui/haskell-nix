---
type: Friction Entry
title: "Translated Linux builder requires a seccomp override"
description: "The existing x86_64 Apple container guest rejected Nix seccomp installation, requiring an explicit guest-only filter-syscalls override before native package checks could run."
generated:
  by: "codex-cli/gpt-6.1-sol"
  at: "2026-10-27T14:11:42Z"
frictionId: FRIC-1
status: "accepted"
impact: detour
kind: environment
origin: "mori://shinzui/haskell-nix"
affects: "mori://apple/container"
plan: "docs/plans/22-add-hinagata-shoko-heni-and-typesafe-hs-support.md"
workaround: "Set filter-syscalls = false only in the guest command NIX_CONFIG; retain the normal host configuration."
resolution: "Keep the guest-only filter-syscalls override for the existing translated Apple-container builder; qualify its correctness evidence and leave the host configuration unchanged."
amended:
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-27T15:11:22Z"
    change: "Accept the existing guest execution constraint for this build matrix."
  - by: "codex-cli/gpt-6.1-sol"
    at: "2026-10-27T15:58:11Z"
    change: "Canonicalize the upstream project reference to its intended Mori URI, pending registration, as required by the user."
---
# Translated Linux builder requires a seccomp override

The intended upstream Mori project URI is recorded above; local registration is pending.

## Attempted

container exec mp3-linux-builder nix build .#checks.x86_64-linux.new-first-party-support

## Encountered

Nix evaluation attempted an import-from-derivation build and the guest could not load the syscall filter.

```text
unable to load seccomp BPF program: Invalid argument
```

## Workaround

Set filter-syscalls = false only in the guest command NIX_CONFIG; retain the normal host configuration.
