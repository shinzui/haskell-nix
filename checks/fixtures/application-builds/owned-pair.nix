# Per-copy archived inputs exercise the producing project recipe and shared guard.
{ source }:
import ./owned.nix ((builtins.fromJSON
  (builtins.readFile (builtins.toPath source + "/.mp4-pilot.json"))) // { inherit source; })
