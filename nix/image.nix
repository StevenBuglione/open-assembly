let
  pkgs = import ./pkgs.nix;
  packages = import ./packages.nix { inherit pkgs; };
  environment = import ./environment.nix { inherit pkgs; };
  root = pkgs.buildEnv {
    name = "open-assembly-toolchain-root";
    paths = packages;
    pathsToLink = [ "/bin" ];
    postBuild = ''
      mkdir -p "$out/share/open-assembly"
      ln -s "${environment.OPEN_ASSEMBLY_GLIB_HEADERS}" "$out/share/open-assembly/glib-headers"
      ln -s "${environment.OPEN_ASSEMBLY_GLIB_CONFIG}" "$out/share/open-assembly/glib-config"
      ln -s "${environment.OPEN_ASSEMBLY_LUA_SOURCE}" "$out/share/open-assembly/lua.tar.gz"
      ln -s "${environment.OPEN_ASSEMBLY_LUA_TESTS}" "$out/share/open-assembly/lua-tests.tar.gz"
      ln -s "${environment.OPEN_ASSEMBLY_BUSYBOX_SOURCE}" "$out/share/open-assembly/busybox.tar.bz2"
      ln -s "${environment.OPEN_ASSEMBLY_LIBC_TEST}" "$out/share/open-assembly/libc-test"
      ln -s "${environment.OPEN_ASSEMBLY_FLOAT_VECTORS}" "$out/share/open-assembly/float-vectors"
      ln -s "${environment.OPEN_ASSEMBLY_OPEN_POSIX}" "$out/share/open-assembly/open-posix.tar.gz"
      ln -s "${environment.OPEN_ASSEMBLY_VALGRIND_HEADERS}" "$out/share/open-assembly/valgrind-headers"
      ln -s "${environment.OPEN_ASSEMBLY_MPFR}" "$out/share/open-assembly/libmpfr.so.6"
    '';
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
