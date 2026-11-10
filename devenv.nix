{ pkgs, ... }:
{
  packages = import ./nix/packages.nix { inherit pkgs; };
  env = import ./nix/environment.nix { inherit pkgs; };
}
