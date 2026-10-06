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

  markUnbrokenDontCheck = { pkg, haskellLib, ... }:
    haskellLib.markUnbroken (haskellLib.dontCheck pkg);

  doJailbreakOnly = { pkg, haskellLib, ... }:
    haskellLib.doJailbreak pkg;

  always = patch: [{ always = true; inherit patch; }];
  admittingRevision = version: max: revision: sha256: [{
    min = version;
    inherit max;
    patch = import ../patches/metadata/admitting-revision-ghc914.nix {
      inherit version revision sha256;
    };
  }];
in
{
  kioku-core = [{
    always = true;
    # Apply after generated first-party source selection, preserving that source.
    afterFirstParty = true;
    patch = import ../patches/kioku-core/0.8.0.2-ghc9141.nix;
  }];
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
  unicode-data = always (args: import ../patches/unicode-data/0.6-ghc914.nix (args // { pkg = dontCheckOnly args; }));
  fuzzyfind = always markUnbrokenDontCheckDoJailbreak;
  # nixpkgs marks sbv-11.7 broken; the library builds fine — only its test
  # suite needs the z3 solver binary. keiki depends on it (symbolic core).
  sbv = always markUnbrokenDontCheckDoJailbreak;

  # ── Hackage version pins ───────────────────────────────────────────
  optparse-applicative = always (import ../patches/optparse-applicative/0.19.nix);
  streamly-core = always (import ../patches/streamly-core/0.3.nix);
  streamly = always (import ../patches/streamly/0.11.nix);
  validation = always (import ../patches/validation/1.2.nix);
  # Upstream's admitting release preserves tests/bounds on the GHC 9.14 matrix.
  # Automatically retires when the selected layer supplies 0.5.0.16 or newer.
  bytestring-lexing = [{
    min = "0.5.0.15";
    max = "0.5.0.16";
    patch = import ../patches/bytestring-lexing/0.5.nix;
  }];
  # Exact upstream metadata repair, restricted to 0.2.6.0 and GHC 9.14.
  cborg-json = [{
    min = "0.2.6.0";
    max = "0.2.6.1";
    patch = import ../patches/cborg-json/0.2.6-ghc914.nix;
  }];
  dec = [{
    min = "0.0.6";
    max = "0.0.7";
    patch = import ../patches/dec/0.0.6-ghc914.nix;
  }];
  http-api-data = [{
    min = "0.6.3";
    max = "0.6.4";
    patch = import ../patches/http-api-data/0.6.3-ghc914.nix;
  }];
  tasty-wai = [{
    min = "0.1.2.0";
    max = "0.1.2.1";
    patch = import ../patches/tasty-wai/0.1.2-ghc914.nix;
  }];
  lens-family-core = [{
    min = "2.1.3";
    max = "2.1.4";
    patch = import ../patches/lens-family/2.1.3-ghc914.nix {
      name = "lens-family-core";
      sha256 = "3714c3fa57a556d6fb958234fa4cde8401e098458dc9041416c54d25ec187473";
    };
  }];
  lens-family = [{
    min = "2.1.3";
    max = "2.1.4";
    patch = import ../patches/lens-family/2.1.3-ghc914.nix {
      name = "lens-family";
      sha256 = "e368ef693ed3d894dcec1735fe2952ab876c49a88231c7d76289d2a9d2bdd66f";
    };
  }];
  rebase = [{
    min = "1.21.2";
    max = "1.22";
    patch = import ../patches/rebase/1.21-ghc914.nix;
  }];
  rerebase = [{
    min = "1.21.2";
    max = "1.22";
    patch = import ../patches/rerebase/1.21-ghc914.nix;
  }];
  tasty-hspec = [{
    min = "1.2.0.4";
    max = "1.2.0.5";
    patch = import ../patches/tasty-hspec/1.2.0-ghc914.nix;
  }];
  # Published GHC 9.14 metadata for mori://phadej/singleton-bool (singleton-bool.cabal;
  # artifact-level URI pending) and mori://haskell-servant/servant/packages/servant,
  # mori://haskell-servant/servant/packages/servant-client,
  # mori://haskell-servant/servant/packages/servant-client-core,
  # mori://haskell-servant/servant/packages/servant-foreign,
  # mori://haskell-servant/servant/packages/servant-docs.
  # Exact identities: https://hackage.haskell.org/package/<name>-<version>/revisions/
  singleton-bool = admittingRevision "0.1.8" "0.1.9" "2" "94988e14281fa9c70714fbae5e32031f7008919c13b060ee16c714edb62858c0";
  servant = admittingRevision "0.20.3.0" "0.20.3.1" "7" "4fe47ef2b2939c018cb0f87f3cd8ede0ae5365a275ad33e3deca109319d42a6f";
  servant-client = admittingRevision "0.20.3.0" "0.20.3.1" "4" "c152c3b72328987f10dd0e2007c703404787e29d0947cad7d033a223a506bbd3";
  servant-client-core = admittingRevision "0.20.3.0" "0.20.3.1" "5" "6611f79f74626c68483e30ff9f6acd0e14f5fedcef710d8472c14be6318cef7c";
  servant-foreign = admittingRevision "0.16.1" "0.16.2" "3" "1b61e76b974e217b33c9c676e950ea15df7ad900dedb54756276bb65d88b7f7d";
  servant-docs = admittingRevision "0.13.1" "0.13.2" "3" "69402db0eb641ee31e20c6e449baf58dac5bbe190150d3eb6d7f5fe861275048";

  # ── hasql ecosystem ────────────────────────────────────────────────
  hasql = always (import ../patches/hasql/1.10.nix);
  postgresql-binary = always (import ../patches/postgresql-binary/0.15.nix);
  hasql-pool = always (import ../patches/hasql-pool/1.4.nix);
  hasql-transaction = always (import ../patches/hasql-transaction/1.2.nix);
  hasql-migration = always (import ../patches/hasql-migration/shinzui.nix);
  hasql-implicits = always (import ../patches/hasql-implicits/0.2.nix);
  hasql-dynamic-statements = always (import ../patches/hasql-dynamic-statements/0.5.nix);
  # Hackage 0.2.5.0 targets hasql 1.10; the 0.2.4.0 release nixpkgs ships only
  # supports hasql < 1.10.
  hasql-notifications = always (import ../patches/hasql-notifications/0.2.nix);

  # ── codd (SQL migration tool; kiroku-store-migrations dependency) ──
  codd = always (import ../patches/codd/0.1.nix);
  # haxl (codd dependency) caps `time < 1.13`; GHC 9.12 ships time 1.14.
  haxl = always dontCheckDoJailbreak;

  # ── OpenTelemetry spec v1.40 family (pgmq-effectful 0.3+ dependency) ─
  # Hackage 1.0.0.0 release line; see ../patches/hs-opentelemetry/1.40.nix.
  # nixpkgs already ships the thread-utils releases the family needs
  # (finalizers 0.1.1.0, context 0.4.1.0).
  thread-utils-finalizers = always dontCheckDoJailbreak;
  thread-utils-context = always dontCheckDoJailbreak;
  hs-opentelemetry-api-types = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-api-types);
  hs-opentelemetry-api = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-api);
  hs-opentelemetry-semantic-conventions = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-semantic-conventions);
  hs-opentelemetry-otlp = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-otlp);
  hs-opentelemetry-sdk = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-sdk);
  hs-opentelemetry-exporter-handle = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-exporter-handle);
  hs-opentelemetry-exporter-in-memory = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-exporter-in-memory);
  hs-opentelemetry-exporter-otlp = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-exporter-otlp);
  hs-opentelemetry-instrumentation-wai = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-instrumentation-wai);
  hs-opentelemetry-propagator-b3 = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-b3);
  hs-opentelemetry-propagator-datadog = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-datadog);
  hs-opentelemetry-propagator-jaeger = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-jaeger);
  hs-opentelemetry-propagator-w3c = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-w3c);
  hs-opentelemetry-propagator-xray = always ({ ... }@args: (import ../patches/hs-opentelemetry/1.40.nix args).hs-opentelemetry-propagator-xray);

  # ── Provider clients and generated-family dependencies ─────────────
  claude = always (import ../patches/claude/1.5.nix);
  # okf-core comes from the okf first-party family (packages/first-party-lock.json).

  # blake3 portable build for aarch64-darwin (shikumi-cache cache key).
  blake3 = always (import ../patches/blake3/portable.nix);
  openai = always (import ../patches/openai/2.5.nix);
  # nixpkgs marks the Hackage cradle-0.0.0.0 broken; the library (all baikai
  # uses) builds with bounds relaxed and tests off.
  cradle = always markUnbrokenDontCheckDoJailbreak;
  # 3.2.x uses cryptohash-md5, avoiding the crypton memory/ram instance clash.
  wai-app-static = always (import ../patches/wai-app-static/3.2.nix);
  # The original 0.20.3.0 metadata caps wai-app-static below 3.2.
  servant-server = always dontCheckDoJailbreak;

  # Shared application HTTP/utility policy belongs in the channel.
  # link-canonical 0.1.0.0 caps http-client-tls and generic-lens below this stack.
  link-canonical = always dontCheckDoJailbreak;
  # Kafka integration tests need a broker; use the maintained runtime source when selected.
  hw-kafka-client = always dontCheckDoJailbreak;
  servant-health = always (import ../patches/servant-health/0.1.nix);
  generic-lens-core = always (import ../patches/generic-lens-core/2.3.nix);
  generic-lens = always (import ../patches/generic-lens/2.3.nix);

  # Public source pins: preserve their Cabal source-repository-package revisions.
  typeid-hs-sql = always (import ../patches/typeid-hs/sql.nix);
  typeid-hs-pg-migrate = always (import ../patches/typeid-hs/pg-migrate.nix);
  hs-opentelemetry-instrumentation-servant = always (import ../patches/hs-opentelemetry-instrumentation-servant/source.nix);

  # ── separate Shibuya adapter repository ────────────────────────────
  shibuya-pgmq-adapter = always (import ../patches/shibuya-pgmq-adapter/0.16.nix);

  # ── shinzui event-sourcing stack ───────────────────────────────────
  # keiki and kioku are first-party families; their records are generated into
  # packages/first-party-lock.json rather than pinned here.

  # ── crypton 1.1 / tls 2.3 / x509 1.9 cascade ───────────────────────
  # nixpkgs' ghc9124 set ships crypton-1.0.6 (which uses `memory`).
  # crypton-1.1.x switched to `ram`; downstream TLS / x509 / hpke bounds then
  # force the whole stack forward in lockstep. Pinning them here keeps any
  # consumer that depends on crypton-1.1.x (e.g. the shinzui hasql-migration
  # fork) instance-coherent.
  # nixpkgs already ships ram 0.22.0 and mlkem 0.2.0.0 (tls 2.3 needs >= 0.2),
  # but marks mlkem broken; unbreak it.
  ram = always dontCheckOnly;
  crypton = always (import ../patches/crypton/1.1.nix);
  crypto-token = always (import ../patches/crypto-token/0.2.nix);
  mlkem = always markUnbrokenDontCheck;
  hpke = always (import ../patches/hpke/0.1.nix);
  crypton-x509 = always (import ../patches/crypton-x509/1.9.nix);
  crypton-x509-store = always (import ../patches/crypton-x509-store/1.9.nix);
  crypton-x509-system = always (import ../patches/crypton-x509-system/1.9.nix);
  crypton-x509-validation = always (import ../patches/crypton-x509-validation/1.9.nix);
  tls = always (import ../patches/tls/2.3.nix);
  # 0.0.9 caps crypto-token < 0.2 and tls < 2.3 even though both updates retain
  # the APIs it uses. Keep the package on the instance-coherent shared stack.
  tls-session-manager = always doJailbreakOnly;
  crypton-connection = always (import ../patches/crypton-connection/0.4.nix);
  http-client-tls = always (import ../patches/http-client-tls/0.4.nix);

  # http-conduit-2.3.9.1 caps http-client-tls < 0.4 in its original .cabal;
  # Hackage has a revision relaxing it to < 0.5 that cabal picks up, but the
  # nixpkgs snapshot ships the unrevised file. Jailbreak to match cabal.
  http-conduit = always doJailbreakOnly;

  # dhall's `use-http-client-tls` flag pins http-client-tls <0.4. Relax the
  # bound rather than disabling the flag: without the flag every remote Dhall
  # import throws `TlsNotSupported` at runtime, on cache miss only.
  dhall = always (args: import ../patches/dhall/keep-http-client-tls.nix (args // {
    pkg = import ../patches/dhall/1.42.3-ghc914.nix args;
  }));
  # dhall-1.42.3 depends on the latest Hackage repline release, 0.4.3.0.
  # That release caps containers below 0.8 even though its API usage remains
  # compatible; GHC 9.14.1 ships containers-0.8.
  repline = always doJailbreakOnly;

  # ── ephemeral-pg (test PostgreSQL; keiro/kiroku test-support dependency) ──
  # Public 0.3.1.0 exports withCachedConfig so consumers can set a stable cleanup
  # root. Older stock versions cannot supply that API, regardless of jailbreak.
  ephemeral-pg = always (import ../patches/ephemeral-pg/0.3.1.nix);

  # ── Version-scoped patches ────────────────────────────────────────
}
