---
type: Guide
title: Adding compatibility patches
description: Add and verify shared compatibility patches for the GitHub and Hackage channels.
docId: DOC-2
tags: [patches, compatibility, maintainers]
generated:
  by: human:nadeem
  at: 2026-10-16T14:44:08Z
---

[User guide](README.md)

# Adding compatibility patches

Shared compatibility patches live in `overlays/registry.nix`. That registry is composed into
both the GitHub and Hackage channels. First-party family sources do not belong there: add or
refresh those through `config/first-party-families.json` and `haskell-nix-update` as
described in [Updating first-party packages](updating-first-party-packages.md).

Third-party Hackage versions come from `cabal/cohort.freeze` and its generated projection,
`generated/cohort-versions.nix`. Add a required package to the cohort's declared policy roots
and upgrade-only floors, solve and verify the cohort, then run `just cohort-generate`.
Do not edit the generated file or fetch a Hackage release from a registry patch.
`registry-policy-only` rejects those fetches in `overlays/` and `patches/`.

The registry wraps the generated versions with build policy: compiler compatibility fixes,
explicit jailbreaks, flags and exceptions for owned non-Hackage sources. Public unpublished
sources use fixed revisions and hashes, as in `patches/typeid-hs/`. Record source ownership
and intentional differences in `config/cohort-policy.json` and the cohort source manifest.
Consumer overlays reuse these recipes; the
[ownership audit](consumer-integration.md#audit-your-local-overlay) enforces that boundary.

The common registry supports two entry types: **always-apply** and **version-scoped**.

## Always-apply entries

Use for patches that should apply regardless of the package version (jailbreaks, unbreaks, or owned non-Hackage sources).

### Built-in helpers

The registry defines five helpers at the top of the file:

| Helper | Effect |
|--------|--------|
| `dontCheckDoJailbreak` | `dontCheck` + `doJailbreak` |
| `markUnbrokenDontCheckDoJailbreak` | `markUnbroken` + `dontCheck` + `doJailbreak` |
| `dontCheckOnly` | `dontCheck` only |
| `markUnbrokenDontCheck` | `markUnbroken` + `dontCheck` |
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
| `pkg` | The selected derivation at this stage, including the generated version layer |
| `lib` | `nixpkgs.lib` |
| `haskellLib` | `haskell.lib.compose` — the standard Haskell derivation helpers |
| `pkgs` | The top-level Nixpkgs package set |
| `hself` | The final (fixed-point) Haskell package set |
| `hsuper` | The previous Haskell package set before this overlay |

## Version-scoped entries

Use when a patch should only apply to a specific version range. The range is half-open: `min <= version < max`.

```nix
cborg-json = [{
  min = "0.2.6.0";
  max = "0.2.6.1";
  patch = import ../patches/cborg-json/0.2.6-ghc914.nix;
}];
```

The first matching entry wins. If no entry matches the resolved version, the package passes through unmodified.

Version comparison uses `lib.versionAtLeast` and `lib.versionOlder`, which compare dot-separated numeric components.

## Complex patches in `patches/`

When a patch needs more than a one-liner, create a file under `patches/<package>/<version>.nix`:

```nix
# patches/my-package/compatibility.nix
{ pkg, lib, haskellLib, ... }:

haskellLib.appendConfigureFlags pkg [ "--flag=new-api" ]
```

Reference it from the registry with `import`:

```nix
my-package = [
  { min = "1.0"; max = "1.1"; patch = import ../patches/my-package/compatibility.nix; }
];
```

### Dependencies used only by disabled upstream tests

Generated third-party recipes disable tests because the cohort solves upstream libraries,
not their test suites. Cabal2nix can still require an argument for a test dependency missing
from the pinned Nixpkgs. Declare that argument in `overlays/cohort-arguments.nix` only after
checking the released Cabal file. Use a lazy `throw` with an explanatory message, rather
than a replacement package: construction succeeds while tests are disabled, but an active
component that uses the missing argument fails. This policy never chooses a version or source.

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
  pkgs.haskell.packages.ghc9124.PACKAGE
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
