{ withOldKernel ? false }:
let
  pkgs = import ./pkgs.nix;
  packages = (import ./packages.nix { inherit pkgs; }) ++ pkgs.lib.optional withOldKernel pkgs.qemu_kvm;
  environment = (import ./environment.nix { inherit pkgs; }) // pkgs.lib.optionalAttrs withOldKernel {
    OPEN_ASSEMBLY_OLD_KERNEL = "${import ./old-kernel.nix { inherit pkgs; }}";
  };
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
      ln -s "${environment.OPEN_ASSEMBLY_ZLIB_SOURCE}" "$out/share/open-assembly/zlib.tar.gz"
      ln -s "${environment.OPEN_ASSEMBLY_SQLITE_SOURCE}" "$out/share/open-assembly/sqlite-source.zip"
      ln -s "${environment.OPEN_ASSEMBLY_SQLITE_AMALGAMATION}" "$out/share/open-assembly/sqlite-amalgamation.zip"
      ln -s "${environment.OPEN_ASSEMBLY_BUSYBOX_SOURCE}" "$out/share/open-assembly/busybox.tar.bz2"
      ln -s "${environment.OPEN_ASSEMBLY_LIBC_TEST}" "$out/share/open-assembly/libc-test"
      ln -s "${environment.OPEN_ASSEMBLY_FLOAT_VECTORS}" "$out/share/open-assembly/float-vectors"
      ln -s "${environment.OPEN_ASSEMBLY_OPEN_POSIX}" "$out/share/open-assembly/open-posix.tar.gz"
      ln -s "${environment.OPEN_ASSEMBLY_GNULIB}" "$out/share/open-assembly/gnulib.tar.gz"
      ln -s "${environment.OPEN_ASSEMBLY_JSON_TESTS}" "$out/share/open-assembly/json-tests.tar.gz"
      ln -s "${environment.OPEN_ASSEMBLY_VALGRIND_HEADERS}" "$out/share/open-assembly/valgrind-headers"
      ln -s "${environment.OPEN_ASSEMBLY_MPFR}" "$out/share/open-assembly/libmpfr.so.6"
    '' + pkgs.lib.optionalString withOldKernel ''
      ln -s "${environment.OPEN_ASSEMBLY_OLD_KERNEL}" "$out/share/open-assembly/old-kernel"
    '';
  };
in pkgs.dockerTools.buildLayeredImage {
  name = if withOldKernel then "open-assembly-old-kernel-toolchain" else "open-assembly-toolchain";
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
