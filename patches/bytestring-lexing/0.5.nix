# Released 0.5.0.16 admits GHC 9.14/base 4.22 without relaxing bounds.
# Retire this replacement once the selected package is already >= 0.5.0.16.
{ hself, ... }:
hself.callHackageDirect
{
  pkg = "bytestring-lexing";
  ver = "0.5.0.16";
  sha256 = "sha256-Fi3+KzDIHA6y/WZ8SVdBQhi9tHhHfw8qEcT6nvW4YXs=";
}
{ }
