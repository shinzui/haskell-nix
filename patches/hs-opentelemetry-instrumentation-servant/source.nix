# mori://shinzui/hs-opentelemetry-instrumentation-servant: retained MultiVerb/AuthProtect fork.
# Keep the source identical to the cohort source manifest and Cabal pin.
{ hself, haskellLib, pkgs, ... }:
haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix
  "hs-opentelemetry-instrumentation-servant"
  (pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "hs-opentelemetry-instrumentation-servant";
    rev = "7a6f692e85295f965cd1827f9354c28af9e62742";
    hash = "sha256-oi3E1KjZLdI7Ezahz/3khwS5uxoLNwrPCzRIO1m7/80=";
  })
{ }))
