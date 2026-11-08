# mori://shinzui/typeid-hs: public source; anonymous hash verified 2026-10-05.
# This revision must equal the applications' Cabal source-repository-package tag.
{ pkgs, ... }:
pkgs.fetchFromGitHub {
  owner = "topagentnetwork";
  repo = "typeid-hs";
  rev = "7164a74c490cc92ffe73a315d827c9515de125d3";
  hash = "sha256-XCq5GXlOK8ZxbR4ZKIEi99rQdJ6vxX1c6/C3nRGvcrA=";
}
