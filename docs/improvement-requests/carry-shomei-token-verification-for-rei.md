---
type: Improvement Request
title: Carry Shomei token verification packages for Rei
description: Add shomei-core, shomei-jwt and their jose dependency to the Rei cohort and its retained runtime so Rei can verify Shomei tokens in both the Cabal and Nix builds.
requestId: IR-5
status: proposed
origin: mori://shinzui/rei/plans/292-verify-shomei-tokens-and-resolve-meibo-principals-on-rei-api-requests
generated:
  by: claude-code/claude-opus-5-5
  at: "2026-11-17T20:30:00Z"
---

# Carry Shomei token verification packages for Rei

Rei ExecPlan 292 (`mori://shinzui/rei/plans/292-verify-shomei-tokens-and-resolve-meibo-principals-on-rei-api-requests`)
adds Shomei JWT verification to `rei-api`. It needs `shomei-core` and `shomei-jwt` from
`mori://shinzui/shomei` (0.3.x, not on Hackage) and their Hackage dependencies `jose` 0.13 and
`concise` 0.1.0.1, which the solver adds when the Shomei pin is present.

Rei's `nix/haskell-overlay.nix` builds only Rei's own packages; shared dependencies come from
this channel, and the retained runtime rejects consumer overrides of shared packages. A local
`source-repository-package` in Rei's `cabal.project` would therefore make the Cabal and Nix
builds disagree, which ADR 016 and `mori://shinzui/mori/okf/adrs/concepts/ADR-24` forbid.

Blocked first on `mori://shinzui/shomei/okf/improvement-requests/concepts/IR-5`: `shomei-core`
0.3.0.0 declares `base64 <1.1`, and the `rei-keiro-0.24` cohort freezes `base64 ==2.0` through
`tls`. A temporary `allow-newer` showed both packages compile against base64 2.0.

Requested: once Shomei releases a version admitting base64 2.0, add a `shomei` source pin
(subdirectories `shomei-core` and `shomei-jwt`) to the `rei-keiro-0.24` profile's
`common.config`, the matching `jose` and `concise` versions to its freeze, and the same
packages to the application selections of the retained runtime Rei uses (keiro-runtime
generation 8, Hackage channel), so `cabal build rei-api` and `nix build` resolve the same
versions. Acceptance: Rei depends on `shomei-jwt` with no local pin or `allow-newer`, and its
runtime derivation identity check still passes.
