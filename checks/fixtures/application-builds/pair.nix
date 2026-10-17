# Explicit per-copy experiment configuration; this file is outside owned sources.
{ source }:
import ./pilot.nix ((builtins.fromJSON
  (builtins.readFile (builtins.toPath source + "/.mp4-pilot.json"))) // { inherit source; })
