{ pkgs, ... }:
{
  packages = import ./nix/packages.nix { inherit pkgs; };
  env.LC_ALL = "C";
  env.PYTHONDONTWRITEBYTECODE = "1";
}
