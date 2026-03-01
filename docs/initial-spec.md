# Nix + Haskell Multi‑Repository Build Strategy

## Version‑Scoped Patch Architecture (Technical Analysis)

---

## 1. Problem Statement

In a multi‑repository Haskell ecosystem built with Nix, teams often accumulate local overlays and overrides to fix:

* broken packages
* incompatible GHC versions
* Cabal constraint issues
* missing patches
* performance or build flags

Over time, these fixes are duplicated across repositories, causing:

* configuration drift
* inconsistent builds
* upgrade friction
* hidden coupling
* high maintenance overhead

Constraints:

* Each repository must remain independently buildable.
* Repositories may use different GHC versions.
* Repositories may depend on different versions of the same library.
* Fixes must be shared without synchronizing upgrades.

---

## 2. Core Design Principle

> Fixes belong to *(package, version range, compiler)* — not to repositories.

Instead of global overlays, implement **version‑scoped patch sets**.

This converts shared configuration into a reusable compatibility layer.

---

## 3. Architecture Overview

```
nix-haskell/
├── flake.nix
├── overlays/
│   └── haskell-overlay.nix
├── patches/
│   └── hasql/
│       ├── 1.9.nix
│       └── 1.10.nix
└── lib/
    └── mkHaskellOverlay.nix
```

### Responsibilities

| Component | Responsibility                     |
| --------- | ---------------------------------- |
| patches/  | Version‑specific fixes             |
| overlays/ | Dynamic dispatch based on versions |
| lib/      | Reusable helpers                   |
| flake     | Distribution boundary              |

---

## 4. Version‑Aware Overlay

The overlay inspects the resolved package version and applies the appropriate fix.

```nix
self: super:

let
  lib = super.lib;

  fixHasql = pkg:
    let v = pkg.version;
    in
      if lib.versionAtLeast v "1.10" && lib.versionOlder v "1.11"
      then import ../patches/hasql/1.10.nix { pkg = pkg; }
      else if lib.versionAtLeast v "1.9" && lib.versionOlder v "1.10"
      then import ../patches/hasql/1.9.nix { pkg = pkg; }
      else pkg;
in
{
  haskellPackages = super.haskellPackages.override {
    overrides = hself: hsuper: {
      hasql = fixHasql hsuper.hasql;
    };
  };
}
```

---

## 5. Patch Definition

### Example: patches/hasql/1.9.nix

```nix
{ pkg }:

pkg.overrideAttrs (old: {
  jailbreak = true;
  patches = (old.patches or []) ++ [
    ./fix-ghc98.patch
  ];
})
```

### Example: patches/hasql/1.10.nix

```nix
{ pkg }:

pkg.overrideAttrs (old: {
  configureFlags = (old.configureFlags or []) ++ [
    "--flag=new-api"
  ];
})
```

---

## 6. Repository Integration

Each repository imports the fixes independently and pins its own revision.

```nix
inputs.haskell-fixes.url = "github:your-org/nix-haskell";

pkgs = import nixpkgs {
  system = "x86_64-linux";
  overlays = [
    haskell-fixes.overlays.default
  ];
};
```

### Result

| Repo      | hasql Version | Applied Fix |
| --------- | ------------- | ----------- |
| Service A | 1.9.x         | 1.9 patch   |
| Service B | 1.10.x        | 1.10 patch  |
| Service C | 1.11          | none        |

No coordination required.

---

## 7. Generalizing Fix Dispatch

Introduce a helper to avoid per‑package logic duplication.

```nix
fixPackageByVersion = name: table: self: super:
let
  pkg = super.${name};
  v = pkg.version;
  match = lib.findFirst
    (entry: lib.versionAtLeast v entry.min
          && lib.versionOlder v entry.max)
    null
    table;
in
  if match == null then pkg
  else import match.patch { pkg = pkg; };
```

Example usage:

```nix
hasql = fixPackageByVersion "hasql" [
  { min = "1.9"; max = "1.10"; patch = ../patches/hasql/1.9.nix; }
  { min = "1.10"; max = "1.11"; patch = ../patches/hasql/1.10.nix; }
];
```

---

## 8. Upgrade Strategy

### Adding Support for New Version

1. Add new patch file.
2. Extend dispatch table.
3. Release new revision.

Older repositories remain unaffected due to flake pinning.

---

## 9. Local Escape Hatch

Repositories may still override locally:

```nix
overlays = [
  shared.overlays.default

  (self: super: {
    hasql = super.hasql.overrideAttrs (_: {
      doCheck = false;
    });
  })
];
```

Local overrides always take precedence.

---

## 10. Properties of the Architecture

| Property                   | Outcome |
| -------------------------- | ------- |
| Decoupled repos            | ✓       |
| Independent upgrades       | ✓       |
| Shared ecosystem knowledge | ✓       |
| Reproducible builds        | ✓       |
| Multi‑GHC support          | ✓       |
| Gradual migration          | ✓       |

---

## 11. Mental Model

This repository is not shared configuration.

It is a:

> **Compatibility Layer between nixpkgs and the Haskell ecosystem**

Equivalent to a specialized internal nixpkgs overlay.

---

## 12. Long‑Term Evolution (Level 3)

Eventually evolve toward:

* `mkHaskellProject` factory
* package‑set generators
* minimal per‑repo Nix code

Where projects declare intent and the shared layer constructs the environment.

---

## 13. Summary

Version‑scoped patches allow asynchronous upgrades across many Haskell repositories without coupling projects together.

Key idea:

> Share fixes as code, not configuration.

