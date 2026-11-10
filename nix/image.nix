let
  pkgs = import ./pkgs.nix;
  packages = import ./packages.nix { inherit pkgs; };
  environment = import ./environment.nix { inherit pkgs; };
  root = pkgs.buildEnv {
    name = "open-assembly-toolchain-root";
    paths = packages;
    pathsToLink = [ "/bin" ];
  };
in pkgs.dockerTools.buildLayeredImage {
  name = "open-assembly-toolchain";
  contents = [ root ];
  extraCommands = ''
    mkdir -p tmp work usr/bin
    chmod 1777 tmp
    ln -s /bin/env usr/bin/env
  '';
  config = {
    WorkingDir = "/work";
    Env = [ "PATH=/bin" ] ++ pkgs.lib.mapAttrsToList (name: value: "${name}=${value}") environment;
    Cmd = [ "/bin/bash" ];
  };
}
