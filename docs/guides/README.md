---
type: Navigation
title: Guides
description: Choose a task-oriented path for consumer adoption or package-set maintenance.
docId: DOC-1
tags: [adoption, navigation, consumers]
timestamp: 2026-10-17T16:22:59Z
generated:
  by: process:codex
  at: 2026-10-17T04:15:00Z
---

# Guides

For changes in a **consumer repository**, start with the task that matches your setup:

1. [Adopt haskell-nix in an existing flake](adopt-in-an-existing-flake.md) to wire the
   inputs, compose the selected extension, and build a consumer target.
2. [Move from an overlay to extension composition](move-from-an-overlay.md) if your
   consumer already imports a haskell-nix overlay and also has local Haskell overrides.
3. [Roll out a first-party package set](roll-out-a-package-set.md) to select a retained
   generation and channel, then validate a consumer upgrade.

4. [Compose applications on the Keiro runtime](compose-on-the-keiro-runtime.md) to retain
   the shared dependency closure and add application recipes in one checked scope.

5. [Develop against a retained runtime](develop-against-a-retained-runtime.md) to add an optional
   project shell and verify scoped compiler, native dependencies and Cabal evidence.

For everyday build and cache use, start with
[Get faster builds and reliable cache hits](faster-builds-and-cache-hits.md).
For measured application build work, follow [Measure and remove avoidable application rebuilds](faster-application-nix-builds.md).

For changes in **haskell-nix**, follow [Create a first-party package set](create-a-package-set.md)
to clone a named selection, choose group generations, and validate its support level.

The [user documentation](../user/README.md) is the reference for package sets, channels,
integration behavior, and troubleshooting. The guides here focus on specific changes and
their validation.
