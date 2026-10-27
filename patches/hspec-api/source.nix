# Heni's adapter uses the formatter API matching the already frozen hspec-core.
# Hspec is not present in the Mori corpus; upstream https://github.com/hspec/hspec.
{ hself, ... }:
hself.callHackageDirect
{
  pkg = "hspec-api";
  ver = "2.11.18";
  sha256 = "sha256-dFyNwoEuZfIYZ5xjYYEakjzYYVv5Cjd8rhISsMB41vk=";
}
{ }
