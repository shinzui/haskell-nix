{ hself, haskellLib, ... }:

haskellLib.dontCheck (haskellLib.doJailbreak (hself.callHackageDirect
{
  pkg = "wai-app-static";
  ver = "3.1.9.1";
  sha256 = "1irlknakxl7dcwxxdw0iliql7xrbyssz4bdk18amr2xl2d0fcwzc";
}
{ }))
