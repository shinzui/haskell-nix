# hs-opentelemetry — the OpenTelemetry spec v1.40 family (the 1.0.0.0 release
# line, semantic-conventions 1.40.0.0), from Hackage. nixpkgs still ships the
# pre-1.0 releases (api 0.3.1.0, sdk 0.1.0.1). pgmq-effectful 0.3+ requires
# this family (>=1.40 semantic-conventions and the matching api that exports the
# v1.40 Propagator names). Its runtime dependency thread-utils-context 0.4.1.0
# already ships in nixpkgs (see ../../overlays/registry.nix).
#
# The whole core family is pinned to one release line so api / api-types /
# semantic-conventions / sdk / exporters / propagators stay internally
# consistent. The sdk's (disabled) test-suite still pulls every exporter and
# propagator as a cabal2nix argument, so they are all provided here.
{ hself, haskellLib, ... }:

let
  inherit (haskellLib) doJailbreak dontCheck;

  hackage = pkg: ver: sha256:
    dontCheck (doJailbreak (hself.callHackageDirect { inherit pkg ver sha256; } { }));
in
{
  hs-opentelemetry-api-types = hackage "hs-opentelemetry-api-types" "1.0.0.0" "sha256-9ByP41wlV45TMCqbyyVpwejQDi5fsG0+j8bMk8ORLw8=";
  hs-opentelemetry-api = hackage "hs-opentelemetry-api" "1.0.0.0" "sha256-COhj9Ms1eu1Gt9wTC21oQ37k6vJ9mxlJvYpHtvXff6A=";
  hs-opentelemetry-semantic-conventions = hackage "hs-opentelemetry-semantic-conventions" "1.40.0.0" "sha256-7cIC9dTrd5bJjAsiEyyupi1xSZyc17FpjbACnm0p5ik=";
  hs-opentelemetry-otlp = hackage "hs-opentelemetry-otlp" "1.0.0.0" "sha256-kVuKKi6qRx+oBQclTpUnx20Eqw+CRQk8pT4tkcxt1xo=";
  hs-opentelemetry-sdk = hackage "hs-opentelemetry-sdk" "1.0.0.0" "sha256-kG8gmP8Lr9mPCnJjukCduFI/tADgKCfuelxcQZcXyA8=";

  hs-opentelemetry-exporter-handle = hackage "hs-opentelemetry-exporter-handle" "1.0.0.0" "sha256-DCoVG0Y2aaMjinOP2GWmew0WmjN96j3/UUzEWxN7Ajs=";
  hs-opentelemetry-exporter-in-memory = hackage "hs-opentelemetry-exporter-in-memory" "1.0.0.0" "sha256-bJjUHBNMRKhmkqRRnUrAQIDLWpUrox7F418r2QbVQ6o=";
  hs-opentelemetry-exporter-otlp = hackage "hs-opentelemetry-exporter-otlp" "1.0.0.0" "sha256-rHgsisH2d45CI9woEDb/j0WnTzllxaE2Mkx5/OmWn0c=";

  # mori://iand675/hs-opentelemetry/packages/hs-opentelemetry-instrumentation-wai
  hs-opentelemetry-instrumentation-wai = hackage "hs-opentelemetry-instrumentation-wai" "1.0.0.0" "sha256-gPU9k2H1MpMEGh0F1Oi5ri8gdsZMCvQBRTnXgDhVAa0=";

  hs-opentelemetry-propagator-b3 = hackage "hs-opentelemetry-propagator-b3" "1.0.0.0" "sha256-gsNe818CprXM9l61mLUsdnePxIQChfml9kegmCDoAmw=";
  hs-opentelemetry-propagator-datadog = hackage "hs-opentelemetry-propagator-datadog" "1.0.0.0" "sha256-nTXEtira3bktvycZkjDmPZewyMJ1IEEDygLT9OiIFYo=";
  hs-opentelemetry-propagator-jaeger = hackage "hs-opentelemetry-propagator-jaeger" "1.0.0.0" "sha256-VL+3YwKbqe0elfZQ0EN7icNS0+pxmtlxlKauPHRqhb8=";
  hs-opentelemetry-propagator-w3c = hackage "hs-opentelemetry-propagator-w3c" "1.0.0.0" "sha256-p8d2Tx8bCVRk6hps8k0qAg/L2gdBVoYuLYJbTzTbI3s=";
  hs-opentelemetry-propagator-xray = hackage "hs-opentelemetry-propagator-xray" "1.0.0.0" "sha256-Tg7TrCMb8GA+jm+ohMAqMW7othRm/HLEyr9SifGa6qI=";
}
