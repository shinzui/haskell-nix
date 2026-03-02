# haskell-nix

Version-scoped Haskell patch management for multi-repository Nix builds.

A shared flake that provides GHC compatibility patches (jailbreaks, version pins, etc.) as a composable Haskell package set extension. Consumers get a single source of truth for cross-cutting Haskell fixes without maintaining duplicate overrides across projects.

## Usage

### Recommended: direct extension composition

Add the flake input and compose `haskellExtension` with your local overrides:

```nix
{
  inputs.haskell-nix.url = "github:shinzui/haskell-nix";

  outputs = { nixpkgs, ... }@inputs:
    let
      pkgs = import nixpkgs { inherit system; };

      haskellPackages = pkgs.haskell.packages.ghc9122.override {
        overrides = pkgs.lib.composeExtensions
          (inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose)
          (import ./nix/haskell-overlay.nix { inherit pkgs; });
      };
    in { /* ... */ };
}
```

`haskellExtension` has the signature `haskellLib -> hself -> hsuper -> { ... }` — a standard Haskell package set extension once partially applied with `haskellLib`.

### Alternative: nixpkgs overlay

For simpler setups where you don't need to compose with local overrides:

```nix
{
  inputs.haskell-nix.url = "github:shinzui/haskell-nix";

  outputs = { nixpkgs, ... }@inputs:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ inputs.haskell-nix.overlays.default ];
      };
    in { /* ... */ };
}
```

This applies patches to `ghc9122` and `ghc914` package sets automatically. Note that calling `.override { overrides = ...; }` on a package set that received patches via the overlay will **replace** them — use the direct composition approach above if you have local overrides.

## Project structure

```
flake.nix                          # Flake outputs: overlays, lib, checks
lib/
  fixPackageByVersion.nix          # Core version-dispatch primitive
  mkHaskellOverlay.nix             # Registry -> multi-GHC nixpkgs overlay
overlays/
  registry.nix                     # Single source of truth for all patches
  haskell-overlay.nix              # Wires registry to mkHaskellOverlay
patches/
  <package>/<version>.nix          # Complex per-version patch files
```

## Flake outputs

| Output | Description |
|--------|-------------|
| `lib.haskellExtension` | Combined registry extension for direct composition |
| `lib.fixPackageByVersion` | Core version-dispatch primitive |
| `lib.mkHaskellOverlay` | Registry to multi-GHC overlay combinator |
| `lib.registry` | The patch registry attrset |
| `overlays.default` | Nixpkgs overlay applying all patches |
| `checks` | Registry validation and overlay evaluation |

## Adding patches

Edit `overlays/registry.nix`. There are two entry types:

### Always-apply

For patches that should apply regardless of the package version (jailbreaks, unbreaks, etc.):

```nix
my-package = always dontCheckDoJailbreak;
```

Built-in patch helpers: `dontCheckDoJailbreak`, `markUnbrokenDontCheckDoJailbreak`, `dontCheckOnly`.

### Version-scoped

For patches that target specific version ranges (`min <= version < max`):

```nix
hasql = [
  { min = "1.9";  max = "1.10"; patch = import ../patches/hasql/1.9.nix; }
  { min = "1.10"; max = "1.11"; patch = import ../patches/hasql/1.10.nix; }
];
```

### Complex patches

For patches that need more than a one-liner, create a file under `patches/<package>/<version>.nix`:

```nix
# patches/hasql/1.9.nix
{ pkg, lib, haskellLib, ... }:

haskellLib.doJailbreak pkg
```

Patch functions receive `{ pkg, lib, haskellLib, hself, hsuper }`.

## Design notes

**Lazy version dispatch**: Version checks are deferred into attribute values, not into attrset structure. Using `optionalAttrs` with version-dependent predicates forces evaluation of `hsuper.<pkg>`, triggering nixpkgs' splice machinery and causing infinite recursion. See `lib/fixPackageByVersion.nix` for details.

**Multi-GHC support**: The overlay applies patches to all configured compiler sets (`ghc9122`, `ghc914` by default). `haskellPackages` is a self-referencing alias in nixpkgs that automatically picks up changes — no separate override needed.

## Verification

```bash
nix flake check
```

This runs two checks:
- **registry-valid**: validates that all registry entries have the expected structure
- **overlay-eval**: forces evaluation of the overlay to catch wiring errors
