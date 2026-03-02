# Adding patches

All patches live in `overlays/registry.nix` — the single source of truth. There are two entry types: **always-apply** and **version-scoped**.

## Always-apply entries

Use for patches that should apply regardless of the package version (jailbreaks, unbreaks, Hackage pins).

### Built-in helpers

The registry defines three helpers at the top of the file:

| Helper | Effect |
|--------|--------|
| `dontCheckDoJailbreak` | `dontCheck` + `doJailbreak` |
| `markUnbrokenDontCheckDoJailbreak` | `markUnbroken` + `dontCheck` + `doJailbreak` |
| `dontCheckOnly` | `dontCheck` only |

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

The patch function receives `{ pkg, lib, haskellLib, hself, hsuper }`:

| Argument | Description |
|----------|-------------|
| `pkg` | The package derivation from `hsuper` (i.e. the unpatched version) |
| `lib` | `nixpkgs.lib` |
| `haskellLib` | `haskell.lib.compose` — the standard Haskell derivation helpers |
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

To get the `sha256` for a new tarball, use `nix-prefetch-url --unpack <url>` or set it to `lib.fakeHash` and let the build error tell you the correct hash.

## Verification

After adding or modifying a patch, run:

```bash
nix flake check
```

This validates registry structure and evaluates the overlay. Note that `overlay-eval` checks structural integrity but does **not** force version dispatch — the patch is only exercised when the package is actually built. To fully test a patch, build a package that uses it:

```bash
nix build .#checks.aarch64-darwin.overlay-eval
```

Or test from a consumer project with `--override-input`:

```bash
nix build --override-input haskell-nix path:/path/to/haskell-nix
```
