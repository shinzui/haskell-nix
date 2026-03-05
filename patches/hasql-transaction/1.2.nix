# hasql-transaction 1.2.2 — pin from Hackage
{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect {
  pkg = "hasql-transaction";
  ver = "1.2.2";
  sha256 = "sha256-o53h6ly2Kukhw9dcyAOvywzwlZDdgb+b/jqbw72lLHg=";
} {}))
