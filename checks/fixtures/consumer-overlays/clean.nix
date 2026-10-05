{ pkgs }:
final: prev: {
  consumer-overlay-example = final.callCabal2nix "package-set-consumer" ../package-sets/consumer { };
}
