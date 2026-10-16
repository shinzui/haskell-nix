# Build policy registry. Hackage versions come from generated/cohort-versions.nix.
# Entries retain bounds/test/flag/compiler policy and exact non-Hackage sources.
# Version-scoped rows match the generated selection; source selection belongs to the cohort.
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
  kioku-cli = [{
    always = true;
    afterFirstParty = true;
    patch = import ../patches/kioku-cli/0.8.0.2-ghc9141.nix;
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
  monad-control = [{
    min = "1.0.3.1";
    max = "1.0.3.2";
    patch = import ../patches/monad-control/transformers-compat-0.8.nix;
  }];
  errors = [{
    min = "2.3.0";
    max = "2.3.1";
    patch = import ../patches/errors/transformers-compat-0.8.nix;
  }];
  unicode-data = always (args: import ../patches/unicode-data/0.6-ghc914.nix (args // { pkg = dontCheckOnly args; }));
  fuzzyfind = always markUnbrokenDontCheckDoJailbreak;
  # SBV integration tests need an external solver; retain the shared test and
  # broken-package policy used by the symbolic runtime.
  sbv = always markUnbrokenDontCheckDoJailbreak;

  # ── Bound policy applied after generated source selection ───────────
  optparse-applicative = always doJailbreakOnly;
  streamly-core = always doJailbreakOnly;
  streamly = always doJailbreakOnly;
  validation = always doJailbreakOnly;
  # Exact upstream metadata repair, restricted to 0.2.6.0 and GHC 9.14.
  cborg-json = [{
    min = "0.2.6.0";
    max = "0.2.6.1";
    patch = import ../patches/cborg-json/0.2.6-ghc914.nix;
  }];
  cborg = [{
    min = "0.2.10.0";
    max = "0.2.10.1";
    patch = import ../patches/cborg/0.2.10-ghc914.nix;
  }];
  serialise = [{
    min = "0.2.6.1";
    max = "0.2.6.2";
    patch = import ../patches/serialise/0.2.6-ghc914.nix;
  }];
  shibuya-pgmq-adapter = [{
    min = "0.16.1.0";
    max = "0.16.1.1";
    patch = import ../patches/shibuya-pgmq-adapter/0.16.1-ghc914.nix;
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
  hasql = always doJailbreakOnly;
  postgresql-binary = always doJailbreakOnly;
  # The Configure provider discovers libpq outside its Cabal dependency fields.
  postgresql-libpq-configure = always ({ pkg, haskellLib, pkgs, ... }:
    haskellLib.overrideCabal
      (drv: {
        libraryPkgconfigDepends = (drv.libraryPkgconfigDepends or [ ]) ++ [ pkgs.libpq ];
      })
      pkg);
  hasql-pool = always doJailbreakOnly;
  hasql-transaction = always doJailbreakOnly;
  hasql-migration = always (import ../patches/hasql-migration/shinzui.nix);
  hasql-implicits = always doJailbreakOnly;
  hasql-dynamic-statements = always doJailbreakOnly;
  # Relax upstream adapter bounds against the shared Hasql cohort.
  hasql-notifications = always doJailbreakOnly;

  # ── codd (SQL migration tool; kiroku-store-migrations dependency) ──
  codd = always (import ../patches/codd/0.1.nix);
  # haxl (codd dependency) caps `time < 1.13`; GHC 9.12 ships time 1.14.
  haxl = always dontCheckDoJailbreak;

  # ── OpenTelemetry spec v1.40 family (pgmq-effectful 0.3+ dependency) ─
  # Keep bound repairs explicit for the generated family and thread utilities.
  thread-utils-finalizers = always dontCheckDoJailbreak;
  thread-utils-context = always dontCheckDoJailbreak;
  hs-opentelemetry-api-types = always doJailbreakOnly;
  hs-opentelemetry-api = always doJailbreakOnly;
  hs-opentelemetry-semantic-conventions = always doJailbreakOnly;
  hs-opentelemetry-otlp = always doJailbreakOnly;
  hs-opentelemetry-sdk = always doJailbreakOnly;
  hs-opentelemetry-exporter-handle = always doJailbreakOnly;
  hs-opentelemetry-exporter-in-memory = always doJailbreakOnly;
  hs-opentelemetry-exporter-otlp = always doJailbreakOnly;
  hs-opentelemetry-instrumentation-wai = always doJailbreakOnly;
  hs-opentelemetry-propagator-b3 = always doJailbreakOnly;
  hs-opentelemetry-propagator-datadog = always doJailbreakOnly;
  hs-opentelemetry-propagator-jaeger = always doJailbreakOnly;
  hs-opentelemetry-propagator-w3c = always doJailbreakOnly;
  hs-opentelemetry-propagator-xray = always doJailbreakOnly;

  # ── Provider clients and generated-family dependencies ─────────────
  claude = always doJailbreakOnly;
  # okf-core comes from the okf first-party family (packages/first-party-lock.json).

  # blake3 portable build for aarch64-darwin (shikumi-cache cache key).
  blake3 = always (import ../patches/blake3/portable.nix);
  openai = always doJailbreakOnly;
  # nixpkgs marks the Hackage cradle-0.0.0.0 broken; the library (all baikai
  # uses) builds with bounds relaxed and tests off.
  cradle = always markUnbrokenDontCheckDoJailbreak;
  # 3.2.x uses cryptohash-md5, avoiding the crypton memory/ram instance clash.
  wai-app-static = always doJailbreakOnly;
  # The original 0.20.3.0 metadata caps wai-app-static below 3.2.
  servant-server = always dontCheckDoJailbreak;

  # Shared application HTTP/utility policy belongs in the channel.
  # link-canonical 0.1.0.0 caps http-client-tls and generic-lens below this stack.
  link-canonical = always dontCheckDoJailbreak;
  # Kafka integration tests need a broker; use the maintained runtime source when selected.
  hw-kafka-client = always dontCheckDoJailbreak;
  servant-health = always doJailbreakOnly;

  # Public source pins: preserve their Cabal source-repository-package revisions.
  cmark-gfm = always (import ../patches/cmark-gfm/source.nix);
  typeid-hs-sql = always (import ../patches/typeid-hs/sql.nix);
  typeid-hs-pg-migrate = always (import ../patches/typeid-hs/pg-migrate.nix);
  hs-opentelemetry-instrumentation-servant = always (import ../patches/hs-opentelemetry-instrumentation-servant/source.nix);

  # ── shinzui event-sourcing stack ───────────────────────────────────
  # keiki and kioku are first-party families; their records are generated into
  # packages/first-party-lock.json rather than pinned here.

  # ── Cryptography/TLS build policy ─────────────────────────────────
  # Versions and sources are selected together by the generated cohort.
  # Keep test exclusions and bound repairs separate from those selections.
  ram = always dontCheckOnly;
  mlkem = always markUnbrokenDontCheck;
  tls = always doJailbreakOnly;
  # The session-manager bounds lag the shared cryptography/TLS API it uses.
  tls-session-manager = always doJailbreakOnly;
  crypton-connection = always doJailbreakOnly;
  http-client-tls = always doJailbreakOnly;

  # Retain the HTTP-conduit bound policy around the selected TLS dependency.
  http-conduit = always doJailbreakOnly;

  # dhall's `use-http-client-tls` flag pins http-client-tls <0.4. Relax the
  # bound rather than disabling the flag: without the flag every remote Dhall
  # import throws `TlsNotSupported` at runtime, on cache miss only.
  dhall = always (args: import ../patches/dhall/keep-http-client-tls.nix (args // {
    pkg = import ../patches/dhall/source.nix args;
  }));
  dhall-json = [{
    min = "1.7.12";
    max = "1.7.13";
    patch = import ../patches/dhall-json/cohort-bounds.nix;
  }];
  # dhall-1.42.3 depends on the latest Hackage repline release, 0.4.3.0.
  # That release caps containers below 0.8 even though its API usage remains
  # compatible; GHC 9.14.1 ships containers-0.8.
  repline = always doJailbreakOnly;

  # ── Ephemeral PostgreSQL integration-test policy ───────────────────
  # The cohort supplies the stable-root cleanup API; this row owns test policy.
  ephemeral-pg = always markUnbrokenDontCheck;

  # ── Version-scoped patches ────────────────────────────────────────
}
