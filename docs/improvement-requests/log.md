# Bundle Update Log

## 2026-10-19
* **Addition**: IR-3 requests targeted published Kioku 0.10.0.0 cohort support and a later Store/runtime update only after the structured error fix is released; no broad refresh or implementation is authorized.

## 2026-10-16
* **Status change**: Complete IR-2: publish Seihou 0.31.0 and adopt the shared generated cohort in Hurl Workbench; default Nix build and full native release gate pass. EP-9 Linux and fresh-CI cache gates remain separate.
* **Update**: Record IR-2 generated-cohort delivery and passing isolated Hurl pin-removal rehearsal; keep permanent managed-pin adoption and remaining matrix gates open.

## 2026-09-21
* **Addition**: IR-2 requests the tested Aeson/generic-lens and WAI/Warp compatibility cohorts discovered while packaging `mori://shinzui/hurl-workbench`, including every transitive version required to replace its consumer-local fixed-hash graph.

## 2026-08-21
* **Status change**: IR-1 `proposed` -\> `completed`. Shipped as the opt-in `disableHaddock` flag on `lib.mkChannelExtension` and `lib.mkHaskellOverlay`, backed by `lib/disableHaddockOverride.nix` and the `build-setting-flags` check.
* **Decision recorded**: the two build-setting flags stay separate rather than collapsing into one `leanBuild`. No consumer had adopted `disableProfiling`, so enabling both together still costs a single rebuild.

## 2026-08-11
* **Addition**: IR-1: stop building Haddock for the package sets haskell-nix patches (raised by `shinzui/dotfiles.nix` while cutting the time `darwin-rebuild switch` spends compiling the globally installed Haskell CLIs).
* **Bundle created**: `improvement-requests`, bound to the published `shinzui/okf-profiles` `coordination.improvementRequests` v0.8.0 profile.
