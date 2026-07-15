# haskell-nix

Version-scoped Haskell patch management for multi-repository Nix builds.

A shared flake that provides GHC compatibility patches (jailbreaks, version pins, etc.) and selectable first-party package sources as composable Haskell package set extensions. Consumers get a single source of truth for cross-cutting Haskell fixes without maintaining duplicate overrides across projects.

## Usage

### Recommended: direct extension composition

Add the flake input, choose the GitHub or Hackage channel, and compose its extension with
your local overrides. The GitHub channel includes unpublished first-party packages and is
the compatibility default:

```nix
{
  inputs.haskell-nix.url = "github:shinzui/haskell-nix";

  outputs = { nixpkgs, ... }@inputs:
    let
      pkgs = import nixpkgs { inherit system; };

      firstPartyExtension = inputs.haskell-nix.lib.haskellExtensions.github;

      haskellPackages = pkgs.haskell.packages.ghc9122.override {
        overrides = pkgs.lib.composeExtensions
          (firstPartyExtension pkgs.haskell.lib.compose pkgs)
          (import ./nix/haskell-overlay.nix { inherit pkgs; });
      };
    in { /* ... */ };
}
```

Change `.github` to `.hackage` to select published Hackage releases. Each constructor has
the signature `haskellLib -> pkgs -> hself -> hsuper -> { ... }`; after applying
`haskellLib` and the top-level Nixpkgs set, it is a standard Haskell package-set extension.
The legacy `lib.haskellExtension` output is an exact alias for
`lib.haskellExtensions.github`.

### Alternative: nixpkgs overlay

For simpler setups where you don't need to compose with local overrides:

```nix
{
  inputs.haskell-nix.url = "github:shinzui/haskell-nix";

  outputs = { nixpkgs, ... }@inputs:
    let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ inputs.haskell-nix.overlays.github ];
      };
    in { /* ... */ };
}
```

Use `overlays.hackage` for published releases. `overlays.default` and `overlays.haskell`
are exact aliases for `overlays.github`. Each overlay applies patches to `ghc9122` and
`ghc914` automatically. Note that calling `.override { overrides = ...; }` on a package
set that received patches via the overlay will **replace** them — use the direct
composition approach above if you have local overrides.

## Project structure

```text
flake.nix                          # Flake outputs: overlays, lib, checks
config/
  first-party-families.json       # Hand-authored first-party family policy
packages/
  first-party-lock.json           # Generated revisions, paths, versions, and hashes
lib/
  fixPackageByVersion.nix          # Core version-dispatch primitive
  mkFirstPartyRegistries.nix       # JSON contracts -> GitHub/Hackage registries
  mkHaskellOverlay.nix             # Registry -> multi-GHC nixpkgs overlay
overlays/
  registry.nix                     # Common compatibility patches
  haskell-overlay.nix              # Wires a selected registry to mkHaskellOverlay
patches/
  <package>/<version>.nix          # Complex per-version patch files
```

## Flake outputs

| Output | Description |
|--------|-------------|
| `lib.haskellExtensions.github` | Compatibility patches plus first-party GitHub sources |
| `lib.haskellExtensions.hackage` | Compatibility patches plus published first-party releases |
| `lib.haskellExtension` | Exact alias for `lib.haskellExtensions.github` |
| `lib.fixPackageByVersion` | Core version-dispatch primitive |
| `lib.mkHaskellOverlay` | Registry to multi-GHC overlay combinator |
| `lib.registries.github` / `.hackage` | Selected patch registry attrsets |
| `lib.registry` | Exact alias for `lib.registries.github` |
| `overlays.github` / `.hackage` | Nixpkgs overlays for each channel |
| `overlays.default` / `.haskell` | Exact aliases for `overlays.github` |
| `checks` | Schema fixtures, registry validation, and channel overlay evaluation |

## Adding patches

Edit `overlays/registry.nix` for common compatibility patches. First-party source metadata
lives in the JSON contracts described in
[Updating first-party packages](docs/user/updating-first-party-packages.md). There are two
common-registry entry types:

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

**Offline channel evaluation**: Nix reads the checked-in family config, package lock, and
`flake.lock`. Hackage and GitHub are never queried during evaluation.

## Verification

```bash
nix flake check
```

This runs three checks:

- **first-party-registry**: validates schemas, rejects invalid fixtures, and applies a local GitHub fixture under both compiler sets
- **registry-valid**: validates both composed channel registries
- **overlay-eval**: forces both overlays under `ghc9122` and `ghc914`
