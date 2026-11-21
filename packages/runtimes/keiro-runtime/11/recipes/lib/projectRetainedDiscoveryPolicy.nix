# Live validation owns discovery policy. Older captured constructors only use
# locked package paths, and their exact-field decoders predate nested discovery.
# Project this metadata at the constructor boundary without rewriting snapshots.
{ config, lock }:
{
  config = config // {
    families = map (family: builtins.removeAttrs family [ "additionalPackagePaths" ]) config.families;
  };
  lock = lock // {
    familySnapshots = map
      (snapshot: snapshot // {
        discoveryPolicy = builtins.removeAttrs snapshot.discoveryPolicy [ "additionalPackagePaths" ];
      })
      lock.familySnapshots;
  };
}
