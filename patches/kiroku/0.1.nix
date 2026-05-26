# kiroku - shinzui/kiroku release source.
{ hself, haskellLib, pkgs, ... }:

let
  src = pkgs.fetchFromGitHub {
    owner = "shinzui";
    repo = "kiroku";
    rev = "62e41558f8bbf785a72ea2726c984a87726491a0";
    hash = "sha256-a+6ze5nz7lI1QhojkZ7UkRQh6SmpYOEmbOI6rKg0Wx0=";
  };
in
{
  kiroku-store = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store" (src + "/kiroku-store") { }));
  kiroku-store-migrations = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-store-migrations" (src + "/kiroku-store-migrations") { }));
  kiroku-test-support = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "kiroku-test-support" (src + "/kiroku-test-support") { }));
  shibuya-kiroku-adapter = haskellLib.dontCheck (haskellLib.doJailbreak (hself.callCabal2nix "shibuya-kiroku-adapter" (src + "/shibuya-kiroku-adapter") { }));
}
