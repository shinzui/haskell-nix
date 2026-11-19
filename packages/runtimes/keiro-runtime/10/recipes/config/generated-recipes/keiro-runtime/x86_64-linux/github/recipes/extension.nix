# Generated raw recipe layer; compose the reviewed policy exactly once.
{ pkgs, haskellLib, policyExtension }:
assert pkgs.stdenv.hostPlatform.system == "x86_64-linux";
pkgs.lib.composeExtensions (final: _previous:
{
  "base64-bytestring" = assert final.ghc.version == "9.12.4"; haskellLib.overrideCabal (_: { revision = "1"; editedCabalFile = "45305ccf8914c66d385b518721472c7b8c858f1986945377f74f85c1e0d49803"; }) (final.callPackage ./packages/base64-bytestring.nix { src = pkgs.fetchzip { url = "mirror://hackage/base64-bytestring-1.2.1.0/base64-bytestring-1.2.1.0.tar.gz"; sha256 = "sha256-Oe2u9XbsjSFi10dsUqlZbjoz+Bl5jn+s3xTTCono/oE="; }; });
}) policyExtension
