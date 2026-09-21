{ ... }:
{
  projectRootFile = "flake.nix";
  # Keep the existing fleet formatter to avoid unrelated style migration.
  programs.nixpkgs-fmt.enable = true;
  settings.global.excludes = [ "agents/**" ".agents/**" ".direnv/**" "result*" ];
}
