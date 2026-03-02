# Patch registry — single source of truth for all version-scoped patches.
#
# To add a new package:
#   1. For simple patches: add an inline entry using one of the helpers below
#   2. For complex patches: create a file under patches/<package>/<version>.nix
#      and reference it with `import ../patches/...`
#
# Entry types:
#   Version-scoped: { min, max, patch } — applies when min <= version < max
#   Always-apply:   { always = true; patch } — skips version check entirely
#                   (use for packages replaced wholesale via callCabal2nix)
#
# Patch functions receive { pkg, lib, haskellLib, hself, hsuper }.
let
  dontCheckDoJailbreak = { pkg, haskellLib, ... }:
    haskellLib.dontCheck (haskellLib.doJailbreak pkg);

  markUnbrokenDontCheckDoJailbreak = { pkg, haskellLib, ... }:
    haskellLib.markUnbroken (haskellLib.dontCheck (haskellLib.doJailbreak pkg));

  dontCheckOnly = { pkg, haskellLib, ... }:
    haskellLib.dontCheck pkg;

  always = patch: [{ always = true; inherit patch; }];
in
{
  # ── GHC 9.12 tool jailbreaks ──────────────────────────────────────
  ormolu              = always dontCheckDoJailbreak;
  fourmolu            = always dontCheckDoJailbreak;
  stylish-haskell     = always dontCheckDoJailbreak;
  hlint               = always dontCheckDoJailbreak;
  hiedb               = always dontCheckDoJailbreak;
  retrie              = always dontCheckDoJailbreak;
  cabal-gild          = always dontCheckDoJailbreak;
  proto-lens          = always dontCheckDoJailbreak;
  proto-lens-runtime  = always dontCheckDoJailbreak;

  # ── Misc compatibility ─────────────────────────────────────────────
  unicode-data        = always dontCheckOnly;
  fuzzyfind           = always markUnbrokenDontCheckDoJailbreak;
  hasql-migration     = always markUnbrokenDontCheckDoJailbreak;

  # ── Hackage version pins ───────────────────────────────────────────
  optparse-applicative = always (import ../patches/optparse-applicative/0.19.nix);
  streamly-core        = always (import ../patches/streamly-core/0.3.nix);
  streamly             = always (import ../patches/streamly/0.11.nix);

  # ── Version-scoped patches ────────────────────────────────────────
  hasql = [
    { min = "1.9";  max = "1.10"; patch = import ../patches/hasql/1.9.nix; }
    { min = "1.10"; max = "1.11"; patch = import ../patches/hasql/1.10.nix; }
  ];
}
