---
type: Friction Entry
title: "Translated Linux builder requires a seccomp override"
description: "The existing x86_64 Apple container guest rejected Nix seccomp installation, requiring an explicit guest-only filter-syscalls override before native package checks could run."
generated:
  by: "codex-cli/gpt-6.1-sol"
  at: "2026-10-27T14:11:42Z"
frictionId: FRIC-1
status: logged
impact: detour
kind: environment
origin: "mori://shinzui/haskell-nix"
affects: "https://github.com/apple/container"
plan: "docs/plans/22-add-hinagata-shoko-heni-and-typesafe-hs-support.md"
workaround: "Set filter-syscalls = false only in the guest command NIX_CONFIG; retain the normal host configuration."
---
# Translated Linux builder requires a seccomp override

## Attempted

container exec mp3-linux-builder nix build .#checks.x86_64-linux.new-first-party-support

## Encountered

Nix evaluation attempted an import-from-derivation build and the guest could not load the syscall filter.

```text
unable to load seccomp BPF program: Invalid argument
```

## Workaround

Set filter-syscalls = false only in the guest command NIX_CONFIG; retain the normal host configuration.
