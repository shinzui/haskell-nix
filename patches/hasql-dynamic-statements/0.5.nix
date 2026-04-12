{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "hasql-dynamic-statements";
  ver = "0.5.1";
  sha256 = "sha256-mKQNMjxS1NfvXsZ6tL8/9PmiiZ3Cfp15MKMMExYngI0=";
} {}))
