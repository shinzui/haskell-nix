[User guide](README.md)

# Adding compatibility patches

Shared compatibility patches live in `overlays/registry.nix`. That registry is composed into
both the GitHub and Hackage channels. First-party family sources do not belong there: add or
refresh those through `config/first-party-families.json` and `haskell-nix-update` as
described in [Updating first-party packages](updating-first-party-packages.md).

The common registry supports two entry types: **always-apply** and **version-scoped**.

## Always-apply entries

Use for patches that should apply regardless of the package version (jailbreaks, unbreaks, Hackage pins).

### Built-in helpers

The registry defines four helpers at the top of the file:

| Helper | Effect |
|--------|--------|
| `dontCheckDoJailbreak` | `dontCheck` + `doJailbreak` |
| `markUnbrokenDontCheckDoJailbreak` | `markUnbroken` + `dontCheck` + `doJailbreak` |
| `dontCheckOnly` | `dontCheck` only |
| `doJailbreakOnly` | `doJailbreak` only |

Add an entry with the `always` wrapper:

```nix
# overlays/registry.nix
my-package = always dontCheckDoJailbreak;
```

This generates `[{ always = true; patch = dontCheckDoJailbreak; }]` — the version check is skipped entirely.

### Custom inline patches

For one-liners that don't fit the built-in helpers, write an inline function:

```nix
my-package = always ({ pkg, haskellLib, ... }:
  haskellLib.appendConfigureFlags pkg [ "--flag=some-flag" ]);
```

The patch function receives `{ pkg, lib, haskellLib, pkgs, hself, hsuper }`:

| Argument | Description |
|----------|-------------|
| `pkg` | The package derivation from `hsuper` (i.e. the unpatched version) |
| `lib` | `nixpkgs.lib` |
| `haskellLib` | `haskell.lib.compose` — the standard Haskell derivation helpers |
| `pkgs` | The top-level Nixpkgs package set |
| `hself` | The final (fixed-point) Haskell package set |
| `hsuper` | The previous Haskell package set before this overlay |

## Version-scoped entries

Use when a patch should only apply to a specific version range. The range is half-open: `min <= version < max`.

```nix
hasql = [
  { min = "1.9";  max = "1.10"; patch = import ../patches/hasql/1.9.nix; }
  { min = "1.10"; max = "1.11"; patch = import ../patches/hasql/1.10.nix; }
];
```

The first matching entry wins. If no entry matches the resolved version, the package passes through unmodified.

Version comparison uses `lib.versionAtLeast` and `lib.versionOlder`, which compare dot-separated numeric components.

## Complex patches in `patches/`

When a patch needs more than a one-liner, create a file under `patches/<package>/<version>.nix`:

```nix
# patches/hasql/1.10.nix
{ pkg, lib, haskellLib, ... }:

haskellLib.appendConfigureFlags pkg [ "--flag=new-api" ]
```

Reference it from the registry with `import`:

```nix
hasql = [
  { min = "1.10"; max = "1.11"; patch = import ../patches/hasql/1.10.nix; }
];
```

### Using `callCabal2nix` for Hackage version pins

To pin a package to a specific Hackage release (e.g. for GHC compatibility), use `hself.callCabal2nix` inside the patch. This replaces the package wholesale rather than modifying it, so it must be an always-apply entry:

```nix
# patches/optparse-applicative/0.19.nix
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "optparse-applicative"
  (builtins.fetchTarball {
    url = "https://hackage.haskell.org/package/optparse-applicative-0.19.0.0/optparse-applicative-0.19.0.0.tar.gz";
    sha256 = "sha256-dhqvRILfdbpYPMxC+WpAyO0KUfq2nLopGk1NdSN2SDM=";
  })
  { }))
```

Note: `callCabal2nix` patches use `hself` (not `pkg`) because they construct a new derivation rather than modifying the existing one. The `pkg` argument is available but unused — destructure with `...` to ignore it.

Wire it in the registry as an always-apply entry:

```nix
optparse-applicative = always (import ../patches/optparse-applicative/0.19.nix);
```

To get the SRI `sha256` for a new tarball, use the same prefetch operation as the first-party
updater:

```bash
nix store prefetch-file --json --unpack URL
```

Copy the returned `hash` value, or temporarily use `lib.fakeHash` and let the focused build
report the expected hash.

## Verification

After adding or modifying a patch, run:

```bash
nix flake check --print-build-logs
```

This validates both composed registry structures and evaluates the channel overlays. The
`overlay-eval` check does **not** build the changed package or guarantee that its version
dispatch branch was selected. Build the actual package under a supported compiler:

```bash
nix build --no-link --print-build-logs --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs {
      system = builtins.currentSystem;
      overlays = [ flake.overlays.github ];
    };
  in
  pkgs.haskell.packages.ghc9122.PACKAGE
'
```

Replace `PACKAGE` with the changed package attribute. Because common compatibility patches
feed both source channels, repeat the focused build with `flake.overlays.hackage` when the
package graph or source provenance could change the result.

Finally, test the real consumer target with `--override-input`:

```bash
nix build --override-input haskell-nix path:/path/to/haskell-nix
```

For membership or shared dependency changes, follow the complete matrix procedure in
[Updating first-party packages](updating-first-party-packages.md), not only the lightweight
overlay check.
