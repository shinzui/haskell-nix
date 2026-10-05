{ lib, pkgs, defaultGhc, haskellExtension }:
let
  scope = pkgs.haskell.packages.${defaultGhc}.override {
    overrides = haskellExtension pkgs.haskell.lib.compose pkgs;
  };
  minimumVersions = {
    blake3 = "0.3.1";
    generic-lens = "2.3.0.0";
    generic-lens-core = "2.3.0.0";
    hasql-notifications = "0.2.5.0";
    hs-opentelemetry-api = "1.0.0.0";
    hs-opentelemetry-api-types = "1.0.0.0";
    hs-opentelemetry-exporter-handle = "1.0.0.0";
    hs-opentelemetry-exporter-in-memory = "1.0.0.0";
    hs-opentelemetry-exporter-otlp = "1.0.0.0";
    hs-opentelemetry-instrumentation-servant = "0.3.0.0";
    hs-opentelemetry-instrumentation-wai = "1.0.0.0";
    hs-opentelemetry-otlp = "1.0.0.0";
    hs-opentelemetry-propagator-b3 = "1.0.0.0";
    hs-opentelemetry-propagator-datadog = "1.0.0.0";
    hs-opentelemetry-propagator-jaeger = "1.0.0.0";
    hs-opentelemetry-propagator-w3c = "1.0.0.0";
    hs-opentelemetry-propagator-xray = "1.0.0.0";
    hs-opentelemetry-sdk = "1.0.0.0";
    hs-opentelemetry-semantic-conventions = "1.40.0.0";
    hw-kafka-client = "5.3.0";
    link-canonical = "0.1.0.0";
    openapi-hs = "5.0.0";
    relay-pagination = "0.1.1.0";
    relay-pagination-conformance = "0.1.1.0";
    relay-pagination-hasql = "0.1.1.0";
    relay-pagination-servant = "0.1.1.0";
    servant-health = "0.1.0.0";
    servant-openapi-hs = "5.1.0";
    servant-server = "0.20.3.0";
    thread-utils-context = "0.4.1.0";
    thread-utils-finalizers = "0.1.1.0";
    typeid-hs-pg-migrate = "0.1.0.0";
    typeid-hs-sql = "0.1.0.0";
    wai-app-static = "3.2.1";
  };
  names = builtins.attrNames minimumVersions;
  versions = lib.genAttrs names (name: scope.${name}.version);
  belowMinimum = builtins.filter
    (name: !(lib.versionAtLeast versions.${name} minimumVersions.${name}))
    names;
  kiokuProfilingRedundant = scope.kioku-core.drvPath ==
    (pkgs.haskell.lib.compose.disableLibraryProfiling scope.kioku-core).drvPath;
  results = { inherit versions belowMinimum kiokuProfilingRedundant; };
in
assert belowMinimum == [ ];
assert kiokuProfilingRedundant;
pkgs.runCommand "shared-overrides"
{
  buildInputs = map (name: scope.${name}) names;
  passthru = { inherit results; };
} ''
  echo '${builtins.toJSON results}'
  touch "$out"
''
