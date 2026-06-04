# hs-opentelemetry — the OpenTelemetry spec v1.40 family, built from the upstream
# iand675/hs-opentelemetry source (the project released v1.40 as a major version;
# Hackage's old releases predate it). pgmq-effectful 0.3+ requires this family
# (>=1.40 semantic-conventions and the matching api that exports the v1.40
# Propagator names). thread-utils is the api's runtime dependency.
#
# The whole core family is built from one source rev so api / api-types /
# semantic-conventions / sdk / exporters / propagators stay internally
# consistent. The sdk's (disabled) test-suite still pulls every exporter and
# propagator as a cabal2nix argument, so they are all provided here.
{ hself, haskellLib, pkgs, ... }:

let
  inherit (haskellLib) doJailbreak dontCheck;

  hsOpenTelemetrySrc = pkgs.fetchFromGitHub {
    owner = "iand675";
    repo = "hs-opentelemetry";
    rev = "46a42cdf80405fdb36fbb48a309254b2332617b4";
    hash = "sha256-4wMAK3WtoSlyrP0IFWFNME///HIXdMZcPfH6ZKpkVfw=";
  };
  threadUtilsSrc = pkgs.fetchFromGitHub {
    owner = "iand675";
    repo = "thread-utils";
    rev = "519ff4613a5b5ee3904be7daefb94bf99ada5ee5";
    hash = "sha256-nlKK794LNHGjXKB1lhCkFJuCEyH+aiGOg6ljV4P1Ijw=";
  };

  pkg = name: subdir: dontCheck (doJailbreak (hself.callCabal2nix name (hsOpenTelemetrySrc + subdir) { }));
  tpkg = name: subdir: dontCheck (doJailbreak (hself.callCabal2nix name (threadUtilsSrc + subdir) { }));
in
{
  thread-utils-finalizers = tpkg "thread-utils-finalizers" "/thread-utils-finalizers";
  thread-utils-context = tpkg "thread-utils-context" "/thread-utils-context";

  hs-opentelemetry-api-types = pkg "hs-opentelemetry-api-types" "/api-types";
  hs-opentelemetry-api = pkg "hs-opentelemetry-api" "/api";
  hs-opentelemetry-semantic-conventions = pkg "hs-opentelemetry-semantic-conventions" "/semantic-conventions";
  hs-opentelemetry-otlp = pkg "hs-opentelemetry-otlp" "/otlp";
  hs-opentelemetry-sdk = pkg "hs-opentelemetry-sdk" "/sdk";

  hs-opentelemetry-exporter-handle = pkg "hs-opentelemetry-exporter-handle" "/exporters/handle";
  hs-opentelemetry-exporter-in-memory = pkg "hs-opentelemetry-exporter-in-memory" "/exporters/in-memory";
  hs-opentelemetry-exporter-otlp = pkg "hs-opentelemetry-exporter-otlp" "/exporters/otlp";

  hs-opentelemetry-propagator-b3 = pkg "hs-opentelemetry-propagator-b3" "/propagators/b3";
  hs-opentelemetry-propagator-datadog = pkg "hs-opentelemetry-propagator-datadog" "/propagators/datadog";
  hs-opentelemetry-propagator-jaeger = pkg "hs-opentelemetry-propagator-jaeger" "/propagators/jaeger";
  hs-opentelemetry-propagator-w3c = pkg "hs-opentelemetry-propagator-w3c" "/propagators/w3c";
  hs-opentelemetry-propagator-xray = pkg "hs-opentelemetry-propagator-xray" "/propagators/xray";
}
