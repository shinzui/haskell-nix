# Bundle Update Log

## 2026-08-21
* **Status change**: IR-1 `proposed` -> `completed`. Shipped as the opt-in `disableHaddock` flag on `lib.mkChannelExtension` and `lib.mkHaskellOverlay`, backed by `lib/disableHaddockOverride.nix` and the `build-setting-flags` check.
* **Decision recorded**: the two build-setting flags stay separate rather than collapsing into one `leanBuild`. No consumer had adopted `disableProfiling`, so enabling both together still costs a single rebuild.

## 2026-08-11
* **Addition**: IR-1: stop building Haddock for the package sets haskell-nix patches (raised by `shinzui/dotfiles.nix` while cutting the time `darwin-rebuild switch` spends compiling the globally installed Haskell CLIs).
* **Bundle created**: `improvement-requests`, bound to the published `shinzui/okf-profiles` `coordination.improvementRequests` v0.8.0 profile.
