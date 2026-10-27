# Bundle Update Log

## 2026-10-27
* **Update**: FRIC-2 accepted: Canonicalize the upstream project reference to its intended Mori URI, pending registration, as required by the user.
* **Update**: FRIC-1 accepted: Canonicalize the upstream project reference to its intended Mori URI, pending registration, as required by the user.
* **Update**: FRIC-2 accepted: Accept the explicit validation environment adapter required by the Nix test wrapper.
* **Update**: FRIC-1 accepted: Accept the existing guest execution constraint for this build matrix.
* **Addition**: FRIC-2 records detour interface friction with mori://nixos/nixpkgs: Nix test wrapper exports an environment that nested Cabal rejects
* **Addition**: FRIC-1 records detour environment friction with mori://apple/container: Translated Linux builder requires a seccomp override
* **Adoption**: Adopt the `friction-log` profile (`coordination.frictionLog`) from https://raw.githubusercontent.com/shinzui/okf-profiles/v0.23.0/package.dhall.
