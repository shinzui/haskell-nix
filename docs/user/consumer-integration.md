# Consumer integration

How to integrate haskell-nix patches into a downstream project.

## Recommended: `haskellExtension` with `composeExtensions`

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    haskell-nix.url = "github:shinzui/haskell-nix";
  };

  outputs = { nixpkgs, ... }@inputs:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };

      haskellPackages = pkgs.haskell.packages.ghc9122.override {
        overrides = pkgs.lib.composeExtensions
          (inputs.haskell-nix.lib.haskellExtension pkgs.haskell.lib.compose)
          (import ./nix/haskell-overlay.nix { inherit pkgs; });
      };
    in {
      # use haskellPackages here
    };
}
```

### How it works

`haskellExtension` has the signature:

```
haskellLib -> hself -> hsuper -> { ... }
```

Partially applying with `pkgs.haskell.lib.compose` yields a standard Haskell package set extension (`hself -> hsuper -> { ... }`). `composeExtensions` chains it with your local overlay so both sets of overrides are applied.

### Ordering

`composeExtensions first second` applies `first`, then `second` on top. Placing `haskellExtension` as the first argument means:

1. haskell-nix patches are applied first
2. Your local overrides see the patched package set and can build on or override them

If your local overlay needs to further modify a package that haskell-nix already patches, your version wins because it runs second.

## Why not the overlay

The overlay (`inputs.haskell-nix.overlays.default`) applies patches by calling `.override` internally. If you then call `.override { overrides = ...; }` on the same package set, nixpkgs **replaces** the previous overrides rather than composing them — your local overrides silently wipe out the haskell-nix patches.

There is an `old:` workaround:

```nix
# Fragile — works but easy to get wrong
pkgs.haskell.packages.ghc9122.override (old: {
  overrides = pkgs.lib.composeExtensions
    (old.overrides or (_: _: { }))
    myOverrides;
})
```

This preserves existing overrides by threading `old.overrides` through, but it's fragile and the composition order is implicit. The `haskellExtension` approach avoids the problem entirely — no overlay on pkgs, no `old:` pattern, explicit composition.

## Updating the lock

When haskell-nix receives new patches:

```bash
nix flake update haskell-nix
```

This updates only the `haskell-nix` input in your lock file. Run your build or `nix flake check` afterwards to verify nothing broke.

### Deployment sequencing

When making changes to haskell-nix that consumers depend on:

1. Push the haskell-nix changes first
2. Run `nix flake update haskell-nix` in each consumer
3. Then update consumer `flake.nix` if needed (e.g. using a newly added package)

Editing a consumer's `flake.nix` to reference something that hasn't been pushed to haskell-nix yet will break `direnv` / `nix develop` because the lock still points to the old revision.

## Local testing with `--override-input`

To test haskell-nix changes from a consumer before pushing:

```bash
# From the consumer project directory
nix build --override-input haskell-nix path:/path/to/local/haskell-nix
```

Or for a dev shell:

```bash
nix develop --override-input haskell-nix path:/path/to/local/haskell-nix
```

This temporarily replaces the locked haskell-nix input with your local checkout without modifying the lock file. Useful for testing patches end-to-end before committing.
