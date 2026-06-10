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
# Patch functions receive { pkg, lib, haskellLib, pkgs, hself, hsuper }.
let
  dontCheckDoJailbreak = { pkg, haskellLib, ... }:
    haskellLib.dontCheck (haskellLib.doJailbreak pkg);

  markUnbrokenDontCheckDoJailbreak = { pkg, haskellLib, ... }:
    haskellLib.markUnbroken (haskellLib.dontCheck (haskellLib.doJailbreak pkg));

  dontCheckOnly = { pkg, haskellLib, ... }:
    haskellLib.dontCheck pkg;

  doJailbreakOnly = { pkg, haskellLib, ... }:
    haskellLib.doJailbreak pkg;

  always = patch: [{ always = true; inherit patch; }];
in
{
  # ── GHC 9.12 tool jailbreaks ──────────────────────────────────────
  ormolu = always dontCheckDoJailbreak;
  fourmolu = always dontCheckDoJailbreak;
  stylish-haskell = always dontCheckDoJailbreak;
  hlint = always dontCheckDoJailbreak;
  hiedb = always dontCheckDoJailbreak;
  retrie = always dontCheckDoJailbreak;
  cabal-gild = always dontCheckDoJailbreak;
  proto-lens = always dontCheckDoJailbreak;
  proto-lens-runtime = always dontCheckDoJailbreak;

  # ── Misc compatibility ─────────────────────────────────────────────
  unicode-data = always dontCheckOnly;
  fuzzyfind = always markUnbrokenDontCheckDoJailbreak;
  # nixpkgs marks sbv-11.7 broken; the library builds fine — only its test
  # suite needs the z3 solver binary. keiki depends on it (symbolic core).
  sbv = always markUnbrokenDontCheckDoJailbreak;

  # ── Hackage version pins ───────────────────────────────────────────
  optparse-applicative = always (import ../patches/optparse-applicative/0.19.nix);
  streamly-core = always (import ../patches/streamly-core/0.3.nix);
  streamly = always (import ../patches/streamly/0.11.nix);
  validation = always (import ../patches/validation/1.2.nix);

  # ── hasql ecosystem ────────────────────────────────────────────────
  hasql = always (import ../patches/hasql/1.10.nix);
  postgresql-binary = always (import ../patches/postgresql-binary/0.15.nix);
  hasql-pool = always (import ../patches/hasql-pool/1.4.nix);
  hasql-transaction = always (import ../patches/hasql-transaction/1.2.nix);
  hasql-migration = always (import ../patches/hasql-migration/shinzui.nix);
  hasql-implicits = always (import ../patches/hasql-implicits/0.2.nix);
  hasql-dynamic-statements = always (import ../patches/hasql-dynamic-statements/0.5.nix);
  # diogob/hasql-notifications master (0.2.5.0) targets hasql 1.10; the Hackage
  # 0.2.4.0 release nixpkgs ships only supports hasql < 1.10.
  hasql-notifications = always (import ../patches/hasql-notifications/0.2.nix);

  # ── codd (SQL migration tool; kiroku-store-migrations dependency) ──
  codd = always (import ../patches/codd/0.1.nix);
  # haxl (codd dependency) caps `time < 1.13`; GHC 9.12 ships time 1.14.
  haxl = always dontCheckDoJailbreak;

  # ── OpenTelemetry spec v1.40 family (pgmq-effectful 0.3+ dependency) ─
  # Built from the upstream iand675/hs-opentelemetry source; see
  # ../patches/hs-opentelemetry/1.40.nix.
  thread-utils-finalizers = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).thread-utils-finalizers);
  thread-utils-context = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).thread-utils-context);
  hs-opentelemetry-api-types = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-api-types);
  hs-opentelemetry-api = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-api);
  hs-opentelemetry-semantic-conventions = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-semantic-conventions);
  hs-opentelemetry-otlp = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-otlp);
  hs-opentelemetry-sdk = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-sdk);
  hs-opentelemetry-exporter-handle = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-exporter-handle);
  hs-opentelemetry-exporter-in-memory = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-exporter-in-memory);
  hs-opentelemetry-exporter-otlp = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-exporter-otlp);
  hs-opentelemetry-propagator-b3 = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-b3);
  hs-opentelemetry-propagator-datadog = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-datadog);
  hs-opentelemetry-propagator-jaeger = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-jaeger);
  hs-opentelemetry-propagator-w3c = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-w3c);
  hs-opentelemetry-propagator-xray = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-xray);

  # ── Baikai provider abstraction ────────────────────────────────────
  baikai = always (import ../patches/baikai/0.1.nix);
  baikai-claude = always (import ../patches/baikai-claude/0.1.nix);
  baikai-effectful = always (import ../patches/baikai-effectful/0.1.nix);
  baikai-openai = always (import ../patches/baikai-openai/0.1.nix);
  claude = always (import ../patches/claude/shinzui.nix);

  # ── Shikumi typed LM programs (over baikai) ────────────────────────
  shikumi = always (import ../patches/shikumi/0.1.nix);
  openai = always (import ../patches/openai/shinzui.nix);
  cradle = always (import ../patches/cradle/garnix.nix);
  wai-app-static = always (import ../patches/wai-app-static/3.1.nix);

  # ── pgmq ecosystem ────────────────────────────────────────────────
  pgmq-core = always (import ../patches/pgmq-core/0.1.nix);
  pgmq-hasql = always (import ../patches/pgmq-hasql/0.1.nix);
  pgmq-effectful = always (import ../patches/pgmq-effectful/0.1.nix);
  pgmq-migration = always (import ../patches/pgmq-migration/0.1.nix);

  # ── shibuya ────────────────────────────────────────────────────────
  shibuya-core = always (import ../patches/shibuya-core/0.1.nix);
  shibuya-pgmq-adapter = always (import ../patches/shibuya-pgmq-adapter/0.1.nix);

  # ── shinzui event-sourcing stack ───────────────────────────────────
  keiki = always ({ ... }@args: (import ../patches/keiki/0.1.nix args).keiki);
  keiki-codec-json = always ({ ... }@args: (import ../patches/keiki/0.1.nix args).keiki-codec-json);
  kiroku-store = always ({ ... }@args: (import ../patches/kiroku/0.1.nix args).kiroku-store);
  kiroku-store-migrations = always ({ ... }@args: (import ../patches/kiroku/0.1.nix args).kiroku-store-migrations);
  kiroku-test-support = always ({ ... }@args: (import ../patches/kiroku/0.1.nix args).kiroku-test-support);
  shibuya-kiroku-adapter = always ({ ... }@args: (import ../patches/kiroku/0.1.nix args).shibuya-kiroku-adapter);
  keiro = always ({ ... }@args: (import ../patches/keiro/0.1.nix args).keiro);
  keiro-core = always ({ ... }@args: (import ../patches/keiro/0.1.nix args).keiro-core);
  keiro-migrations = always ({ ... }@args: (import ../patches/keiro/0.1.nix args).keiro-migrations);
  keiro-test-support = always ({ ... }@args: (import ../patches/keiro/0.1.nix args).keiro-test-support);
  jitsurei = always ({ ... }@args: (import ../patches/keiro/0.1.nix args).jitsurei);

  # ── crypton 1.1 / tls 2.3 / x509 1.9 cascade ───────────────────────
  # nixpkgs' ghc9122 set ships crypton-1.0.5 (which uses `memory`).
  # crypton-1.1.x switched to `ram`; downstream TLS / x509 / hpke bounds then
  # force the whole stack forward in lockstep. Pinning them here keeps any
  # consumer that depends on crypton-1.1.x (e.g. the shinzui hasql-migration
  # fork) instance-coherent.
  ram = always (import ../patches/ram/0.22.nix);
  crypton = always (import ../patches/crypton/1.1.nix);
  mlkem = always (import ../patches/mlkem/0.2.nix);
  hpke = always (import ../patches/hpke/0.1.nix);
  crypton-x509 = always (import ../patches/crypton-x509/1.9.nix);
  crypton-x509-store = always (import ../patches/crypton-x509-store/1.9.nix);
  crypton-x509-system = always (import ../patches/crypton-x509-system/1.9.nix);
  crypton-x509-validation = always (import ../patches/crypton-x509-validation/1.9.nix);
  tls = always (import ../patches/tls/2.3.nix);
  crypton-connection = always (import ../patches/crypton-connection/0.4.nix);
  http-client-tls = always (import ../patches/http-client-tls/0.4.nix);

  # http-conduit-2.3.9.1 caps http-client-tls < 0.4 in its original .cabal;
  # Hackage has a revision relaxing it to < 0.5 that cabal picks up, but the
  # nixpkgs snapshot ships the unrevised file. Jailbreak to match cabal.
  http-conduit = always doJailbreakOnly;

  # dhall has a manual `use-http-client-tls` flag pinned to http-client-tls
  # <0.4. Disable it so dhall compiles against 0.4.x.
  dhall = always (import ../patches/dhall/no-http-client-tls.nix);

  # ── ephemeral-pg (test PostgreSQL; keiro/kiroku test-support dependency) ──
  ephemeral-pg = always (import ../patches/ephemeral-pg/0.2.nix);

  # ── Version-scoped patches ────────────────────────────────────────
}
