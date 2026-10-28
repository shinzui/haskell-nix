# Select inside a package attribute value. Always rows must remain lazy in the
# resolved version: source-replacing recipes may not have a base package at all.
{ lib }:
entries: facts:
let
  always = lib.findFirst (entry: entry.always or false) null entries;
in
if always != null then always else
lib.findFirst
  (entry: !(entry.always or false)
    && lib.versionAtLeast facts.version entry.min
    && lib.versionOlder facts.version entry.max)
  null
  entries
