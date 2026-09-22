---
type: Navigation
title: Adoption guides
description: Choose a task-oriented path for adding haskell-nix to a consumer and rolling out a selected package set.
docId: DOC-1
tags: [adoption, navigation, consumers]
generated:
  by: process:codex
  at: 2026-09-22T22:46:10Z
---

# Adoption guides

These guides walk through changes in a **consumer repository**. Start with the task that
matches your current setup:

1. [Adopt haskell-nix in an existing flake](adopt-in-an-existing-flake.md) to wire the
   inputs, compose the selected extension, and build a consumer target.
2. [Move from an overlay to extension composition](move-from-an-overlay.md) if your
   consumer already imports a haskell-nix overlay and also has local Haskell overrides.
3. [Roll out a first-party package set](roll-out-a-package-set.md) to select a retained
   generation and channel, then validate a consumer upgrade.

The [user documentation](../user/README.md) is the reference for package sets, channels,
integration behavior, and troubleshooting. The guides here focus on making and checking
specific adoption changes.
