[User guide](README.md)

# Consumer integration

How to integrate haskell-nix patches into a downstream project.

## Recommended: a channel extension with `composeExtensions`

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

      firstPartyExtension = inputs.haskell-nix.lib.haskellExtensions.github;

      haskellPackages = pkgs.haskell.packages.ghc9122.override {
        overrides = pkgs.lib.composeExtensions
          (firstPartyExtension pkgs.haskell.lib.compose pkgs)
          (import ./nix/haskell-overlay.nix { inherit pkgs; });
      };
    in {
      # use haskellPackages here
    };
}
```

### How it works

The GitHub and Hackage extension constructors have the signature:

```text
haskellLib -> pkgs -> hself -> hsuper -> { ... }
```

Applying a constructor with `pkgs.haskell.lib.compose` and `pkgs` yields a standard Haskell
package-set extension (`hself -> hsuper -> { ... }`). `composeExtensions` chains it with
your local overlay so both sets of overrides are applied.

Choose `.github` for every package at its locked source revision, including unpublished
packages. Choose `.hackage` for the latest recorded official release; unpublished packages
are omitted. Channel selection changes first-party package provenance but retains the
common GHC compatibility registry in both cases.

See the [channel reference](channels.md) for the current package inventory and commands that
show which names each registry exports.

### Ordering

`composeExtensions first second` applies `first`, then `second` on top. Placing the selected
channel extension as the first argument means:

1. haskell-nix patches and selected first-party packages are applied first
2. Your local overrides see the patched package set and can build on or override them

If your local overlay needs to further modify a package that haskell-nix already patches, your version wins because it runs second.

## Why not the overlay

The channel overlays (`inputs.haskell-nix.overlays.github` and `.hackage`) apply patches by
calling `.override` internally. If you then call `.override { overrides = ...; }` on the
same package set, nixpkgs **replaces** the previous overrides rather than composing them —
your local overrides silently wipe out the haskell-nix patches.

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

## Compatibility aliases

Existing consumers do not need an immediate source change. The singular and default names
remain GitHub-channel aliases:

```text
lib.haskellExtension  -> lib.haskellExtensions.github
lib.registry          -> lib.registries.github
overlays.default      -> overlays.github
overlays.haskell      -> overlays.github
```

New code should use the plural or named output so source provenance is visible at the call
site.

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

For a dual-channel change, exercise a consumer target once with
`lib.haskellExtensions.github` selected and once with
`lib.haskellExtensions.hackage` selected. A GitHub-only package is expected to be absent in
the second run; that is an availability guarantee, not a resolution failure to work around.
After the local checks pass, remove `--override-input`, push haskell-nix, update the locked
input normally, and rerun the same consumer target.

See [Troubleshooting](troubleshooting.md) if a later package-set override removes the shared
patches or a package is intentionally unavailable from the selected channel.
