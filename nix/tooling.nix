{ inputs, self, ... }:
{
  perSystem = { pkgs, ... }:
    let
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs ../treefmt.nix;
    in
    {
      formatter = treefmt.config.build.wrapper;
      checks = {
        formatting = treefmt.config.build.check self;
        nix-unit = pkgs.runCommand "nix-unit-tests"
          {
            nativeBuildInputs = [ pkgs.nix-unit ];
          } ''
          export NIX_CONFIG="experimental-features = nix-command flakes"
          nix-unit --eval-store dummy:// --expr 'import ${self}/checks/unit.nix {
            lib = import ${inputs.nixpkgs}/lib;
          }'
          touch "$out"
        '';
      };
    };
}
